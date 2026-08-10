import asyncio
import hashlib
import json
import math
import os
import shutil
import subprocess
from pathlib import Path
from types import SimpleNamespace
from typing import Callable

import pytest

import server as wrapper
from server import _patch_upstream


PLY = b"""ply
format ascii 1.0
element vertex 1
property float x
property float y
property float z
end_header
0 0 0
"""


class FakeUpstream:
    def __init__(
        self,
        binary: str | None,
        *,
        output_mode: str = "success",
        returncode: int = 0,
        validation_returncode: int = 0,
        load_error: bool = False,
        has_normals: bool = True,
        normals_tools: int = 1,
        on_primary_run: Callable[[list[str]], None] | None = None,
        external_target: Path | None = None,
    ) -> None:
        self.binary = binary
        self.output_mode = output_mode
        self.returncode = returncode
        self.validation_returncode = validation_returncode
        self.load_error = load_error
        self.has_normals = has_normals
        self.on_primary_run = on_primary_run
        self.external_target = external_target
        self.cc_calls: list[list[str]] = []
        self.handle_get_cloudcompare_info = lambda _args: self._err("unpatched")
        self.handle_compute_normals = lambda _args: self._err("unpatched")
        normal_tool = SimpleNamespace(
            name="compute_normals",
            description="upstream schema",
            inputSchema={
                "type": "object",
                "properties": {
                    "input_path": {"type": "string"},
                    "output_path": {"type": "string"},
                    "mode": {"type": "string"},
                    "radius": {"type": "number"},
                    "knn": {"type": "integer"},
                },
                "required": ["input_path", "output_path"],
            },
        )
        self.TOOLS = [normal_tool for _ in range(normals_tools)] + [
            SimpleNamespace(name="other_tool", description="unchanged", inputSchema={})
        ]

    def find_cloudcompare(self) -> str | None:
        return self.binary

    def _ok(self, data: dict[str, object]) -> list[SimpleNamespace]:
        return [SimpleNamespace(text=json.dumps(data))]

    def _err(self, message: str) -> list[SimpleNamespace]:
        return [SimpleNamespace(text=json.dumps({"error": message}))]

    def _run_result(
        self,
        rc: int,
        stdout: str,
        stderr: str,
        extra: dict | None = None,
    ) -> list[SimpleNamespace]:
        result = {
            "returncode": rc,
            "stdout": stdout or "(none)",
            "stderr": stderr or "(none)",
            "success": rc == 0,
        }
        if extra:
            result.update(extra)
        return self._ok(result)

    def _ensure_output_dir(self, path: str) -> None:
        Path(path).parent.mkdir(parents=True, exist_ok=True)

    def _ext_flag(self, path: str) -> str:
        return {".ply": "PLY", ".las": "LAS", ".e57": "E57"}.get(
            Path(path).suffix.lower(), "PLY"
        )

    def _load_cloud(self, path: str) -> tuple[list, None, dict]:
        if self.load_error:
            raise ValueError("unreadable staged cloud")
        if not Path(path).read_bytes():
            raise ValueError("empty staged cloud")
        return [], None, {"has_normals": self.has_normals}

    def cc_run(self, args: list[str]) -> tuple[int, str, str]:
        self.cc_calls.append(args)
        if "FILE" not in args:
            return self.validation_returncode, "validation stdout", "validation stderr"

        output = Path(args[args.index("FILE") + 1])
        if self.output_mode == "success":
            output.write_bytes(PLY)
        elif self.output_mode == "empty":
            output.write_bytes(b"")
        elif self.output_mode == "partial":
            output.write_bytes(b"partial")
        elif self.output_mode == "sidecar":
            output.write_bytes(PLY)
            output.with_name("sidecar.bin").write_bytes(b"sidecar")
        elif self.output_mode == "symlink":
            assert self.external_target is not None
            output.unlink(missing_ok=True)
            output.symlink_to(self.external_target)
        if self.on_primary_run is not None:
            self.on_primary_run(args)
        return self.returncode, "stdout", "stderr"

    async def call_tool(self, name: str, arguments: dict) -> list[SimpleNamespace]:
        dispatch = {
            "get_cloudcompare_info": self.handle_get_cloudcompare_info,
            "compute_normals": self.handle_compute_normals,
        }
        return dispatch[name](arguments)


