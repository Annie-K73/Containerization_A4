#!/usr/bin/env bash
set -Eeuo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:${COURSE_HTTP_PORT:-8080}}"

assert_json_field() {
  local endpoint="$1"
  local field="$2"
  local expected="$3"
  local body
  body="$(curl --fail --silent --show-error --max-time 5 "${BASE_URL}${endpoint}")"
  python3 - "${body}" "${field}" "${expected}" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
field, expected = sys.argv[2], sys.argv[3]
actual = payload.get(field)
if str(actual) != expected:
    raise SystemExit(f"{field}: expected {expected!r}, observed {actual!r}")
PY
}

assert_json_field "/healthz" "status" "ok"
assert_json_field "/readyz" "status" "ready"
assert_json_field "/version" "application" "delivery-api"
if [[ -n "${EXPECTED_GIT_SHA:-}" ]]; then
  if [[ ! "${EXPECTED_GIT_SHA}" =~ ^[a-f0-9]{40}$ ]]; then
    echo "ERROR: EXPECTED_GIT_SHA must be a full lowercase 40-character Git SHA" >&2
    exit 1
  fi
  assert_json_field "/version" "git_sha" "${EXPECTED_GIT_SHA}"
fi

echo "PASS: liveness, readiness, and release-identity checks succeeded"
