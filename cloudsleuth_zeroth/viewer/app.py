"""The web page (one HTML file, no build step): project overview, results computed
live, a guided 3-step demo, and a case explorer with a service map, ranked causes
and the evidence report.

Run:  make viewer      then open http://localhost:8000
"""

import os
from functools import lru_cache
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse

from .. import case_io, labels, topology
from ..faults import FAULT_KINDS
from ..core.diagnose import diagnose
from ..evaluation.evaluate import score_dataset

ROOT = Path(__file__).resolve().parents[2]
DATASETS = {"simulator": ROOT / "data" / "simulator", "demo_app": ROOT / "data" / "demo_app"}
PAGE = Path(__file__).with_name("index.html")

app = FastAPI(title="CloudSleuth-Zeroth-Prototype")


def _dataset(name):
    if name not in DATASETS:
        raise HTTPException(404, f"unknown dataset {name}")
    return DATASETS[name]


@app.get("/", response_class=HTMLResponse)
def index():
    return PAGE.read_text()


@app.get("/health")
def health():
    """Used by Docker HEALTHCHECK and the Jenkins smoke test."""
    return {"status": "ok", "cases": {name: len(case_io.list_cases(folder)) for name, folder in DATASETS.items()}}


@app.get("/api/info")
def info():
    """Which build is running. Jenkins passes these in with `docker run -e ...`."""
    build = os.environ.get("BUILD_NUMBER")
    return {"build": build,
            "commit": os.environ.get("GIT_COMMIT_SHORT"),
            "deployed_at": os.environ.get("DEPLOYED_AT"),
            "where": "AWS EC2, deployed by Jenkins" if build else "local machine"}


@app.get("/api/topology")
def graph():
    """The service graph, for the map on the page."""
    return {"services": topology.SERVICES, "database": topology.DATABASE,
            "calls": topology.CALLS, "db_callers": topology.DB_CALLERS,
            "fault_kinds": {k: {"group": g, "meaning": m} for k, (g, m) in FAULT_KINDS.items()}}


@lru_cache(maxsize=4)
def _score(folder):
    return score_dataset(Path(folder))


@app.get("/api/results")
def results():
    """Accuracy of every method on every dataset, computed by running the code here
    (the first call takes a few seconds; then it is cached)."""
    out = {}
    for name, folder in DATASETS.items():
        if case_io.list_cases(folder):
            r = _score(str(folder))
            out[name] = {"cases": r["cases"], "methods": r["methods"]}
    return out


@app.get("/api/cases")
def cases():
    return {name: case_io.list_cases(folder) for name, folder in DATASETS.items()}


@app.get("/api/diagnose")
def run(dataset: str, case: str, no_db: bool = False, method: str = "D"):
    folder = _dataset(dataset)
    if case not in case_io.list_cases(folder):
        raise HTTPException(404, f"unknown case {case}")
    result = diagnose(case_io.load_telemetry(case_io.telemetry_path(folder, case)),
                      use_db=not no_db, method=method)
    result.pop("attribution", None)
    return result


@app.get("/api/truth")
def truth(dataset: str, case: str):
    """The true answer, only shown when the user clicks 'reveal' AFTER diagnosing."""
    return labels.read_label(_dataset(dataset), case)