class CloudCompareUpstream(FakeUpstream):
    def __init__(self, binary: str) -> None:
        super().__init__(binary)

    def cc_run(self, args: list[str]) -> tuple[int, str, str]:
        self.cc_calls.append(args)
        result = subprocess.run(
            [self.binary, "-SILENT", *args],
            capture_output=True,
            text=True,
            env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
        )
        return result.returncode, result.stdout, result.stderr

    def _load_cloud(self, path: str) -> tuple[list, None, dict]:
        header = (
            Path(path)
            .read_bytes()
            .split(b"end_header", 1)[0]
            .decode("ascii", errors="ignore")
        )
        properties = {
            line.split()[-1]
            for line in header.splitlines()
            if line.startswith("property ")
        }
        return [], None, {"has_normals": {"nx", "ny", "nz"}.issubset(properties)}


def call_info(upstream: FakeUpstream) -> dict[str, object]:
    result = asyncio.run(upstream.call_tool("get_cloudcompare_info", {}))
    return json.loads(result[0].text)


def call_normals(upstream: FakeUpstream, arguments: dict) -> dict[str, object]:
    result = asyncio.run(upstream.call_tool("compute_normals", arguments))
    return json.loads(result[0].text)


def source_file(tmp_path: Path) -> Path:
    source = tmp_path / "source.ply"
    source.write_bytes(PLY)
    return source


def staging_entries(*directories: Path) -> list[Path]:
    return [
        entry
        for directory in directories
        if directory.exists()
        for entry in directory.glob(".*-staging-*")
    ]


def test_patched_dispatch_reports_nix_version_and_binary(monkeypatch) -> None:
    wrapper = Path(__file__).resolve().parents[1] / "default.nix"
    assert 'export QT_QPA_PLATFORM="offscreen"' in wrapper.read_text(encoding="utf-8")

    monkeypatch.setenv("CLOUDCOMPARE_VERSION", "2.13.2")
    upstream = FakeUpstream("/run/current-system/sw/bin/CloudCompare")
    _patch_upstream(upstream)
    assert call_info(upstream) == {
        "binary": "/run/current-system/sw/bin/CloudCompare",
        "platform": "Linux",
        "version": "2.13.2",
        "ready": True,
    }


def test_patched_dispatch_rejects_missing_binary(monkeypatch) -> None:
    monkeypatch.setenv("CLOUDCOMPARE_VERSION", "2.13.2")
    upstream = FakeUpstream(None)
    _patch_upstream(upstream)
    assert "CloudCompare executable not found" in call_info(upstream)["error"]


@pytest.mark.parametrize("version", [None, ""])
def test_patched_dispatch_rejects_missing_version(monkeypatch, version) -> None:
    if version is None:
        monkeypatch.delenv("CLOUDCOMPARE_VERSION", raising=False)
    else:
        monkeypatch.setenv("CLOUDCOMPARE_VERSION", version)
    upstream = FakeUpstream("/run/current-system/sw/bin/CloudCompare")
    _patch_upstream(upstream)
    assert "CLOUDCOMPARE_VERSION is not set" in call_info(upstream)["error"]


@pytest.mark.parametrize("normals_tools", [0, 2])
def test_patch_requires_exactly_one_compute_normals_tool(normals_tools: int) -> None:
    upstream = FakeUpstream("/bin/CloudCompare", normals_tools=normals_tools)
    with pytest.raises(RuntimeError, match="exactly one compute_normals"):
        _patch_upstream(upstream)
    assert upstream.handle_compute_normals({})[0].text == json.dumps(
        {"error": "unpatched"}
    )


def test_compute_normals_schema_is_closed_and_removes_knn() -> None:
    upstream = FakeUpstream("/bin/CloudCompare")
    original_other_tool = upstream.TOOLS[1]
    _patch_upstream(upstream)
    tool = next(tool for tool in upstream.TOOLS if tool.name == "compute_normals")
    properties = tool.inputSchema["properties"]
    assert tool.inputSchema["additionalProperties"] is False
    assert "knn" not in properties
    assert "source coordinate units" in properties["radius"]["description"]
    assert "auto" in properties["radius"]["description"]
    output_description = properties["output_path"]["description"]
    assert "only PLY" in output_description
    assert "LAS" not in output_description
    assert "LAZ" not in output_description
    assert "PCD" not in output_description
    assert tool.inputSchema["required"] == ["input_path", "output_path"]
    assert upstream.TOOLS[1] is original_other_tool


