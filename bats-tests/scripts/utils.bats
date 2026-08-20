#!/usr/bin/env bats

load test_helper

setup() {
  setup_common
  register_stub git
}

# --- report ---------------------------------------------------------------

@test "report prints an INFO line" {
  run zsh -c "source '$SCRIPT_DIR/utils.sh'; report info hello"
  [ "$status" -eq 0 ]
  [[ "$output" == *"INFO"* && "$output" == *"hello"* ]]
}

@test "report prints a SUCCESS line" {
  run zsh -c "source '$SCRIPT_DIR/utils.sh'; report success hello"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SUCCESS"* && "$output" == *"hello"* ]]
}

@test "report prints a WARNING line" {
  run zsh -c "source '$SCRIPT_DIR/utils.sh'; report warning hello"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING"* && "$output" == *"hello"* ]]
}

@test "report prints an ERROR line" {
  run zsh -c "source '$SCRIPT_DIR/utils.sh'; report error hello"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ERROR"* && "$output" == *"hello"* ]]
}

@test "report passes unknown levels through untouched" {
  run zsh -c "source '$SCRIPT_DIR/utils.sh'; report bogus hello"
  [ "$status" -eq 0 ]
  [[ "$output" == "hello" ]]
}

# --- press_enter ----------------------------------------------------------

@test "press_enter waits for input and continues" {
  run zsh -c "source '$SCRIPT_DIR/utils.sh'; press_enter 'Hit enter'; echo after" <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hit enter"* && "$output" == *"after"* ]]
}

# --- ensure_fresh ---------------------------------------------------------

@test "ensure_fresh skips silently outside a git repo" {
  run zsh -c "source '$SCRIPT_DIR/utils.sh'; ensure_fresh scripts/setup-osx.sh setup-osx.sh; echo done"
  [ "$status" -eq 0 ]
  [[ "$output" == *"done"* ]]
  [[ "$output" != *"is up-to-date."* ]]
}

@test "ensure_fresh skips when the repo does not track the script" {
  # A utils.sh sourced from outside the real checkout resolves repo_root
  # to a directory without scripts/setup-osx.sh (the piped-run case);
  # the check must stop there instead of fetching an unrelated remote.
  mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
  cp "$SCRIPT_DIR/utils.sh" "$BATS_TEST_TMPDIR/elsewhere/"
  export GIT_STUB_INSIDE_WORK_TREE=1
  run zsh -c "source '$BATS_TEST_TMPDIR/elsewhere/utils.sh'; ensure_fresh scripts/setup-osx.sh setup-osx.sh; echo done"
  [ "$status" -eq 0 ]
  [[ "$output" == *"done"* ]]
  [[ "$output" != *"setup-osx.sh is up-to-date."* ]]
  [[ "$output" != *"has updates on the remote"* ]]
}

@test "ensure_fresh warns and continues when the fetch fails" {
  export GIT_STUB_INSIDE_WORK_TREE=1 GIT_STUB_FETCH_FAIL=1
  run zsh -c "source '$SCRIPT_DIR/utils.sh'; ensure_fresh scripts/setup-osx.sh setup-osx.sh; echo done"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Could not reach the remote"* ]]
  [[ "$output" == *"done"* ]]
}

@test "ensure_fresh confirms an up-to-date script" {
  export GIT_STUB_INSIDE_WORK_TREE=1
  run zsh -c "source '$SCRIPT_DIR/utils.sh'; ensure_fresh scripts/setup-osx.sh setup-osx.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"is up-to-date"* ]]
}

@test "ensure_fresh continues when the user declines to abort" {
  export GIT_STUB_INSIDE_WORK_TREE=1 GIT_STUB_DIFF_DIRTY=1
  run zsh -c "source '$SCRIPT_DIR/utils.sh'; ensure_fresh scripts/setup-osx.sh setup-osx.sh; echo done" <<< "continue"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Continuing with the current copy"* ]]
  [[ "$output" == *"done"* ]]
}

@test "ensure_fresh aborts when the user asks to" {
  export GIT_STUB_INSIDE_WORK_TREE=1 GIT_STUB_DIFF_DIRTY=1
  run zsh -c "source '$SCRIPT_DIR/utils.sh'; ensure_fresh scripts/setup-osx.sh setup-osx.sh" <<< "abort"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Aborting"* ]]
}

# --- start_run_log --------------------------------------------------------

@test "start_run_log tees output to a timestamped log with colors stripped" {
  run zsh -c "source '$SCRIPT_DIR/utils.sh'; start_run_log setup-osx; report success colored; echo plain"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Run log:"* ]]

  local logfile
  logfile="$(find . -maxdepth 1 -name 'setup-osx-*.log' | head -1)"
  [ -n "$logfile" ]
  [[ "$logfile" =~ setup-osx-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}\.log ]]

  # The tee/sed writers can still be flushing after zsh exits; wait for
  # the last line before asserting the contents.
  local waited=0
  while ! grep -q "plain" "$logfile" && (( waited < 50 )); do
    sleep 0.1
    waited=$((waited + 1))
  done

  grep -q "SUCCESS colored" "$logfile"
  grep -q "plain" "$logfile"
  [ "$(grep -c $'\x1b' "$logfile" || true)" -eq 0 ]
}

# --- summary --------------------------------------------------------------

@test "print_run_summary shows all three sections" {
  run zsh -c "source '$SCRIPT_DIR/utils.sh'; note_added alpha; note_present beta; note_followup gamma; print_run_summary"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installed:"* && "$output" == *"alpha"* ]]
  [[ "$output" == *"Already present:"* && "$output" == *"beta"* ]]
  [[ "$output" == *"Follow-ups:"* && "$output" == *"gamma"* ]]
  [[ "$output" != *"Run log:"* ]]
}

@test "print_run_summary omits empty sections and prints the log path" {
  run zsh -c "source '$SCRIPT_DIR/utils.sh'; start_run_log demo; print_run_summary"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Installed:"* ]]
  [[ "$output" != *"Already present:"* ]]
  [[ "$output" != *"Follow-ups:"* ]]
  [[ "$output" == *"Run log:"* ]]
}
