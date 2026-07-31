import json
import sys
from pathlib import Path

import pytest
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

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


@pytest.mark.asyncio
async def test_server_registers_exact_mesh_tools() -> None:
    tools = await server.mcp.list_tools()

    assert {tool.name for tool in tools} == EXPECTED_TOOLS


@pytest.mark.asyncio
async def test_server_serves_inspect_mesh_over_stdio(cube_path: Path) -> None:
    parameters = StdioServerParameters(
        command=sys.executable,
        args=[str(Path(server.__file__).resolve())],
    )

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
