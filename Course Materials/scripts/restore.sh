#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
APP_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
PROJECT="docker-delivery"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

if (($# != 2)) || [[ "$2" != --confirm-database-replace ]]; then
  printf 'Usage: bash scripts/restore.sh /absolute/path/to/backups/FILE.dump --confirm-database-replace\n' >&2
  exit 2
fi

source_input="$1"
[[ -f "$source_input" && ! -L "$source_input" ]] \
  || die "backup source must be a regular non-symlink file"
backup_path="$(realpath -e -- "$source_input")"
backup_dir="$(realpath -e -- "$APP_ROOT/backups" 2>/dev/null)" \
  || die "canonical backup directory is unavailable"
[[ "$backup_path" == "$backup_dir"/*.dump ]] \
  || die "backup must be a .dump file directly inside $backup_dir"
[[ "$(stat -c '%u:%a' -- "$backup_path")" == "$(id -u):600" ]] \
  || die "backup must be owned by the current account with mode 0600"
checksum_path="$backup_path.sha256"
[[ -f "$checksum_path" && ! -L "$checksum_path" ]] \
  || die "checksum sidecar is missing or unsafe"
[[ "$(stat -c '%u:%a' -- "$checksum_path")" == "$(id -u):600" ]] \
  || die "checksum sidecar must be owned by the current account with mode 0600"
(
  cd "$backup_dir"
  sha256sum --check "$(basename -- "$checksum_path")"
)

: "${COURSE_ROOT:?load course.env before running restore}"
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

printf 'Creating a pre-restore safety backup...\n'
pre_restore_record="$(bash scripts/backup.sh)"
printf '%s\n' "$pre_restore_record"
pre_restore_path="$(sed -n 's/^backup_path=//p' <<<"$pre_restore_record")"
[[ "$pre_restore_path" == "$backup_dir"/*.dump ]] \
  || die "pre-restore backup did not return a bounded path"

docker compose -p "$PROJECT" -f compose.yaml exec -T postgres \
  pg_restore --clean --if-exists --no-owner --exit-on-error \
  --username "${POSTGRES_USER:-delivery}" \
  --dbname "${POSTGRES_DB:-delivery}" < "$backup_path"

bash scripts/smoke.sh
bash scripts/regression.sh
printf 'PASS restore: source=%s pre_restore_backup=%s verification=smoke+regression\n' \
  "$backup_path" "$pre_restore_path"
