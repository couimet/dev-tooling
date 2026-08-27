#!/usr/bin/env bats

load test_helper

setup() {
  setup_common
  # Keep code/cursor and other Homebrew/local tools out of the sandbox:
  # this machine has real code and cursor on PATH, which would otherwise
  # make install_ide_extensions reach out to the real installs. Tests
  # opt an IDE in explicitly by creating a stub in TEST_BIN.
  export PATH="$TEST_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
  copy_scripts
  OSX="$TEST_SCRIPTS/setup-osx.sh"
}

# Everything already in place so the run walks the "present" paths.
baseline_env() {
  git config --global user.name "Test User"
  git config --global user.email "test@example.com"
  make_ssh_key
  export SSH_ADD_HAS_ED25519=1 BREW_HAS_GIT=1
  # Where the script looks for brew after a fresh install; the stub bin
  # makes the shellenv pickup deterministic in every environment.
  export BREW_BIN_DIR="$TEST_BIN"
  mkdir -p "$HOME/.nvm"
  cat > "$HOME/.nvm/nvm.sh" <<'EOF'
nvm() { echo "nvm $*"; }
EOF
  touch "$HOME/.nvm/bash_completion"
}

APPS_DISPLAY=("iTerm2" "VS Code" "Cursor" "Postman" "Rectangle" "Google Chrome" "Slack" "Discord" "Telegram" "Signal" "WhatsApp" "MacPass" "1Password")
APPS_PATHS=("iTerm" "Visual Studio Code" "Cursor" "Postman" "Rectangle" "Google Chrome" "Slack" "Discord" "Telegram" "Signal" "WhatsApp" "MacPass" "1Password")

# The shared IDE extension list, mirrored from scripts/setup-osx.sh.
IDE_EXTENSIONS=(
  esbenp.prettier-vscode
  dbaeumer.vscode-eslint
  eamodio.gitlens
  pflannery.vscode-versionlens
  bierner.markdown-mermaid
  couimet.rangelink-vscode-extension
)

# --- CLI ------------------------------------------------------------------

@test "--help prints usage and exits 0" {
  run zsh "$OSX" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: setup-osx.sh"* ]]
}

@test "unknown option exits 1" {
  run zsh "$OSX" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "--ide without a value exits 1" {
  run zsh "$OSX" --ide
  [ "$status" -eq 1 ]
  [[ "$output" == *"--ide requires a choice"* ]]
}

@test "--ide with an invalid value exits 1" {
  run zsh "$OSX" --ide bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown --ide choice"* ]]
}

@test "--password-manager without a value exits 1" {
  run zsh "$OSX" --password-manager
  [ "$status" -eq 1 ]
  [[ "$output" == *"--password-manager requires a choice"* ]]
}

@test "--password-manager with an invalid value exits 1" {
  run zsh "$OSX" --password-manager bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown --password-manager choice"* ]]
}

@test "--ide vscode --password-manager macpass only checks those tools" {
  baseline_env
  run zsh "$OSX" --ide vscode --password-manager macpass
  [ "$status" -eq 0 ]
  [[ "$output" == *"Checking if VS Code is installed"* ]]
  [[ "$output" == *"Checking if MacPass is installed"* ]]
  [[ "$output" != *"Checking if Cursor is installed"* ]]
  [[ "$output" != *"Checking if 1Password is installed"* ]]
}

@test "--ide cursor --password-manager 1password only checks those tools" {
  baseline_env
  run zsh "$OSX" --ide cursor --password-manager 1password
  [ "$status" -eq 0 ]
  [[ "$output" == *"Checking if Cursor is installed"* ]]
  [[ "$output" == *"Checking if 1Password is installed"* ]]
  [[ "$output" != *"Checking if VS Code is installed"* ]]
  [[ "$output" != *"Checking if MacPass is installed"* ]]
}

@test "--ide both --password-manager both checks all four" {
  baseline_env
  run zsh "$OSX" --ide both --password-manager both
  [ "$status" -eq 0 ]
  [[ "$output" == *"Checking if VS Code is installed"* ]]
  [[ "$output" == *"Checking if Cursor is installed"* ]]
  [[ "$output" == *"Checking if MacPass is installed"* ]]
  [[ "$output" == *"Checking if 1Password is installed"* ]]
}

@test "--ide skip --password-manager skip checks none of them" {
  baseline_env
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" != *"Checking if VS Code is installed"* ]]
  [[ "$output" != *"Checking if Cursor is installed"* ]]
  [[ "$output" != *"Checking if MacPass is installed"* ]]
  [[ "$output" != *"Checking if 1Password is installed"* ]]
}

@test "interactive prompts accept skip answers" {
  baseline_env
  run zsh "$OSX" <<< $'4\n4\n'
  [ "$status" -eq 0 ]
  [[ "$output" == *"IDE Selection"* ]]
  [[ "$output" == *"Password Manager Selection"* ]]
  [[ "$output" != *"Checking if VS Code is installed"* ]]
}

@test "interactive prompt falls back to VS Code on invalid input" {
  baseline_env
  run zsh "$OSX" <<< $'9\n4\n'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Invalid choice. Installing VS Code by default"* ]]
  [[ "$output" == *"Checking if VS Code is installed"* ]]
}

@test "interactive option 1 selects VS Code and MacPass" {
  baseline_env
  run zsh "$OSX" <<< $'1\n1\n'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Checking if VS Code is installed"* ]]
  [[ "$output" == *"Checking if MacPass is installed"* ]]
  [[ "$output" != *"Checking if Cursor is installed"* ]]
  [[ "$output" != *"Checking if 1Password is installed"* ]]
}

@test "interactive option 2 selects Cursor and 1Password" {
  baseline_env
  run zsh "$OSX" <<< $'2\n2\n'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Checking if Cursor is installed"* ]]
  [[ "$output" == *"Checking if 1Password is installed"* ]]
  [[ "$output" != *"Checking if VS Code is installed"* ]]
  [[ "$output" != *"Checking if MacPass is installed"* ]]
}

@test "interactive option 3 selects both tools" {
  baseline_env
  run zsh "$OSX" <<< $'3\n3\n'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Checking if VS Code is installed"* ]]
  [[ "$output" == *"Checking if Cursor is installed"* ]]
  [[ "$output" == *"Checking if MacPass is installed"* ]]
  [[ "$output" == *"Checking if 1Password is installed"* ]]
}

# --- companion scripts (curl-pipe mode) -----------------------------------

@test "downloads companion scripts when running standalone" {
  baseline_env
  mkdir -p "$BATS_TEST_TMPDIR/standalone" "$BATS_TEST_TMPDIR/tmp"
  cp "$TEST_SCRIPTS/setup-osx.sh" "$BATS_TEST_TMPDIR/standalone/"
  run env TMPDIR="$BATS_TEST_TMPDIR/tmp" zsh "$BATS_TEST_TMPDIR/standalone/setup-osx.sh" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"Done!"* ]]
  [ -f "$BATS_TEST_TMPDIR/tmp/dev-tooling-scripts/utils.sh" ]
  [ -f "$BATS_TEST_TMPDIR/tmp/dev-tooling-scripts/setup-github-ssh.sh" ]
}

