from __future__ import annotations

import importlib
import hashlib
import math
import os
import platform
import secrets
import stat
import sys
from pathlib import Path
from types import ModuleType
from typing import Any


_CLOUD_OUTPUT_FORMATS = {
    ".ply": "PLY",
}


class _NormalsError(ValueError):
    pass


def _validate_paths(input_value: str, output_value: str) -> tuple[Path, Path]:
    source = Path(input_value)
    destination = Path(output_value)
    if not source.is_absolute():
        raise _NormalsError("compute_normals input path must be absolute")
    if not destination.is_absolute():
        raise _NormalsError("compute_normals output path must be absolute")
    try:
        source_stat = source.stat()
    except OSError as error:
        raise _NormalsError(
            f"compute_normals input file not found: {source}"
        ) from error
    if not stat.S_ISREG(source_stat.st_mode):
        raise _NormalsError(f"compute_normals input is not a regular file: {source}")
    if source == destination:
        raise _NormalsError("compute_normals input and output paths must be different")
    if os.path.lexists(destination):
        try:
            if os.path.samefile(source, destination):
                raise _NormalsError(
                    f"compute_normals output aliases the input file: {destination}"
                )
        except OSError:
            pass
        raise _NormalsError(
            f"compute_normals output path already exists: {destination}"
        )
    if not destination.parent.is_dir():
        raise _NormalsError(
            f"compute_normals output parent directory does not exist: {destination.parent}"
        )
    if destination.suffix.lower() not in _CLOUD_OUTPUT_FORMATS:
        raise _NormalsError(
            f"compute_normals unsupported output suffix: {destination.suffix}"
        )
    return source, destination


def _open_directory(path: Path) -> int:
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
                    raise _NormalsError(
                        f"compute_normals output parent contains symlink component: {component}"
                    ) from error
                raise _NormalsError(
                    f"compute_normals cannot securely open output parent component: {component}"
                ) from error
            os.close(directory_fd)
            directory_fd = next_fd
        return directory_fd
    except Exception:
        os.close(directory_fd)
        raise


def _verify_directory(path: Path, expected_fd: int) -> None:
    current_fd: int | None = None
    try:
        current_fd = _open_directory(path)
        expected = os.fstat(expected_fd)
        current = os.fstat(current_fd)
        if (expected.st_dev, expected.st_ino) != (current.st_dev, current.st_ino):
            raise _NormalsError("compute_normals output directory identity changed")
    except Exception as error:
        if isinstance(error, _NormalsError) and "identity changed" in str(error):
            raise
        raise _NormalsError(
            "compute_normals output directory identity changed"
        ) from error
    finally:
        if current_fd is not None:
            os.close(current_fd)


def _identity(path: Path) -> tuple[int, int, int, int]:
    path_stat = path.stat()
    return (
        path_stat.st_dev,
        path_stat.st_ino,
        path_stat.st_size,
        path_stat.st_mtime_ns,
    )


