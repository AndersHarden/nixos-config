from pathlib import Path
from typing import Iterable

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
    return mesh_set


def _vector(value: Iterable[float]) -> list[float]:
    return [float(component) for component in value]


def _metadata(mesh_set: pymeshlab.MeshSet) -> dict:
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
        "volume": float(geometric["mesh_volume"]),
        "bounds": {"min": _vector(bounds.min()), "max": _vector(bounds.max())},
    }


def inspect_mesh(input_path: str) -> dict:
    path = validate_input_path(input_path)
    return {"input_path": str(path), **_metadata(_load_mesh(path))}