@test "aborts when the companion scripts cannot be downloaded" {
  baseline_env
  mkdir -p "$BATS_TEST_TMPDIR/standalone" "$BATS_TEST_TMPDIR/tmp"
  cp "$TEST_SCRIPTS/setup-osx.sh" "$BATS_TEST_TMPDIR/standalone/"
  export CURL_SERVE_COMPANIONS=0
  run env TMPDIR="$BATS_TEST_TMPDIR/tmp" zsh "$BATS_TEST_TMPDIR/standalone/setup-osx.sh" --ide skip --password-manager skip
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not download the shared helpers"* ]]
}

@test "aborts without reusing a stale cached helper when the refresh fails" {
  baseline_env
  mkdir -p "$BATS_TEST_TMPDIR/standalone" "$BATS_TEST_TMPDIR/tmp/dev-tooling-scripts"
  cp "$TEST_SCRIPTS/setup-osx.sh" "$BATS_TEST_TMPDIR/standalone/"
  cat > "$BATS_TEST_TMPDIR/tmp/dev-tooling-scripts/utils.sh" <<EOF
touch "$BATS_TEST_TMPDIR/marker"
EOF
  export CURL_SERVE_COMPANIONS=0
  run env TMPDIR="$BATS_TEST_TMPDIR/tmp" zsh "$BATS_TEST_TMPDIR/standalone/setup-osx.sh" --ide skip --password-manager skip
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not download the shared helpers"* ]]
  [ ! -f "$BATS_TEST_TMPDIR/marker" ]
}

@test "piped stdin run does not source a local utils.sh" {
  baseline_env
  # A decoy utils.sh in the invocation directory must not be picked up
  # when the script is read from stdin: SCRIPT_DIR stays empty and the
  # helpers are fetched into $TMPDIR instead.
  local decoy="$BATS_TEST_TMPDIR/decoy"
  mkdir -p "$decoy" "$BATS_TEST_TMPDIR/tmp"
  cat > "$decoy/utils.sh" <<EOF
touch "$decoy/marker"
EOF
  cd "$decoy"
  # -s reads the script from stdin; "--" keeps the flags from being
  # parsed as zsh options.
  run env TMPDIR="$BATS_TEST_TMPDIR/tmp" zsh -s -- --ide skip --password-manager skip < "$OSX"
  [ "$status" -eq 0 ]
  [ ! -f "$decoy/marker" ]
}

@test "standalone run executes the downloaded SSH setup" {
  git config --global user.name "Test User"
  git config --global user.email "test@example.com"
  export BREW_HAS_GIT=1
  mkdir -p "$HOME/.nvm"
  cat > "$HOME/.nvm/nvm.sh" <<'EOF'
nvm() { echo "nvm $*"; }
EOF
  mkdir -p "$BATS_TEST_TMPDIR/standalone" "$BATS_TEST_TMPDIR/tmp"
  cp "$TEST_SCRIPTS/setup-osx.sh" "$BATS_TEST_TMPDIR/standalone/"
  run env TMPDIR="$BATS_TEST_TMPDIR/tmp" zsh "$BATS_TEST_TMPDIR/standalone/setup-osx.sh" --ide skip --password-manager skip <<< ""
  [ "$status" -eq 0 ]
  [ -f "$HOME/.ssh/id_ed25519" ]
  [[ "$output" == *"GitHub security"* ]]
  grep -q "Host github.com" "$HOME/.ssh/config"
  grep -qF "$(cat "$HOME/.ssh/id_ed25519.pub")" "$HOME/.config/git/allowed_signers"
}

# --- Homebrew -------------------------------------------------------------

@test "Homebrew is reported as present with its version" {
  baseline_env
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"Homebrew (Homebrew 4.5.0)"* ]]
}

@test "installs Homebrew when missing" {
  baseline_env
  export FORCE_COMMAND_MISSING="brew"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [ -f "$HOME/.homebrew-installed" ]
  local clean; clean="$(plain "$output")"
  [[ "$clean" == *"✔ Homebrew"* ]]
}

@test "reports when Homebrew is installed but its shellenv cannot be initialized" {
  baseline_env
  # Point the test hook at a bin with no brew in it, so the fallback
  # prefixes are never probed and the failure path is exercised even on
  # machines with a real Homebrew install.
  mkdir -p "$BATS_TEST_TMPDIR/empty-bin"
  export BREW_BIN_DIR="$BATS_TEST_TMPDIR/empty-bin" FORCE_COMMAND_MISSING="brew"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [ -f "$HOME/.homebrew-installed" ]
  [[ "$output" == *"shell environment could not be initialized"* ]]
  local clean; clean="$(plain "$output")"
  [[ "$clean" != *"✔ Homebrew"* ]]
}

# --- Git ------------------------------------------------------------------

@test "Git installed via brew is reported present with its version and a shadow warning" {
  baseline_env
  # Resolve git strictly to the system binary so the shadow follow-up
  # triggers deterministically, even on machines with Homebrew's git
  # earlier in the PATH.
  export PATH="$TEST_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"Git 2.55.0 (Homebrew)"* ]]
  [[ "$output" == *"shadowed by /usr/bin/git"* ]]
}

@test "installs the Homebrew Git when only the system Git exists" {
  baseline_env
  unset BREW_HAS_GIT
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"System Git detected"* ]]
  local clean; clean="$(plain "$output")"
  [[ "$clean" == *"✔ Git"* ]]
}

@test "installs Git when no git command is found" {
  baseline_env
  export FORCE_COMMAND_MISSING="git"
  unset BREW_HAS_GIT
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  local clean; clean="$(plain "$output")"
  [[ "$clean" == *"✔ Git"* ]]
}

@test "reports a follow-up when brew install git fails" {
  baseline_env
  export FORCE_COMMAND_MISSING="git" BREW_INSTALL_FAIL=1
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"brew install git failed."* ]]
  [[ "$output" == *"Install it manually: brew install git"* ]]
  local clean; clean="$(plain "$output")"
  [[ "$clean" != *"✔ Git"* ]]
}

@test "no shadow warning when git resolves outside /usr/bin" {
  baseline_env
  register_stub git
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"Git 2.55.0 (Homebrew)"* ]]
  [[ "$output" != *"shadowed by /usr/bin/git"* ]]
}

# --- Git identity ---------------------------------------------------------

@test "exits when the git identity is missing" {
  baseline_env
  rm -f "$HOME/.gitconfig"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 1 ]
  [[ "$output" == *"Git configuration is incomplete"* ]]
}

@test "exits when only the git email is missing" {
  baseline_env
  git config --global user.name "Test User"
  git config --global --unset user.email
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 1 ]
  [[ "$output" == *"Git configuration is incomplete"* ]]
}

