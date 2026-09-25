#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
APP_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
[[ "$APP_ROOT" =~ ^/srv/esilv-docker/[a-z_][a-z0-9_-]{0,31}/docker-delivery$ ]] \
  || { printf 'ERROR: initializer must run from the canonical Classroom root: %s\n' "$APP_ROOT" >&2; exit 2; }
[[ -d "$APP_ROOT/.git" && ! -L "$APP_ROOT/.git" ]] \
  || { printf 'ERROR: canonical Classroom Git metadata is absent\n' >&2; exit 2; }
: "${COURSE_ROOT:?load the instructor-provisioned course.env first}"
COURSE_ROOT="$(realpath -e -- "$COURSE_ROOT")"
[[ "$COURSE_ROOT" == /opt/esilv/docker-devops-foundations ]] \
  || { printf 'ERROR: non-canonical COURSE_ROOT: %s\n' "$COURSE_ROOT" >&2; exit 2; }

PACK_ROOT="${APP_ROOT}/final-docker-delivery-pack"
SKELETON="${COURSE_ROOT}/3_project/final_pack_skeleton"
TEMPLATES="${COURSE_ROOT}/3_project/templates"
CONTRACT_TEMPLATES="${COURSE_ROOT}/0_technical_support/_shared/templates"
MODE="${1:---initialize}"

case "$MODE" in
  --initialize|--sync) ;;
  -h|--help)
    printf 'Usage: bash scripts/init_final_pack.sh [--initialize|--sync]\n'
    exit 0
    ;;
  *) printf 'ERROR: unknown mode: %s\n' "$MODE" >&2; exit 2 ;;
esac

if [[ -e "$PACK_ROOT" ]]; then
  [[ -d "$PACK_ROOT" && ! -L "$PACK_ROOT" ]] \
    || { printf 'ERROR: final-pack root is not a safe directory: %s\n' "$PACK_ROOT" >&2; exit 2; }
  [[ "$(realpath -e -- "$PACK_ROOT")" == "$PACK_ROOT" ]] \
    || { printf 'ERROR: final-pack root does not resolve canonically\n' >&2; exit 2; }
fi

install -d -m 0750 \
  "$PACK_ROOT/architecture" "$PACK_ROOT/definitions" \
  "$PACK_ROOT/definitions/nginx" "$PACK_ROOT/definitions/db/init" \
  "$PACK_ROOT/operations" "$PACK_ROOT/tests/regression" \
  "$PACK_ROOT/evidence/TD01" "$PACK_ROOT/evidence/TD02" \
  "$PACK_ROOT/evidence/TD03" "$PACK_ROOT/evidence/TD04" \
  "$PACK_ROOT/evidence/TD05" "$PACK_ROOT/evidence/TD06" \
  "$PACK_ROOT/security" "$PACK_ROOT/handoff" "$PACK_ROOT/governance"

while IFS= read -r directory; do
  [[ -d "$directory" && ! -L "$directory" ]] \
    || { printf 'ERROR: unsafe final-pack directory: %s\n' "$directory" >&2; exit 2; }
done < <(find "$PACK_ROOT" -type d -print)

install_if_absent() {
  local source="$1" target="$2"
  if [[ -e "$target" ]]; then
    [[ -f "$target" && ! -L "$target" ]] \
      || { printf 'ERROR: refusing unsafe existing final-pack target: %s\n' "$target" >&2; return 2; }
  else
    install -m 0640 -- "$source" "$target"
  fi
}

while IFS= read -r relative; do
  install_if_absent "$SKELETON/$relative" "$PACK_ROOT/$relative"
done <<'SKELETON_FILES'
README.md
executive-summary.md
architecture/decision-log.md
architecture/system-diagram.mmd
architecture/system-diagram.dot
operations/RUNBOOK.md
tests/commands.txt
tests/TEST_CARDS.md
security/threat-model.md
security/vulnerability-triage.md
security/residual-risk.md
handoff/kubernetes-handoff.md
SKELETON_FILES
chmod 0750 "$PACK_ROOT/tests/commands.txt"

