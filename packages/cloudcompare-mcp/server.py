from __future__ import annotations

import importlib
import os
import platform
import sys
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

    upstream.handle_get_cloudcompare_info = handle_get_cloudcompare_info


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
