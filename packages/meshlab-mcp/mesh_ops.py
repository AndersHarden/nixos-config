import os
import tempfile
from pathlib import Path
from typing import Callable, Iterable

import pymeshlab


SUPPORTED_EXTENSIONS = {".obj", ".off", ".ply", ".stl"}


class MeshOperationError(ValueError):
    pass


def validate_input_path(value: str) -> Path:
    path = Path(value)
    if not path.is_absolute():
        raise MeshOperationError("Input path must be absolute")
    if not path.is_file():
        raise MeshOperationError(f"Input path is not an existing file: {path}")
    if path.suffix.lower() not in SUPPORTED_EXTENSIONS:
        raise MeshOperationError(f"Unsupported mesh extension: {path.suffix}")
    return path


def validate_output_path(input_path: Path, output_path: Path) -> Path:
    if not output_path.is_absolute():
        raise MeshOperationError("Output path must be absolute")
    if input_path == output_path:
        raise MeshOperationError("Input and output paths must be different")
    if output_path.exists():
        raise MeshOperationError(f"Output path already exists: {output_path}")
    if not output_path.parent.is_dir():
        raise MeshOperationError(
            f"Output parent directory does not exist: {output_path.parent}"
        )
    if output_path.suffix.lower() not in SUPPORTED_EXTENSIONS:
        raise MeshOperationError(f"Unsupported mesh extension: {output_path.suffix}")
    return output_path


def _load_mesh(path: Path) -> pymeshlab.MeshSet:
    mesh_set = pymeshlab.MeshSet()
    try:
        mesh_set.load_new_mesh(str(path))
    except Exception as error:
        raise MeshOperationError(f"Failed to load mesh '{path}': {error}") from error
    if mesh_set.current_mesh().vertex_number() == 0:
        raise MeshOperationError(f"Mesh has no vertices: {path}")
    if mesh_set.current_mesh().face_number() == 0:
        raise MeshOperationError(f"Mesh has no faces: {path}")
    return mesh_set


def _vector(value: Iterable[float]) -> list[float]:
    return [float(component) for component in value]


def _metadata(mesh_set: pymeshlab.MeshSet) -> dict[str, object]:
    topological = mesh_set.get_topological_measures()
    geometric = mesh_set.get_geometric_measures()
    bounds = geometric["bbox"]
    return {
        "vertices": int(topological["vertices_number"]),
        "faces": int(topological["faces_number"]),
        "connected_components": int(topological["connected_components_number"]),
        "holes": int(topological["number_holes"]),
        "boundary_edges": int(topological["boundary_edges"]),
        "is_two_manifold": bool(topological["is_mesh_two_manifold"]),
        "surface_area": float(geometric["surface_area"]),
        "volume": float(geometric.get("mesh_volume", 0.0)),
        "volume_available": "mesh_volume" in geometric,
        "bounds": {"min": _vector(bounds.min()), "max": _vector(bounds.max())},
    }


def inspect_mesh(input_path: str) -> dict[str, object]:
    path = validate_input_path(input_path)
    return {"input_path": str(path), **_metadata(_load_mesh(path))}


def _transform(
    operation: str,
    input_path: str,
    output_path: str,
    action: Callable[[pymeshlab.MeshSet], None],
    parameters: dict[str, object],
) -> dict[str, object]:
    source = Path(input_path)
    temporary_path: Path | None = None
    try:
        source = validate_input_path(input_path)
        destination = validate_output_path(source, Path(output_path))
        mesh_set = _load_mesh(source)
        before = _metadata(mesh_set)
        action(mesh_set)

        with tempfile.NamedTemporaryFile(
            dir=destination.parent,
            prefix=f".{destination.stem}-",
            suffix=destination.suffix,
            delete=False,
        ) as temporary_file:
            temporary_path = Path(temporary_file.name)

        mesh_set.save_current_mesh(str(temporary_path))
        after = _metadata(_load_mesh(temporary_path))
        if after["vertices"] == 0 or after["faces"] == 0:
            raise MeshOperationError("Operation produced an empty mesh")
        os.replace(temporary_path, destination)
        temporary_path = None
        return {
            "operation": operation,
            "input_path": str(source),
            "output_path": str(destination),
            "parameters": parameters,
            "before": before,
            "after": after,
        }
    except Exception as error:
        raise MeshOperationError(
            f"{operation} failed for source '{source}': {error}"
        ) from error
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


