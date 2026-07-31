from typing import Literal

from mcp.server.fastmcp import FastMCP

import mesh_ops
from mesh_ops import MeshInspection, MeshOperationResult


mcp = FastMCP("meshlab-mcp")


@mcp.tool()
def inspect_mesh(input_path: str) -> MeshInspection:
    """Inspect a mesh and return topology, geometry, and bounds metadata."""
    return mesh_ops.inspect_mesh(input_path)


@mcp.tool()
def clean_mesh(input_path: str, output_path: str) -> MeshOperationResult:
    """Remove duplicate, null, and unreferenced mesh elements."""
    return mesh_ops.clean_mesh(input_path, output_path)


@mcp.tool()
def repair_holes(
    input_path: str, output_path: str, max_hole_size: int = 30
) -> MeshOperationResult:
    """Close mesh holes up to the specified boundary size."""
    return mesh_ops.repair_holes(input_path, output_path, max_hole_size)


@mcp.tool()
def compute_normals(input_path: str, output_path: str) -> MeshOperationResult:
    """Orient faces coherently and compute face and vertex normals."""
    return mesh_ops.compute_normals(input_path, output_path)


@mcp.tool()
def simplify_mesh(
    input_path: str, output_path: str, target_faces: int
) -> MeshOperationResult:
    """Simplify a mesh to the requested target face count."""
    return mesh_ops.simplify_mesh(input_path, output_path, target_faces)


@mcp.tool()
def remesh_mesh(
    input_path: str,
    output_path: str,
    target_edge_length: float,
    iterations: int = 5,
) -> MeshOperationResult:
    """Remesh a surface isotropically at the requested edge length."""
    return mesh_ops.remesh_mesh(
        input_path, output_path, target_edge_length, iterations
    )


@mcp.tool()
def smooth_mesh(
    input_path: str,
    output_path: str,
    method: Literal["taubin", "laplacian"] = "taubin",
    iterations: int = 10,
) -> MeshOperationResult:
    """Smooth a mesh with Taubin or Laplacian smoothing."""
    return mesh_ops.smooth_mesh(input_path, output_path, method, iterations)


@mcp.tool()
def export_mesh(input_path: str, output_path: str) -> MeshOperationResult:
    """Export a mesh to another supported mesh format."""
    return mesh_ops.export_mesh(input_path, output_path)


if __name__ == "__main__":
    mcp.run(transport="stdio")
