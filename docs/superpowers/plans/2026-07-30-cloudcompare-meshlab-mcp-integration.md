# CloudCompare and MeshLab MCP Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install and expose CloudCompare and a safe PyMeshLab MCP server globally in OpenCode, route the reverse-engineering skills to the correct application, remove Bitwarden Desktop, activate the NixOS configuration, and push the intended repository changes.

**Architecture:** CloudCompare remains a NixOS package and is controlled through a pinned community `stdio` MCP server. Mesh operations are implemented as stateless Python functions behind an official FastMCP `stdio` server, packaged with `python313.withPackages` so PyMeshLab's native libraries resolve correctly on NixOS. Every mutating mesh tool reads an immutable input, writes and validates a temporary derivative, then atomically publishes a distinct output.

**Tech Stack:** NixOS flakes, Python 3.13, PyMeshLab 2025.7, MCP Python SDK/FastMCP, pytest, CloudCompare 2.13, OpenCode MCP configuration, Markdown skills

---

## File Map

- Create `packages/meshlab-mcp/mesh_ops.py`: path validation, metadata extraction, atomic output handling, and constrained PyMeshLab operations.
- Create `packages/meshlab-mcp/server.py`: FastMCP server and the eight public tools.
- Create `packages/meshlab-mcp/default.nix`: Nix wrapper containing Python, MCP SDK, and PyMeshLab.
- Create `packages/cloudcompare-mcp/default.nix`: pinned upstream source and flake-locked Python runtime wrapper.
- Create `packages/meshlab-mcp/tests/conftest.py`: reusable closed and open mesh fixtures.
- Create `packages/meshlab-mcp/tests/test_mesh_ops.py`: unit and geometry integration tests.
- Create `packages/meshlab-mcp/tests/test_server.py`: MCP tool registration and `stdio` protocol tests.
- Modify `modules/desktop/media-creation.nix`: install the local `meshlab-mcp` package beside MeshLab and CloudCompare.
- Modify `modules/desktop/browsers.nix`: remove `bitwarden-desktop` only.
- Modify `~/.config/opencode/opencode.json`: add global `cloudcompare` and `meshlab` MCP servers.
- Modify `/home/anders/Projekt/FreeCAD/skills/pointcloud-analysis/SKILL.md`: require named CloudCompare MCP tools for point-cloud work.
- Modify `/home/anders/Projekt/FreeCAD/skills/mesh-repair/SKILL.md`: require MeshLab MCP for mesh work and delegate point clouds to CloudCompare.
- Preserve the pre-existing unstaged change in `flake.lock`; never stage or rewrite it.

### Task 1: Mesh Path Validation and Metadata

**Files:**
- Create: `packages/meshlab-mcp/mesh_ops.py`
- Create: `packages/meshlab-mcp/tests/conftest.py`
- Create: `packages/meshlab-mcp/tests/test_mesh_ops.py`

- [ ] **Step 1: Add deterministic mesh fixtures**

Create `packages/meshlab-mcp/tests/conftest.py` with ASCII OBJ fixtures. `cube_path` is a closed triangulated cube; `open_tetra_path` is a tetrahedron missing one face.

```python
from pathlib import Path

import pytest


CUBE_OBJ = """v -1 -1 -1
v 1 -1 -1
v 1 1 -1
v -1 1 -1
v -1 -1 1
v 1 -1 1
v 1 1 1
v -1 1 1
f 1 3 2
f 1 4 3
f 5 6 7
f 5 7 8
f 1 2 6
f 1 6 5
f 2 3 7
f 2 7 6
f 3 4 8
f 3 8 7
f 4 1 5
f 4 5 8
"""

OPEN_TETRA_OBJ = """v 1 1 1
v -1 -1 1
v -1 1 -1
v 1 -1 -1
f 1 2 3
f 1 4 2
f 2 4 3
"""


@pytest.fixture
def cube_path(tmp_path: Path) -> Path:
    path = tmp_path / "cube.obj"
    path.write_text(CUBE_OBJ, encoding="ascii")
    return path


@pytest.fixture
def open_tetra_path(tmp_path: Path) -> Path:
    path = tmp_path / "open-tetra.obj"
    path.write_text(OPEN_TETRA_OBJ, encoding="ascii")
    return path
```

- [ ] **Step 2: Write failing validation and metadata tests**

Create `packages/meshlab-mcp/tests/test_mesh_ops.py`:

```python
from pathlib import Path

import pytest

from mesh_ops import MeshOperationError, inspect_mesh, validate_output_path


def test_inspect_mesh_reports_topology_and_bounds(cube_path: Path) -> None:
    result = inspect_mesh(str(cube_path.resolve()))
    assert result["vertices"] == 8
    assert result["faces"] == 12
    assert result["connected_components"] == 1
    assert result["holes"] == 0
    assert result["bounds"]["min"] == [-1.0, -1.0, -1.0]
    assert result["bounds"]["max"] == [1.0, 1.0, 1.0]


def test_input_must_be_absolute(cube_path: Path) -> None:
    with pytest.raises(MeshOperationError, match="absolute"):
        inspect_mesh(cube_path.name)


def test_output_must_differ_from_input(cube_path: Path) -> None:
    with pytest.raises(MeshOperationError, match="different"):
        validate_output_path(cube_path.resolve(), cube_path.resolve())


def test_existing_output_is_rejected(cube_path: Path, tmp_path: Path) -> None:
    output = tmp_path / "existing.ply"
    output.write_text("existing", encoding="ascii")
    with pytest.raises(MeshOperationError, match="already exists"):
        validate_output_path(cube_path.resolve(), output.resolve())
```

