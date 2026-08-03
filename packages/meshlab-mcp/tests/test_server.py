import asyncio
import json
import os
import shutil
import sys
from pathlib import Path
from typing import get_type_hints

import pytest
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
from pydantic import TypeAdapter, ValidationError

import server


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


@pytest.fixture
def isolated_server_path(tmp_path: Path) -> Path:
    package_dir = tmp_path / "meshlab-mcp"
    package_dir.mkdir()
    source_dir = Path(server.__file__).resolve().parent
    for name in ("server.py", "mesh_ops.py"):
        shutil.copy2(source_dir / name, package_dir / name)
    return package_dir / "server.py"


def stdio_parameters(server_path: Path) -> StdioServerParameters:
    environment = {
        key: value for key, value in os.environ.items() if key != "PYTHONPATH"
    }
    return StdioServerParameters(
        command=sys.executable,
        args=[str(server_path)],
        env=environment,
    )


@pytest.mark.asyncio
async def test_server_registers_exact_mesh_tools() -> None:
    tools = await server.mcp.list_tools()

    assert {tool.name for tool in tools} == EXPECTED_TOOLS


@pytest.mark.asyncio
async def test_server_serves_inspect_mesh_over_stdio_from_isolated_package(
    cube_path: Path, isolated_server_path: Path
) -> None:
    parameters = stdio_parameters(isolated_server_path)

    async with asyncio.timeout(15):
        async with stdio_client(parameters) as (read_stream, write_stream):
            async with ClientSession(read_stream, write_stream) as session:
                await session.initialize()
                tools = await session.list_tools()
                result = await session.call_tool(
                    "inspect_mesh", {"input_path": str(cube_path)}
                )

    assert {tool.name for tool in tools.tools} == EXPECTED_TOOLS
    assert len(tools.tools) == 8
    assert result.isError is False
    assert json.loads(result.content[0].text)["vertices"] == 8


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("operation", "fixture_name", "arguments"),
    [
        ("clean_mesh", "cube_path", {}),
        ("repair_holes", "open_tetra_path", {"max_hole_size": 20}),
    ],
)
async def test_server_returns_valid_structured_mutation_result_over_stdio(
    operation: str,
    fixture_name: str,
    arguments: dict[str, object],
    request: pytest.FixtureRequest,
    tmp_path: Path,
    isolated_server_path: Path,
) -> None:
    input_path = request.getfixturevalue(fixture_name)
    output_path = tmp_path / f"{operation}.ply"
    parameters = stdio_parameters(isolated_server_path)

    async with asyncio.timeout(15):
        async with stdio_client(parameters) as (read_stream, write_stream):
            async with ClientSession(read_stream, write_stream) as session:
                await session.initialize()
                result = await session.call_tool(
                    operation,
                    {
                        "input_path": str(input_path),
                        "output_path": str(output_path),
                        **arguments,
                    },
                )

    assert result.isError is False
    assert result.structuredContent is not None
    assert result.structuredContent["warnings"] == []
    assert json.loads(result.content[0].text) == result.structuredContent
    assert output_path.is_file()


@pytest.mark.asyncio
async def test_server_lists_required_array_warnings_output_schema() -> None:
    tools = {
        tool.name: tool
        for tool in await server.mcp.list_tools()
        if tool.name != "inspect_mesh"
    }

    for tool in tools.values():
        assert tool.outputSchema is not None
        warnings = tool.outputSchema["properties"]["warnings"]
        assert "warnings" in tool.outputSchema["required"]
        assert warnings["type"] == "array"
        assert warnings["items"] == {"type": "string"}
        assert "default" not in warnings


