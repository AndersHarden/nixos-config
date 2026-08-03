from __future__ import annotations

import importlib
import math
import os
import platform
import sys
from pathlib import Path
from types import ModuleType
from typing import Any


def _patch_upstream(upstream: Any) -> None:
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
        input_path = args["input_path"]
        output_path = args["output_path"]
        if "knn" in args:
            return upstream._err(
                "compute_normals does not support 'knn' in CloudCompare 2.13; "
                "omit radius for auto selection or provide radius in source coordinate units"
            )

        modes = {"LS": "LS", "QUADRIC": "QUADRIC", "TRIANGULATION": "TRI"}
        mode = args.get("mode", "LS").upper()
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

        if not Path(input_path).is_file():
            return upstream._err(f"compute_normals input file not found: {input_path}")

        upstream._ensure_output_dir(output_path)
        radius_arg = "auto" if radius is None else str(radius)
        rc, stdout, stderr = upstream.cc_run([
            "-AUTO_SAVE", "OFF",
            "-O", input_path,
            "-OCTREE_NORMALS", radius_arg,
            "-MODEL", modes[mode],
            "-C_EXPORT_FMT", upstream._ext_flag(output_path),
            "-SAVE_CLOUDS", "FILE", output_path,
        ])
        context = {
            "operation": "compute_normals",
            "input": input_path,
            "output": output_path,
            "mode": mode,
            "radius": radius_arg,
        }
        if rc == 0 and not Path(output_path).is_file():
            return upstream._err(
                "compute_normals returned code 0 but did not create output file "
                f"{output_path}; stdout={stdout.strip() or '(none)'}; "
                f"stderr={stderr.strip() or '(none)'}"
            )
        return upstream._run_result(rc, stdout, stderr, context)

    upstream.handle_get_cloudcompare_info = handle_get_cloudcompare_info
    upstream.handle_compute_normals = handle_compute_normals

    for index, tool in enumerate(upstream.TOOLS):
        if tool.name == "compute_normals":
            upstream.TOOLS[index] = type(tool)(
                name="compute_normals",
                description="Estimate surface normals with CloudCompare octree normals.",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "input_path": {"type": "string"},
                        "output_path": {"type": "string"},
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
            break


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
