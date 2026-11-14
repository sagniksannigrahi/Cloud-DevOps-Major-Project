import pytest

pytest.importorskip("fastapi")
from fastapi.testclient import TestClient  # noqa: E402

from cloudsleuth_zeroth.viewer import app as viewer  # noqa: E402


def test_viewer_lists_and_diagnoses(small_dataset, monkeypatch):
    monkeypatch.setattr(viewer, "DATASETS", {"simulator": small_dataset})
    client = TestClient(viewer.app)
    page = client.get("/")
    assert "CloudSleuth" in page.text
    assert client.get("/api/info").json()["where"]
    assert "postgres" == client.get("/api/topology").json()["database"]
    cases = client.get("/api/cases").json()
    assert cases["simulator"]
    r = client.get("/api/diagnose", params={"dataset": "simulator", "case": cases["simulator"][0]}).json()
    assert "ranking" in r
    res = client.get("/api/results").json()["simulator"]["methods"]["D (evidence rules)"]
    assert res["fault_cases"] > 0 and res["top1"] <= res["fault_cases"]