- [ ] **Step 3: Run tests and verify RED**

Run:

```bash
PYTHONPATH=packages/meshlab-mcp nix shell --impure --expr 'with import <nixpkgs> {}; python313.withPackages (ps: with ps; [ pymeshlab pytest ])' --command pytest packages/meshlab-mcp/tests/test_mesh_ops.py -v
```

Expected: collection fails because `mesh_ops` does not exist.

- [ ] **Step 4: Implement validation and metadata**

Create `packages/meshlab-mcp/mesh_ops.py` with:

```python
from __future__ import annotations

import os
import tempfile
from pathlib import Path
from typing import Callable

import pymeshlab


SUPPORTED_EXTENSIONS = {".obj", ".off", ".ply", ".stl"}


class MeshOperationError(ValueError):
    pass


def validate_input_path(value: str) -> Path:
    path = Path(value)
    if not path.is_absolute():
        raise MeshOperationError("input path must be absolute")
    if not path.is_file():
        raise MeshOperationError(f"input file does not exist: {path}")
    if path.suffix.lower() not in SUPPORTED_EXTENSIONS:
        raise MeshOperationError(f"unsupported mesh format: {path.suffix}")
    return path


def validate_output_path(input_path: Path, output_path: Path) -> Path:
    if not output_path.is_absolute():
        raise MeshOperationError("output path must be absolute")
    if input_path == output_path:
        raise MeshOperationError("input and output paths must be different")
    if output_path.exists():
        raise MeshOperationError(f"output already exists: {output_path}")
    if not output_path.parent.is_dir():
        raise MeshOperationError(f"output directory does not exist: {output_path.parent}")
    if output_path.suffix.lower() not in SUPPORTED_EXTENSIONS:
        raise MeshOperationError(f"unsupported mesh format: {output_path.suffix}")
    return output_path


def _load_mesh(path: Path) -> pymeshlab.MeshSet:
    mesh_set = pymeshlab.MeshSet()
    try:
        mesh_set.load_new_mesh(str(path))
    except Exception as exc:
        raise MeshOperationError(f"failed to load mesh {path}: {exc}") from exc
    if mesh_set.current_mesh().vertex_number() == 0:
        raise MeshOperationError(f"mesh has no vertices: {path}")
    return mesh_set


def _vector(values: object) -> list[float]:
    return [float(value) for value in values]


def _metadata(mesh_set: pymeshlab.MeshSet) -> dict[str, object]:
    mesh = mesh_set.current_mesh()
    topology = mesh_set.get_topological_measures()
    geometry = mesh_set.get_geometric_measures()
    bounds = mesh.bounding_box()
    return {
        "vertices": int(mesh.vertex_number()),
        "faces": int(mesh.face_number()),
        "connected_components": int(topology["connected_components_number"]),
        "holes": int(topology["number_holes"]),
        "boundary_edges": int(topology["boundary_edges"]),
        "is_two_manifold": bool(topology["is_mesh_two_manifold"]),
        "surface_area": float(geometry["surface_area"]),
        "volume": float(geometry.get("mesh_volume", 0.0)),
        "bounds": {"min": _vector(bounds.min()), "max": _vector(bounds.max())},
    }


def inspect_mesh(input_path: str) -> dict[str, object]:
    source = validate_input_path(input_path)
    result = _metadata(_load_mesh(source))
    result["input_path"] = str(source)
    return result
```

- [ ] **Step 5: Run tests and verify GREEN**

Run the Step 3 command. Expected: four tests pass.

- [ ] **Step 6: Commit the metadata foundation**

```bash
git add packages/meshlab-mcp/mesh_ops.py packages/meshlab-mcp/tests/conftest.py packages/meshlab-mcp/tests/test_mesh_ops.py
git commit -m "feat: add validated mesh inspection"
```

### Task 2: Non-Destructive Mesh Operations

**Files:**
- Modify: `packages/meshlab-mcp/mesh_ops.py`
- Modify: `packages/meshlab-mcp/tests/test_mesh_ops.py`

- [ ] **Step 1: Add failing operation tests**

Append tests that call every public operation, assert that the source bytes are unchanged, assert that a distinct output exists and reopens, and check operation-specific effects:

```python
from mesh_ops import (
    clean_mesh,
    compute_normals,
    export_mesh,
    remesh_mesh,
    repair_holes,
    simplify_mesh,
    smooth_mesh,
)


@pytest.mark.parametrize(
    ("operation", "kwargs"),
    [
        (clean_mesh, {}),
        (compute_normals, {}),
        (simplify_mesh, {"target_faces": 6}),
        (remesh_mesh, {"target_edge_length": 0.75, "iterations": 1}),
        (smooth_mesh, {"method": "taubin", "iterations": 1}),
    ],
)
def test_transformations_preserve_source_and_publish_valid_output(
    cube_path: Path,
    tmp_path: Path,
    operation,
    kwargs: dict,
) -> None:
    original = cube_path.read_bytes()
    output = tmp_path / f"{operation.__name__}.ply"
    result = operation(str(cube_path.resolve()), str(output.resolve()), **kwargs)
    assert cube_path.read_bytes() == original
    assert output.is_file()
    assert result["after"]["vertices"] > 0
    assert result["after"]["faces"] > 0


def test_repair_holes_reduces_hole_count(open_tetra_path: Path, tmp_path: Path) -> None:
    output = tmp_path / "repaired.ply"
    result = repair_holes(
        str(open_tetra_path.resolve()),
        str(output.resolve()),
        max_hole_size=20,
    )
    assert result["before"]["holes"] == 1
    assert result["after"]["holes"] == 0


def test_export_mesh_converts_format(cube_path: Path, tmp_path: Path) -> None:
    output = tmp_path / "cube.stl"
    result = export_mesh(str(cube_path.resolve()), str(output.resolve()))
    assert output.is_file()
    assert result["operation"] == "export_mesh"


@pytest.mark.parametrize(
    ("call", "message"),
    [
        (lambda src, dst: repair_holes(src, dst, max_hole_size=0), "max_hole_size"),
        (lambda src, dst: simplify_mesh(src, dst, target_faces=3), "target_faces"),
        (lambda src, dst: remesh_mesh(src, dst, target_edge_length=0.0), "target_edge_length"),
        (lambda src, dst: smooth_mesh(src, dst, method="unknown", iterations=1), "method"),
        (lambda src, dst: smooth_mesh(src, dst, method="taubin", iterations=101), "iterations"),
    ],
)
def test_invalid_operation_parameters_are_rejected(
    cube_path: Path,
    tmp_path: Path,
    call,
    message: str,
) -> None:
    with pytest.raises(MeshOperationError, match=message):
        call(str(cube_path.resolve()), str((tmp_path / "output.ply").resolve()))
```

