#!/usr/bin/env bash
#
# commit-if-changed.sh - Commits the files stamp.sh just modified as
# github-actions[bot] and pushes with --force-with-lease.
#
# Inputs (environment variables, as set by action.yml):
#   FILES          newline-separated list of modified files produced by
#                  stamp.sh (empty means nothing changed)
#   VERSION        optional CalVer@SHA string for the commit message;
#                  derived from VERSION_FILE + git HEAD when empty
#   VERSION_FILE   file whose top '## YYYY.0M.0D' entry provides the
#                  CalVer part (default: CHANGELOG.md)
#
# Prints "All files already at current version, nothing to commit" and
# exits 0 when FILES is empty. Otherwise configures the bot identity,
# commits with "chore: stamp versions with <version> [skip ci]", and
# pushes with --force-with-lease.

set -euo pipefail

FILES="${FILES:-}"
VERSION="${VERSION:-}"
VERSION_FILE="${VERSION_FILE:-CHANGELOG.md}"

if [[ -z "${FILES//[[:space:]]/}" ]]; then
  echo "All files already at current version, nothing to commit"
  exit 0
fi

if [[ -z "$VERSION" ]]; then
  CALVER=$(grep -m1 '^## [0-9]' "$VERSION_FILE" | sed 's/^## //' || true)
  SHA=$(git rev-parse --short HEAD)
  VERSION="${CALVER}@${SHA}"
fi

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

path_args=()
while IFS= read -r file; do
  [[ -n "$file" ]] && path_args+=("$file")
done <<< "$FILES"

git add -- "${path_args[@]}"
git commit -m "chore: stamp versions with ${VERSION} [skip ci]"
git push --force-with-lease
