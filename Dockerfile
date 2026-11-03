# syntax=docker/dockerfile:1.7

# Frozen by the semester version manifest. Students may override this build
# argument only with another instructor-approved digest.
ARG PYTHON_IMAGE=python:3.12-slim@sha256:44ff437bba879d4941b710a369a8f19266aea34b29002807f0c487fabc9eec9b

FROM ${PYTHON_IMAGE} AS builder
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1
WORKDIR /build
COPY requirements.txt ./

# STUDENT-TASK(TD02): install the hash-locked dependencies into an artifact
# that can be copied into a minimal runtime stage. Do not copy application
# source before this dependency step.

# STUDENT-TASK(TD02): add a separate runtime stage that:
# - consumes the same locked PYTHON_IMAGE argument;
# - accepts APP_VERSION, GIT_SHA and SOURCE_URL build arguments;
# - records OCI version, source and full Git revision labels;
# - copies only the dependency artifact and required application files;
# - creates and selects UID/GID 10001;
# - exposes port 8000 and documents SIGTERM behavior;
# - starts Gunicorn as the exec-form PID 1 command;
# - implements a bounded liveness health check.

# This builder-only scaffold is intentionally not a runnable submission.