@pytest.mark.parametrize(
    "arguments",
    [
        {"input_path": "source.ply", "output_path": "/tmp/out.ply"},
        {"input_path": "/tmp/source.ply", "output_path": "out.ply"},
    ],
)
def test_compute_normals_rejects_relative_paths_without_cc_run(
    arguments: dict,
) -> None:
    upstream = FakeUpstream("/bin/CloudCompare", output_mode="none")
    _patch_upstream(upstream)
    assert "absolute" in call_normals(upstream, arguments)["error"]
    assert upstream.cc_calls == []


def test_compute_normals_rejects_missing_input_without_cc_run(tmp_path: Path) -> None:
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)
    missing = tmp_path / "missing.ply"
    result = call_normals(
        upstream,
        {"input_path": str(missing), "output_path": str(tmp_path / "out.ply")},
    )
    assert str(missing) in result["error"]
    assert upstream.cc_calls == []


def test_compute_normals_rejects_non_regular_input_without_cc_run(
    tmp_path: Path,
) -> None:
    source_directory = tmp_path / "source.ply"
    source_directory.mkdir()
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)
    result = call_normals(
        upstream,
        {
            "input_path": str(source_directory),
            "output_path": str(tmp_path / "out.ply"),
        },
    )
    assert "regular file" in result["error"]
    assert upstream.cc_calls == []


def test_compute_normals_rejects_missing_output_parent_without_cc_run(
    tmp_path: Path,
) -> None:
    source = source_file(tmp_path)
    destination = tmp_path / "missing" / "out.ply"
    upstream = FakeUpstream("/bin/CloudCompare", output_mode="none")
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )
    assert "parent" in result["error"].lower()
    assert not destination.parent.exists()
    assert upstream.cc_calls == []


def test_compute_normals_rejects_unsupported_output_suffix_without_cc_run(
    tmp_path: Path,
) -> None:
    source = source_file(tmp_path)
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)
    result = call_normals(
        upstream,
        {"input_path": str(source), "output_path": str(tmp_path / "out.invalid")},
    )
    assert "unsupported" in result["error"].lower()
    assert upstream.cc_calls == []


def test_compute_normals_rejects_same_input_and_output_without_cc_run(
    tmp_path: Path,
) -> None:
    source = source_file(tmp_path)
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(source)}
    )
    assert "different" in result["error"].lower()
    assert upstream.cc_calls == []


def test_compute_normals_rejects_existing_destination_without_cc_run(
    tmp_path: Path,
) -> None:
    source = source_file(tmp_path)
    destination = tmp_path / "out.ply"
    destination.write_bytes(b"old")
    upstream = FakeUpstream("/bin/CloudCompare", output_mode="none")
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )
    assert "already exists" in result["error"]
    assert destination.read_bytes() == b"old"
    assert upstream.cc_calls == []


def test_compute_normals_rejects_dangling_output_symlink_without_cc_run(
    tmp_path: Path,
) -> None:
    source = source_file(tmp_path)
    destination = tmp_path / "out.ply"
    target = tmp_path / "missing-target"
    destination.symlink_to(target)
    upstream = FakeUpstream("/bin/CloudCompare", output_mode="none")
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )
    assert "already exists" in result["error"]
    assert not target.exists()
    assert upstream.cc_calls == []


def test_compute_normals_rejects_output_hardlink_to_input_without_cc_run(
    tmp_path: Path,
) -> None:
    source = source_file(tmp_path)
    destination = tmp_path / "out.ply"
    os.link(source, destination)
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )
    assert "alias" in result["error"] or "already exists" in result["error"]
    assert upstream.cc_calls == []


def test_compute_normals_rejects_output_parent_symlink_component_without_cc_run(
    tmp_path: Path,
) -> None:
    source = source_file(tmp_path)
    real_parent = tmp_path / "real"
    real_parent.mkdir()
    linked_parent = tmp_path / "linked"
    linked_parent.symlink_to(real_parent, target_is_directory=True)
    upstream = FakeUpstream("/bin/CloudCompare", output_mode="none")
    _patch_upstream(upstream)
    result = call_normals(
        upstream,
        {
            "input_path": str(source),
            "output_path": str(linked_parent / "out.ply"),
        },
    )
    assert "symlink" in result["error"].lower()
    assert upstream.cc_calls == []