# --- SSH key handling -----------------------------------------------------

@test "generates a key, waits for GitHub, and runs the SSH setup" {
  git config --global user.name "Test User"
  git config --global user.email "test@example.com"
  export BREW_HAS_GIT=1
  mkdir -p "$HOME/.nvm"
  cat > "$HOME/.nvm/nvm.sh" <<'EOF'
nvm() { echo "nvm $*"; }
EOF
  run zsh "$OSX" --ide skip --password-manager skip <<< ""
  [ "$status" -eq 0 ]
  [ -f "$HOME/.ssh/id_ed25519" ]
  [[ "$output" == *"copied to the clipboard"* ]]
  [[ "$output" == *"GitHub security"* ]]
  grep -q "pbcopy" "$STUB_CALLS"
  grep -q "Host github.com" "$HOME/.ssh/config"
  grep -qF "$(cat "$HOME/.ssh/id_ed25519.pub")" "$HOME/.config/git/allowed_signers"
  local clean; clean="$(plain "$output")"
  [[ "$clean" == *"✔ GitHub SSH key"* ]]
}

@test "missing setup-github-ssh.sh is reported and skipped, not fatal" {
  git config --global user.name "Test User"
  git config --global user.email "test@example.com"
  export BREW_HAS_GIT=1
  mkdir -p "$HOME/.nvm"
  cat > "$HOME/.nvm/nvm.sh" <<'EOF'
nvm() { echo "nvm $*"; }
EOF
  rm "$TEST_SCRIPTS/setup-github-ssh.sh"
  run zsh "$OSX" --ide skip --password-manager skip <<< ""
  [ "$status" -eq 0 ]
  [ -f "$HOME/.ssh/id_ed25519" ]
  [[ "$output" == *"setup-github-ssh.sh not found"* ]]
  [[ "$output" == *"Run scripts/setup-github-ssh.sh --key="* ]]
  [[ "$output" != *"GitHub security"* ]]
  local clean; clean="$(plain "$output")"
  [[ "$clean" == *"✔ GitHub SSH key (id_ed25519)"* ]]
  [[ "$clean" != *"and SSH configuration"* ]]
}

@test "existing key with a loaded agent shows the standalone command hint" {
  baseline_env
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"SSH key already exists"* ]]
  [[ "$output" != *"GitHub security"* ]]
  [[ "$output" == *"setup-github-ssh.sh --key="* ]]
  [[ "$output" == *"GitHub SSH key (id_ed25519)"* ]]
}

@test "existing key not in the agent gets loaded again" {
  baseline_env
  unset SSH_ADD_HAS_ED25519
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  grep -q "ssh-add $HOME/.ssh/id_ed25519" "$STUB_CALLS"
}

@test "existing key already in the agent is not added again" {
  baseline_env
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  ! grep -q "ssh-add $HOME/.ssh/id_ed25519" "$STUB_CALLS"
}

# --- nvm and Node ---------------------------------------------------------

@test "nvm is reported present with its version" {
  baseline_env
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvm is installed"* ]]
}

@test "installs the latest nvm when missing" {
  baseline_env
  rm -rf "$HOME/.nvm"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing nvm v0.40.3"* ]]
  local clean; clean="$(plain "$output")"
  [[ "$clean" == *"✔ nvm v0.40.3"* ]]
  [ -f "$HOME/.nvm/nvm.sh" ]
}

@test "skips the nvm install when the latest release tag cannot be resolved" {
  baseline_env
  rm -rf "$HOME/.nvm"
  export CURL_NVM_LATEST_FAIL=1
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"Could not resolve the latest nvm release tag"* ]]
  [[ "$output" == *"https://github.com/nvm-sh/nvm#installing-and-updating"* ]]
  [[ "$output" != *"nvm v"* ]]
  [[ "$output" != *"has been installed"* ]]
}

@test "skips the nvm install when the installer download fails" {
  baseline_env
  rm -rf "$HOME/.nvm"
  export CURL_NVM_INSTALL_FAIL=1
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"Could not download the nvm installer"* ]]
  [[ "$output" == *"https://github.com/nvm-sh/nvm#installing-and-updating"* ]]
  [[ "$output" != *"has been installed"* ]]
  [ ! -f "$HOME/.nvm/nvm.sh" ]
}

@test "Node.js on the pinned major is reported present" {
  baseline_env
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"Node.js v24.1.0"* ]]
}

@test "Node.js on another major triggers nvm install" {
  baseline_env
  export NODE_VERSION_OUTPUT="v22.0.0"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvm install 24"* ]]
  [[ "$output" == *"via nvm"* ]]
}

@test "Node.js on a different major with a matching substring is reinstalled" {
  baseline_env
  # v22.24.1 contains "24" as a substring, so a naive grep-based major
  # check would wrongly treat it as the pinned major 24.
  export NODE_VERSION_OUTPUT="v22.24.1"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvm install 24"* ]]
  [[ "$output" == *"via nvm"* ]]
}

@test "missing Node.js triggers nvm install" {
  baseline_env
  export FORCE_COMMAND_MISSING="node"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvm install 24"* ]]
  [[ "$output" == *"via nvm"* ]]
}

@test "reports when nvm cannot install or activate Node.js" {
  baseline_env
  export FORCE_COMMAND_MISSING="node"
  # The script sources the nvm function from nvm.sh, so make every
  # install/use/alias call fail after the command -v nvm gate.
  cat > "$HOME/.nvm/nvm.sh" <<'EOF'
nvm() { echo "nvm failed" && return 1; }
EOF
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"could not install or activate"* ]]
  [[ "$output" != *"via nvm"* ]]
}

@test "reports when nvm is not available before the Node.js install" {
  baseline_env
  # With the nvm release lookup failing, the install branch never
  # sources a nvm function, so the Node.js block hits the missing-nvm
  # error instead of running install/use/alias.
  rm -rf "$HOME/.nvm"
  export FORCE_COMMAND_MISSING="node" CURL_NVM_LATEST_FAIL=1
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvm is not available in this shell"* ]]
  [[ "$output" == *"Install nvm first: https://github.com/nvm-sh/nvm#installing-and-updating"* ]]
  [[ "$output" != *"via nvm"* ]]
}

@test "adds the nvm loader to ~/.zshrc when it is missing" {
  baseline_env
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [ -f "$HOME/.zshrc" ]
  grep -qF 'export NVM_DIR="$HOME/.nvm"' "$HOME/.zshrc"
  grep -qF '[ -s "$NVM_DIR/nvm.sh" ]' "$HOME/.zshrc"
  grep -qF '[ -s "$NVM_DIR/bash_completion" ]' "$HOME/.zshrc"
  [[ "$output" == *"Added the nvm loader to ~/.zshrc"* ]]
  [[ "$output" == *"nvm shell profile"* ]]
  ! grep -qF '/opt/homebrew/opt/nvm' "$HOME/.zshrc"
}

