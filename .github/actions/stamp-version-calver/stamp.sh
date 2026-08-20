#!/usr/bin/env bash
#
# stamp.sh - Stamps a VERSION="..." assignment into the target scripts
# using a CalVer@SHA version derived from the version file and git HEAD.
#
# Inputs (environment variables, as set by action.yml):
#   FILES          space-separated list of files or glob patterns to stamp
#                  (required); patterns expand relative to the working
#                  directory, and a pattern matching nothing is a warning
#   EXCLUDE        space-separated glob patterns of files to skip
#                  (default: none)
#   VERSION_FILE   file whose top '## YYYY.0M.0D' entry provides the
#                  CalVer part (default: CHANGELOG.md)
#   VERSION        optional CalVer@SHA override (e.g. 2026.08.19@abc1234);
#                  derived from VERSION_FILE + git HEAD when empty
#   VAR_NAME       name of the assignment to stamp (default: VERSION;
#                  use e.g. VERSION_UTILS for a sourced helper)
#
# Options:
#   --dry-run      preview changes without writing any file
#   --help, -h     show this help message
#
# Each file is stamped in place:
#   - an existing 'VERSION="..."' line is replaced with the new version
#   - otherwise 'VERSION="..."' (plus a blank line) is inserted after the
#     shebang and header comment block, before the first line of code
#
# Output:
#   stdout   the list of modified files, one per line (empty when nothing
#            changed); consumed by commit-if-changed.sh in the same action
#   stderr   human-readable per-file status lines and the summary line:
#              FILE    (no change)              already at target version
#              FILE    old_ver -> new_ver       updated in-place
#              FILE    (new) -> new_ver         first stamp
#              WARNING: FILE  reason            file missing, skipped
#            Stamped N file(s), M skipped (already at version), K warning(s)
#            (' [dry run]' is appended when --dry-run is used)
#
# This script only rewrites the files; committing and pushing are handled
# by commit-if-changed.sh in the same action.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: stamp.sh [--dry-run] [--help]

Environment inputs:
  FILES          space-separated files or glob patterns to stamp (required)
  EXCLUDE        space-separated glob patterns to skip (default: none)
  VERSION_FILE   version file to read the CalVer from (default: CHANGELOG.md)
  VERSION        optional CalVer@SHA override (e.g., 2026.08.19@abc1234)
  VAR_NAME       assignment name to stamp (default: VERSION)

Options:
  --dry-run      Preview changes without writing any file
  --help, -h     Show this help message
EOF
}

DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown flag: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      echo "Unexpected argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

FILES="${FILES:-}"
EXCLUDE="${EXCLUDE:-}"
VERSION="${VERSION:-}"
VERSION_FILE="${VERSION_FILE:-CHANGELOG.md}"
VAR_NAME="${VAR_NAME:-VERSION}"