- [ ] **Step 2: Run tests and verify RED**

Run the Task 1 Step 3 command. Expected: import errors for the missing operation functions.

- [ ] **Step 3: Add atomic transformation support**

Append `_transform` to `mesh_ops.py`. It validates before loading, saves to a same-format temporary path in the destination directory, reopens the temporary mesh, then uses `os.replace` only after validation:

```python
def _transform(
    operation: str,
    input_path: str,
    output_path: str,
    action: Callable[[pymeshlab.MeshSet], None],
    parameters: dict[str, object],
) -> dict[str, object]:
    source = validate_input_path(input_path)
    destination = validate_output_path(source, Path(output_path))
    mesh_set = _load_mesh(source)
    before = _metadata(mesh_set)
    temporary: Path | None = None
    try:
        action(mesh_set)
        with tempfile.NamedTemporaryFile(
            prefix=f".{destination.stem}.",
            suffix=destination.suffix,
            dir=destination.parent,
            delete=False,
        ) as handle:
            temporary = Path(handle.name)
        mesh_set.save_current_mesh(str(temporary))
        after = _metadata(_load_mesh(temporary))
        if int(after["vertices"]) == 0 or int(after["faces"]) == 0:
            raise MeshOperationError(f"{operation} produced an empty mesh")
        os.replace(temporary, destination)
        temporary = None
        return {
            "operation": operation,
            "input_path": str(source),
            "output_path": str(destination),
            "parameters": parameters,
            "before": before,
            "after": after,
        }
    except MeshOperationError:
        raise
    except Exception as exc:
        raise MeshOperationError(f"{operation} failed for {source}: {exc}") from exc
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
```

- [ ] **Step 4: Implement the constrained operations**

Append these public functions to `mesh_ops.py`:

```python
def clean_mesh(input_path: str, output_path: str) -> dict[str, object]:
    def action(mesh_set: pymeshlab.MeshSet) -> None:
        mesh_set.meshing_remove_duplicate_vertices()
        mesh_set.meshing_remove_duplicate_faces()
        mesh_set.meshing_remove_null_faces()
        mesh_set.meshing_remove_unreferenced_vertices()

    return _transform("clean_mesh", input_path, output_path, action, {})


def repair_holes(
    input_path: str,
    output_path: str,
    max_hole_size: int = 30,
) -> dict[str, object]:
    if not 1 <= max_hole_size <= 100000:
        raise MeshOperationError("max_hole_size must be between 1 and 100000")

    def action(mesh_set: pymeshlab.MeshSet) -> None:
        mesh_set.meshing_close_holes(maxholesize=max_hole_size)

    return _transform(
        "repair_holes", input_path, output_path, action, {"max_hole_size": max_hole_size}
    )


def compute_normals(input_path: str, output_path: str) -> dict[str, object]:
    def action(mesh_set: pymeshlab.MeshSet) -> None:
        mesh_set.compute_normal_per_face()
        mesh_set.compute_normal_per_vertex()

    return _transform("compute_normals", input_path, output_path, action, {})


def simplify_mesh(
    input_path: str,
    output_path: str,
    target_faces: int,
) -> dict[str, object]:
    if target_faces < 4:
        raise MeshOperationError("target_faces must be at least 4")

    def action(mesh_set: pymeshlab.MeshSet) -> None:
        if target_faces >= mesh_set.current_mesh().face_number():
            raise MeshOperationError("target_faces must be lower than the source face count")
        mesh_set.meshing_decimation_quadric_edge_collapse(
            targetfacenum=target_faces,
            preserveboundary=True,
            preservenormal=True,
            preservetopology=True,
            autoclean=True,
        )

    return _transform(
        "simplify_mesh", input_path, output_path, action, {"target_faces": target_faces}
    )


def remesh_mesh(
    input_path: str,
    output_path: str,
    target_edge_length: float,
    iterations: int = 5,
) -> dict[str, object]:
    if target_edge_length <= 0:
        raise MeshOperationError("target_edge_length must be greater than zero")
    if not 1 <= iterations <= 20:
        raise MeshOperationError("iterations must be between 1 and 20")

    def action(mesh_set: pymeshlab.MeshSet) -> None:
        mesh_set.meshing_isotropic_explicit_remeshing(
            iterations=iterations,
            targetlen=pymeshlab.AbsoluteValue(target_edge_length),
            adaptive=False,
            checksurfdist=True,
        )

    return _transform(
        "remesh_mesh",
        input_path,
        output_path,
        action,
        {"target_edge_length": target_edge_length, "iterations": iterations},
    )


def smooth_mesh(
    input_path: str,
    output_path: str,
    method: str = "taubin",
    iterations: int = 10,
) -> dict[str, object]:
    if method not in {"taubin", "laplacian"}:
        raise MeshOperationError("method must be 'taubin' or 'laplacian'")
    if not 1 <= iterations <= 100:
        raise MeshOperationError("iterations must be between 1 and 100")

    def action(mesh_set: pymeshlab.MeshSet) -> None:
        if method == "taubin":
            mesh_set.apply_coord_taubin_smoothing(stepsmoothnum=iterations)
        else:
            mesh_set.apply_coord_laplacian_smoothing(
                stepsmoothnum=iterations,
                boundary=False,
                cotangentweight=True,
            )

    return _transform(
        "smooth_mesh", input_path, output_path, action, {"method": method, "iterations": iterations}
    )


def export_mesh(input_path: str, output_path: str) -> dict[str, object]:
    return _transform("export_mesh", input_path, output_path, lambda _mesh_set: None, {})
```

