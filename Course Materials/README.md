# Docker Delivery Student Scaffold

Course Lead — Badr Tajini · ESILV teaching scaffold · 2026–2027

This repository is deliberately incomplete. It supplies a tested application
and frozen dependencies so that programming experience does not determine the
Docker grade. You must engineer, test and justify the delivery definitions as
the course progresses.

Do not treat a `STUDENT-TASK(...)` marker as evidence that work passed. A marker
identifies an unfinished definition. Replace the marker with a versioned
implementation, execute the corresponding acceptance tests and record the
result in the required evidence pack.

## Two roots, two purposes

- `COURSE_ROOT=/opt/esilv/docker-devops-foundations` is the read-only course
  bundle installed by the teaching team.
- `APP_ROOT=/srv/esilv-docker/$USER/docker-delivery` is your private GitHub
  Classroom repository and the working directory for application commands.

The Classroom exporter places this scaffold at the repository root. Therefore
`Dockerfile`, `compose.yaml` and `.github/workflows/container-delivery.yml`
must remain at that root. Labs and project documents are exported under
`docs/2_labs/` and `docs/3_project/`; trusted validators are under
`tools/validation/`.

## What is supplied

The following material is complete and may be treated as course-owned input:

- the Flask/Gunicorn API in `app/` and `wsgi.py`;
- `/healthz`, `/readyz`, `/version` and the item API;
- PostgreSQL initialization SQL;
- exact Python 3.12 dependency locks;
- unit tests for the application contract;
- non-secret configuration names in `.env.example`;
- a stack bootstrap, endpoint smoke test and persistence regression for use
  after the stack exists;
- bounded logical backup/restore runbooks that students execute and audit;
- candidate scanning, evidence curation and cumulative-pack initialization
  helpers. These enforce path/credential boundaries but do not manufacture
  evidence or decide whether an engineering claim is true.

The following material is scaffolding, not a solution:

| Milestone | Files students complete | First assessed in |
|---|---|---|
| Image definition | `Dockerfile`, `.dockerignore` | TD02 |
| Multi-service runtime | `compose.yaml`, `nginx/nginx.conf` | TD04 |
| Least-privilege delta | `compose.yaml`, runtime contract | TD05 |
| Immutable delivery | `.github/workflows/container-delivery.yml`, `scripts/deploy.sh`, `scripts/rollback.sh` | TD06 |

TD03 deliberately uses versioned `docker run` definitions created in its
evidence pack. It does not require a completed Compose stack.

## Verify the supplied application

This test proves the application contract only. It does not prove image,
network, persistence, security, delivery or rollback claims.

```bash
cd "$APP_ROOT"
python3 -m venv .venv
. .venv/bin/activate
python -m pip install --require-hashes --requirement requirements-dev.txt
PYTHONDONTWRITEBYTECODE=1 pytest -q -p no:cacheprovider
```

The lock files are generated from `requirements.in` and
`requirements-dev.in`. Do not edit a compiled lock by hand.

## Runtime target

By the end of TD05, the student-owned definitions must implement this bounded
single-host topology:

```text
SSH tunnel / local curl
        |
127.0.0.1:8080
        |
      proxy  -- edge network --  delivery-api:8000
                                      |
                                  data network
                                      |
                                postgres:5432
                                      |
                                named volume
```

Only the proxy may be published, and it must bind to loopback. The API and
database stay on private Docker networks. PostgreSQL state must survive
container replacement and be recoverable from a checksum-verified backup.

From a workstation, reach the loopback service through SSH forwarding:

```bash
ssh -L 8080:127.0.0.1:8080 student@YOUR_SERVER
```

## Protected pair secret

Students do not create, read, print, commit or repair the database password.
After both Classroom clones exist, an instructor or administrator installs the
same pair secret into each clone with the canonical helper in `COURSE_ROOT`.
The installed file is owned by UID `0` and GID `20001`
(`esilv-course-secrets`), mode `0440`, at
`secrets/postgres_password.txt`. If that invariant is absent, stop and request
the administrator action described in the onboarding guide.

The mechanism is deliberately limited to a dedicated course VPS. It is not an
enterprise secret manager. Docker-daemon access is root-equivalent; never
publish its API or use this repository on an unrelated host.

## Milestone replay

Before TD01, run `bash scripts/init_final_pack.sh --initialize` and follow the
Final Pack Workbook under `docs/student_support/`. Use `--sync` only after a
verified milestone; review every copied definition and never treat a remaining
`STUDENT-TASK` marker as complete.

Follow the lab in `docs/2_labs/` or the same path under `COURSE_ROOT`.

1. TD02 replaces the image-definition markers and proves a non-root,
   digest-pinned, Git-identified image.
2. TD03 proves private networking, service discovery, persistence and
   checksum-backed restoration with explicit `docker run` definitions.
3. TD04 replaces the Compose and proxy markers, audits the supplied operational
   scripts, diagnoses an assigned failure and executes a recorded recovery path.
4. TD05 applies and tests the security delta. Advanced controls never
   compensate for a broken runtime contract.
5. TD06 completes the workflow and digest deploy/rollback scripts, audits the
   supplied backup/restore procedures, publishes a candidate
   by Git SHA, records its digest, scans that digest, produces an SBOM, obtains
   approval, promotes by digest and executes rollback.

Within a pair, only one driver changes the shared Compose project at a time.
The partner first synchronizes to the exact full Git commit. Evidence from a
different revision or a divergent working tree does not support the claim.
Follow `docs/student_support/pair_replay_protocol.md`: uncommitted work remains
in one clone, the complete candidate is pushed, and only then does the second
account become the sole Docker driver for independent replay.

Before every candidate commit, scan both untracked/tracked submission files and
the staged index:

```bash
bash scripts/scan_submission.sh "$PACK_ROOT" final-docker-delivery-pack
git add PATHS_NAMED_BY_THE_LAB
bash scripts/scan_submission.sh --staged
```

A finding is a stop condition. If a real credential entered Git, notify the
instructor and rotate it; deleting the visible line is not containment.

## Definition checks

The trusted validator performs static rejection before any submitted Docker
definition is executed:

```bash
python3 tools/validation/validate_definitions.py .
```

An incomplete scaffold is expected to fail the final definition contract. Do
not weaken the validator to obtain green output. Complete the milestone,
inspect every finding and repair the definition.

After TD04 supplies a healthy stack, the reusable endpoint check is:

```bash
bash scripts/smoke.sh
```

Unit tests and static validation are necessary but insufficient. Delivery
claims still require versioned definitions, replayable tests, runtime evidence
and a rollback or recovery path.