@test "reports an error instead of success when the nvm loader cannot be appended" {
  baseline_env
  # A directory in place of ~/.zshrc makes the append fail, exercising
  # the profile-write failure path without needing to stub cat.
  mkdir -p "$HOME/.zshrc"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"Failed to write the nvm loader to ~/.zshrc"* ]]
  [[ "$output" != *"Added the nvm loader to ~/.zshrc"* ]]
  [[ "$output" == *"Add to ~/.zshrc: export NVM_DIR=\"\$HOME/.nvm\""* ]]
  [[ "$output" != *"nvm shell profile (~/.zshrc)"* ]]
}

@test "does not duplicate the nvm loader when ~/.zshrc already has it" {
  baseline_env
  cat > "$HOME/.zshrc" <<'EOF'
# nvm (added by the dev-tooling setup script)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [ "$(grep -c 'export NVM_DIR' "$HOME/.zshrc")" -eq 1 ]
  [[ "$output" == *"already configured"* ]]
}

@test "repairs the loader when ~/.zshrc has only the NVM_DIR export" {
  baseline_env
  printf 'export NVM_DIR="$HOME/.nvm"\n' > "$HOME/.zshrc"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  grep -qF '[ -s "$NVM_DIR/nvm.sh" ]' "$HOME/.zshrc"
  grep -qF '[ -s "$NVM_DIR/bash_completion" ]' "$HOME/.zshrc"
  [[ "$output" == *"Added the nvm loader to ~/.zshrc"* ]]
}

@test "repairs the loader when ~/.zshrc has the sources but no export" {
  baseline_env
  cat > "$HOME/.zshrc" <<'EOF'
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
EOF
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  grep -qF 'export NVM_DIR="$HOME/.nvm"' "$HOME/.zshrc"
  [[ "$output" == *"Added the nvm loader to ~/.zshrc"* ]]
}

@test "configures the shell profile after a fresh nvm install" {
  baseline_env
  rm -rf "$HOME/.nvm"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [ -f "$HOME/.nvm/nvm.sh" ]
  [ -f "$HOME/.zshrc" ]
  grep -qF 'export NVM_DIR="$HOME/.nvm"' "$HOME/.zshrc"
  [[ "$output" == *"has been installed"* ]]
  [[ "$output" == *"nvm shell profile"* ]]
}

@test "skips the profile write when nvm is not installed" {
  baseline_env
  rm -rf "$HOME/.nvm"
  export CURL_NVM_LATEST_FAIL=1
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [ ! -f "$HOME/.zshrc" ]
  [[ "$output" != *"nvm shell profile"* ]]
}

@test "uses a Homebrew-installed nvm without reinstalling" {
  baseline_env
  rm -rf "$HOME/.nvm"
  export BREW_HAS_NVM=1
  export BREW_NVM_PREFIX="$BATS_TEST_TMPDIR/brew-nvm"
  mkdir -p "$BREW_NVM_PREFIX/etc/bash_completion.d"
  cat > "$BREW_NVM_PREFIX/nvm.sh" <<'EOF'
nvm() { echo "nvm $*"; }
EOF
  touch "$BREW_NVM_PREFIX/etc/bash_completion.d/nvm"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvm is installed (via Homebrew)"* ]]
  [[ "$output" != *"Installing nvm"* ]]
  [ ! -f "$HOME/.nvm/nvm.sh" ]
  grep -qF "[ -s \"$BREW_NVM_PREFIX/nvm.sh\" ]" "$HOME/.zshrc"
}

@test "does not duplicate the Homebrew loader when ~/.zshrc already has it" {
  baseline_env
  rm -rf "$HOME/.nvm"
  export BREW_HAS_NVM=1
  export BREW_NVM_PREFIX="$BATS_TEST_TMPDIR/brew-nvm"
  mkdir -p "$BREW_NVM_PREFIX/etc/bash_completion.d"
  cat > "$BREW_NVM_PREFIX/nvm.sh" <<'EOF'
nvm() { echo "nvm $*"; }
EOF
  touch "$BREW_NVM_PREFIX/etc/bash_completion.d/nvm"
  cat > "$HOME/.zshrc" <<EOF
export NVM_DIR="\$HOME/.nvm"
[ -s "$BREW_NVM_PREFIX/nvm.sh" ] && \. "$BREW_NVM_PREFIX/nvm.sh"
[ -s "$BREW_NVM_PREFIX/etc/bash_completion.d/nvm" ] && \. "$BREW_NVM_PREFIX/etc/bash_completion.d/nvm"
EOF
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [ "$(grep -c 'export NVM_DIR' "$HOME/.zshrc")" -eq 1 ]
  [[ "$output" == *"already configured"* ]]
}

@test "prefers the nvm-sh install when both layouts exist" {
  baseline_env
  export BREW_HAS_NVM=1
  export BREW_NVM_PREFIX="$BATS_TEST_TMPDIR/brew-nvm"
  mkdir -p "$BREW_NVM_PREFIX/etc/bash_completion.d"
  cat > "$BREW_NVM_PREFIX/nvm.sh" <<'EOF'
nvm() { echo "brew nvm $*"; }
EOF
  touch "$BREW_NVM_PREFIX/etc/bash_completion.d/nvm"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" != *"via Homebrew"* ]]
  [[ "$output" == *"nvm is installed"* ]]
  grep -qF '[ -s "$NVM_DIR/nvm.sh" ]' "$HOME/.zshrc"
  ! grep -qF '/opt/homebrew/opt/nvm' "$HOME/.zshrc"
}

@test "installs nvm-sh when the brew nvm is not loadable" {
  baseline_env
  rm -rf "$HOME/.nvm"
  export BREW_HAS_NVM=1
  export BREW_NVM_PREFIX="$BATS_TEST_TMPDIR/empty-brew-nvm"
  mkdir -p "$BREW_NVM_PREFIX"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing nvm v0.40.3"* ]]
  [ -f "$HOME/.nvm/nvm.sh" ]
}

# --- pnpm warning ---------------------------------------------------------

@test "warns when pnpm is installed through brew" {
  baseline_env
  export BREW_HAS_PNPM=1
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"pnpm is installed through Homebrew"* ]]
}

@test "stays silent when pnpm is not installed through brew" {
  baseline_env
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" != *"pnpm is installed through Homebrew"* ]]
}

# --- Applications ---------------------------------------------------------

@test "every already installed app is reported with its version" {
  baseline_env
  for app in "${APPS_PATHS[@]}"; do
    make_app "$app" 1.2.3
  done
  run zsh "$OSX" --ide both --password-manager both
  [ "$status" -eq 0 ]
  for name in "${APPS_DISPLAY[@]}"; do
    [[ "$output" == *"$name 1.2.3"* ]]
  done
}

