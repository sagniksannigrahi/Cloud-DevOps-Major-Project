# CloudSleuth-Zeroth-Prototype

**Early prototype for the Zeroth Review** of our final-year research project:

> *CloudSleuth: Evidence-Based Root-Cause Analysis for Microservices, with Calibrated Confidence and an Independent Benchmark* 

- Students: Sagnik Sannigrahi , Malik Inam Ul Haq
- Batch B763, Dept. of Computing Technologies (CTECH), SRM IST Kattankulathur
- Guide: Dr. A. M. Vidhyalakshmi

This repo is a **small, working, early prototype**. It is not the finished system.
It shows the pipeline end to end on two datasets. Several parts are only **planned**;
see [STATUS.md](STATUS.md) and [ARCHITECTURE.md](ARCHITECTURE.md).

## Cloud & DevOps major project: how it is deployed

CloudSleuth's web viewer is deployed on **AWS EC2** by a **Jenkins** pipeline that pulls from
**GitHub**, builds and tests a **Docker** image, and deploys it. The server is configured by
**Ansible**, and its firewall is managed by **Terraform**. Every `git push` to `main` redeploys automatically.

```
laptop --git push--> GitHub --webhook / poll--> Jenkins on EC2 --> docker build --> pytest in the image
                                                                --> docker run (port 80) --> /health check
laptop --ansible-playbook--> EC2: swap, Docker, Java, Jenkins, plugins, admin user, pipeline job
laptop --terraform apply--> AWS: security group (22, 80, 8080) + Ansible inventory with the current IP
```

| Tool | Where | What it does |
|---|---|---|
| AWS | EC2 t3.micro, Ubuntu 26.04, us-east-1 | Runs Jenkins and the app container |
| Git / GitHub | this repo | Source of truth; Jenkins deploys `main` |
| Jenkins | [`Jenkinsfile`](Jenkinsfile) | Checkout → Build image → Test → Deploy → Smoke test |
| Docker | [`Dockerfile`](Dockerfile) | One image: tested, then deployed on port 80 |
| Ansible | [`infra/ansible/playbook.yml`](infra/ansible/playbook.yml) | Server setup + Jenkins configuration as code |
| Terraform | [`infra/terraform/main.tf`](infra/terraform/main.tf) | Security group and Ansible inventory |

Set up from scratch (needs the EC2 key at `~/.ssh/devops-project.pem` and AWS Learner Lab credentials):

```bash
cd infra/terraform && terraform init && terraform apply   # open ports, write the inventory
cd ../ansible && ansible-playbook playbook.yml              # install and configure Docker + Jenkins
# Jenkins: http://<EC2 IP>:8080 (user admin, password in infra/ansible/.jenkins-admin-password)
# App:     http://<EC2 IP>/
```

## What it does (in one paragraph)

When something breaks in a microservice app, many services look unhealthy at once. The task
is to find the one that actually caused it. CloudSleuth reads the telemetry (metrics, traces,
logs, recent changes and database stats) and runs these steps: **anomaly detection** (median/MAD,
must stay unusual for 3 readings) → **telemetry snapshot** → **trace attribution** (each service's
OWN time vs time WAITING on others) → **evidence-based ranking** ("method D", hand-written rules).
The output is a **ranked list of likely causes**, a **fault type**, and an **evidence report**
listing what supports and what contradicts the top cause. The score is a **raw score, not calibrated
yet** (calibration is planned).

## Two datasets

| | Dataset 1: Simulator | Dataset 2: Live demo app |
|---|---|---|
| What | Python program that generates failure cases on demand | 6 small Python services + PostgreSQL in Docker, real traffic |
| Faults | 16 kinds in 8 groups (database, delay, resources, errors, settings, availability, network, multiple) | 6 live faults so far (db_lock, slow_service, service_crash, cpu_hog, bad_config, network_delay); the other 10 are TODO |
| Size | 144 cases = 128 with a fault + 16 normal (noise, missing data, mild faults, red-herring changes) | one case per `make fault` run |
| True answers | `data/simulator/labels/` (separate files + SHA-256) | `data/demo_app/labels/` (separate files + SHA-256) |

The diagnosis code (`cloudsleuth_zeroth/core/`) **never reads the labels**; a test checks this.