@pytest.mark.parametrize(
    ("mode", "cloudcompare_mode"),
    [("LS", "LS"), ("QUADRIC", "QUADRIC"), ("TRIANGULATION", "TRI")],
)
def test_compute_normals_maps_modes_and_writes_only_to_staging(
    tmp_path: Path,
    mode: str,
    cloudcompare_mode: str,
) -> None:
    source = source_file(tmp_path)
    destination = tmp_path / f"{mode.lower()}.ply"
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)
    result = call_normals(
        upstream,
        {"input_path": str(source), "output_path": str(destination), "mode": mode},
    )
    argv = upstream.cc_calls[0]
    staged_path = argv[-1]
    assert result["success"] is True
    assert result["output"] == str(destination)
    assert argv == [
        "-AUTO_SAVE",
        "OFF",
        "-O",
        str(source),
        "-OCTREE_NORMALS",
        "auto",
        "-MODEL",
        cloudcompare_mode,
        "-C_EXPORT_FMT",
        "PLY",
        "-SAVE_CLOUDS",
        "FILE",
        staged_path,
    ]
    assert staged_path != str(destination)
    assert "/proc/" in staged_path and "/fd/" in staged_path


def test_compute_normals_passes_radius_positionally(tmp_path: Path) -> None:
    source = source_file(tmp_path)
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)
    result = call_normals(
        upstream,
        {
            "input_path": str(source),
            "output_path": str(tmp_path / "out.ply"),
            "radius": 2.0,
        },
    )
    assert result["success"] is True
    argv = upstream.cc_calls[0]
    assert argv[argv.index("-OCTREE_NORMALS") + 1] == "2.0"
    assert not {"-COMPUTE_NORMALS", "-RADIUS", "-KNN"}.intersection(argv)


def test_compute_normals_rejects_legacy_knn_without_cc_run(tmp_path: Path) -> None:
    source = source_file(tmp_path)
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)
    result = call_normals(
        upstream,
        {
            "input_path": str(source),
            "output_path": str(tmp_path / "out.ply"),
            "knn": 12,
        },
    )
    assert "knn" in result["error"]
    assert upstream.cc_calls == []


@pytest.mark.parametrize("radius", [0, -1, math.inf, -math.inf, math.nan, True, "2.0"])
def test_compute_normals_rejects_invalid_radius_without_cc_run(
    tmp_path: Path, radius: object
) -> None:
    source = source_file(tmp_path)
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)
    result = call_normals(
        upstream,
        {
            "input_path": str(source),
            "output_path": str(tmp_path / "out.ply"),
            "radius": radius,
        },
    )
    assert "radius" in result["error"]
    assert upstream.cc_calls == []


def test_rc_zero_without_new_staging_output_does_not_publish(tmp_path: Path) -> None:
    source = source_file(tmp_path)
    destination = tmp_path / "out.ply"
    upstream = FakeUpstream("/bin/CloudCompare", output_mode="none")
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )
    assert "did not create" in result["error"] or "nonempty" in result["error"]
    assert not destination.exists()
    assert staging_entries(tmp_path) == []


@pytest.mark.parametrize("output_mode", ["empty", "sidecar"])
def test_invalid_staging_output_is_rejected_and_cleaned(
    tmp_path: Path, output_mode: str
) -> None:
    source = source_file(tmp_path)
    destination = tmp_path / "out.ply"
    upstream = FakeUpstream("/bin/CloudCompare", output_mode=output_mode)
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )
    assert "error" in result
    assert not destination.exists()
    assert staging_entries(tmp_path) == []


def test_failed_cloudcompare_cleans_partial_staging_without_publishing(
    tmp_path: Path,
) -> None:
    source = source_file(tmp_path)
    destination = tmp_path / "out.ply"
    upstream = FakeUpstream("/bin/CloudCompare", output_mode="partial", returncode=1)
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )
    assert result["success"] is False
    assert not destination.exists()
    assert staging_entries(tmp_path) == []


def test_unreadable_native_staging_output_is_not_published(tmp_path: Path) -> None:
    source = source_file(tmp_path)
    destination = tmp_path / "out.ply"
    upstream = FakeUpstream("/bin/CloudCompare", load_error=True)
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )
    assert "validation" in result["error"].lower()
    assert not destination.exists()
    assert staging_entries(tmp_path) == []