@test "every missing app is installed" {
  baseline_env
  run zsh "$OSX" --ide both --password-manager both
  [ "$status" -eq 0 ]
  local clean; clean="$(plain "$output")"
  for name in "${APPS_DISPLAY[@]}"; do
    [[ "$clean" == *"✔ $name 1.2.3"* ]]
  done
}

@test "an app without an Info.plist reports an unknown version" {
  baseline_env
  mkdir -p "$APPS_DIR/iTerm.app"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"iTerm2 is installed"* ]]
  [[ "$output" == *"→ version: unknown"* ]]
}

@test "reports a follow-up when an app install fails" {
  baseline_env
  export BREW_INSTALL_FAIL=1
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"brew install --cask iterm2 failed."* ]]
  local clean; clean="$(plain "$output")"
  [[ "$clean" != *"✔ iTerm2"* ]]
}

# --- CLIs -----------------------------------------------------------------

@test "Docker CLI present and Docker app present" {
  baseline_env
  make_app "Docker" 4.30.0
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"Docker Docker version 27.0.3"* ]]
}

@test "Docker missing triggers the cask install" {
  baseline_env
  export FORCE_COMMAND_MISSING="docker"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  local clean; clean="$(plain "$output")"
  [[ "$clean" == *"✔ Docker 1.2.3"* ]]
}

@test "CLI tools are reported present with versions" {
  baseline_env
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"docker-compose Docker Compose version v2.29.1"* ]]
  [[ "$output" == *"AWS CLI aws-cli/2.17.30"* ]]
  [[ "$output" == *"jq jq-1.7.1"* ]]
  [[ "$output" == *"GitHub CLI (gh) gh version 2.55.0"* ]]
  [[ "$output" == *"Claude Code 2.1.211 (Claude Code)"* ]]
  [[ "$output" == *"1Password CLI 2.39.0"* ]]
  [[ "$output" == *"bats Bats 1.14.0"* ]]
  # Kubernetes clients: the first three answer a version subcommand, so
  # these lines also prove the probes reach their tools.
  [[ "$output" == *"kubectl Client Version: v1.36.4"* ]]
  [[ "$output" == *"helm v4.2.4+g1a5686c"* ]]
  [[ "$output" == *"kustomize v5.8.1"* ]]
  [[ "$output" == *"argocd argocd: v3.5.1+c6b4b7d"* ]]
  [[ "$output" == *"velero Version: v1.18.2"* ]]
  # Data wrangling and scanning
  [[ "$output" == *"yq yq (https://github.com/mikefarah/yq/) version v4.53.6"* ]]
  [[ "$output" == *"pre-commit pre-commit 4.6.2"* ]]
  [[ "$output" == *"trivy Version: 0.74.0"* ]]
  # Terraform tooling
  [[ "$output" == *"terraform Terraform v1.14.2"* ]]
  [[ "$output" == *"tflint TFLint version 0.59.0"* ]]
  [[ "$output" == *"terraform-docs terraform-docs version v0.24.0"* ]]
}

@test "missing CLIs are installed and gh gets the auth follow-up" {
  baseline_env
  export FORCE_COMMAND_MISSING="docker-compose aws jq gh claude op bats kubectl helm kustomize argocd velero yq pre-commit trivy terraform tflint terraform-docs"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  local clean; clean="$(plain "$output")"
  [[ "$clean" == *"✔ docker-compose"* ]]
  [[ "$clean" == *"✔ AWS CLI"* ]]
  [[ "$clean" == *"✔ jq"* ]]
  [[ "$clean" == *"✔ GitHub CLI (gh)"* ]]
  [[ "$clean" == *"✔ Claude Code"* ]]
  [[ "$clean" == *"✔ 1Password CLI"* ]]
  [[ "$output" == *"Run 'gh auth login'"* ]]
  # The versions come from the post-install probe, so the same lines
  # cover the probe on the install path.
  [[ "$clean" == *"✔ kubectl Client Version: v1.36.4"* ]]
  [[ "$clean" == *"✔ helm v4.2.4+g1a5686c"* ]]
  [[ "$clean" == *"✔ kustomize v5.8.1"* ]]
  [[ "$clean" == *"✔ argocd argocd: v3.5.1+c6b4b7d"* ]]
  [[ "$clean" == *"✔ velero Version: v1.18.2"* ]]
  [[ "$clean" == *"✔ yq yq ("* ]]
  [[ "$clean" == *"✔ pre-commit pre-commit 4.6.2"* ]]
  [[ "$clean" == *"✔ trivy Version: 0.74.0"* ]]
  [[ "$clean" == *"✔ terraform Terraform v1.14.2"* ]]
  [[ "$clean" == *"✔ tflint TFLint version 0.59.0"* ]]
  [[ "$clean" == *"✔ terraform-docs terraform-docs version v0.24.0"* ]]
  [[ "$clean" == *"✔ bats Bats 1.14.0"* ]]
  # kubectl and bats have formula names that differ from their commands.
  grep -qF "brew install kubernetes-cli" "$STUB_CALLS"
  grep -qF "brew install bats-core" "$STUB_CALLS"
  # the 1Password CLI ships as a cask, so this also pins that the call
  # took the --cask path instead of asking brew for an "op" formula.
  grep -qF "brew install --cask 1password-cli" "$STUB_CALLS"
}

@test "reports a follow-up when the claude-code cask install fails" {
  baseline_env
  export FORCE_COMMAND_MISSING="claude" BREW_INSTALL_FAIL=1
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"brew install --cask claude-code failed."* ]]
  [[ "$output" == *"Install it manually: brew install --cask claude-code"* ]]
  local clean; clean="$(plain "$output")"
  [[ "$clean" != *"✔ Claude Code"* ]]
}

@test "--password-manager skip still installs the 1Password CLI" {
  baseline_env
  export FORCE_COMMAND_MISSING="op"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  # the CLI has to come out even when the password manager choice skips
  # every GUI app, which is the whole point of installing it outside that
  # block. Telling the two apart takes the word after "1Password": the
  # app's check line is otherwise a prefix of the CLI's.
  [[ "$output" == *"Checking if 1Password CLI is installed"* ]]
  [[ "$output" != *"Checking if 1Password is installed"* ]]
  local clean; clean="$(plain "$output")"
  [[ "$clean" == *"✔ 1Password CLI 2.39.0"* ]]
  # same trap in the brew log, where "--cask 1password-cli" contains
  # "--cask 1password", so the app install is ruled out on a whole-line
  # match rather than a substring.
  grep -qxF "brew install --cask 1password-cli" "$STUB_CALLS"
  ! grep -qxF "brew install --cask 1password" "$STUB_CALLS"
}

@test "reports a follow-up when the 1password-cli cask install fails" {
  baseline_env
  export FORCE_COMMAND_MISSING="op" BREW_INSTALL_FAIL=1
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"brew install --cask 1password-cli failed."* ]]
  [[ "$output" == *"Install it manually: brew install --cask 1password-cli"* ]]
  local clean; clean="$(plain "$output")"
  [[ "$clean" != *"✔ 1Password CLI"* ]]
}

