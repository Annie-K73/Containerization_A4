# Containerization_A4
Repository for our pair project related to the Containerization course A4.

Application code, tests and version locks are supplied inputs. You implement the
Docker delivery definitions across TD1–TD6. STUDENT-TASK markers and scripts that
exit 64 mean work remains; the initial scaffold is deliberately not deployable.

## Start

Extract the starter into a folder you own and open Bash there. Source
`. scripts/course-env.sh` to load the supplied version pins. This helper creates
no containers, networks, passwords or evidence. Use the course Setup page for
Docker checks and Git initialization. Do not change image or dependency locks
merely to bypass a failure.

## What you complete

- TD1: your repeatable container run file and real lifecycle observations.
- TD2: Dockerfile and .dockerignore; build, test and publish your API image.
- TD3: private connectivity, file secret, persistent data and a verified restore.
- TD4: Compose and proxy configuration; your diagnosis of an observed fault.
- TD5: hardening controls, allowed/denied checks and vulnerability triage.
- TD6: CI, exact-digest deployment and rollback, backed by your own observations.

The supplied API exposes /healthz, /readyz, /version and /items. Read the app and
tests for the request/response contract. Keep actual outputs and a plain-language
OBSERVATIONS.md in evidence/TD01 through evidence/TD06. There is no browser grade.
Record a failed or blocked check honestly; never replace observations with an
expected answer. The optional smoke helper checks HTTP behavior and does not
build or repair your definitions. The submission scanner checks secrets only.

## Test supplied application code

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install --require-hashes --requirement requirements-dev.txt
python -m pytest -q
```

These app tests do not validate your Dockerfile, Compose or release workflow.
Keep credentials, secrets, backups and local environments out of Git. Only the
proxy may publish a host port, on loopback. Use the course SSH tunnel instructions
for your own remote server. Ask on Discord remotely or Badr on campus.
