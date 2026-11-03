#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/scan_submission.sh PATH [PATH ...]
  bash scripts/scan_submission.sh --staged

The path form scans tracked and untracked files below the named submission
roots. The --staged form scans every file selected for the next Git commit.
Either form exits non-zero on a high-confidence credential or prohibited path.
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

repository_root="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || die "run from inside your project Git repository"
repository_root="$(cd -- "$repository_root" && pwd -P)" \
  || die "cannot resolve the project Git repository"
[[ -d "$repository_root/.git" && ! -L "$repository_root/.git" ]] \
  || die "the project repository metadata is unavailable or unsafe"

# Keep signatures split so this scanner does not flag its own source.
pat_prefix='gh[pousr]_'
fine_pat_prefix='github_pat_'
private_key_prefix='-----BEGIN '
content_pattern="${pat_prefix}[A-Za-z0-9_]{20,}|${fine_pat_prefix}[A-Za-z0-9_]{20,}|${private_key_prefix}(RSA |OPENSSH |EC |DSA )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|[A-Za-z][A-Za-z0-9+.-]*://[^[:space:]/:@]+:[^@[:space:]/]+@|\"auth\"[[:space:]]*:[[:space:]]*\"[A-Za-z0-9+/=]{16,}\""

findings=0
scanned=0

check_path() {
  local relative="$1"
  case "/$relative" in
    */.docker-auth/*|*/.gh-auth/*|*/secrets/*|*/.ssh/*)
      printf 'REJECT path: %s\n' "$relative" >&2
      findings=$((findings + 1))
      ;;
    */.env.example)
      ;;
    */.env|*/.env.*|*/id_rsa|*/id_ed25519|*.pem|*.p12|*.pfx|*.key)
      # release.env is intentionally not covered by these exact .env forms.
      printf 'REJECT credential-shaped path: %s\n' "$relative" >&2
      findings=$((findings + 1))
      ;;
  esac
  case "/$relative" in
    */final-docker-delivery-pack/definitions/db/init/001-schema.sql)
      # Versioned empty-volume schema input, not a captured database export.
      ;;
    */final-docker-delivery-pack/*)
      case "$relative" in
        *.dump|*.sql|*.bak|*.tar|*.tar.gz|*.tgz)
          printf 'REJECT raw data/archive in final pack: %s\n' "$relative" >&2
          findings=$((findings + 1))
          ;;
      esac
      ;;
  esac
}

check_worktree_file() {
  local path="$1" relative
  relative="${path#"$repository_root"/}"
  check_path "$relative"
  scanned=$((scanned + 1))
  if grep -Iq . -- "$path" 2>/dev/null; then
    if grep -nE "$content_pattern" -- "$path" >&2; then
      printf 'REJECT high-confidence credential content: %s\n' "$relative" >&2
      findings=$((findings + 1))
    fi
  fi
}

check_staged_file() {
  local relative="$1" grep_status git_status
  local -a pipeline_status
  check_path "$relative"
  scanned=$((scanned + 1))
  # Use grep's status, not the producer's possible SIGPIPE status under -q.
  # Disable errexit as well: a clean grep result is status 1 and is expected.
  set +e
  set +o pipefail
  git show ":$relative" | grep -IEn "$content_pattern" >&2
  pipeline_status=("${PIPESTATUS[@]}")
  set -o pipefail
  set -e
  git_status="${pipeline_status[0]}"
  grep_status="${pipeline_status[1]}"
  [[ "$git_status" == 0 ]] || die "could not read staged file: $relative"
  if [[ "$grep_status" == 0 ]]; then
    printf 'REJECT high-confidence credential content in staged file: %s\n' "$relative" >&2
    findings=$((findings + 1))
  elif [[ "$grep_status" != 1 ]]; then
    die "could not scan staged file: $relative"
  fi
}

if [[ "${1:-}" == --staged ]]; then
  (($# == 1)) || die "--staged does not accept path arguments"
  while IFS= read -r -d '' relative; do
    check_staged_file "$relative"
  done < <(git diff --cached --name-only --diff-filter=ACMR -z)
else
  (($# >= 1)) || { usage >&2; exit 2; }
  for candidate in "$@"; do
    [[ -e "$candidate" ]] || die "scan root does not exist: $candidate"
    resolved="$(realpath -e -- "$candidate")"
    [[ "$resolved" == "$repository_root" || "$resolved" == "$repository_root"/* ]] \
      || die "scan root must resolve inside the Classroom repository: $candidate"
    if [[ -L "$candidate" ]]; then
      printf 'REJECT symbolic-link scan root: %s\n' "$candidate" >&2
      findings=$((findings + 1))
      continue
    fi
    while IFS= read -r -d '' link; do
      printf 'REJECT symbolic link in submission root: %s\n' \
        "${link#"$repository_root"/}" >&2
      findings=$((findings + 1))
    done < <(find "$resolved" -type l -print0)
    while IFS= read -r -d '' file; do
      check_worktree_file "$file"
    done < <(find "$resolved" -type f -print0)
  done
fi

if ((findings > 0)); then
  printf 'FAIL submission scan: %d finding(s) across %d file(s)\n' \
    "$findings" "$scanned" >&2
  exit 1
fi
printf 'PASS submission scan: %d file(s), no high-confidence credential or prohibited path\n' \
  "$scanned"