- [ ] **Step 5: Run tests and verify GREEN**

Run the Task 1 Step 3 command. Expected: all metadata and operation tests pass.

- [ ] **Step 6: Commit the operations**

```bash
git add packages/meshlab-mcp/mesh_ops.py packages/meshlab-mcp/tests/test_mesh_ops.py
git commit -m "feat: add safe mesh processing operations"
```

### Task 3: Standards-Compliant MCP Server

**Files:**
- Create: `packages/meshlab-mcp/server.py`
- Create: `packages/meshlab-mcp/tests/test_server.py`

- [ ] **Step 1: Write failing tool-registration test**

Create `packages/meshlab-mcp/tests/test_server.py`:

```python
import asyncio

from server import mcp


EXPECTED_TOOLS = {
    "inspect_mesh",
    "clean_mesh",
    "repair_holes",
    "compute_normals",
    "simplify_mesh",
    "remesh_mesh",
    "smooth_mesh",
    "export_mesh",
}


def test_server_registers_only_safe_tools() -> None:
    tools = asyncio.run(mcp.list_tools())
    assert {tool.name for tool in tools} == EXPECTED_TOOLS
```

- [ ] **Step 2: Run test and verify RED**

Run:

```bash
PYTHONPATH=packages/meshlab-mcp nix shell --impure --expr 'with import <nixpkgs> {}; python313.withPackages (ps: with ps; [ mcp pymeshlab pytest ])' --command pytest packages/meshlab-mcp/tests/test_server.py -v
```

Expected: collection fails because `server` does not exist.

- [ ] **Step 3: Implement the FastMCP surface**

Create `packages/meshlab-mcp/server.py`:

```python
from mcp.server.fastmcp import FastMCP

import mesh_ops


mcp = FastMCP("meshlab-mcp")


@mcp.tool()
def inspect_mesh(input_path: str) -> dict[str, object]:
    """Inspect a mesh without modifying it."""
    return mesh_ops.inspect_mesh(input_path)


@mcp.tool()
def clean_mesh(input_path: str, output_path: str) -> dict[str, object]:
    """Remove duplicate, unreferenced, degenerate, and zero-area elements."""
    return mesh_ops.clean_mesh(input_path, output_path)


@mcp.tool()
def repair_holes(
    input_path: str,
    output_path: str,
    max_hole_size: int = 30,
) -> dict[str, object]:
    """Fill mesh holes no larger than max_hole_size edges."""
    return mesh_ops.repair_holes(input_path, output_path, max_hole_size)


@mcp.tool()
def compute_normals(input_path: str, output_path: str) -> dict[str, object]:
    """Compute face and vertex normals on a derivative mesh."""
    return mesh_ops.compute_normals(input_path, output_path)


@mcp.tool()
def simplify_mesh(
    input_path: str,
    output_path: str,
    target_faces: int,
) -> dict[str, object]:
    """Apply topology- and boundary-preserving quadric decimation."""
    return mesh_ops.simplify_mesh(input_path, output_path, target_faces)


@mcp.tool()
def remesh_mesh(
    input_path: str,
    output_path: str,
    target_edge_length: float,
    iterations: int = 5,
) -> dict[str, object]:
    """Apply isotropic remeshing with an absolute target edge length."""
    return mesh_ops.remesh_mesh(
        input_path, output_path, target_edge_length, iterations
    )


@mcp.tool()
def smooth_mesh(
    input_path: str,
    output_path: str,
    method: str = "taubin",
    iterations: int = 10,
) -> dict[str, object]:
    """Apply bounded Taubin or Laplacian coordinate smoothing."""
    return mesh_ops.smooth_mesh(input_path, output_path, method, iterations)


@mcp.tool()
def export_mesh(input_path: str, output_path: str) -> dict[str, object]:
    """Convert a mesh to OBJ, OFF, PLY, or STL and validate the result."""
    return mesh_ops.export_mesh(input_path, output_path)


if __name__ == "__main__":
    mcp.run(transport="stdio")
```

- [ ] **Step 4: Run registration test and verify GREEN**

Run the Step 2 command. Expected: one test passes and exactly eight tools are registered.

- [ ] **Step 5: Add and run a real stdio smoke test**

Add these imports and the live protocol test to `test_server.py`:

