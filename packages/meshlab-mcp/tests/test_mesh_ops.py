import base64
import os
from pathlib import Path
from typing import get_args, get_type_hints

import pymeshlab
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
        ("smooth_mesh", {"method": "laplacian", "iterations": 1}),
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
    if operation == "simplify_mesh":
        assert result["after"]["faces"] <= parameters["target_faces"]


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
        (
            "repair_holes",
            {"max_hole_size": 0},
            "max_hole_size must be between 1 and 100000",
        ),
        (
            "repair_holes",
            {"max_hole_size": 100001},
            "max_hole_size must be between 1 and 100000",
        ),
        ("simplify_mesh", {"target_faces": 3}, "target_faces must be at least 4"),
        (
            "simplify_mesh",
            {"target_faces": 12},
            "target_faces must be lower than the source face count",
        ),
        (
            "remesh_mesh",
            {"target_edge_length": 0},
            "target_edge_length must be a finite number greater than 0",
        ),
        (
            "remesh_mesh",
            {"target_edge_length": float("nan")},
            "target_edge_length must be a finite number greater than 0",
        ),
        (
            "remesh_mesh",
            {"target_edge_length": float("inf")},
            "target_edge_length must be a finite number greater than 0",
        ),
        (
            "remesh_mesh",
            {"target_edge_length": float("-inf")},
            "target_edge_length must be a finite number greater than 0",
        ),
        (
            "remesh_mesh",
            {"target_edge_length": "0.75"},
            "target_edge_length must be a finite number greater than 0",
        ),
        (
            "remesh_mesh",
            {"target_edge_length": True},
            "target_edge_length must be a finite number greater than 0",
        ),
        (
            "remesh_mesh",
            {"target_edge_length": 0.75, "iterations": 0},
            "iterations must be between 1 and 20",
        ),
        (
            "remesh_mesh",
            {"target_edge_length": 0.75, "iterations": 21},
            "iterations must be between 1 and 20",
        ),
        (
            "smooth_mesh",
            {"method": "unknown"},
            "method must be 'taubin' or 'laplacian'",
        ),
        (
            "smooth_mesh",
            {"iterations": 0},
            "iterations must be between 1 and 100",
        ),
        (
            "smooth_mesh",
            {"iterations": 101},
            "iterations must be between 1 and 100",
        ),
    ],
)
def test_mesh_transform_rejects_invalid_parameters(
    cube_path: Path,
    tmp_path: Path,
    operation: str,
    parameters: dict[str, object],
    message: str,
) -> None:
    output_path = tmp_path / f"invalid-{operation}.ply"

    with pytest.raises(MeshOperationError) as error:
        getattr(mesh_ops, operation)(str(cube_path), str(output_path), **parameters)

    assert message in str(error.value)
    assert not output_path.exists()


def test_remesh_mesh_defaults_to_five_iterations(
    cube_path: Path, tmp_path: Path
) -> None:
    output_path = tmp_path / "remeshed-default.ply"

    result = mesh_ops.remesh_mesh(
        str(cube_path), str(output_path), target_edge_length=0.75
    )

    assert result["parameters"]["iterations"] == 5