def test_readable_output_without_normals_is_not_published(
    tmp_path: Path,
) -> None:
    source = source_file(tmp_path)
    destination = tmp_path / "out.ply"
    upstream = FakeUpstream("/bin/CloudCompare", has_normals=False)
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )
    assert "does not contain normals" in result["error"]
    assert not destination.exists()
    assert staging_entries(tmp_path) == []


def test_readable_output_with_normals_is_published(
    tmp_path: Path,
) -> None:
    source = source_file(tmp_path)
    destination = tmp_path / "out.ply"
    upstream = FakeUpstream("/bin/CloudCompare", has_normals=True)
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )
    assert result["success"] is True
    assert destination.is_file()
    assert staging_entries(tmp_path) == []


@pytest.mark.parametrize(
    "suffix",
    [".las", ".laz", ".pcd", ".xyz", ".asc", ".txt", ".e57", ".obj", ".bin"],
)
def test_all_normals_output_formats_except_ply_are_rejected(
    tmp_path: Path, suffix: str
) -> None:
    source = source_file(tmp_path)
    destination = tmp_path / f"out{suffix}"
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )
    assert "unsupported" in result["error"].lower()
    assert upstream.cc_calls == []
    assert not destination.exists()


def test_real_cloudcompare_ply_contract_preserves_verifiable_normals(
    tmp_path: Path,
) -> None:
    configured = os.environ.get("CLOUDCOMPARE_PATH")
    binary = configured if configured and Path(configured).is_file() else None
    binary = binary or shutil.which("CloudCompare") or shutil.which("cloudcompare")
    if binary is None:
        pytest.skip("CloudCompare executable is not available")

    source = tmp_path / "grid.ply"
    points = [f"{x} {y} {0.001 * ((x + y) % 3)}" for y in range(10) for x in range(10)]
    source.write_text(
        "\n".join(
            [
                "ply",
                "format ascii 1.0",
                f"element vertex {len(points)}",
                "property float x",
                "property float y",
                "property float z",
                "end_header",
                *points,
                "",
            ]
        ),
        encoding="ascii",
    )
    destination = tmp_path / "normals.ply"
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    upstream = CloudCompareUpstream(binary)
    _patch_upstream(upstream)

    result = call_normals(
        upstream,
        {
            "input_path": str(source),
            "output_path": str(destination),
            "mode": "LS",
        },
    )

    assert result["success"] is True
    assert destination.is_file()
    assert upstream._load_cloud(str(destination))[2]["has_normals"] is True
    assert hashlib.sha256(source.read_bytes()).hexdigest() == source_hash
    assert staging_entries(tmp_path) == []


def test_success_preserves_source_and_atomically_publishes_output(
    tmp_path: Path,
) -> None:
    source = source_file(tmp_path)
    destination = tmp_path / "out.ply"
    before_bytes = source.read_bytes()
    before_hash = hashlib.sha256(before_bytes).hexdigest()
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )
    assert result["success"] is True
    assert destination.read_bytes() == PLY
    assert source.read_bytes() == before_bytes
    assert hashlib.sha256(source.read_bytes()).hexdigest() == before_hash
    assert source.stat().st_ino != destination.stat().st_ino
    assert staging_entries(tmp_path) == []


def test_destination_race_at_commit_is_no_clobber_and_cleans_staging(
    tmp_path: Path,
) -> None:
    source = source_file(tmp_path)
    destination = tmp_path / "out.ply"

    def create_racer(_args: list[str]) -> None:
        destination.write_bytes(b"racer")

    upstream = FakeUpstream("/bin/CloudCompare", on_primary_run=create_racer)
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )
    assert "already exists" in result["error"]
    assert destination.read_bytes() == b"racer"
    assert staging_entries(tmp_path) == []


def test_source_mutation_during_cc_run_aborts_without_output(tmp_path: Path) -> None:
    source = source_file(tmp_path)
    destination = tmp_path / "out.ply"

    def mutate_source(_args: list[str]) -> None:
        source.write_bytes(b"mutated")

    upstream = FakeUpstream("/bin/CloudCompare", on_primary_run=mutate_source)
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )
    assert "source file identity changed" in result["error"]
    assert not destination.exists()
    assert staging_entries(tmp_path) == []


