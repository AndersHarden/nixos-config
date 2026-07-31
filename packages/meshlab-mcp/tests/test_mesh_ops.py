from pathlib import Path

import pytest

from mesh_ops import MeshOperationError, inspect_mesh, validate_output_path


def test_inspect_mesh_returns_cube_metadata(cube_path: Path) -> None:
    metadata = inspect_mesh(str(cube_path))

    assert metadata["vertices"] == 8
    assert metadata["faces"] == 12
    assert metadata["connected_components"] == 1
    assert metadata["holes"] == 0
    assert metadata["bounds"] == {
        "min": [-1.0, -1.0, -1.0],
        "max": [1.0, 1.0, 1.0],
    }


def test_inspect_mesh_rejects_relative_input() -> None:
    with pytest.raises(MeshOperationError, match="absolute"):
        inspect_mesh("cube.obj")


def test_validate_output_path_rejects_input_path(cube_path: Path) -> None:
    with pytest.raises(MeshOperationError, match="different"):
        validate_output_path(cube_path, cube_path)


def test_validate_output_path_rejects_existing_file(
    cube_path: Path, tmp_path: Path
) -> None:
    output_path = tmp_path / "existing.obj"
    output_path.write_text("", encoding="ascii")

    with pytest.raises(MeshOperationError, match="already exists"):
        validate_output_path(cube_path, output_path)
