#!/usr/bin/env bats

load ../scripts/test_helper.bash

# The action scripts under test. Inputs travel through environment
# variables, matching how action.yml maps its inputs onto them.
STAMP="$PROJECT_ROOT/.github/actions/stamp-version-calver/stamp.sh"
COMMIT_IF_CHANGED="$PROJECT_ROOT/.github/actions/stamp-version-calver/commit-if-changed.sh"

# fixture_repo — temp git repo with a committed CHANGELOG.md (top entry
# ## 2026.08.19) and a committed target.sh (shebang + header comment +
# code). Runs are made from inside the repo so git and CHANGELOG.md
# resolve. A bare remote is added so push assertions have somewhere to go.
fixture_repo() {
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO"
  cd "$REPO"
  git init -q
  git config user.name "Test User"
  git config user.email "test@example.com"
  git config commit.gpgsign false
  git config core.abbrev 7
  cat > CHANGELOG.md <<'EOF'
# Changelog

## 2026.08.19

### Added

- test entry
EOF
  cat > target.sh <<'EOF'
#!/bin/zsh
# Target script used by the stamp action tests.

echo hi
EOF
  git add CHANGELOG.md target.sh
  git commit -q -m "fixture"
  export REPO
}

# fixture_repo_with_remote — fixture_repo plus a bare origin remote with
# the fixture commit pushed, so commit-if-changed.sh can push for real.
fixture_repo_with_remote() {
  fixture_repo
  git init -q --bare "$BATS_TEST_TMPDIR/remote.git"
  git remote add origin "$BATS_TEST_TMPDIR/remote.git"
  git push -q -u origin HEAD
}

# --- stamp.sh -------------------------------------------------------------

@test "stamp replaces an existing VERSION assignment" {
  fixture_repo
  echo 'VERSION="1.2.3@abc1234"' >> target.sh
  run env FILES=target.sh VERSION=2026.08.19@abc1234 bash "$STAMP"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^VERSION=' target.sh)" -eq 1 ]
  grep -q 'VERSION="2026.08.19@abc1234"' target.sh
}

@test "stamp inserts after the header comment block when VERSION is absent" {
  fixture_repo
  run env FILES=target.sh VERSION=2026.08.19@abc1234 bash "$STAMP"
  [ "$status" -eq 0 ]
  [ "$(head -1 target.sh)" = "#!/bin/zsh" ]
  local version_line; version_line="$(grep -n '^VERSION=' target.sh | cut -d: -f1)"
  local code_line; code_line="$(grep -n '^echo hi' target.sh | cut -d: -f1)"
  [ "$version_line" -lt "$code_line" ]
  [ "$(sed -n "$((version_line + 1))p" target.sh)" = "" ]
}

@test "stamp reports skipped when the file is already at the target version" {
  fixture_repo
  echo 'VERSION="2026.08.19@abc1234"' >> target.sh
  run env FILES=target.sh VERSION=2026.08.19@abc1234 bash "$STAMP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"(no change)"* ]]
  [[ "$output" == *"Stamped 0 file(s), 1 skipped"* ]]
}

@test "stamp derives the version from the version file and git HEAD" {
  fixture_repo
  run env FILES=target.sh bash "$STAMP"
  [ "$status" -eq 0 ]
  grep -Eq '^VERSION="2026\.08\.19@[0-9a-f]{7,40}"$' target.sh
}

@test "stamp reads a custom version file via VERSION_FILE" {
  fixture_repo
  printf '# Changelog\n\n## 2026.08.20\n' > custom.md
  run env FILES=target.sh VERSION_FILE=custom.md bash "$STAMP"
  [ "$status" -eq 0 ]
  grep -Eq '^VERSION="2026\.08\.20@[0-9a-f]{7,40}"$' target.sh
}

@test "stamp --dry-run previews without writing" {
  fixture_repo
  run env FILES=target.sh VERSION=2026.08.19@abc1234 bash "$STAMP" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"(new) -> 2026.08.19@abc1234"* ]]
  [[ "$output" == *"[dry run]"* ]]
  ! grep -q '^VERSION=' target.sh
}