```python
import json
import sys
from pathlib import Path

import pytest
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


SERVER_PATH = Path(__file__).parents[1] / "server.py"


@pytest.mark.asyncio
async def test_stdio_initialize_list_and_call(cube_path: Path) -> None:
    parameters = StdioServerParameters(
        command=sys.executable,
        args=[str(SERVER_PATH)],
    )
    async with stdio_client(parameters) as (read_stream, write_stream):
        async with ClientSession(read_stream, write_stream) as session:
            await session.initialize()
            listed = await session.list_tools()
            assert {tool.name for tool in listed.tools} == EXPECTED_TOOLS
            result = await session.call_tool(
                "inspect_mesh",
                {"input_path": str(cube_path.resolve())},
            )
    assert not result.isError
    text = "".join(item.text for item in result.content if item.type == "text")
    assert json.loads(text)["vertices"] == 8
```

Run:

```bash
PYTHONPATH=packages/meshlab-mcp nix shell --impure --expr 'with import <nixpkgs> {}; python313.withPackages (ps: with ps; [ mcp pymeshlab pytest pytest-asyncio ])' --command pytest packages/meshlab-mcp/tests/test_server.py -v
```

Expected: registration and live protocol tests pass.

- [ ] **Step 6: Run the complete MeshLab suite**

```bash
PYTHONPATH=packages/meshlab-mcp nix shell --impure --expr 'with import <nixpkgs> {}; python313.withPackages (ps: with ps; [ mcp pymeshlab pytest pytest-asyncio ])' --command pytest packages/meshlab-mcp/tests -v
```

Expected: all tests pass with no errors.

- [ ] **Step 7: Commit the MCP server**

```bash
git add packages/meshlab-mcp/server.py packages/meshlab-mcp/tests/test_server.py
git commit -m "feat: expose mesh operations through MCP"
```

### Task 4: Declarative NixOS Packaging and Bitwarden Removal

**Files:**
- Create: `packages/meshlab-mcp/default.nix`
- Modify: `modules/desktop/media-creation.nix`
- Modify: `modules/desktop/browsers.nix`

- [ ] **Step 1: Create the Nix wrapper**

Create `packages/meshlab-mcp/default.nix`:

```nix
{ python313, writeShellApplication }:

let
  pythonEnv = python313.withPackages (ps: with ps; [
    mcp
    pymeshlab
  ]);
in
writeShellApplication {
  name = "meshlab-mcp";
  runtimeInputs = [ pythonEnv ];
  text = ''
    exec ${pythonEnv}/bin/python ${./.}/server.py "$@"
  '';
}
```

- [ ] **Step 2: Install the local package in the desktop profile**

Change the start of `modules/desktop/media-creation.nix` to:

```nix
{ config, pkgs, ... }:

let
  meshlabMcp = pkgs.callPackage ../../packages/meshlab-mcp { };
in
{
```

Add `meshlabMcp` immediately after `meshlab` in `environment.systemPackages`. Keep the existing `cloudcompare` line unchanged.

- [ ] **Step 3: Remove Bitwarden Desktop only**

Delete the single `bitwarden-desktop` line from `modules/desktop/browsers.nix`. Do not change Firefox, Chrome, Chromium, ChromeDriver, Ladybird, or Brave.

- [ ] **Step 4: Evaluate and build without rewriting the lock file**

Run:

```bash
nix flake show --json --no-write-lock-file
nix build .#nixosConfigurations.laptop-intel.config.system.build.toplevel --no-link
```

Expected: both commands exit 0. `git diff -- flake.lock` must remain identical to the pre-existing diff.

- [ ] **Step 5: Run the packaged server tests through its Nix dependencies**

Run the complete suite command from Task 3 Step 6. Expected: all tests pass.

- [ ] **Step 6: Inspect only the intended package changes**

Inspect `git status`, `git diff`, and `git log --oneline -10`, then isolate the intended diff:

```bash
git diff -- packages/meshlab-mcp/default.nix modules/desktop/media-creation.nix modules/desktop/browsers.nix
```

Confirm the diff contains only the wrapper installation and Bitwarden removal. Leave these changes uncommitted until activation succeeds, and confirm `flake.lock` remains modified and unstaged.

### Task 5: Activate and Verify NixOS

**Files:**
- No source changes expected.

- [ ] **Step 1: Activate the current host**

```bash
sudo nixos-rebuild switch --flake .#laptop-intel
```

Expected: activation completes without evaluation or service errors.

- [ ] **Step 2: Verify installed applications and MCP command**

```bash
command -v CloudCompare
nix eval --raw .#nixosConfigurations.laptop-intel.pkgs.cloudcompare.version
command -v meshlab
meshlab --version
command -v meshlab-mcp
```

Expected: all commands resolve under `/run/current-system/sw/bin`; Nix package metadata reports CloudCompare 2.13.x and MeshLab reports 2025.07. Do not use `CloudCompare --version`: this package does not support the flag and exits nonzero.

- [ ] **Step 3: Verify Bitwarden removal**

```bash
test ! -e /run/current-system/sw/bin/bitwarden
test ! -e /run/current-system/sw/bin/bitwarden-desktop
```

Expected: both commands exit 0.

- [ ] **Step 4: Smoke-test the installed MeshLab MCP server**

Run this installed-command protocol check from the repository root:

