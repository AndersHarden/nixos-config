import asyncio
import json
from types import SimpleNamespace

import pytest

from server import _patch_upstream


class FakeUpstream:
    def __init__(self, binary: str | None) -> None:
        self.binary = binary
        self.handle_get_cloudcompare_info = lambda _args: self._err("unpatched")

    def find_cloudcompare(self) -> str | None:
        return self.binary

    def _ok(self, data: dict[str, object]) -> list[SimpleNamespace]:
        return [SimpleNamespace(text=json.dumps(data))]

    def _err(self, message: str) -> list[SimpleNamespace]:
        return [SimpleNamespace(text=json.dumps({"error": message}))]

    async def call_tool(self, name: str, arguments: dict) -> list[SimpleNamespace]:
        dispatch = {"get_cloudcompare_info": self.handle_get_cloudcompare_info}
        return dispatch[name](arguments)


def call_info(upstream: FakeUpstream) -> dict[str, object]:
    result = asyncio.run(upstream.call_tool("get_cloudcompare_info", {}))
    return json.loads(result[0].text)


def test_patched_dispatch_reports_nix_version_and_binary(monkeypatch) -> None:
    monkeypatch.setenv("CLOUDCOMPARE_VERSION", "2.13.2")
    upstream = FakeUpstream("/run/current-system/sw/bin/CloudCompare")

    _patch_upstream(upstream)

    assert call_info(upstream) == {
        "binary": "/run/current-system/sw/bin/CloudCompare",
        "platform": "Linux",
        "version": "2.13.2",
        "ready": True,
    }


def test_patched_dispatch_rejects_missing_binary(monkeypatch) -> None:
    monkeypatch.setenv("CLOUDCOMPARE_VERSION", "2.13.2")
    upstream = FakeUpstream(None)

    _patch_upstream(upstream)

    result = call_info(upstream)
    assert "CloudCompare executable not found" in result["error"]
    assert "ready" not in result


@pytest.mark.parametrize("version", [None, ""])
def test_patched_dispatch_rejects_missing_version(monkeypatch, version) -> None:
    if version is None:
        monkeypatch.delenv("CLOUDCOMPARE_VERSION", raising=False)
    else:
        monkeypatch.setenv("CLOUDCOMPARE_VERSION", version)
    upstream = FakeUpstream("/run/current-system/sw/bin/CloudCompare")

    _patch_upstream(upstream)

    result = call_info(upstream)
    assert "CLOUDCOMPARE_VERSION is not set" in result["error"]
    assert "ready" not in result
