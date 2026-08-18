#!/usr/bin/env bats

load test_helper

setup() {
  setup_common
  copy_scripts
  OSX="$TEST_SCRIPTS/setup-osx.sh"
}

# Everything already in place so the run walks the "present" paths.
baseline_env() {
  git config --global user.name "Test User"
  git config --global user.email "test@example.com"
  make_ssh_key
  export SSH_ADD_HAS_ED25519=1 BREW_HAS_GIT=1
  mkdir -p "$HOME/.nvm"
  cat > "$HOME/.nvm/nvm.sh" <<'EOF'
nvm() { echo "nvm $*"; }
EOF
  touch "$HOME/.nvm/bash_completion"
}

APPS_DISPLAY=("iTerm2" "VS Code" "Cursor" "Postman" "Rectangle" "Google Chrome" "Slack" "Discord" "Telegram" "Signal" "WhatsApp" "MacPass" "1Password")
APPS_PATHS=("iTerm" "Visual Studio Code" "Cursor" "Postman" "Rectangle" "Google Chrome" "Slack" "Discord" "Telegram" "Signal" "WhatsApp" "MacPass" "1Password")

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

# --- Git ------------------------------------------------------------------

@test "Git installed via brew is reported present with its version and a shadow warning" {
  baseline_env
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
  touch "$HOME/.nvm/nvm.sh"
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
  grep -q "ssh-add" "$STUB_CALLS"
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
  [[ "$output" == *"✔ nvm v0.40.3"* ]]
  [ -f "$HOME/.nvm/nvm.sh" ]
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

@test "missing Node.js triggers nvm install" {
  baseline_env
  export FORCE_COMMAND_MISSING="node"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvm install 24"* ]]
  [[ "$output" == *"via nvm"* ]]
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
}

@test "missing CLIs are installed and gh gets the auth follow-up" {
  baseline_env
  export FORCE_COMMAND_MISSING="docker-compose aws jq gh"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"✔ docker-compose"* ]]
  [[ "$output" == *"✔ AWS CLI"* ]]
  [[ "$output" == *"✔ jq"* ]]
  [[ "$output" == *"✔ GitHub CLI (gh)"* ]]
  [[ "$output" == *"Run 'gh auth login'"* ]]
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

@test "oh-my-zsh is reported present with its version" {
  baseline_env
  register_stub git
  mkdir -p "$HOME/.oh-my-zsh/.git"
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [[ "$output" == *"→ version: master (abc1234)"* ]]
  [[ "$output" == *"oh-my-zsh master (abc1234)"* ]]
}

@test "installs oh-my-zsh when missing" {
  baseline_env
  run zsh "$OSX" --ide skip --password-manager skip
  [ "$status" -eq 0 ]
  [ -f "$HOME/.oh-my-zsh-installed" ]
  local clean; clean="$(plain "$output")"
  [[ "$clean" == *"✔ oh-my-zsh"* ]]
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
