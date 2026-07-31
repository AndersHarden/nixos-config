from pathlib import Path

import pytest

import mesh_ops
from mesh_ops import MeshOperationError, inspect_mesh, validate_output_path


def test_inspect_mesh_returns_cube_metadata(cube_path: Path) -> None:
    metadata = inspect_mesh(str(cube_path))

    assert metadata["vertices"] == 8
    assert metadata["faces"] == 12
    assert metadata["connected_components"] == 1
    assert metadata["holes"] == 0
    assert metadata["volume_available"] is True
    assert metadata["bounds"] == {
        "min": [-1.0, -1.0, -1.0],
        "max": [1.0, 1.0, 1.0],
    }


def test_inspect_mesh_returns_open_mesh_metadata(open_tetra_path: Path) -> None:
    metadata = inspect_mesh(str(open_tetra_path))

    assert metadata["input_path"] == str(open_tetra_path)
    assert metadata["vertices"] == 4
    assert metadata["faces"] == 3
    assert metadata["connected_components"] == 1
    assert metadata["holes"] == 1
    assert metadata["boundary_edges"] == 3
    assert metadata["is_two_manifold"] is True
    assert metadata["surface_area"] > 0.0
    assert metadata["volume"] == 0.0
    assert metadata["volume_available"] is False
    assert metadata["bounds"] == {
        "min": [-1.0, -1.0, -1.0],
        "max": [1.0, 1.0, 1.0],
    }


def test_inspect_mesh_rejects_mesh_without_faces(vertex_only_path: Path) -> None:
    with pytest.raises(MeshOperationError, match="faces"):
        inspect_mesh(str(vertex_only_path))


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


@pytest.mark.parametrize(
    ("operation", "parameters"),
    [
        ("clean_mesh", {}),
        ("compute_normals", {}),
        ("simplify_mesh", {"target_faces": 6}),
        ("remesh_mesh", {"target_edge_length": 0.75, "iterations": 1}),
        ("smooth_mesh", {"method": "taubin", "iterations": 1}),
    ],
)
def test_mesh_transform_preserves_source_and_writes_nonempty_ply(
    cube_path: Path, tmp_path: Path, operation: str, parameters: dict[str, object]
) -> None:
    source_bytes = cube_path.read_bytes()
    output_path = tmp_path / f"{operation}.ply"

    result = getattr(mesh_ops, operation)(str(cube_path), str(output_path), **parameters)

    assert cube_path.read_bytes() == source_bytes
    assert output_path.is_file()
    assert output_path != cube_path
    assert result["operation"] == operation
    assert result["before"]["vertices"] > 0
    assert result["before"]["faces"] > 0
    assert result["after"]["vertices"] > 0
    assert result["after"]["faces"] > 0


def test_repair_holes_closes_open_tetra(open_tetra_path: Path, tmp_path: Path) -> None:
    source_bytes = open_tetra_path.read_bytes()
    output_path = tmp_path / "repaired.ply"

    result = mesh_ops.repair_holes(
        str(open_tetra_path), str(output_path), max_hole_size=20
    )

    assert open_tetra_path.read_bytes() == source_bytes
    assert output_path.is_file()
    assert result["before"]["holes"] == 1
    assert result["after"]["holes"] == 0


def test_export_mesh_converts_obj_to_stl(cube_path: Path, tmp_path: Path) -> None:
    source_bytes = cube_path.read_bytes()
    output_path = tmp_path / "cube.stl"

    result = mesh_ops.export_mesh(str(cube_path), str(output_path))

    assert cube_path.read_bytes() == source_bytes
    assert output_path.is_file()
    assert result["operation"] == "export_mesh"
    assert result["after"]["vertices"] > 0
    assert result["after"]["faces"] > 0


@pytest.mark.parametrize(
    ("operation", "parameters", "message"),
    [
        ("repair_holes", {"max_hole_size": 0}, "max_hole_size"),
        ("simplify_mesh", {"target_faces": 3}, "target_faces"),
        ("remesh_mesh", {"target_edge_length": 0}, "target_edge_length"),
        ("smooth_mesh", {"method": "unknown"}, "method"),
        ("smooth_mesh", {"iterations": 101}, "iterations"),
    ],
)
def test_mesh_transform_rejects_invalid_parameters(
    cube_path: Path,
    tmp_path: Path,
    operation: str,
    parameters: dict[str, object],
    message: str,
) -> None:
    output_path = tmp_path / f"invalid-{message}.ply"

    with pytest.raises(MeshOperationError, match=message):
        getattr(mesh_ops, operation)(str(cube_path), str(output_path), **parameters)

    assert not output_path.exists()