```bash
nix shell --impure --expr 'with import <nixpkgs> {}; python313.withPackages (ps: with ps; [ mcp ])' --command python3 - <<'PY'
import asyncio
import json
import tempfile
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

CUBE = """v 0 0 0
v 1 0 0
v 0 1 0
v 0 0 1
f 1 3 2
f 1 2 4
f 2 3 4
f 3 1 4
"""

async def main() -> None:
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "cube.obj"
        path.write_text(CUBE, encoding="ascii")
        params = StdioServerParameters(command="/run/current-system/sw/bin/meshlab-mcp")
        async with stdio_client(params) as (read_stream, write_stream):
            async with ClientSession(read_stream, write_stream) as session:
                await session.initialize()
                tools = await session.list_tools()
                assert len(tools.tools) == 8
                result = await session.call_tool("inspect_mesh", {"input_path": str(path)})
        assert not result.isError
        text = "".join(item.text for item in result.content if item.type == "text")
        assert json.loads(text)["vertices"] == 4

asyncio.run(main())
PY
```

Expected: exit 0 with eight tools, no protocol error, and four fixture vertices.

- [ ] **Step 5: Commit the activated NixOS changes**

Inspect `git status`, `git diff`, and `git log --oneline -10`, then stage only the activated package changes:

```bash
git add packages/meshlab-mcp/default.nix modules/desktop/media-creation.nix modules/desktop/browsers.nix
git commit -m "feat: install mesh processing MCP"
```

Confirm `flake.lock` remains modified and unstaged.

### Task 6: CloudCompare MCP and Global OpenCode Configuration

**Files:**
- Create: `packages/cloudcompare-mcp/default.nix`
- Modify: `modules/desktop/media-creation.nix`
- Modify: `/home/anders/.config/opencode/opencode.json`

- [ ] **Step 1: Add the declarative CloudCompare MCP wrapper**

Create `packages/cloudcompare-mcp/default.nix`:

```nix
{ fetchFromGitHub, python313, writeShellApplication }:
let
  src = fetchFromGitHub {
    owner = "yufeioptimal";
    repo = "cloudcompare-mcp";
    rev = "22b5232fd14e8ca02105aa47dcac40ad248a705c";
    hash = "sha256-xeAy0OEc18kOCEobmOImEL7hg+VDMxGgbIGufUrCSOs=";
  };
  pythonEnv = python313.withPackages (ps: with ps; [
    mcp
    numpy
    matplotlib
    laspy
    lazrs
    plyfile
  ]);
in
writeShellApplication {
  name = "cloudcompare-mcp";
  runtimeInputs = [ pythonEnv ];
  text = ''
    exec ${pythonEnv}/bin/python ${src}/src/cloudcompare_mcp/server.py "$@"
  '';
}
```

- [ ] **Step 2: Install the wrapper beside CloudCompare**

Add `cloudcompareMcp = pkgs.callPackage ../../packages/cloudcompare-mcp { };` in the existing `let` block in `modules/desktop/media-creation.nix`. Add `cloudcompareMcp` immediately after the existing `cloudcompare` package and preserve every other byte.

- [ ] **Step 3: Build and smoke-test the wrapper directly**

Build the package with the flake's pinned nixpkgs:

```bash
export CLOUDCOMPARE_MCP="$(nix build --no-link --print-out-paths --impure --expr 'let pkgs = (builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.x86_64-linux; in pkgs.callPackage ./packages/cloudcompare-mcp { }')"
```

Run a real MCP client with `CLOUDCOMPARE_PATH=/run/current-system/sw/bin/CloudCompare` and a PLY fixture:

```bash
nix shell --impure --expr 'with import <nixpkgs> {}; python313.withPackages (ps: with ps; [ mcp ])' --command python3 - <<'PY'
import asyncio
import json
import os
import tempfile
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

SERVER = os.environ["CLOUDCOMPARE_MCP"] + "/bin/cloudcompare-mcp"
PLY = """ply
format ascii 1.0
element vertex 4
property float x
property float y
property float z
end_header
0 0 0
1 0 0
0 1 0
0 0 1
"""

async def main() -> None:
    async with asyncio.timeout(120):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "points.ply"
            output = root / "sampled.ply"
            source.write_text(PLY, encoding="ascii")
            params = StdioServerParameters(
                command=SERVER,
                env={**os.environ, "CLOUDCOMPARE_PATH": "/run/current-system/sw/bin/CloudCompare"},
            )
            async with stdio_client(params) as (read_stream, write_stream):
                async with ClientSession(read_stream, write_stream) as session:
                    await session.initialize()
                    tools = await session.list_tools()
                    assert len(tools.tools) == 14
                    metadata = await session.call_tool("read_cloud_metadata", {"file_path": str(source)})
                    sampled = await session.call_tool("subsample", {
                        "input_path": str(source), "output_path": str(output),
                        "method": "RANDOM", "parameter": 2,
                    })
                    output_metadata = await session.call_tool("read_cloud_metadata", {"file_path": str(output)})
            assert not metadata.isError and not sampled.isError and not output_metadata.isError
            text = lambda result: "".join(item.text for item in result.content if item.type == "text")
            assert json.loads(text(metadata))["point_count"] == 4
            assert json.loads(text(sampled))["success"] is True
            assert json.loads(text(output_metadata))["point_count"] == 2
            assert output.is_file() and output.read_bytes()[:3].lower() == b"ply"

asyncio.run(main())
PY
```

Expected: initialization and all calls succeed, 14 tools are listed, and the output is a readable two-point PLY. `get_cloudcompare_info` may be used to verify the executable path but not the package version. Verify CloudCompare version `2.13.2` with `nix eval --raw .#nixosConfigurations.laptop-intel.pkgs.cloudcompare.version`; `CloudCompare --version` is unsupported and exits nonzero.

