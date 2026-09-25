#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
APP_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
PROJECT="docker-delivery"
TEMP_BACKUP=""

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

cleanup() {
  [[ -z "$TEMP_BACKUP" || ! -e "$TEMP_BACKUP" ]] || rm -f -- "$TEMP_BACKUP"
}
trap cleanup EXIT

(($# == 0)) || die "backup.sh accepts no arguments; it writes one bounded timestamped backup"
: "${COURSE_ROOT:?load course.env before running backup}"
set -a
# shellcheck source=/dev/null
source "$COURSE_ROOT/0_technical_support/versions.env"
# shellcheck source=/dev/null
source "$APP_ROOT/release.env"
set +a
export POSTGRES_SECRET_SOURCE="$APP_ROOT/secrets/postgres_password.txt"

cd "$APP_ROOT"
docker compose -p "$PROJECT" -f compose.yaml config --quiet
postgres_id="$(docker compose -p "$PROJECT" -f compose.yaml ps -q postgres)"
[[ -n "$postgres_id" ]] || die "PostgreSQL is not running in the fixed Compose project"
[[ "$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$postgres_id")" == "$PROJECT" ]] \
  || die "refusing a PostgreSQL container outside the fixed Compose project"
[[ "$(docker inspect --format '{{index .Config.Labels "com.docker.compose.service"}}' "$postgres_id")" == postgres ]] \
  || die "resolved container is not the PostgreSQL service"

backup_dir="$APP_ROOT/backups"
install -d -m 0700 -- "$backup_dir"
timestamp="$(date -u +%Y%m%dT%H%M%S%NZ)"
backup_name="delivery-${timestamp}.dump"
backup_path="$backup_dir/$backup_name"
[[ ! -e "$backup_path" && ! -e "$backup_path.sha256" ]] \
  || die "backup target already exists: $backup_path"
TEMP_BACKUP="$(mktemp "$backup_dir/.delivery.XXXXXX")"
chmod 0600 -- "$TEMP_BACKUP"

docker compose -p "$PROJECT" -f compose.yaml exec -T postgres \
  pg_dump --username "${POSTGRES_USER:-delivery}" \
  --dbname "${POSTGRES_DB:-delivery}" --format=custom > "$TEMP_BACKUP"
[[ "$(stat -c '%s' -- "$TEMP_BACKUP")" -ge 512 ]] \
  || die "backup is unexpectedly small or empty"
docker compose -p "$PROJECT" -f compose.yaml exec -T postgres \
  pg_restore --list < "$TEMP_BACKUP" >/dev/null

mv -- "$TEMP_BACKUP" "$backup_path"
TEMP_BACKUP=""
(
  cd "$backup_dir"
  sha256sum "$backup_name" > "$backup_name.sha256"
  chmod 0600 "$backup_name.sha256"
)
printf 'backup_path=%s\nchecksum_path=%s\n' "$backup_path" "$backup_path.sha256"
printf 'PASS backup: custom-format archive is non-empty, listable and checksum-bound\n'
