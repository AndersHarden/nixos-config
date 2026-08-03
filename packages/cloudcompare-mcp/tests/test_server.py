import asyncio
import hashlib
import json
import math
import os
from pathlib import Path
from types import SimpleNamespace
from typing import Callable

import pytest

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
        load_error: bool = False,
        normals_tools: int = 1,
        on_cc_run: Callable[[list[str]], None] | None = None,
    ) -> None:
        self.binary = binary
        self.output_mode = output_mode
        self.returncode = returncode
        self.load_error = load_error
        self.on_cc_run = on_cc_run
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

    def _load_cloud(self, path: str) -> tuple[list, None, dict]:
        if self.load_error:
            raise ValueError("unreadable staged cloud")
        if not Path(path).read_bytes():
            raise ValueError("empty staged cloud")
        return [], None, {}

    def cc_run(self, args: list[str]) -> tuple[int, str, str]:
        self.cc_calls.append(args)
        if "FILE" in args:
            output = Path(args[args.index("FILE") + 1])
            if self.output_mode == "success":
                output.write_bytes(PLY)
            elif self.output_mode == "empty":
                output.touch()
            elif self.output_mode == "partial":
                output.write_bytes(b"partial")
            elif self.output_mode == "sidecar":
                output.write_bytes(PLY)
                output.with_name("sidecar.bin").write_bytes(b"sidecar")
        if self.on_cc_run is not None:
            self.on_cc_run(args)
        return self.returncode, "stdout", "stderr"

    async def call_tool(self, name: str, arguments: dict) -> list[SimpleNamespace]:
        dispatch = {
            "get_cloudcompare_info": self.handle_get_cloudcompare_info,
            "compute_normals": self.handle_compute_normals,
        }
        return dispatch[name](arguments)


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


def staging_entries(directory: Path) -> list[Path]:
    return list(directory.glob(".*-staging-*"))


def test_patched_dispatch_reports_nix_version_and_binary(monkeypatch) -> None:
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
    assert tool.inputSchema["required"] == ["input_path", "output_path"]
    assert upstream.TOOLS[1] is original_other_tool


@pytest.mark.parametrize(
    ("arguments", "message"),
    [
        ({"input_path": "source.ply", "output_path": "/tmp/out.ply"}, "absolute"),
        ({"input_path": "/tmp/source.ply", "output_path": "out.ply"}, "absolute"),
    ],
)
def test_compute_normals_rejects_relative_paths_without_cc_run(
    arguments: dict,
    message: str,
) -> None:
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)

    assert message in call_normals(upstream, arguments)["error"]
    assert upstream.cc_calls == []


def test_compute_normals_rejects_missing_input_without_cc_run(tmp_path: Path) -> None:
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)
    missing = tmp_path / "missing.ply"

    result = call_normals(
        upstream, {"input_path": str(missing), "output_path": str(tmp_path / "out.ply")}
    )

    assert str(missing) in result["error"]
    assert upstream.cc_calls == []


def test_compute_normals_rejects_missing_output_parent_without_cc_run(
    tmp_path: Path,
) -> None:
    source = source_file(tmp_path)
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)

    result = call_normals(
        upstream,
        {
            "input_path": str(source),
            "output_path": str(tmp_path / "missing" / "out.ply"),
        },
    )

    assert "parent" in result["error"].lower()
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
    destination.symlink_to(tmp_path / "missing-target")
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)

    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )

    assert "already exists" in result["error"]
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

    assert "already exists" in result["error"] or "alias" in result["error"]
    assert upstream.cc_calls == []


def test_compute_normals_rejects_output_parent_symlink_component_without_cc_run(
    tmp_path: Path,
) -> None:
    source = source_file(tmp_path)
    real_parent = tmp_path / "real"
    real_parent.mkdir()
    linked_parent = tmp_path / "linked"
    linked_parent.symlink_to(real_parent, target_is_directory=True)
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)

    result = call_normals(
        upstream,
        {"input_path": str(source), "output_path": str(linked_parent / "out.ply")},
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

    assert "did not create" in result["error"]
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


def test_non_native_output_is_reopened_by_cloudcompare_without_auto_save(
    tmp_path: Path,
) -> None:
    source = source_file(tmp_path)
    destination = tmp_path / "out.e57"
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)

    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )

    assert result["success"] is True
    assert upstream.cc_calls[1][:3] == ["-AUTO_SAVE", "OFF", "-O"]
    assert "-OCTREE_NORMALS" not in upstream.cc_calls[1]


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

    def create_racer(args: list[str]) -> None:
        if "FILE" in args:
            destination.write_bytes(b"racer")

    upstream = FakeUpstream("/bin/CloudCompare", on_cc_run=create_racer)
    _patch_upstream(upstream)

    result = call_normals(
        upstream, {"input_path": str(source), "output_path": str(destination)}
    )

    assert "already exists" in result["error"]
    assert destination.read_bytes() == b"racer"
    assert staging_entries(tmp_path) == []