@test "falls back to -v when --version is unsupported" {
  baseline_env
  cat > "$TEST_BIN/aws" <<'EOF'
#!/bin/bash
case "$1" in
  --version) exit 1 ;;
  *) echo "aws-cli/2.17.30" ;;
esac
EOF
  chmod +x "$TEST_BIN/aws"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"AWS CLI aws-cli/2.17.30"* ]]
}

@test "falls back to -V when --version and -v are unsupported" {
  baseline_env
  cat > "$TEST_BIN/jq" <<'EOF'
#!/bin/bash
case "$1" in
  -V) echo "jq-1.7.1" ;;
  *) exit 1 ;;
esac
EOF
  chmod +x "$TEST_BIN/jq"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"jq jq-1.7.1"* ]]
}

@test "reports an unknown version when no version flag works" {
  baseline_env
  cat > "$TEST_BIN/docker" <<'EOF'
#!/bin/bash
exit 1
EOF
  chmod +x "$TEST_BIN/docker"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"→ version: unknown"* ]]
  [[ "$output" == *"Docker unknown"* ]]
}

@test "app version falls back to unknown when the plist cannot be read" {
  baseline_env
  export DEFAULT_VERSION=FAIL FORCE_COMMAND_MISSING="docker"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  local clean; clean="$(plain "$output")"
  [[ "$clean" == *"✔ Docker unknown"* ]]
}

@test "command version falls back to unknown when the tool is silent" {
  baseline_env
  cat > "$TEST_BIN/docker-compose" <<'EOF'
#!/bin/bash
exit 1
EOF
  chmod +x "$TEST_BIN/docker-compose"
  export FORCE_COMMAND_MISSING="docker-compose"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  local clean; clean="$(plain "$output")"
  [[ "$clean" == *"✔ docker-compose unknown"* ]]
}

# --- version probes -------------------------------------------------------

@test "a version probe reports the version from its own subcommand" {
  baseline_env
  # --version answers with something else entirely, so a summary line
  # carrying the subcommand's output can only have come from the probe.
  cat > "$TEST_BIN/kubectl" <<'EOF'
#!/bin/bash
if [[ "$1" == "version" && "$2" == "--client" ]]; then
  echo "Client Version: v1.36.4"
  exit 0
fi
echo "ladder output: v0.0.0"
EOF
  chmod +x "$TEST_BIN/kubectl"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"kubectl Client Version: v1.36.4"* ]]
  [[ "$output" != *"ladder output"* ]]
}

@test "a multi-word version probe reaches the tool as separate arguments" {
  baseline_env
  # zsh does not word-split an unquoted $var, so a probe forwarded as a
  # single string would arrive as one argument and the probe would fail
  # silently. The stub records its own argv so the two cases are
  # distinguishable from the outside.
  cat > "$TEST_BIN/kubectl" <<'EOF'
#!/bin/bash
echo "kubectl argc=$# argv1=[$1] argv2=[$2]" >> "$STUB_CALLS"
echo "Client Version: v1.36.4"
EOF
  chmod +x "$TEST_BIN/kubectl"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  grep -qF "kubectl argc=2 argv1=[version] argv2=[--client]" "$STUB_CALLS"
  [ "$(grep -cF "argv1=[version --client]" "$STUB_CALLS")" -eq 0 ]
  [ "$(grep -cF "kubectl argc=1" "$STUB_CALLS")" -eq 0 ]
  [[ "$output" == *"kubectl Client Version: v1.36.4"* ]]
}

@test "a failing version probe reports an unknown version" {
  baseline_env
  # The probe fails and only --version answers; the probe replaces the
  # --version / -v / -V ladder rather than falling back to it, so the
  # version stays unknown.
  cat > "$TEST_BIN/helm" <<'EOF'
#!/bin/bash
case "$1" in
  --version) echo "v4.2.4+g1a5686c" ;;
  *) exit 1 ;;
esac
EOF
  chmod +x "$TEST_BIN/helm"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  local clean; clean="$(plain "$output")"
  [[ "$clean" == *"- helm unknown"* ]]
  [[ "$clean" != *"helm v4.2.4+g1a5686c"* ]]
}

@test "a version probe picks the version off a later output line" {
  baseline_env
  # velero leads with a "Client:" header and puts the version on the
  # next, tab-indented line, so the first line is not the version.
  cat > "$TEST_BIN/velero" <<'EOF'
#!/bin/bash
printf 'Client:\n\tVersion: v1.18.2\n\tGit commit: 1234567\n'
EOF
  chmod +x "$TEST_BIN/velero"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  local clean; clean="$(plain "$output")"
  [[ "$clean" == *"- velero Version: v1.18.2"* ]]
  [[ "$clean" != *"- velero Client:"* ]]
}

@test "the legacy positional install_cmd arguments still resolve the formula" {
  baseline_env
  export FORCE_COMMAND_MISSING="aws jq"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"Checking if AWS CLI is installed"* ]]
  grep -qF "brew install awscli" "$STUB_CALLS"
  grep -qF "brew install jq" "$STUB_CALLS"
  local clean; clean="$(plain "$output")"
  [[ "$clean" == *"✔ AWS CLI aws-cli/2.17.30"* ]]
  [[ "$clean" == *"✔ jq jq-1.7.1"* ]]
}

# add_install_cmd_call <line> — inserts an extra install_cmd call into
# the sandboxed copy of the script, above the jq check, so an argument
# pattern with no production call site can still be exercised through a
# real run.
add_install_cmd_call() {
  local src="$TEST_SCRIPTS/setup-osx.sh"
  awk -v line="$1" '$0 == "install_cmd jq" { print line } { print }' "$src" > "$src.patched"
  mv "$src.patched" "$src"
  chmod +x "$src"
}

@test "an unknown install_cmd option is reported without aborting the run" {
  baseline_env
  add_install_cmd_call 'install_cmd nosuchtool --bogus-option value'
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"install_cmd nosuchtool: unknown option: --bogus-option"* ]]
  [[ "$output" == *"Install it manually: brew install nosuchtool"* ]]
  # The typo costs one tool, not the run: the steps after it still happen.
  [[ "$output" == *"Checking if jq is installed"* ]]
  [[ "$output" == *"════ Run summary ════"* ]]
  ! grep -qF "brew install nosuchtool" "$STUB_CALLS"
}

@test "an install_cmd option with no value is reported without hanging" {
  baseline_env
  # Without the value guard this spins forever on "shift count must be
  # <= $#", so a clean exit is itself part of what is being asserted.
  add_install_cmd_call 'install_cmd nosuchtool --formula'
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"install_cmd nosuchtool: --formula requires a value."* ]]
  [[ "$output" == *"Install it manually: brew install nosuchtool"* ]]
  [[ "$output" == *"Checking if jq is installed"* ]]
  [[ "$output" == *"════ Run summary ════"* ]]
  [ "$(grep -cF "brew install nosuchtool" "$STUB_CALLS")" -eq 0 ]
}