@pytest.mark.asyncio
async def test_server_lists_constrained_mutation_input_schemas() -> None:
    tools = {tool.name: tool for tool in await server.mcp.list_tools()}

    assert tools["repair_holes"].inputSchema["properties"]["max_hole_size"] == {
        "default": 30,
        "maximum": 100000,
        "minimum": 1,
        "title": "Max Hole Size",
        "type": "integer",
    }
    assert tools["simplify_mesh"].inputSchema["properties"]["target_faces"] == {
        "minimum": 4,
        "title": "Target Faces",
        "type": "integer",
    }
    assert tools["remesh_mesh"].inputSchema["properties"][
        "target_edge_length"
    ] == {
        "exclusiveMinimum": 0,
        "title": "Target Edge Length",
        "type": "number",
    }
    assert tools["remesh_mesh"].inputSchema["properties"]["iterations"] == {
        "default": 5,
        "maximum": 20,
        "minimum": 1,
        "title": "Iterations",
        "type": "integer",
    }
    assert tools["smooth_mesh"].inputSchema["properties"]["iterations"] == {
        "default": 10,
        "maximum": 100,
        "minimum": 1,
        "title": "Iterations",
        "type": "integer",
    }
    assert tools["smooth_mesh"].inputSchema["properties"]["method"] == {
        "default": "taubin",
        "enum": ["taubin", "laplacian"],
        "title": "Method",
        "type": "string",
    }


@pytest.mark.asyncio
async def test_server_rejects_out_of_bounds_calls_before_creating_output(
    cube_path: Path, tmp_path: Path, isolated_server_path: Path
) -> None:
    invalid_calls = [
        ("repair_holes", {"max_hole_size": 0}),
        ("repair_holes", {"max_hole_size": 100001}),
        ("simplify_mesh", {"target_faces": 3}),
        ("remesh_mesh", {"target_edge_length": 0.0}),
        ("remesh_mesh", {"target_edge_length": 0.75, "iterations": 0}),
        ("remesh_mesh", {"target_edge_length": 0.75, "iterations": 21}),
        ("smooth_mesh", {"iterations": 0}),
        ("smooth_mesh", {"iterations": 101}),
        ("smooth_mesh", {"method": "unknown"}),
    ]
    parameters = stdio_parameters(isolated_server_path)

    async with asyncio.timeout(15):
        async with stdio_client(parameters) as (read_stream, write_stream):
            async with ClientSession(read_stream, write_stream) as session:
                await session.initialize()
                for index, (operation, arguments) in enumerate(invalid_calls):
                    output_path = tmp_path / f"invalid-{index}.ply"
                    result = await session.call_tool(
                        operation,
                        {
                            "input_path": str(cube_path),
                            "output_path": str(output_path),
                            **arguments,
                        },
                    )

                    assert result.isError is True
                    assert "validation error" in result.content[0].text.lower()
                    assert not output_path.exists()


@pytest.mark.parametrize("value", [float("nan"), float("inf"), float("-inf")])
def test_remesh_parameter_annotation_rejects_non_finite_values(value: float) -> None:
    annotation = get_type_hints(server.remesh_mesh, include_extras=True)[
        "target_edge_length"
    ]

    with pytest.raises(ValidationError):
        TypeAdapter(annotation).validate_python(value)


@pytest.mark.asyncio
async def test_clean_mesh_has_exact_operation_description() -> None:
    tools = {tool.name: tool for tool in await server.mcp.list_tools()}

    assert tools["clean_mesh"].description == (
        "Remove duplicate vertices/faces, zero-area faces, and unreferenced vertices."
    )


@pytest.mark.asyncio
async def test_server_returns_mcp_error_for_missing_mesh(
    tmp_path: Path, isolated_server_path: Path
) -> None:
    parameters = stdio_parameters(isolated_server_path)
    missing_path = tmp_path / "missing.obj"

    async with asyncio.timeout(15):
        async with stdio_client(parameters) as (read_stream, write_stream):
            async with ClientSession(read_stream, write_stream) as session:
                await session.initialize()
                result = await session.call_tool(
                    "inspect_mesh", {"input_path": str(missing_path)}
                )

    assert result.isError is True
    assert "Input path is not an existing file" in result.content[0].text