@test "stamp exits 1 when the version file is missing" {
  fixture_repo
  run env FILES=target.sh VERSION_FILE=nope.md bash "$STAMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"version file not found: nope.md"* ]]
}

@test "stamp exits 1 when the version file has no dated entry" {
  fixture_repo
  printf '# Changelog\n\nNo dated entries here.\n' > CHANGELOG.md
  run env FILES=target.sh bash "$STAMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no '## YYYY.0M.0D' entry found in CHANGELOG.md"* ]]
}

@test "stamp exits 1 when the resolved version is not CalVer@SHA" {
  fixture_repo
  run env FILES=target.sh VERSION=garbage bash "$STAMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"version must match CalVer@SHA format"* ]]
}

@test "stamp exits 1 when deriving outside a git repository" {
  local dir="$BATS_TEST_TMPDIR/nogit"
  mkdir -p "$dir"
  cd "$dir"
  printf '# Changelog\n\n## 2026.08.19\n' > CHANGELOG.md
  printf 'echo hi\n' > target.sh
  run env FILES=target.sh bash "$STAMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not resolve git HEAD SHA"* ]]
}

@test "stamp reports a warning and continues for a missing file" {
  fixture_repo
  run env FILES="target.sh missing.sh" VERSION=2026.08.19@abc1234 bash "$STAMP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING"* ]]
  [[ "$output" == *"1 warning(s)"* ]]
  grep -q 'VERSION="2026.08.19@abc1234"' target.sh
}

@test "stamp exits 1 when FILES is empty" {
  fixture_repo
  run env FILES= bash "$STAMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FILES must be a non-empty"* ]]
}

@test "stamp --help exits 0" {
  run bash "$STAMP" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: stamp.sh"* ]]
}

@test "stamp rejects an unknown flag" {
  run bash "$STAMP" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown flag"* ]]
}

@test "stamp uses a custom assignment name via VAR_NAME" {
  fixture_repo
  run env FILES=target.sh VERSION=2026.08.19@abc1234 VAR_NAME=VERSION_UTILS bash "$STAMP"
  [ "$status" -eq 0 ]
  grep -q 'VERSION_UTILS="2026.08.19@abc1234"' target.sh
  ! grep -q '^VERSION="' target.sh
}

@test "stamp replaces only the VAR_NAME assignment when both names exist" {
  fixture_repo
  printf 'VERSION="1.0.0@1111111"\nVERSION_UTILS="2.0.0@2222222"\n' >> target.sh
  run env FILES=target.sh VERSION=2026.08.19@abc1234 VAR_NAME=VERSION_UTILS bash "$STAMP"
  [ "$status" -eq 0 ]
  grep -q 'VERSION_UTILS="2026.08.19@abc1234"' target.sh
  grep -q 'VERSION="1.0.0@1111111"' target.sh
}

@test "stamp exits 1 when VAR_NAME is not a valid identifier" {
  fixture_repo
  run env FILES=target.sh VERSION=2026.08.19@abc1234 VAR_NAME='bad name!' bash "$STAMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"VAR_NAME must be a valid shell identifier"* ]]
}

@test "stamp expands glob patterns in FILES" {
  fixture_repo
  printf '#!/bin/zsh\necho a\n' > a.sh
  printf '#!/bin/zsh\necho b\n' > b.sh
  run env FILES="*.sh" VERSION=2026.08.19@abc1234 bash "$STAMP"
  [ "$status" -eq 0 ]
  grep -q 'VERSION="2026.08.19@abc1234"' a.sh
  grep -q 'VERSION="2026.08.19@abc1234"' b.sh
  grep -q 'VERSION="2026.08.19@abc1234"' target.sh
}

@test "stamp warns when a glob pattern matches nothing" {
  fixture_repo
  run env FILES="nope-*.sh" VERSION=2026.08.19@abc1234 bash "$STAMP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pattern matched no files"* ]]
  [[ "$output" == *"1 warning(s)"* ]]
}