## Offline demo: no Docker, no internet, no installs

Needs only Python 3.11+ (the simulator, core and evaluation use the standard library only).

```bash
cd Cloud-DevOps-Major-Project      # the cloned repo folder
make data     # 1. generate the 144-case simulator dataset
make eval     # 2. run method D + baselines, print the top-1 / top-3 table
make story    # 3. the database-lock story: WITHOUT vs WITH database evidence
```

`make demo` runs all three in one go. Tables are also saved to `results/`.

Diagnose a single case yourself:

```bash
python3 -m cloudsleuth_zeroth.core.diagnose data/simulator/telemetry/sim-045.json
python3 -m cloudsleuth_zeroth.core.diagnose data/simulator/telemetry/sim-045.json --no-db-evidence
```

## The web page (what to show in a demo)

Open the app and use the **3-step tour** on the page:
1. **Database lock demo**: a live case; CloudSleuth ranks `postgres` first, fault type `db_lock`, with its evidence.
2. **With vs without database data**: the same case side by side; without DB data it blames the wrong service.
3. **Compare with a simple baseline**: "blame the loudest alarm" on the same case, then **Reveal true answer**.

Above the tour: the problem / solution / result in one line each, the course-requirement checklist
(AWS, Git, Jenkins, Docker + Ansible + Terraform), and a results panel that the server computes by running
every method on every case. On EC2 the header shows the live Jenkins build number and commit.

Run it locally with Docker (no Python setup needed):

```bash
docker build -t cloudsleuth . && docker run --rm -p 8000:8000 cloudsleuth   # open http://localhost:8000
```

## Tests and the viewer

These need a one-time `pip install` into `.venv` (done automatically by make, needs internet once).

```bash
make test     # pytest
make viewer   # open http://localhost:8000 ; pick a case, run diagnosis, see the evidence report
```

## Live demo (Docker Desktop)

```bash
make up                      # build + start everything (first build needs internet)
#   wait ~2 minutes so there is normal traffic to compare against
make fault NAME=db_lock      # inject a DB lock for 120 s, record a snapshot, save the true answer (~2.5 min)
make diagnose                # diagnose the newest live case (DB evidence ON)
make diagnose-nodb           # same case, DB evidence OFF  -> blames the wrong service
make down                    # stop and remove everything
```

`make live-story` runs the DB-lock story on the recorded live db_lock case, and
`make diagnose CASE=live-...` diagnoses any recorded case (`make live-cases` lists them).
Other live faults: `make faults` lists them (`slow_service`, `service_crash`, `cpu_hog`, `bad_config`,
`network_delay`, and `normal` for a no-fault snapshot). `make live-eval` scores all recorded live cases.
Recorded live cases are kept in `data/demo_app/` (committed), so they can be diagnosed even
without Docker.

Useful pages while it runs: Jaeger http://localhost:16686, Prometheus http://localhost:9090,
gateway http://localhost:18080/health. If a port is busy, stop the other program using it.

## Folder map

```
cloudsleuth_zeroth/
  core/          the diagnosis (anomaly, snapshot, attribution, ranking, baselines, diagnose, report)
  simulator/     dataset 1 generator (model, faults, generate)
  evaluation/    evaluate.py (top-1/top-3 table), story.py (DB-lock story)
  viewer/        FastAPI app + one HTML page
  topology.py faults.py case_io.py labels.py   shared pieces
demo_app/        docker-compose.yml, services/ (gateway, orders, inventory, payments, worker, loadgen), config/
faultlab/        fault_lab.py (inject + record + label), recorder.py (Prometheus/Jaeger/Loki -> snapshot)
tests/           pytest tests
data/            simulator/ (generated, not committed), demo_app/ (recorded live cases)
```

## Honest notes

- Simulator results are **optimistic**: we wrote both the simulator and the rules, and the
  rules were adjusted while looking at the same simulator. They are a sanity check, not a result.
  The independent benchmark (planned) is where the real numbers will come from.
- Method D weights are hand-set first guesses. The raw score is **not** a probability.
- Only 6 of the 16 fault kinds can be injected live so far.
- The folder path contains spaces ("4th year", "College Notes"); every command above works from it.