def test_same_size_source_mutation_with_restored_mtime_is_detected(
    tmp_path: Path,
) -> None:
    source = source_file(tmp_path)
    destination = tmp_path / "out.ply"

    def mutate_source_without_metadata_change(_args: list[str]) -> None:
        before = source.stat()
        content = source.read_bytes()
        source.write_bytes(bytes([content[0] ^ 1]) + content[1:])
        os.utime(source, ns=(before.st_atime_ns, before.st_mtime_ns))

    upstream = FakeUpstream(
        "/bin/CloudCompare", on_primary_run=mutate_source_without_metadata_change
    )
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )
    assert "source file digest changed" in result["error"]
    assert not destination.exists()
    assert staging_entries(tmp_path) == []


def test_parent_identity_change_before_publish_aborts_without_output(
    tmp_path: Path,
) -> None:
    source = source_file(tmp_path)
    output_parent = tmp_path / "output"
    output_parent.mkdir()
    moved_parent = tmp_path / "moved-output"
    destination = output_parent / "out.ply"

    def replace_parent(_args: list[str]) -> None:
        output_parent.rename(moved_parent)
        output_parent.mkdir()

    upstream = FakeUpstream("/bin/CloudCompare", on_primary_run=replace_parent)
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )
    assert "directory identity changed" in result["error"]
    assert not destination.exists()
    assert not (moved_parent / destination.name).exists()
    assert staging_entries(output_parent, moved_parent) == []


def test_parent_identity_change_after_link_rolls_back_bound_destination(
    tmp_path: Path, monkeypatch
) -> None:
    source = source_file(tmp_path)
    output_parent = tmp_path / "output"
    output_parent.mkdir()
    moved_parent = tmp_path / "moved-output"
    destination = output_parent / "out.ply"
    real_link = os.link

    def link_then_replace(*args, **kwargs) -> None:
        real_link(*args, **kwargs)
        output_parent.rename(moved_parent)
        output_parent.mkdir()

    monkeypatch.setattr(wrapper.os, "link", link_then_replace)
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )
    assert "directory identity changed" in result["error"]
    assert not destination.exists()
    assert not (moved_parent / destination.name).exists()
    assert staging_entries(output_parent, moved_parent) == []


def test_generic_post_link_error_rolls_back_published_destination(
    tmp_path: Path, monkeypatch
) -> None:
    source = source_file(tmp_path)
    destination = tmp_path / "out.ply"
    real_link = os.link
    real_stat = os.stat
    linked = False

    def tracked_link(*args, **kwargs) -> None:
        nonlocal linked
        real_link(*args, **kwargs)
        linked = True

    def fail_first_post_link_stat(path, *args, **kwargs):
        if linked and path == destination.name and kwargs.get("dir_fd") is not None:
            raise OSError("injected post-link stat failure")
        return real_stat(path, *args, **kwargs)

    monkeypatch.setattr(wrapper.os, "link", tracked_link)
    monkeypatch.setattr(wrapper.os, "stat", fail_first_post_link_stat)
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )
    assert "injected post-link stat failure" in result["error"]
    assert not destination.exists()
    assert staging_entries(tmp_path) == []


def test_staging_temp_symlink_is_rejected_without_external_target_write(
    tmp_path: Path,
) -> None:
    source = source_file(tmp_path)
    destination = tmp_path / "out.ply"
    external_target = tmp_path / "external.ply"
    external_target.write_bytes(b"protected")
    upstream = FakeUpstream(
        "/bin/CloudCompare",
        output_mode="symlink",
        external_target=external_target,
    )
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )
    assert "staging output" in result["error"].lower()
    assert external_target.read_bytes() == b"protected"
    assert not destination.exists()
    assert staging_entries(tmp_path) == []


def test_post_commit_cleanup_failure_returns_success_warning_and_destination(
    tmp_path: Path, monkeypatch
) -> None:
    source = source_file(tmp_path)
    destination = tmp_path / "out.ply"
    real_rmdir = os.rmdir

    def fail_staging_rmdir(path, *args, **kwargs) -> None:
        if "-staging-" in os.fspath(path):
            raise OSError("injected cleanup failure")
        real_rmdir(path, *args, **kwargs)

    monkeypatch.setattr(wrapper.os, "rmdir", fail_staging_rmdir)
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)
    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )
    assert result["success"] is True
    assert destination.is_file()
    assert any("cleanup failure" in warning for warning in result["warnings"])
