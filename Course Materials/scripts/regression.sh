#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
APP_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
PROJECT="docker-delivery"
WORK_DIR=""

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

cleanup() {
  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" && "$WORK_DIR" == /tmp/esilv-regression.* ]]; then
    rm -f -- "$WORK_DIR/created.json" "$WORK_DIR/fetched.json"
    rmdir -- "$WORK_DIR"
  fi
}
trap cleanup EXIT

[[ -d "$APP_ROOT/.git" && -f "$APP_ROOT/compose.yaml" ]] \
  || die "run from the supplied Classroom repository layout"
: "${COURSE_ROOT:?load course.env before running regression}"
set -a
# shellcheck source=/dev/null
source "$COURSE_ROOT/0_technical_support/versions.env"
# shellcheck source=/dev/null
source "$APP_ROOT/release.env"
set +a
export POSTGRES_SECRET_SOURCE="$APP_ROOT/secrets/postgres_password.txt"

command -v jq >/dev/null 2>&1 || die "jq is unavailable"
docker info >/dev/null 2>&1 || die "Docker daemon is unavailable"
cd "$APP_ROOT"
docker compose -p "$PROJECT" -f compose.yaml config --quiet

WORK_DIR="$(mktemp -d /tmp/esilv-regression.XXXXXX)"
marker="td-regression-$(date -u +%Y%m%dT%H%M%SZ)-${RANDOM}"
base_url="${BASE_URL:-http://127.0.0.1:${COURSE_HTTP_PORT:-8080}}"

payload="$(jq -nc --arg name "$marker" '{name: $name}')"
curl --fail --silent --show-error --max-time 5 \
  --header 'Content-Type: application/json' --data "$payload" \
  "$base_url/api/items" > "$WORK_DIR/created.json"
item_id="$(jq -er '.item.id | select(type == "number")' "$WORK_DIR/created.json")"

docker compose -p "$PROJECT" -f compose.yaml up \
  --detach --no-build --no-deps --force-recreate \
  --wait --wait-timeout 90 delivery-api

ready=false
for _attempt in $(seq 1 30); do
  if curl --fail --silent --show-error --max-time 3 \
    "$base_url/readyz" >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 1
done
[[ "$ready" == true ]] || die "proxy/API readiness did not recover after API recreation"

curl --fail --silent --show-error --max-time 5 \
  "$base_url/api/items/$item_id" > "$WORK_DIR/fetched.json"
jq -e --arg marker "$marker" --argjson id "$item_id" \
  '.id == $id and .name == $marker' "$WORK_DIR/fetched.json" >/dev/null

if [[ -n "${EXPECTED_GIT_SHA:-}" ]]; then
  [[ "$EXPECTED_GIT_SHA" =~ ^[a-f0-9]{40}$ ]] \
    || die "EXPECTED_GIT_SHA must be a full lower-case Git revision"
  BASE_URL="$base_url" EXPECTED_GIT_SHA="$EXPECTED_GIT_SHA" bash scripts/smoke.sh
else
  BASE_URL="$base_url" bash scripts/smoke.sh
fi

printf 'PASS regression: item_id=%s marker=%s persisted_across=delivery-api-recreation\n' \
  "$item_id" "$marker"