- [ ] **Step 4: Build and activate the laptop configuration**

```bash
nix build .#nixosConfigurations.laptop-intel.config.system.build.toplevel --no-link
sudo nixos-rebuild switch --flake .#laptop-intel
test -x /run/current-system/sw/bin/cloudcompare-mcp
```

Expected: build and activation exit 0, and the installed wrapper is executable. Repeat Step 3's smoke with `SERVER = "/run/current-system/sw/bin/cloudcompare-mcp"` to verify the active profile headlessly.

- [ ] **Step 5: Replace the global MCP command and deny the raw tool**

Preserve every existing key in `/home/anders/.config/opencode/opencode.json`. Replace only the `cloudcompare.command` array and add the top-level permission:

Under the existing top-level `mcp` object, replace the CloudCompare entry with:

```json
"cloudcompare": {
  "type": "local",
  "command": ["/run/current-system/sw/bin/cloudcompare-mcp"],
  "enabled": true,
  "timeout": 120000,
  "environment": {
    "CLOUDCOMPARE_PATH": "/run/current-system/sw/bin/CloudCompare"
  }
}
```

Add this separate top-level key beside `mcp`:

```json
"permission": {
  "cloudcompare_run_cloudcompare_command": "deny"
}
```

OpenCode exposes MCP tools as `<server>_<tool>`, making `cloudcompare_run_cloudcompare_command` the exact permission key.

- [ ] **Step 6: Validate the resolved OpenCode configuration and permission**

```bash
opencode debug config
opencode mcp list
```

Expected: config parsing succeeds, the resolved command is `/run/current-system/sw/bin/cloudcompare-mcp`, the resolved top-level permission contains `"cloudcompare_run_cloudcompare_command": "deny"`, and all six MCP servers are connected. A currently running OpenCode session may not expose the new command or permission until restart.

### Task 7: Route Point-Cloud Analysis to CloudCompare

**Files:**
- Modify: `/home/anders/Projekt/FreeCAD/skills/pointcloud-analysis/SKILL.md`

- [ ] **Step 1: Run and record the RED baseline**

Dispatch at least three fresh subagents without added CloudCompare instructions using these scenarios:

1. "Analyze `/data/scan.e57`, remove statistical outliers, estimate normals, and return a cleaned derivative without changing the source. State the application and tools you would call."
2. "Register `/data/mobile.las` to `/data/reference.las` with ICP and report RMS. State the application and tools you would call."
3. "Compute cloud-to-mesh deviation between `/data/scan.ply` and `/data/model.stl`. State the application and tools you would call."

Record whether each response names CloudCompare MCP and the appropriate named tool. The expected baseline failure is ambiguity or unspecified execution tooling.

- [ ] **Step 2: Add explicit application and tool routing**

Replace the frontmatter description with:

```yaml
description: Use when point clouds or scan data need inspection, cleanup, registration, dimensional analysis, or preparation for CAD reconstruction.
```

Insert this section after the Purpose section and before `# When to use`:

```markdown
# Required application and MCP tools

Use the global `cloudcompare` MCP server for all supported point-cloud operations. Call `get_cloudcompare_info` before the first CloudCompare-backed operation in a workflow.

| Need | MCP tool |
| --- | --- |
| Executable path check | `get_cloudcompare_info` |
| Metadata | `read_cloud_metadata` or `load_cloud_info` |
| Visual inspection | `visualize_cloud` |
| Density reduction | `subsample` |
| Statistical cleanup | `statistical_outlier_removal` |
| Normals | `compute_normals` |
| Registration | `icp_registration` |
| Cloud comparison | `compute_cloud_to_cloud_distances` |
| Scan-to-mesh comparison | `compute_cloud_to_mesh_distances` |
| Scalar thresholding | `filter_by_scalar_field` |
| Merge or conversion | `merge_clouds` or `convert_format` |

Always use absolute input and output paths. Preserve every source file and write each processed result to a distinct path. Record the tool, parameters, output path, and returned measurements.

Use `run_cloudcompare_command` only when no named tool covers an explicitly requested operation. Record every argument and expected output before calling it.

Triangulated mesh repair belongs to `mesh-repair` and the global `meshlab` MCP server. This skill may compare a point cloud with a mesh, but it does not repair that mesh.

---
```

Use this exact mapping in the section:

| Need | MCP tool |
| --- | --- |
| Executable path check | `get_cloudcompare_info` |
| Metadata | `read_cloud_metadata` or `load_cloud_info` |
| Visual inspection | `visualize_cloud` |
| Density reduction | `subsample` |
| Statistical cleanup | `statistical_outlier_removal` |
| Normals | `compute_normals` |
| Registration | `icp_registration` |
| Cloud comparison | `compute_cloud_to_cloud_distances` |
| Scan-to-mesh comparison | `compute_cloud_to_mesh_distances` |
| Scalar thresholding | `filter_by_scalar_field` |
| Merge or conversion | `merge_clouds` or `convert_format` |

Change the supported-format wording so OBJ, STL, and mesh-based scans are accepted only as comparison references; remove "STL or mesh analysis" from the point-cloud trigger list. Keep the existing prohibition on mesh repair and FreeCAD document creation.

- [ ] **Step 3: Run GREEN scenarios**

Repeat the three baseline scenarios with the edited skill loaded. Expected: every response selects CloudCompare MCP, names the exact mapped tool, preserves the source, and gives a distinct output path.

- [ ] **Step 4: Check skill structure**

Verify frontmatter remains valid, `name` still matches `pointcloud-analysis`, no unsupported MCP tool is named, and no instructions tell the agent to create FreeCAD documents.