def test_transform_does_not_clobber_racing_destination(
    cube_path: Path, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    output_path = tmp_path / "raced.ply"
    real_link = os.link

    def create_destination_then_link(
        source: str,
        destination: str,
        *,
        src_dir_fd: int,
        dst_dir_fd: int,
        follow_symlinks: bool,
    ) -> None:
        racer_fd = os.open(
            destination,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL,
            0o600,
            dir_fd=dst_dir_fd,
        )
        try:
            os.write(racer_fd, b"racer")
        finally:
            os.close(racer_fd)
        real_link(
            source,
            destination,
            src_dir_fd=src_dir_fd,
            dst_dir_fd=dst_dir_fd,
            follow_symlinks=follow_symlinks,
        )

    monkeypatch.setattr(os, "link", create_destination_then_link)

    with pytest.raises(MeshOperationError, match="already exists"):
        mesh_ops.clean_mesh(str(cube_path), str(output_path))

    assert output_path.read_bytes() == b"racer"


def test_transform_does_not_replace_dangling_destination_symlink(
    cube_path: Path, tmp_path: Path
) -> None:
    output_path = tmp_path / "dangling.ply"
    output_path.symlink_to("missing-target.ply")

    with pytest.raises(MeshOperationError, match="already exists"):
        mesh_ops.clean_mesh(str(cube_path), str(output_path))

    assert output_path.is_symlink()
    assert os.readlink(output_path) == "missing-target.ply"


def test_transform_rejects_symlink_component_in_output_parent(
    cube_path: Path, tmp_path: Path
) -> None:
    real_parent = tmp_path / "real"
    real_parent.mkdir()
    linked_parent = tmp_path / "linked"
    linked_parent.symlink_to(real_parent, target_is_directory=True)
    output_path = linked_parent / "output.ply"

    with pytest.raises(MeshOperationError, match="symlink"):
        mesh_ops.clean_mesh(str(cube_path), str(output_path))

    assert not (real_parent / "output.ply").exists()


def test_transform_rejects_changed_output_directory_identity(
    cube_path: Path, tmp_path: Path
) -> None:
    output_parent = tmp_path / "output"
    output_parent.mkdir()
    moved_parent = tmp_path / "moved"
    attacker_parent = tmp_path / "attacker"
    attacker_parent.mkdir()
    output_path = output_parent / "output.ply"

    def swap_parent(mesh_set: object) -> None:
        output_parent.rename(moved_parent)
        output_parent.symlink_to(attacker_parent, target_is_directory=True)

    with pytest.raises(MeshOperationError, match="directory identity changed"):
        mesh_ops._transform("swap_parent", str(cube_path), str(output_path), swap_parent, {})

    assert not (moved_parent / "output.ply").exists()
    assert not (attacker_parent / "output.ply").exists()


def test_transform_error_has_context_and_cleans_temporary_file(
    cube_path: Path, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    output_path = tmp_path / "failed.ply"

    def fail_link(*args: object, **kwargs: object) -> None:
        raise OSError("publish failed")

    monkeypatch.setattr(os, "link", fail_link)

    with pytest.raises(MeshOperationError) as error:
        mesh_ops.clean_mesh(str(cube_path), str(output_path))

    message = str(error.value)
    assert "clean_mesh" in message
    assert str(cube_path) in message
    assert str(output_path) in message
    assert "parameters={}" in message
    assert "publish failed" in message
    assert list(tmp_path.glob(".failed-*")) == []


def test_cleanup_error_does_not_mask_publication_error(
    cube_path: Path, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    output_path = tmp_path / "failed.ply"

    def fail_link(*args: object, **kwargs: object) -> None:
        raise OSError("publish failed")

    def fail_unlink(*args: object, **kwargs: object) -> None:
        raise OSError("cleanup failed")

    monkeypatch.setattr(os, "link", fail_link)
    monkeypatch.setattr(os, "unlink", fail_unlink)

    with pytest.raises(MeshOperationError) as error:
        mesh_ops.clean_mesh(str(cube_path), str(output_path))

    assert "publish failed" in str(error.value)
    assert "cleanup failed" not in str(error.value)


def test_clean_mesh_removes_duplicate_geometry(tmp_path: Path) -> None:
    input_path = tmp_path / "dirty.obj"
    input_path.write_text(
        """\
v 0 0 0
v 1 0 0
v 0 1 0
v 9 9 9
v 0 0 0
f 1 2 3
f 1 2 3
f 5 2 3
""",
        encoding="ascii",
    )
    source_bytes = input_path.read_bytes()
    output_path = tmp_path / "clean.ply"

    result = mesh_ops.clean_mesh(str(input_path), str(output_path))

    assert input_path.read_bytes() == source_bytes
    assert result["after"]["vertices"] < result["before"]["vertices"]
    assert result["after"]["faces"] < result["before"]["faces"]
    assert result["after"]["vertices"] == 3
    assert result["after"]["faces"] == 1


def test_compute_normals_orients_faces_and_writes_normals(tmp_path: Path) -> None:
    input_path = tmp_path / "inconsistent.obj"
    input_path.write_text(
        """\
v 0 0 0
v 1 0 0
v 1 1 0
v 0 1 0
f 1 2 3
f 1 4 3
""",
        encoding="ascii",
    )
    output_path = tmp_path / "normals.ply"

    mesh_ops.compute_normals(str(input_path), str(output_path))

    mesh_set = pymeshlab.MeshSet()
    mesh_set.load_new_mesh(str(output_path))
    mesh = mesh_set.current_mesh()
    face_normals = mesh.face_normal_matrix()
    vertex_normals = mesh.vertex_normal_matrix()
    assert float(face_normals[0] @ face_normals[1]) > 0.99
    assert ((vertex_normals * vertex_normals).sum(axis=1) > 0.99).all()


def test_remesh_changes_tessellation(cube_path: Path, tmp_path: Path) -> None:
    result = mesh_ops.remesh_mesh(
        str(cube_path),
        str(tmp_path / "remeshed.ply"),
        target_edge_length=0.75,
        iterations=1,
    )

    assert result["after"]["faces"] > result["before"]["faces"]
    assert result["after"]["surface_area"] > 0


@pytest.mark.parametrize("method", ["taubin", "laplacian"])
def test_smoothing_preserves_topology_and_changes_bounds(
    cube_path: Path, tmp_path: Path, method: str
) -> None:
    result = mesh_ops.smooth_mesh(
        str(cube_path),
        str(tmp_path / f"smoothed-{method}.ply"),
        method=method,
        iterations=1,
    )

    assert result["after"]["vertices"] == result["before"]["vertices"]
    assert result["after"]["faces"] == result["before"]["faces"]
    assert result["after"]["bounds"] != result["before"]["bounds"]
    assert result["after"]["surface_area"] > 0


def test_mesh_operation_annotations_expose_result_schema() -> None:
    assert get_type_hints(mesh_ops._metadata)["return"] is mesh_ops.MeshMetadata
    assert (
        get_type_hints(mesh_ops._transform)["return"]
        is mesh_ops.MeshOperationResult
    )
    assert get_type_hints(mesh_ops.clean_mesh)["return"] is mesh_ops.MeshOperationResult
    assert get_args(get_type_hints(mesh_ops.smooth_mesh)["method"]) == (
        "taubin",
        "laplacian",
    )


def test_private_staging_prevents_public_temp_symlink_substitution(
    cube_path: Path, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    output_path = tmp_path / "output.ply"
    external_target = tmp_path / "external.ply"
    external_target.write_bytes(b"external-data")
    real_save = pymeshlab.MeshSet.save_current_mesh

    def substitute_public_temp(
        mesh_set: pymeshlab.MeshSet, path: str, **kwargs: object
    ) -> None:
        for candidate in tmp_path.iterdir():
            if candidate.name.startswith(".output-") and candidate.is_file():
                candidate.unlink()
                candidate.symlink_to(external_target)
        real_save(mesh_set, path, **kwargs)

    monkeypatch.setattr(
        pymeshlab.MeshSet, "save_current_mesh", substitute_public_temp
    )

    result = mesh_ops.clean_mesh(str(cube_path), str(output_path))

    assert result["operation"] == "clean_mesh"
    assert external_target.read_bytes() == b"external-data"
    assert output_path.is_file()
    assert not output_path.is_symlink()
    assert not any(
        candidate.name.startswith(".output-staging-")
        for candidate in tmp_path.iterdir()
    )


def test_transform_rolls_back_if_parent_changes_during_link(
    cube_path: Path, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    output_parent = tmp_path / "output"
    output_parent.mkdir()
    moved_parent = tmp_path / "moved"
    attacker_parent = tmp_path / "attacker"
    attacker_parent.mkdir()
    output_path = output_parent / "result.ply"
    real_link = os.link

    def swap_parent_then_link(
        source: str,
        destination: str,
        *,
        src_dir_fd: int,
        dst_dir_fd: int,
        follow_symlinks: bool,
    ) -> None:
        output_parent.rename(moved_parent)
        output_parent.symlink_to(attacker_parent, target_is_directory=True)
        real_link(
            source,
            destination,
            src_dir_fd=src_dir_fd,
            dst_dir_fd=dst_dir_fd,
            follow_symlinks=follow_symlinks,
        )

    monkeypatch.setattr(os, "link", swap_parent_then_link)

    with pytest.raises(MeshOperationError, match="directory identity changed"):
        mesh_ops.clean_mesh(str(cube_path), str(output_path))

    assert not (moved_parent / "result.ply").exists()
    assert not (attacker_parent / "result.ply").exists()


def test_cleanup_failure_after_commit_returns_warning(
    cube_path: Path, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    output_path = tmp_path / "output.ply"
    real_link = os.link
    real_unlink = os.unlink
    committed = False

    def track_link(*args: object, **kwargs: object) -> None:
        nonlocal committed
        real_link(*args, **kwargs)
        committed = True

    def fail_post_commit_cleanup(
        path: str, *, dir_fd: int | None = None
    ) -> None:
        if committed and path != output_path.name:
            raise OSError("post-commit cleanup failed")
        real_unlink(path, dir_fd=dir_fd)

    monkeypatch.setattr(os, "link", track_link)
    monkeypatch.setattr(os, "unlink", fail_post_commit_cleanup)

    result = mesh_ops.clean_mesh(str(cube_path), str(output_path))

    assert output_path.is_file()
    assert any("post-commit cleanup failed" in warning for warning in result["warnings"])
    assert "warnings" in mesh_ops.MeshOperationResult.__required_keys__


def test_transform_rejects_material_obj_sidecar_output(tmp_path: Path) -> None:
    input_path = tmp_path / "textured.obj"
    material_path = tmp_path / "material.mtl"
    texture_path = tmp_path / "texture.png"
    input_path.write_text(
        """\
mtllib material.mtl
v 0 0 0
v 1 0 0
v 0 1 0
vt 0 0
vt 1 0
vt 0 1
usemtl material
f 1/1 2/2 3/3
""",
        encoding="ascii",
    )
    material_path.write_text(
        """\
newmtl material
Kd 1.0 1.0 1.0
map_Kd texture.png
""",
        encoding="ascii",
    )
    texture_path.write_bytes(
        base64.b64decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk"
            "+A8AAQUBAScY42YAAAAASUVORK5CYII="
        )
    )
    source_bytes = {
        path: path.read_bytes()
        for path in (input_path, material_path, texture_path)
    }
    output_path = tmp_path / "output.obj"

    with pytest.raises(
        MeshOperationError, match="multi-file mesh output is not supported"
    ):
        mesh_ops.export_mesh(str(input_path), str(output_path))

    assert all(
        path.read_bytes() == content for path, content in source_bytes.items()
    )
    assert not output_path.exists()
    assert not any(
        path.name.startswith(".output-staging-") for path in tmp_path.iterdir()
    )


@pytest.mark.parametrize("extension", ["obj", "off", "ply", "stl"])
def test_export_mesh_supports_single_file_formats(
    cube_path: Path, tmp_path: Path, extension: str
) -> None:
    output_path = tmp_path / f"single.{extension}"

    result = mesh_ops.export_mesh(str(cube_path), str(output_path))

    assert output_path.is_file()
    assert result["after"]["vertices"] > 0
    assert result["after"]["faces"] > 0