if [[ ! "$VAR_NAME" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
  echo "Error: VAR_NAME must be a valid shell identifier (e.g. VERSION or VERSION_UTILS), got: $VAR_NAME" >&2
  exit 1
fi

if [[ -z "${FILES// }" ]]; then
  echo "Error: FILES must be a non-empty, space-separated list of files or glob patterns" >&2
  exit 1
fi
patterns=()
read -r -a patterns <<< "$FILES"
excludes=()
if [[ -n "$EXCLUDE" ]]; then
  read -r -a excludes <<< "$EXCLUDE"
fi

if [[ -z "$VERSION" ]]; then
  if [[ ! -f "$VERSION_FILE" ]]; then
    echo "Error: version file not found: $VERSION_FILE" >&2
    exit 1
  fi
  CALVER=$(grep -m1 '^## [0-9]' "$VERSION_FILE" | sed 's/^## //' || true)
  if [[ -z "$CALVER" ]]; then
    echo "Error: no '## YYYY.0M.0D' entry found in $VERSION_FILE" >&2
    exit 1
  fi
  if ! SHA=$(git rev-parse --short HEAD); then
    echo "Error: could not resolve git HEAD SHA (not a git repository?)" >&2
    exit 1
  fi
  VERSION="${CALVER}@${SHA}"
fi

if [[ ! "$VERSION" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}(\.[0-9]+)?@[0-9a-f]{7,40}$ ]]; then
  echo "Error: version must match CalVer@SHA format (e.g., 2026.08.19@abc1234), got: $VERSION" >&2
  exit 1
fi

stamped=0
skipped=0
warnings=0
changed_files=()

# Expand glob patterns and apply exclusions so callers can select whole
# file groups instead of maintaining per-file lists. Literal paths pass
# through untouched so the main loop can warn about missing files.
file_list=()
for pattern in "${patterns[@]}"; do
  matches=()
  if [[ "$pattern" == *[*?]* ]]; then
    shopt -s nullglob
    # shellcheck disable=SC2206  # glob expansion is the intent here
    matches=($pattern)
    shopt -u nullglob
    if [[ ${#matches[@]} -eq 0 ]]; then
      printf "  WARNING: %-44s %s\n" "$pattern" "pattern matched no files" >&2
      warnings=$((warnings + 1))
      continue
    fi
  else
    matches=("$pattern")
  fi
  for file in "${matches[@]}"; do
    skip=false
    if [[ ${#excludes[@]} -gt 0 ]]; then
      for ex in "${excludes[@]}"; do
        # shellcheck disable=SC2254  # ex is a glob pattern by design
        case "$file" in $ex) skip=true; break ;; esac
      done
    fi
    [[ "$skip" == "true" ]] && continue
    file_list+=("$file")
  done
done
# A file matched by several patterns is stamped only once.
if [[ ${#file_list[@]} -gt 0 ]]; then
  uniq_list=()
  while IFS= read -r file; do
    [[ -n "$file" ]] && uniq_list+=("$file")
  done < <(printf '%s\n' "${file_list[@]}" | sort -u)
  file_list=("${uniq_list[@]}")
fi

for file in "${file_list[@]+"${file_list[@]}"}"; do
  if [[ ! -f "$file" ]]; then
    printf "  WARNING: %-44s %s\n" "$file" "file not found, skipped" >&2
    warnings=$((warnings + 1))
    continue
  fi

  old_ver="$(grep -m1 "^${VAR_NAME}=\".*\"\$" "$file" | sed -E "s/^${VAR_NAME}=\"(.*)\"$/\1/" || true)"
  if [[ -n "$old_ver" ]]; then
    if [[ "$old_ver" == "$VERSION" ]]; then
      status="nochange"
    else
      status="updated"
    fi
  else
    status="new"
  fi

  case "$status" in
    nochange)
      printf "  %-52s (no change)\n" "$file" >&2
      skipped=$((skipped + 1))
      ;;
    updated)
      printf "  %-52s %s -> %s\n" "$file" "$old_ver" "$VERSION" >&2
      stamped=$((stamped + 1))
      ;;
    new)
      printf "  %-52s (new) -> %s\n" "$file" "$VERSION" >&2
      stamped=$((stamped + 1))
      ;;
  esac

  if [[ "$status" != "nochange" && "$DRY_RUN" != "true" ]]; then
    if [[ "$status" == "new" ]]; then
      mode="insert"
    else
      mode="replace"
    fi
    tmp_file="$(mktemp)"
    awk -v name="$VAR_NAME" -v ver="$VERSION" -v mode="$mode" '
      mode == "replace" && $0 ~ ("^" name "=\".*\"$") { print name "=\"" ver "\""; next }
      mode == "insert" && !inserted && !/^[[:space:]]*(#.*)?$/ { print name "=\"" ver "\""; print ""; inserted=1 }
      { print }
    ' "$file" > "$tmp_file"
    cat "$tmp_file" > "$file"
    rm -f "$tmp_file"
    changed_files+=("$file")
  fi
done

dry_run_label=""
if [[ "$DRY_RUN" == "true" ]]; then
  dry_run_label=" [dry run]"
fi

echo "" >&2
echo "Stamped ${stamped} file(s), ${skipped} skipped (already at version), ${warnings} warning(s)${dry_run_label}" >&2

# The modified-file list is the machine-readable contract with the commit
# step, so the file selection is resolved exactly once per invocation.
if [[ ${#changed_files[@]} -gt 0 ]]; then
  printf '%s\n' "${changed_files[@]}"
fi
