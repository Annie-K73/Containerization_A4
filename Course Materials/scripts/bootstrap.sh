#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
APP_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
PROJECT="docker-delivery"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

[[ -d "$APP_ROOT/.git" && ! -L "$APP_ROOT/.git" ]] \
  || die "run the stack bootstrap from a Classroom clone"
: "${COURSE_ROOT:?load the instructor-provisioned course.env first}"
[[ "$(realpath -e -- "$COURSE_ROOT")" == /opt/esilv/docker-devops-foundations ]] \
  || die "COURSE_ROOT is not the canonical read-only course bundle"
[[ -f "$APP_ROOT/release.env" && ! -L "$APP_ROOT/release.env" ]] \
  || die "release.env is missing or unsafe"

# These files contain only reviewed non-secret exports/coordinates.
set -a
# shellcheck source=/dev/null
source "$COURSE_ROOT/0_technical_support/versions.env"
# shellcheck source=/dev/null
source "$APP_ROOT/release.env"
set +a

case "${DELIVERY_API_IMAGE:-}" in
  ghcr.io/*@sha256:[a-f0-9]*) ;;
  *) die "DELIVERY_API_IMAGE must be the TD02 immutable GHCR coordinate" ;;
esac
[[ "${DELIVERY_API_IMAGE##*@sha256:}" =~ ^[a-f0-9]{64}$ ]] \
  || die "DELIVERY_API_IMAGE digest must contain 64 lower-case hexadecimal characters"

secret="$APP_ROOT/secrets/postgres_password.txt"
[[ -f "$secret" && ! -L "$secret" ]] || die "administrator-installed secret is absent or unsafe"
[[ "$(stat -c '%u:%g:%a' -- "$secret")" == "0:${COURSE_SECRET_GROUP_ID}:440" ]] \
  || die "secret metadata differs from root:${COURSE_SECRET_GROUP_ID} mode 0440"
git -C "$APP_ROOT" check-ignore --quiet -- secrets/postgres_password.txt \
  || die "secret path is not ignored by Git"
export POSTGRES_SECRET_SOURCE="$secret"

command -v docker >/dev/null 2>&1 || die "docker is unavailable"
docker info >/dev/null 2>&1 || die "the current account cannot reach the Docker daemon"
docker image inspect "$DELIVERY_API_IMAGE" >/dev/null 2>&1 \
  || die "the private API digest is not local; use the bounded GHCR session to pull it first"

cd "$APP_ROOT"
docker compose -p "$PROJECT" -f compose.yaml config --quiet
docker compose -p "$PROJECT" -f compose.yaml up \
  --detach --no-build --wait --wait-timeout 120 --remove-orphans
bash scripts/smoke.sh

printf 'PASS stack bootstrap: project=%s image=%s\n' "$PROJECT" "$DELIVERY_API_IMAGE"
printf 'The protected secret was checked by metadata only; its value was not read or printed.\n'