### Task 8: Route Mesh Repair to MeshLab MCP

**Files:**
- Modify: `/home/anders/Projekt/FreeCAD/skills/mesh-repair/SKILL.md`

- [ ] **Step 1: Run and record the RED baseline**

Dispatch at least three fresh subagents without added MeshLab instructions:

1. "Clean duplicate and degenerate elements in `/data/scan.obj`, preserving the source. State the application and tools you would call."
2. "Close holes no larger than 40 edges and recompute normals in `/data/part.stl`. State the application and tools you would call."
3. "Reduce `/data/dense.ply` to 100000 faces, preserving topology and boundaries. State the application and tools you would call."

Record whether each response names MeshLab MCP and the safe core tool. Expected baseline failure: unspecified application, generic filters, or overlap with point-cloud analysis.

- [ ] **Step 2: Add explicit MeshLab routing**

Replace the frontmatter description with:

```yaml
description: Use when scanned triangle meshes need cleaning, topology repair, normal correction, remeshing, smoothing, simplification, or safe format conversion before analysis or CAD reconstruction.
```

Remove `point clouds` from `# When to use`, replace `point cloud cleanup` under Responsibilities with `mesh cleanup`, and remove the point-cloud inspection subsection. Insert this section after Responsibilities and before Input:

```markdown
# Required application and MCP tools

Use the global `meshlab` MCP server for all triangulated mesh operations.

| Need | MCP tool |
| --- | --- |
| Mesh statistics and topology | `inspect_mesh` |
| Duplicate/degenerate cleanup | `clean_mesh` |
| Bounded hole filling | `repair_holes` |
| Face and vertex normals | `compute_normals` |
| Quadric decimation | `simplify_mesh` |
| Isotropic remeshing | `remesh_mesh` |
| Conservative smoothing | `smooth_mesh` |
| Format conversion | `export_mesh` |

Every tool call must use absolute paths. Mutating calls must use a distinct output path and retain the source unchanged. Record explicit numeric limits and compare returned before/after metadata.

Do not call generic filters, shell commands, or Python execution. Point-cloud filtering, downsampling, ICP, and C2C/C2M calculations belong to `pointcloud-analysis` and the global `cloudcompare` MCP server.

---
```

Use this exact mapping in the section:

| Need | MCP tool |
| --- | --- |
| Mesh statistics and topology | `inspect_mesh` |
| Duplicate/degenerate cleanup | `clean_mesh` |
| Bounded hole filling | `repair_holes` |
| Face and vertex normals | `compute_normals` |
| Quadric decimation | `simplify_mesh` |
| Isotropic remeshing | `remesh_mesh` |
| Conservative smoothing | `smooth_mesh` |
| Format conversion | `export_mesh` |

Change the Input `type` field from `mesh | pointcloud` to `mesh`. Remove or redirect remaining instructions for voxel downsampling, point-cloud duplicate removal, and point-cloud smoothing so they call `pointcloud-analysis` rather than MeshLab MCP.

- [ ] **Step 3: Run GREEN scenarios**

Repeat all three baseline scenarios with the edited skill loaded. Expected: each response selects MeshLab MCP, calls only mapped tools, preserves source files, and uses separate derivative paths.

- [ ] **Step 4: Check skill structure**

Verify valid frontmatter, unchanged skill name, no generic `apply_filter`, and no FreeCAD document modification instructions.

### Task 9: Final Verification, Commit, and Push

**Files:**
- Verify all intended files above.

- [ ] **Step 1: Run all MeshLab tests fresh**

```bash
PYTHONPATH=packages/meshlab-mcp nix shell --impure --expr 'with import <nixpkgs> {}; python313.withPackages (ps: with ps; [ mcp pymeshlab pytest pytest-asyncio ])' --command pytest packages/meshlab-mcp/tests -v
```

Expected: all tests pass.

- [ ] **Step 2: Run full Nix verification fresh**

```bash
nix flake show --json --no-write-lock-file
nix build .#nixosConfigurations.laptop-intel.config.system.build.toplevel --no-link
```

Expected: both commands exit 0 without changing `flake.lock` beyond its pre-existing diff.

- [ ] **Step 3: Verify active programs and MCP configuration**

```bash
nix eval --raw .#nixosConfigurations.laptop-intel.pkgs.cloudcompare.version
command -v CloudCompare
command -v cloudcompare-mcp
meshlab --version
command -v meshlab-mcp
opencode debug config
opencode mcp list
```

Expected: Nix metadata reports CloudCompare 2.13.x, both applications and MCP wrappers resolve, OpenCode reports both new servers, and the resolved permission denies `cloudcompare_run_cloudcompare_command`. Do not use `CloudCompare --version` as version evidence.

- [ ] **Step 4: Inspect repository state before the final commit**

Run `git status --short`, `git diff`, and `git log --oneline -10`. Confirm only intended uncommitted NixOS files remain and `flake.lock` is not staged.

- [ ] **Step 5: Commit any remaining intended repository changes**

Stage only explicit files from this plan. Use a concise repository-style message. Never include `flake.lock` unless the user separately requests that existing change.

- [ ] **Step 6: Push the completed NixOS commits**

```bash
git push origin main
```

Expected: push succeeds without force and `origin/main` includes the design and implementation commits.

- [ ] **Step 7: Report external changes and restart requirement**

Report that `~/.config/opencode/opencode.json` and the two skill files are outside the Git repository. Tell the user to quit and restart OpenCode so the running process loads the new MCP definitions.