@test "stamp skips files matching EXCLUDE" {
  fixture_repo
  run env FILES="*.sh" EXCLUDE=target.sh VERSION=2026.08.19@abc1234 bash "$STAMP"
  [ "$status" -eq 0 ]
  ! grep -q '^VERSION=' target.sh
}

@test "stamp stamps a file matched by several patterns only once" {
  fixture_repo
  run env FILES="*.sh target.sh" VERSION=2026.08.19@abc1234 bash "$STAMP"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^VERSION=' target.sh)" -eq 1 ]
}

@test "stamp prints the modified files to stdout, one per line" {
  fixture_repo
  printf '#!/bin/zsh\necho a\n' > a.sh
  run env FILES="*.sh" VERSION=2026.08.19@abc1234 bash -c '"$0" 2>/dev/null' "$STAMP"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'a.sh\ntarget.sh')" ]
}

@test "stamp prints nothing to stdout when nothing changed" {
  fixture_repo
  echo 'VERSION="2026.08.19@abc1234"' >> target.sh
  run env FILES=target.sh VERSION=2026.08.19@abc1234 bash -c '"$0" 2>/dev/null' "$STAMP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "stamp --dry-run prints nothing to stdout" {
  fixture_repo
  run env FILES=target.sh VERSION=2026.08.19@abc1234 bash -c '"$0" --dry-run 2>/dev/null' "$STAMP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- commit-if-changed.sh -------------------------------------------------

@test "commit-if-changed prints nothing to commit when FILES is empty" {
  fixture_repo
  run env FILES= bash "$COMMIT_IF_CHANGED"
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to commit"* ]]
  [ "$(git rev-list --count HEAD)" -eq 1 ]
}

@test "commit-if-changed commits as the bot with a skip-ci message and pushes" {
  fixture_repo_with_remote
  echo 'VERSION="2026.08.19@abc1234"' >> target.sh
  run env FILES=target.sh VERSION=2026.08.19@abc1234 bash "$COMMIT_IF_CHANGED"
  [ "$status" -eq 0 ]
  [ "$(git log -1 --format=%an)" = "github-actions[bot]" ]
  [ "$(git log -1 --format=%ae)" = "github-actions[bot]@users.noreply.github.com" ]
  [[ "$(git log -1 --format=%s)" == "chore: stamp versions with 2026.08.19@abc1234 [skip ci]" ]]
  [ "$(git -C "$BATS_TEST_TMPDIR/remote.git" rev-parse HEAD)" = "$(git rev-parse HEAD)" ]
}

@test "commit-if-changed derives the version for the commit message" {
  fixture_repo_with_remote
  echo 'VERSION="2026.08.19@abc1234"' >> target.sh
  run env FILES=target.sh bash "$COMMIT_IF_CHANGED"
  [ "$status" -eq 0 ]
  [[ "$(git log -1 --format=%s)" =~ ^chore:\ stamp\ versions\ with\ 2026\.08\.19@[0-9a-f]{7,40}\ \[skip\ ci\]$ ]]
  [ "$(git -C "$BATS_TEST_TMPDIR/remote.git" rev-parse HEAD)" = "$(git rev-parse HEAD)" ]
}

@test "commit-if-changed commits the newline-separated list from stamp.sh" {
  fixture_repo_with_remote
  echo 'VERSION="2026.08.19@abc1234"' >> target.sh
  printf '#!/bin/zsh\necho other\n' > other.sh
  git add other.sh
  git commit -q -m "add other"
  echo 'VERSION="2026.08.19@abc1234"' >> other.sh
  run env FILES=$'target.sh\nother.sh' VERSION=2026.08.19@abc1234 bash "$COMMIT_IF_CHANGED"
  [ "$status" -eq 0 ]
  local committed; committed="$(git show --name-only --format= HEAD)"
  [[ "$committed" == *"target.sh"* ]]
  [[ "$committed" == *"other.sh"* ]]
}
