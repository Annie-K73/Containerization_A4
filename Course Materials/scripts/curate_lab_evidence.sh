#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  printf 'Usage: bash scripts/curate_lab_evidence.sh TD01|TD02|TD03|TD04|TD05|TD06 SOURCE_EVIDENCE_DIR\n'
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

(($# == 2)) || { usage >&2; exit 2; }
lab_id="$1"
source_input="$2"
[[ "$lab_id" =~ ^TD0[1-6]$ ]] || die "invalid lab identifier: $lab_id"

repository_root="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || die "run from inside the Classroom Git repository"
repository_root="$(realpath -e -- "$repository_root")"
source_root="$(realpath -e -- "$source_input" 2>/dev/null)" \
  || die "source evidence directory is unavailable: $source_input"
[[ -d "$source_root" && ! -L "$source_input" ]] \
  || die "source evidence must be a non-symlink directory"
[[ "$source_root" == "$repository_root"/submissions/TD0[1-6]_*/evidence ]] \
  || die "source must be one dated lab pack's evidence directory"

target_root="$repository_root/final-docker-delivery-pack/evidence/$lab_id"
[[ -d "$target_root" && ! -L "$target_root" ]] \
  || die "initialize the final pack before curating $lab_id"
[[ -z "$(find "$source_root" -type l -print -quit)" ]] \
  || die "source evidence contains a symbolic link"

copied=0
excluded=0
while IFS= read -r -d '' source_file; do
  relative="${source_file#"$source_root"/}"
  case "/$relative" in
    */secrets/*|*/.docker-auth/*|*/.gh-auth/*|*/.ssh/*|*/.env|*/.env.*)
      die "prohibited evidence path: $relative"
      ;;
  esac
  case "$relative" in
    *.dump|*.sql|*.bak|*.tar|*.tar.gz|*.tgz)
      printf 'EXCLUDE raw data/archive from final pack: %s\n' "$relative"
      excluded=$((excluded + 1))
      continue
      ;;
  esac
  target_file="$target_root/$relative"
  install -d -m 0750 -- "$(dirname -- "$target_file")"
  [[ ! -e "$target_file" || ( -f "$target_file" && ! -L "$target_file" ) ]] \
    || die "unsafe final-pack evidence target: $target_file"
  install -m 0640 -- "$source_file" "$target_file"
  copied=$((copied + 1))
done < <(find "$source_root" -type f -print0)

printf 'Curated %s: copied=%d excluded_raw_data=%d target=%s\n' \
  "$lab_id" "$copied" "$excluded" "$target_root"
