import math
import os
import secrets
import stat
from numbers import Real
from pathlib import Path
from typing import Callable, Iterable, Literal, TypedDict

import pymeshlab


SUPPORTED_EXTENSIONS = {".obj", ".off", ".ply", ".stl"}


class MeshBounds(TypedDict):
    min: list[float]
    max: list[float]


class MeshMetadata(TypedDict):
    vertices: int
    faces: int
    connected_components: int
    holes: int
    boundary_edges: int
    is_two_manifold: bool
    surface_area: float
    volume: float
    volume_available: bool
    bounds: MeshBounds


class MeshInspection(MeshMetadata):
    input_path: str


class MeshOperationResult(TypedDict):
    operation: str
    input_path: str
    output_path: str
    parameters: dict[str, object]
    before: MeshMetadata
    after: MeshMetadata


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
    if output_path.exists() or output_path.is_symlink():
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


def _metadata(mesh_set: pymeshlab.MeshSet) -> MeshMetadata:
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


def inspect_mesh(input_path: str) -> MeshInspection:
    path = validate_input_path(input_path)
    return {"input_path": str(path), **_metadata(_load_mesh(path))}


def _open_directory_no_symlinks(path: Path) -> int:
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    directory_fd = os.open("/", flags)
    try:
        for component in path.parts[1:]:
            try:
                next_fd = os.open(component, flags, dir_fd=directory_fd)
            except OSError as error:
                try:
                    component_stat = os.stat(
                        component, dir_fd=directory_fd, follow_symlinks=False
                    )
                except OSError:
                    component_stat = None
                if component_stat is not None and stat.S_ISLNK(component_stat.st_mode):
                    raise MeshOperationError(
                        f"Output parent contains symlink component: {component}"
                    ) from error
                raise MeshOperationError(
                    f"Cannot securely open output parent component: {component}"
                ) from error
            os.close(directory_fd)
            directory_fd = next_fd
        return directory_fd
    except Exception:
        os.close(directory_fd)
        raise


def _verify_directory_identity(path: Path, directory_fd: int) -> None:
    verification_fd: int | None = None
    try:
        verification_fd = _open_directory_no_symlinks(path)
        opened = os.fstat(directory_fd)
        current = os.fstat(verification_fd)
        if (opened.st_dev, opened.st_ino) != (current.st_dev, current.st_ino):
            raise MeshOperationError("Output directory identity changed")
    except Exception as error:
        if isinstance(error, MeshOperationError) and str(error) == (
            "Output directory identity changed"
        ):
            raise
        raise MeshOperationError("Output directory identity changed") from error
    finally:
        if verification_fd is not None:
            os.close(verification_fd)


def _transform(
    operation: str,
    input_path: str,
    output_path: str,
    action: Callable[[pymeshlab.MeshSet], None],
    parameters: dict[str, object],
) -> MeshOperationResult:
    source = Path(input_path)
    destination = Path(output_path)
    directory_fd: int | None = None
    temporary_name: str | None = None
    failed = False
    try:
        source = validate_input_path(input_path)
        destination = validate_output_path(source, destination)
        directory_fd = _open_directory_no_symlinks(destination.parent)
        mesh_set = _load_mesh(source)
        before = _metadata(mesh_set)
        action(mesh_set)

        temporary_name = (
            f".{destination.stem}-{secrets.token_hex(8)}{destination.suffix}"
        )
        temporary_fd = os.open(
            temporary_name,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
            0o600,
            dir_fd=directory_fd,
        )
        os.close(temporary_fd)
        temporary_path = Path(f"/proc/self/fd/{directory_fd}/{temporary_name}")
        mesh_set.save_current_mesh(str(temporary_path))
        after = _metadata(_load_mesh(temporary_path))
        if after["vertices"] == 0 or after["faces"] == 0:
            raise MeshOperationError("Operation produced an empty mesh")
        _verify_directory_identity(destination.parent, directory_fd)
        try:
            os.link(
                temporary_name,
                destination.name,
                src_dir_fd=directory_fd,
                dst_dir_fd=directory_fd,
                follow_symlinks=False,
            )
        except FileExistsError as error:
            raise MeshOperationError(
                f"Output path already exists: {destination}"
            ) from error
        os.unlink(temporary_name, dir_fd=directory_fd)
        temporary_name = None
        return {
            "operation": operation,
            "input_path": str(source),
            "output_path": str(destination),
            "parameters": parameters,
            "before": before,
            "after": after,
        }
    except Exception as error:
        failed = True
        raise MeshOperationError(
            f"{operation} failed for source '{source}', destination "
            f"'{destination}', parameters={parameters!r}: {error}"
        ) from error
    finally:
        if temporary_name is not None and directory_fd is not None:
            try:
                os.unlink(temporary_name, dir_fd=directory_fd)
            except FileNotFoundError:
                pass
            except OSError:
                if not failed:
                    raise
        if directory_fd is not None:
            try:
                os.close(directory_fd)
            except OSError:
                if not failed:
                    raise


def clean_mesh(input_path: str, output_path: str) -> MeshOperationResult:
    def clean(mesh_set: pymeshlab.MeshSet) -> None:
        mesh_set.meshing_remove_duplicate_vertices()
        mesh_set.meshing_remove_duplicate_faces()
        mesh_set.meshing_remove_null_faces()
        mesh_set.meshing_remove_unreferenced_vertices()

    return _transform("clean_mesh", input_path, output_path, clean, {})


def repair_holes(
    input_path: str, output_path: str, max_hole_size: int = 30
) -> MeshOperationResult:
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


def compute_normals(input_path: str, output_path: str) -> MeshOperationResult:
    def compute(mesh_set: pymeshlab.MeshSet) -> None:
        mesh_set.meshing_re_orient_faces_coherently()
        mesh_set.compute_normal_per_face()
        mesh_set.compute_normal_per_vertex()

    return _transform("compute_normals", input_path, output_path, compute, {})


def simplify_mesh(
    input_path: str, output_path: str, target_faces: int
) -> MeshOperationResult:
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
) -> MeshOperationResult:
    if (
        isinstance(target_edge_length, bool)
        or not isinstance(target_edge_length, Real)
        or not math.isfinite(target_edge_length)
        or target_edge_length <= 0
    ):
        raise MeshOperationError(
            "target_edge_length must be a finite number greater than 0"
        )
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
    method: Literal["taubin", "laplacian"] = "taubin",
    iterations: int = 10,
) -> MeshOperationResult:
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


def export_mesh(input_path: str, output_path: str) -> MeshOperationResult:
    return _transform("export_mesh", input_path, output_path, lambda mesh_set: None, {})