install_if_absent "$TEMPLATES/CLAIMS_INDEX.md" "$PACK_ROOT/claims-index.md"
install_if_absent "$TEMPLATES/AI_USE_DISCLOSURE.md" "$PACK_ROOT/governance/AI_USE_DISCLOSURE.md"
install_if_absent "$TEMPLATES/CONTRIBUTION_LOG.md" "$PACK_ROOT/governance/CONTRIBUTION_LOG.md"
install_if_absent "$TEMPLATES/RISK_REGISTER.md" "$PACK_ROOT/governance/RISK_REGISTER.md"
install_if_absent "$TEMPLATES/INCIDENT_POSTMORTEM.md" "$PACK_ROOT/governance/INCIDENT_POSTMORTEM.md"
install_if_absent "$CONTRACT_TEMPLATES/runtime_contract.template.yaml" "$PACK_ROOT/runtime-contract.yaml"
install_if_absent "$CONTRACT_TEMPLATES/test_cards.final.template.json" "$PACK_ROOT/tests/test-cards.json"
install_if_absent "$CONTRACT_TEMPLATES/evidence_manifest.final.template.json" "$PACK_ROOT/evidence/manifest.json"

if [[ "$MODE" == --sync ]]; then
  while IFS='|' read -r source target; do
    [[ -f "$APP_ROOT/$source" && ! -L "$APP_ROOT/$source" ]] \
      || { printf 'ERROR: required source is missing or unsafe: %s\n' "$source" >&2; exit 2; }
    [[ ! -e "$PACK_ROOT/$target" || ( -f "$PACK_ROOT/$target" && ! -L "$PACK_ROOT/$target" ) ]] \
      || { printf 'ERROR: refusing unsafe synchronization target: %s\n' "$target" >&2; exit 2; }
    install -m 0640 -- "$APP_ROOT/$source" "$PACK_ROOT/$target"
  done <<'SYNC_FILES'
Dockerfile|definitions/Dockerfile
.dockerignore|definitions/.dockerignore
compose.yaml|definitions/compose.yaml
nginx/nginx.conf|definitions/nginx.conf
.github/workflows/container-delivery.yml|definitions/pipeline.yaml
nginx/nginx.conf|definitions/nginx/nginx.conf
db/init/001-schema.sql|definitions/db/init/001-schema.sql
.env.example|definitions/runtime.env.example
scripts/bootstrap.sh|operations/bootstrap.sh
scripts/deploy.sh|operations/deploy.sh
scripts/rollback.sh|operations/rollback.sh
scripts/backup.sh|operations/backup.sh
scripts/restore.sh|operations/restore.sh
scripts/smoke.sh|tests/smoke.sh
scripts/regression.sh|tests/regression/regression.sh
SYNC_FILES
  if [[ -f "$APP_ROOT/release.env" && ! -L "$APP_ROOT/release.env" ]]; then
    [[ ! -e "$PACK_ROOT/definitions/release.env" \
      || ( -f "$PACK_ROOT/definitions/release.env" && ! -L "$PACK_ROOT/definitions/release.env" ) ]] \
      || { printf 'ERROR: unsafe release.env synchronization target\n' >&2; exit 2; }
    install -m 0640 -- "$APP_ROOT/release.env" "$PACK_ROOT/definitions/release.env"
  elif [[ -e "$APP_ROOT/release.env" ]]; then
    printf 'ERROR: release.env exists but is not a safe regular file\n' >&2
    exit 2
  fi
  chmod 0750 "$PACK_ROOT/operations/bootstrap.sh" \
    "$PACK_ROOT/operations/deploy.sh" "$PACK_ROOT/operations/rollback.sh" \
    "$PACK_ROOT/operations/backup.sh" "$PACK_ROOT/operations/restore.sh" \
    "$PACK_ROOT/tests/smoke.sh" "$PACK_ROOT/tests/regression/regression.sh"
fi

printf 'Final-pack workspace: %s\n' "$PACK_ROOT"
printf 'Mode: %s\n' "$MODE"
printf '%s\n' \
  'Runtime-produced artifacts are intentionally not fabricated.' \
  'Before final validation, add architecture/system-diagram.png, security/sbom.cdx.json,' \
  'executed evidence, completed JSON contracts, and remove every STUDENT-TASK marker.'
