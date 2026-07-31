import asyncio
import json
import os
import shutil
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