def _digest(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _cleanup_staging(
    output_directory_fd: int,
    staging_directory_fd: int | None,
    staging_name: str | None,
    staging_identity: tuple[int, int] | None,
) -> list[str]:
    warnings: list[str] = []
    if staging_directory_fd is not None:
        try:
            entries = os.listdir(staging_directory_fd)
        except OSError as error:
            warnings.append(f"Failed to list normals staging directory: {error}")
        else:
            for entry in entries:
                try:
                    os.unlink(entry, dir_fd=staging_directory_fd)
                except FileNotFoundError:
                    pass
                except OSError as error:
                    warnings.append(
                        f"Failed to remove normals staging entry '{entry}': {error}"
                    )
        try:
            os.close(staging_directory_fd)
        except OSError as error:
            warnings.append(f"Failed to close normals staging directory: {error}")
    if staging_name is not None:
        try:
            current = os.stat(
                staging_name, dir_fd=output_directory_fd, follow_symlinks=False
            )
            if (
                staging_identity is not None
                and (
                    current.st_dev,
                    current.st_ino,
                )
                != staging_identity
            ):
                warnings.append(
                    "Normals staging directory identity changed during cleanup"
                )
            else:
                os.rmdir(staging_name, dir_fd=output_directory_fd)
        except FileNotFoundError:
            pass
        except OSError as error:
            warnings.append(f"Failed to remove normals staging directory: {error}")
    return warnings


def _patch_upstream(upstream: Any) -> None:
    matching_tools = [
        (index, tool)
        for index, tool in enumerate(upstream.TOOLS)
        if tool.name == "compute_normals"
    ]
    if len(matching_tools) != 1:
        raise RuntimeError(
            "Expected exactly one compute_normals Tool definition, "
            f"found {len(matching_tools)}"
        )

    def handle_get_cloudcompare_info(_args: dict) -> list:
        binary = upstream.find_cloudcompare()
        if not binary:
            return upstream._err("CloudCompare executable not found")
        version = os.environ.get("CLOUDCOMPARE_VERSION")
        if not version:
            return upstream._err("CLOUDCOMPARE_VERSION is not set")
        return upstream._ok(
            {
                "binary": binary,
                "platform": platform.system(),
                "version": version,
                "ready": True,
            }
        )

    def handle_compute_normals(args: dict) -> list:
        if "knn" in args:
            return upstream._err(
                "compute_normals does not support 'knn' in CloudCompare 2.13; "
                "omit radius for auto selection or provide radius in source coordinate units"
            )

        modes = {"LS": "LS", "QUADRIC": "QUADRIC", "TRIANGULATION": "TRI"}
        mode_value = args.get("mode", "LS")
        if not isinstance(mode_value, str):
            return upstream._err("compute_normals mode must be a string")
        mode = mode_value.upper()
        if mode not in modes:
            return upstream._err(
                f"Invalid compute_normals mode {mode!r}; expected LS, QUADRIC, or TRIANGULATION"
            )

        radius = args.get("radius")
        if radius is not None and (
            isinstance(radius, bool)
            or not isinstance(radius, (int, float))
            or not math.isfinite(radius)
            or radius <= 0
        ):
            return upstream._err(
                "compute_normals radius must be a finite number greater than zero "
                "in source coordinate units"
            )

        try:
            source, destination = _validate_paths(
                args["input_path"], args["output_path"]
            )
        except (KeyError, TypeError, _NormalsError) as error:
            return upstream._err(str(error))

        radius_arg = "auto" if radius is None else str(radius)
        context: dict[str, object] = {
            "operation": "compute_normals",
            "input": str(source),
            "output": str(destination),
            "mode": mode,
            "radius": radius_arg,
        }
        output_directory_fd: int | None = None
        staging_directory_fd: int | None = None
        staging_name: str | None = None
        staging_identity: tuple[int, int] | None = None
        published = False
        committed = False
        try:
            output_directory_fd = _open_directory(destination.parent)
            if os.path.lexists(destination):
                raise _NormalsError(
                    f"compute_normals output path already exists: {destination}"
                )
            source_identity = _identity(source)
            source_digest = _digest(source)

            staging_name = f".{destination.stem}-staging-{secrets.token_hex(8)}"
            os.mkdir(staging_name, mode=0o700, dir_fd=output_directory_fd)
            staging_directory_fd = os.open(
                staging_name,
                os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                dir_fd=output_directory_fd,
            )
            os.fchmod(staging_directory_fd, 0o700)
            staging_stat = os.fstat(staging_directory_fd)
            staging_identity = (staging_stat.st_dev, staging_stat.st_ino)

            # Mode 0700 excludes other UIDs. Same-UID manipulation is outside
            # the threat model; inode checks still reject replaced temp files.
            temporary_name = f"cloud-{secrets.token_hex(8)}{destination.suffix.lower()}"
            temporary_fd = os.open(
                temporary_name,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                0o600,
                dir_fd=staging_directory_fd,
            )
            temporary_stat = os.fstat(temporary_fd)
            temporary_identity = (temporary_stat.st_dev, temporary_stat.st_ino)
            os.close(temporary_fd)
            temporary_path = Path(
                f"/proc/{os.getpid()}/fd/{staging_directory_fd}/{temporary_name}"
            )

            rc, stdout, stderr = upstream.cc_run(
                [
                    "-AUTO_SAVE",
                    "OFF",
                    "-O",
                    str(source),
                    "-OCTREE_NORMALS",
                    radius_arg,
                    "-MODEL",
                    modes[mode],
                    "-C_EXPORT_FMT",
                    _CLOUD_OUTPUT_FORMATS[destination.suffix.lower()],
                    "-SAVE_CLOUDS",
                    "FILE",
                    str(temporary_path),
                ]
            )
            if rc != 0:
                warnings = _cleanup_staging(
                    output_directory_fd,
                    staging_directory_fd,
                    staging_name,
                    staging_identity,
                )
                staging_directory_fd = None
                staging_name = None
                if warnings:
                    context["warnings"] = warnings
                return upstream._run_result(rc, stdout, stderr, context)

            entries = set(os.listdir(staging_directory_fd))
            if entries != {temporary_name}:
                if temporary_name not in entries:
                    raise _NormalsError(
                        "compute_normals did not create the reserved staging output"
                    )
                raise _NormalsError(
                    "compute_normals produced unsupported sidecar files"
                )
            saved_stat = os.stat(
                temporary_name,
                dir_fd=staging_directory_fd,
                follow_symlinks=False,
            )
            if (
                not stat.S_ISREG(saved_stat.st_mode)
                or (saved_stat.st_dev, saved_stat.st_ino) != temporary_identity
            ):
                raise _NormalsError("compute_normals staging output identity changed")
            if saved_stat.st_size == 0:
                raise _NormalsError("compute_normals staging output must be nonempty")

            try:
                _, _, metadata = upstream._load_cloud(str(temporary_path))
            except Exception as error:
                raise _NormalsError(
                    f"compute_normals staging validation failed: {error}"
                ) from error
            if metadata.get("has_normals") is not True:
                raise _NormalsError(
                    "compute_normals staged output does not contain normals"
                )

            if set(os.listdir(staging_directory_fd)) != {temporary_name}:
                raise _NormalsError("compute_normals validation produced sidecar files")
            verified_stat = os.stat(
                temporary_name,
                dir_fd=staging_directory_fd,
                follow_symlinks=False,
            )
            if (verified_stat.st_dev, verified_stat.st_ino) != temporary_identity:
                raise _NormalsError("compute_normals staging output identity changed")
            if _identity(source) != source_identity:
                raise _NormalsError("compute_normals source file identity changed")
            if _digest(source) != source_digest:
                raise _NormalsError("compute_normals source file digest changed")

            _verify_directory(destination.parent, output_directory_fd)
            try:
                os.link(
                    temporary_name,
                    destination.name,
                    src_dir_fd=staging_directory_fd,
                    dst_dir_fd=output_directory_fd,
                    follow_symlinks=False,
                )
            except FileExistsError as error:
                raise _NormalsError(
                    f"compute_normals output path already exists: {destination}"
                ) from error
            published = True
            published_stat = os.stat(
                destination.name,
                dir_fd=output_directory_fd,
                follow_symlinks=False,
            )
            if (published_stat.st_dev, published_stat.st_ino) != temporary_identity:
                raise _NormalsError("compute_normals published output identity changed")
            _verify_directory(destination.parent, output_directory_fd)
            committed = True

            warnings = _cleanup_staging(
                output_directory_fd,
                staging_directory_fd,
                staging_name,
                staging_identity,
            )
            staging_directory_fd = None
            staging_name = None
            if warnings:
                context["warnings"] = warnings
            try:
                os.close(output_directory_fd)
            except OSError as error:
                context.setdefault("warnings", []).append(
                    f"Failed to close normals output directory: {error}"
                )
            output_directory_fd = None
            return upstream._run_result(rc, stdout, stderr, context)
        except Exception as error:
            rollback_error: OSError | None = None
            if published and not committed and output_directory_fd is not None:
                try:
                    os.unlink(destination.name, dir_fd=output_directory_fd)
                    published = False
                except OSError as unlink_error:
                    rollback_error = unlink_error
            cleanup_warnings: list[str] = []
            if output_directory_fd is not None:
                cleanup_warnings = _cleanup_staging(
                    output_directory_fd,
                    staging_directory_fd,
                    staging_name,
                    staging_identity,
                )
                staging_directory_fd = None
                staging_name = None
            message = (
                f"compute_normals failed for source '{source}', destination "
                f"'{destination}', mode={mode}, radius={radius_arg}: {error}"
            )
            if cleanup_warnings:
                message += f"; cleanup warnings={cleanup_warnings!r}"
            if rollback_error is not None:
                message += f"; rollback failed: {rollback_error}"
            return upstream._err(message)
        finally:
            if (
                not committed
                and output_directory_fd is not None
                and staging_name is not None
            ):
                _cleanup_staging(
                    output_directory_fd,
                    staging_directory_fd,
                    staging_name,
                    staging_identity,
                )
            if output_directory_fd is not None:
                try:
                    os.close(output_directory_fd)
                except OSError:
                    pass

    upstream.handle_get_cloudcompare_info = handle_get_cloudcompare_info
    upstream.handle_compute_normals = handle_compute_normals

    index, tool = matching_tools[0]
    upstream.TOOLS[index] = type(tool)(
        name="compute_normals",
        description="Estimate surface normals with CloudCompare octree normals.",
        inputSchema={
            "type": "object",
            "additionalProperties": False,
            "properties": {
                "input_path": {"type": "string"},
                "output_path": {
                    "type": "string",
                    "description": (
                        "Absolute output path ending in only PLY; this is the "
                        "supported format that preserves verifiable normals."
                    ),
                },
                "mode": {
                    "type": "string",
                    "enum": ["LS", "QUADRIC", "TRIANGULATION"],
                    "default": "LS",
                },
                "radius": {
                    "type": "number",
                    "exclusiveMinimum": 0,
                    "description": (
                        "Optional octree radius in source coordinate units; "
                        "omit to let CloudCompare select auto. Prefer auto when unknown."
                    ),
                },
            },
            "required": ["input_path", "output_path"],
        },
    )


def _load_upstream() -> ModuleType:
    source = os.environ.get("CLOUDCOMPARE_MCP_SOURCE")
    if not source:
        raise RuntimeError("CLOUDCOMPARE_MCP_SOURCE is not set")
    sys.path.insert(0, source)
    return importlib.import_module("cloudcompare_mcp.server")


def main() -> None:
    upstream = _load_upstream()
    _patch_upstream(upstream)
    upstream.main()


if __name__ == "__main__":
    main()