def clean_mesh(input_path: str, output_path: str) -> dict[str, object]:
    def clean(mesh_set: pymeshlab.MeshSet) -> None:
        mesh_set.meshing_remove_duplicate_vertices()
        mesh_set.meshing_remove_duplicate_faces()
        mesh_set.meshing_remove_null_faces()
        mesh_set.meshing_remove_unreferenced_vertices()

    return _transform("clean_mesh", input_path, output_path, clean, {})


def repair_holes(
    input_path: str, output_path: str, max_hole_size: int = 30
) -> dict[str, object]:
    if not 1 <= max_hole_size <= 100000:
        raise MeshOperationError("max_hole_size must be between 1 and 100000")

    def repair(mesh_set: pymeshlab.MeshSet) -> None:
        mesh_set.meshing_close_holes(maxholesize=max_hole_size)

    return _transform(
        "repair_holes",
        input_path,
        output_path,
        repair,
        {"max_hole_size": max_hole_size},
    )


def compute_normals(input_path: str, output_path: str) -> dict[str, object]:
    def compute(mesh_set: pymeshlab.MeshSet) -> None:
        mesh_set.compute_normal_per_face()
        mesh_set.compute_normal_per_vertex()

    return _transform("compute_normals", input_path, output_path, compute, {})


def simplify_mesh(
    input_path: str, output_path: str, target_faces: int
) -> dict[str, object]:
    if target_faces < 4:
        raise MeshOperationError("target_faces must be at least 4")

    def simplify(mesh_set: pymeshlab.MeshSet) -> None:
        if target_faces >= mesh_set.current_mesh().face_number():
            raise MeshOperationError(
                "target_faces must be lower than the source face count"
            )
        mesh_set.meshing_decimation_quadric_edge_collapse(
            targetfacenum=target_faces,
            preserveboundary=True,
            preservenormal=True,
            preservetopology=True,
            autoclean=True,
        )

    return _transform(
        "simplify_mesh",
        input_path,
        output_path,
        simplify,
        {"target_faces": target_faces},
    )


def remesh_mesh(
    input_path: str,
    output_path: str,
    target_edge_length: float,
    iterations: int = 5,
) -> dict[str, object]:
    if target_edge_length <= 0:
        raise MeshOperationError("target_edge_length must be greater than 0")
    if not 1 <= iterations <= 20:
        raise MeshOperationError("iterations must be between 1 and 20")

    def remesh(mesh_set: pymeshlab.MeshSet) -> None:
        mesh_set.meshing_isotropic_explicit_remeshing(
            targetlen=pymeshlab.PureValue(target_edge_length),
            iterations=iterations,
            adaptive=False,
            checksurfdist=True,
        )

    return _transform(
        "remesh_mesh",
        input_path,
        output_path,
        remesh,
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

    def smooth(mesh_set: pymeshlab.MeshSet) -> None:
        if method == "taubin":
            mesh_set.apply_coord_taubin_smoothing(stepsmoothnum=iterations)
        else:
            mesh_set.apply_coord_laplacian_smoothing(
                stepsmoothnum=iterations,
                boundary=False,
                cotangentweight=True,
            )

    return _transform(
        "smooth_mesh",
        input_path,
        output_path,
        smooth,
        {"method": method, "iterations": iterations},
    )


def export_mesh(input_path: str, output_path: str) -> dict[str, object]:
    return _transform("export_mesh", input_path, output_path, lambda mesh_set: None, {})