@test "an install_cmd --cask with no value is reported without hanging" {
  baseline_env
  add_install_cmd_call 'install_cmd nosuchtool --cask'
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"install_cmd nosuchtool: --cask requires a value."* ]]
  # nothing has set a cask yet at the point the guard fires, so the hint
  # falls back to the command name.
  [[ "$output" == *"Install it manually: brew install nosuchtool"* ]]
  [[ "$output" == *"Checking if jq is installed"* ]]
  [[ "$output" == *"════ Run summary ════"* ]]
  [ "$(grep -cF "nosuchtool" "$STUB_CALLS")" -eq 0 ]
}

@test "a missing value after a --cask names the cask in the hint" {
  baseline_env
  add_install_cmd_call 'install_cmd nosuchtool --cask nosuchcask --tap'
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"install_cmd nosuchtool: --tap requires a value."* ]]
  # a cask-only call has no formula to fall back on, so a hint reading
  # "brew install nosuchtool" would send the reader after a formula that
  # does not exist.
  [[ "$output" == *"Install it manually: brew install --cask nosuchcask"* ]]
  [[ "$output" == *"Checking if jq is installed"* ]]
  [[ "$output" == *"════ Run summary ════"* ]]
}

@test "an install_cmd --version-from-app with no value is reported without hanging" {
  baseline_env
  add_install_cmd_call 'install_cmd nosuchtool --cask nosuchcask --version-from-app'
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"install_cmd nosuchtool: --version-from-app requires a value."* ]]
  [[ "$output" == *"Install it manually: brew install --cask nosuchcask"* ]]
  [[ "$output" == *"Checking if jq is installed"* ]]
  [[ "$output" == *"════ Run summary ════"* ]]
}

@test "install_cmd --formula together with --cask is reported and skipped" {
  baseline_env
  add_install_cmd_call 'install_cmd nosuchtool --formula nosuchformula --cask nosuchcask'
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"install_cmd nosuchtool: --formula and --cask are mutually exclusive."* ]]
  [[ "$output" == *"Install it manually: brew install nosuchformula"* ]]
  [[ "$output" == *"Checking if jq is installed"* ]]
  [[ "$output" == *"════ Run summary ════"* ]]
  # neither of the two packages is worth guessing at, so nothing is
  # installed for this call at all.
  [ "$(grep -cF "nosuchformula" "$STUB_CALLS")" -eq 0 ]
  [ "$(grep -cF "nosuchcask" "$STUB_CALLS")" -eq 0 ]
}

# --- taps -----------------------------------------------------------------

@test "a missing tool from a tap is tapped before it is installed" {
  baseline_env
  export FORCE_COMMAND_MISSING="terraform"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  grep -qF "brew tap hashicorp/tap" "$STUB_CALLS"
  grep -qF "brew install hashicorp/tap/terraform" "$STUB_CALLS"
  local tap_line install_line
  tap_line="$(grep -nF "brew tap hashicorp/tap" "$STUB_CALLS" | head -1 | cut -d: -f1)"
  install_line="$(grep -nF "brew install hashicorp/tap/terraform" "$STUB_CALLS" | head -1 | cut -d: -f1)"
  [ "$tap_line" -lt "$install_line" ]
  local clean; clean="$(plain "$output")"
  [[ "$clean" == *"✔ terraform Terraform v1.14.2"* ]]
}

@test "a tool that is already present is never tapped" {
  baseline_env
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  # Nothing is missing, so a re-run on a provisioned machine makes no
  # tap call at all -- not even the listing that checks for one.
  ! grep -q "brew tap" "$STUB_CALLS"
}

@test "a tap that is already there is not added again" {
  baseline_env
  export FORCE_COMMAND_MISSING="terraform" BREW_TAPS="hashicorp/tap"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  grep -qF "brew install hashicorp/tap/terraform" "$STUB_CALLS"
  [ "$(grep -cF "brew tap hashicorp/tap" "$STUB_CALLS")" -eq 0 ]
  local clean; clean="$(plain "$output")"
  [[ "$clean" == *"✔ terraform Terraform v1.14.2"* ]]
}

@test "a failing tap skips the install and leaves a follow-up" {
  baseline_env
  export FORCE_COMMAND_MISSING="terraform" BREW_TAP_FAIL=1
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"brew tap hashicorp/tap failed."* ]]
  [[ "$output" == *"Add the tap manually: brew tap hashicorp/tap"* ]]
  # A formula from a tap that is not there cannot resolve, so the
  # install is not attempted and nothing is recorded as installed.
  [ "$(grep -cF "brew install hashicorp/tap/terraform" "$STUB_CALLS")" -eq 0 ]
  local clean; clean="$(plain "$output")"
  [[ "$clean" != *"✔ terraform"* ]]
}

# --- IDE extensions ------------------------------------------------------

# make_ide_stub <cli> <installed-env> <fail-env> — a fake code/cursor CLI
# in TEST_BIN, created per-test so other tests never see an IDE present.
# --list-extensions prints one installed ID per line from the installed
# env var; --install-extension records the invocation to STUB_CALLS, and
# exits 1 when the fail env var is set (a failing install) or prints a
# success line and exits 0; any other argument prints a version string.
make_ide_stub() {
  local cli="$1" installed_env="$2" fail_env="$3"
  cat > "$TEST_BIN/$cli" <<EOF
#!/bin/bash
case "\$1" in
  --list-extensions)
    for id in \${$installed_env:-}; do
      echo "\$id"
    done
    ;;
  --install-extension)
    echo "$cli --install-extension \$2" >> "\$STUB_CALLS"
    if [[ "\$$fail_env" == "1" ]]; then
      exit 1
    fi
    echo "Installing extension \$2..."
    ;;
  *)
    echo "1.99.0"
    ;;
esac
EOF
  chmod +x "$TEST_BIN/$cli"
}

@test "skips IDE extensions when no IDE is on disk" {
  baseline_env
  run zsh "$OSX" --ide both --password-manager both
  [ "$status" -eq 0 ]
  [[ "$output" == *"No VS Code installation found; skipping its extensions."* ]]
  [[ "$output" == *"No Cursor installation found; skipping its extensions."* ]]
  ! grep -q -- "--install-extension" "$STUB_CALLS"
}

@test "installs all IDE extensions via code on PATH" {
  baseline_env
  make_ide_stub code CODE_INSTALLED_EXTENSIONS CODE_INSTALL_FAIL
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  local clean; clean="$(plain "$output")"
  for id in "${IDE_EXTENSIONS[@]}"; do
    grep -q "code --install-extension $id" "$STUB_CALLS"
    [[ "$clean" == *"✔ VS Code: $id"* ]]
  done
  [[ "$output" != *"No VS Code installation found"* ]]
  [[ "$output" == *"No Cursor installation found; skipping its extensions."* ]]
}

