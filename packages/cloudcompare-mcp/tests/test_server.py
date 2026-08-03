import asyncio
import json
import math
from pathlib import Path
from types import SimpleNamespace

import pytest

from server import _patch_upstream


class FakeUpstream:
    def __init__(
        self,
        binary: str | None,
        *,
        create_output: bool = True,
        returncode: int = 0,
    ) -> None:
        self.binary = binary
        self.create_output = create_output
        self.returncode = returncode
        self.cc_calls: list[list[str]] = []
        self.handle_get_cloudcompare_info = lambda _args: self._err("unpatched")
        self.handle_compute_normals = lambda _args: self._err("unpatched")
        self.TOOLS = [
            SimpleNamespace(
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
            ),
            SimpleNamespace(name="other_tool", description="unchanged", inputSchema={}),
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
        return {".ply": "PLY", ".las": "LAS"}.get(Path(path).suffix, "PLY")

    def cc_run(self, args: list[str]) -> tuple[int, str, str]:
        self.cc_calls.append(args)
        if self.create_output and "FILE" in args:
            Path(args[args.index("FILE") + 1]).touch()
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

    result = call_info(upstream)
    assert "CloudCompare executable not found" in result["error"]
    assert "ready" not in result


@pytest.mark.parametrize("version", [None, ""])
def test_patched_dispatch_rejects_missing_version(monkeypatch, version) -> None:
    if version is None:
        monkeypatch.delenv("CLOUDCOMPARE_VERSION", raising=False)
    else:
        monkeypatch.setenv("CLOUDCOMPARE_VERSION", version)
    upstream = FakeUpstream("/run/current-system/sw/bin/CloudCompare")

    _patch_upstream(upstream)

    result = call_info(upstream)
    assert "CLOUDCOMPARE_VERSION is not set" in result["error"]
    assert "ready" not in result


@pytest.mark.parametrize(
    ("mode", "cloudcompare_mode"),
    [("LS", "LS"), ("QUADRIC", "QUADRIC"), ("TRIANGULATION", "TRI")],
)
def test_compute_normals_maps_modes_and_uses_auto_radius(
    tmp_path: Path,
    mode: str,
    cloudcompare_mode: str,
) -> None:
    source = tmp_path / "source.ply"
    output = tmp_path / f"{mode.lower()}.ply"
    source.touch()
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)

    result = call_normals(
        upstream,
        {"input_path": str(source), "output_path": str(output), "mode": mode},
    )

    assert result["success"] is True
    assert upstream.cc_calls == [[
        "-AUTO_SAVE", "OFF",
        "-O", str(source),
        "-OCTREE_NORMALS", "auto",
        "-MODEL", cloudcompare_mode,
        "-C_EXPORT_FMT", "PLY",
        "-SAVE_CLOUDS", "FILE", str(output),
    ]]


def test_compute_normals_passes_radius_as_positional_source_unit_value(tmp_path: Path) -> None:
    source = tmp_path / "source.ply"
    output = tmp_path / "normals.ply"
    source.touch()
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)

    result = call_normals(
        upstream,
        {"input_path": str(source), "output_path": str(output), "radius": 2.0},
    )

    assert result["success"] is True
    argv = upstream.cc_calls[0]
    assert argv[argv.index("-OCTREE_NORMALS") + 1] == "2.0"
    assert not {"-COMPUTE_NORMALS", "-RADIUS", "-KNN"}.intersection(argv)


def test_compute_normals_schema_removes_knn_and_documents_radius() -> None:
    upstream = FakeUpstream("/bin/CloudCompare")
    original_other_tool = upstream.TOOLS[1]

    _patch_upstream(upstream)

    tool = next(tool for tool in upstream.TOOLS if tool.name == "compute_normals")
    properties = tool.inputSchema["properties"]
    assert "knn" not in properties
    assert "source coordinate units" in properties["radius"]["description"]
    assert "auto" in properties["radius"]["description"]
    assert tool.inputSchema["required"] == ["input_path", "output_path"]
    assert upstream.TOOLS[1] is original_other_tool


def test_compute_normals_rejects_legacy_knn_without_running_cloudcompare(tmp_path: Path) -> None:
    source = tmp_path / "source.ply"
    source.touch()
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)

    result = call_normals(
        upstream,
        {"input_path": str(source), "output_path": str(tmp_path / "out.ply"), "knn": 12},
    )

    assert "knn" in result["error"]
    assert upstream.cc_calls == []


@pytest.mark.parametrize("radius", [0, -1, math.inf, -math.inf, math.nan, True, "2.0"])
def test_compute_normals_rejects_invalid_radius_without_running_cloudcompare(
    tmp_path: Path,
    radius: object,
) -> None:
    source = tmp_path / "source.ply"
    source.touch()
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)

    result = call_normals(
        upstream,
        {"input_path": str(source), "output_path": str(tmp_path / "out.ply"), "radius": radius},
    )

    assert "radius" in result["error"]
    assert upstream.cc_calls == []


def test_compute_normals_rejects_missing_input_without_running_cloudcompare(tmp_path: Path) -> None:
    source = tmp_path / "missing.ply"
    upstream = FakeUpstream("/bin/CloudCompare")
    _patch_upstream(upstream)

    result = call_normals(
        upstream,
        {"input_path": str(source), "output_path": str(tmp_path / "out.ply")},
    )

    assert str(source) in result["error"]
    assert upstream.cc_calls == []


def test_compute_normals_rc_zero_without_output_is_an_error(tmp_path: Path) -> None:
    source = tmp_path / "source.ply"
    source.touch()
    upstream = FakeUpstream("/bin/CloudCompare", create_output=False)
    _patch_upstream(upstream)

    result = call_normals(
        upstream,
        {"input_path": str(source), "output_path": str(tmp_path / "out.ply")},
    )

    assert result["error"]
    assert "output" in result["error"].lower()