@test "an already installed extension is reported present and not reinstalled" {
  baseline_env
  make_ide_stub code CODE_INSTALLED_EXTENSIONS CODE_INSTALL_FAIL
  export CODE_INSTALLED_EXTENSIONS="esbenp.prettier-vscode"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [ "$(grep -c "code --install-extension esbenp.prettier-vscode" "$STUB_CALLS")" -eq 0 ]
  local clean; clean="$(plain "$output")"
  [[ "$clean" == *"- VS Code: esbenp.prettier-vscode"* ]]
  local count; count="$(grep -c "code --install-extension" "$STUB_CALLS")"
  [ "$count" -eq 5 ]
}

@test "installs all IDE extensions via cursor on PATH" {
  baseline_env
  make_ide_stub cursor CURSOR_INSTALLED_EXTENSIONS CURSOR_INSTALL_FAIL
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  local clean; clean="$(plain "$output")"
  for id in "${IDE_EXTENSIONS[@]}"; do
    grep -q "cursor --install-extension $id" "$STUB_CALLS"
    [[ "$clean" == *"✔ Cursor: $id"* ]]
  done
  [[ "$output" != *"No Cursor installation found"* ]]
  [[ "$output" == *"No VS Code installation found; skipping its extensions."* ]]
}

@test "installs all IDE extensions to both code and cursor" {
  baseline_env
  make_ide_stub code CODE_INSTALLED_EXTENSIONS CODE_INSTALL_FAIL
  make_ide_stub cursor CURSOR_INSTALLED_EXTENSIONS CURSOR_INSTALL_FAIL
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [ "$(grep -c "code --install-extension" "$STUB_CALLS")" -eq 6 ]
  [ "$(grep -c "cursor --install-extension" "$STUB_CALLS")" -eq 6 ]
  [[ "$output" != *"No VS Code installation found"* ]]
  [[ "$output" != *"No Cursor installation found"* ]]
}

@test "--ide skip still installs extensions when code is on PATH" {
  baseline_env
  make_ide_stub code CODE_INSTALLED_EXTENSIONS CODE_INSTALL_FAIL
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" != *"Checking if VS Code is installed"* ]]
  [ "$(grep -c "code --install-extension" "$STUB_CALLS")" -eq 6 ]
}

@test "falls back to the bundled code binary when code is not on PATH" {
  baseline_env
  make_ide_stub code CODE_INSTALLED_EXTENSIONS CODE_INSTALL_FAIL
  local bundled="$APPS_DIR/Visual Studio Code.app/Contents/Resources/app/bin"
  mkdir -p "$bundled"
  cp "$TEST_BIN/code" "$bundled/code"
  chmod +x "$bundled/code"
  rm "$TEST_BIN/code"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" != *"No VS Code installation found"* ]]
  [ "$(grep -c "code --install-extension" "$STUB_CALLS")" -eq 6 ]
  [[ "$output" == *"No Cursor installation found; skipping its extensions."* ]]
}

@test "reports a failing extension install and a manual follow-up" {
  baseline_env
  make_ide_stub code CODE_INSTALLED_EXTENSIONS CODE_INSTALL_FAIL
  export CODE_INSTALL_FAIL=1
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"Failed to install esbenp.prettier-vscode for VS Code."* ]]
  [[ "$output" == *"Install it manually:"* ]]
  [[ "$output" == *"code --install-extension esbenp.prettier-vscode"* ]]
  local clean; clean="$(plain "$output")"
  [[ "$clean" != *"✔ VS Code: esbenp.prettier-vscode"* ]]
  [ "$(grep -c "code --install-extension" "$STUB_CALLS")" -eq 6 ]
}

# --- shell setup ----------------------------------------------------------

@test "zsh already the default shell is reported present" {
  baseline_env
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"already the default shell"* ]]
  [[ "$output" == *"zsh as the default shell"* ]]
}

@test "switches the default shell when it is not zsh" {
  baseline_env
  run env SHELL=/bin/bash zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"switching with chsh"* ]]
  [[ "$output" == *"Restart the terminal"* ]]
  grep -q "chsh" "$STUB_CALLS"
}

@test "reports a follow-up when chsh fails" {
  baseline_env
  export CHSH_FAIL=1
  run env SHELL=/bin/bash zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"chsh failed"* ]]
  [[ "$output" == *"Set zsh as the default shell manually"* ]]
  [[ "$output" != *"zsh set as the default shell"* ]]
  [[ "$output" != *"Restart the terminal"* ]]
}

@test "oh-my-zsh is reported present with its version" {
  baseline_env
  register_stub git
  mkdir -p "$HOME/.oh-my-zsh/.git"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"→ version: master (abc1234)"* ]]
  [[ "$output" == *"oh-my-zsh master (abc1234)"* ]]
  [ ! -f "$HOME/.oh-my-zsh-installed" ]
  run grep -q "ohmyzsh/ohmyzsh/master/tools/install.sh" "$STUB_CALLS"
  [ "$status" -eq 1 ]
}

@test "installs oh-my-zsh when missing" {
  baseline_env
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [ -f "$HOME/.oh-my-zsh-installed" ]
  local clean; clean="$(plain "$output")"
  [[ "$clean" == *"✔ oh-my-zsh"* ]]
  # The nvm profile step runs after oh-my-zsh, so the loader survives the
  # (stubbed) fresh oh-my-zsh install instead of being written earlier
  # and then replaced with the oh-my-zsh template.
  grep -q 'NVM_DIR' "$HOME/.zshrc"
}

@test "installs oh-my-zsh unattended so it cannot hijack the run" {
  baseline_env
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [ -f "$HOME/.oh-my-zsh-installed" ]
  [ "$(cat "$HOME/.oh-my-zsh-args")" = "--unattended" ]
}

@test "oh-my-zsh without a git checkout reports an unknown version" {
  baseline_env
  mkdir -p "$HOME/.oh-my-zsh"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"→ version: unknown"* ]]
  [[ "$output" == *"oh-my-zsh unknown"* ]]
}

# --- summary and log ------------------------------------------------------

@test "ends with the run summary and the log path" {
  baseline_env
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"════ Run summary ════"* ]]
  [[ "$output" == *"Run log:"* ]]
  [[ -n "$(find . -maxdepth 1 -name 'setup-osx-*.log' | head -1)" ]]
}

# --- version --------------------------------------------------------------

@test "start banner reports the stamped version" {
  baseline_env
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  local clean; clean="$(plain "$output")"
  [[ "$clean" =~ dev-tooling\ setup\ scripts\ [0-9]{4}\.[0-9]{2}\.[0-9]{2}(\.[0-9]+)?@[0-9a-f]{7,40} ]]
}

@test "--version prints the stamped version and exits 0" {
  run zsh "$OSX" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}(\.[0-9]+)?@[0-9a-f]{7,40}$ ]]
}
