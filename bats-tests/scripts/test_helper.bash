SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../scripts" && pwd)"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STUBS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/stubs" && pwd)"
export SCRIPT_DIR PROJECT_ROOT STUBS_DIR

# Common test environment. Individual .bats files call this from their
# own setup() and can add file-specific state on top.
setup_common() {
  TEST_HOME="$BATS_TEST_TMPDIR/home"
  TEST_BIN="$BATS_TEST_TMPDIR/bin"
  TEST_APPS="$BATS_TEST_TMPDIR/apps"
  TEST_SCRIPTS="$BATS_TEST_TMPDIR/scripts"
  mkdir -p "$TEST_HOME" "$TEST_BIN" "$TEST_APPS" "$TEST_SCRIPTS"
  export HOME="$TEST_HOME"
  export APPS_DIR="$TEST_APPS"
  export PATH="$TEST_BIN:$PATH"
  export STUB_CALLS="$BATS_TEST_TMPDIR/stub-calls.log"
  : > "$STUB_CALLS"

  # macOS/CI commands the scripts shell out to; all state is kept inside
  # the fake HOME so real files are never touched.
  register_stub brew
  register_stub curl
  register_stub defaults
  register_stub pbcopy
  register_stub ssh-agent
  register_stub ssh-add
  register_stub chsh

  # Tools that resolve through check_command; they report a version and
  # let the tests exercise the "already present" branches. Use
  # FORCE_COMMAND_MISSING to exercise the install branches instead.
  make_tool docker "Docker version 27.0.3"
  make_tool docker-compose "Docker Compose version v2.29.1"
  make_tool aws "aws-cli/2.17.30"
  make_tool jq "jq-1.7.1"
  make_tool gh "gh version 2.55.0 (2024-08-01)"
  cat > "$TEST_BIN/node" <<'EOF'
#!/bin/bash
echo "${NODE_VERSION_OUTPUT:-v24.1.0}"
EOF
  chmod +x "$TEST_BIN/node"

  cd "$BATS_TEST_TMPDIR" || return
}

# Copies the production scripts into the test sandbox so the tests run
# against an isolated copy (and land any run logs in the tmpdir).
copy_scripts() {
  cp "$PROJECT_ROOT/scripts/setup-osx.sh" "$PROJECT_ROOT/scripts/setup-github-ssh.sh" "$PROJECT_ROOT/scripts/utils.sh" "$TEST_SCRIPTS/"
  chmod +x "$TEST_SCRIPTS"/*.sh
  export TEST_SCRIPTS
}

# register_stub <name> — exposes a stub from stubs/ into the fake bin
register_stub() {
  cp "$STUBS_DIR/$1" "$TEST_BIN/$1"
  chmod +x "$TEST_BIN/$1"
}

# make_tool <name> <version-output> — fake CLI reporting a fixed version
make_tool() {
  local name="$1" output="$2"
  cat > "$TEST_BIN/$name" <<EOF
#!/bin/bash
echo "$output"
EOF
  chmod +x "$TEST_BIN/$name"
}

# plain <text> — strips ANSI escape sequences for easier assertions
plain() {
  sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g' <<< "$1"
}

# make_app <AppName> [version] — fake installed app for APPS_DIR
make_app() {
  local name="$1" version="${2:-1.2.3}"
  mkdir -p "$APPS_DIR/$name.app/Contents"
  cat > "$APPS_DIR/$name.app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict><key>CFBundleShortVersionString</key><string>$version</string></dict></plist>
EOF
}

# make_ssh_key [name] — real ed25519 key pair inside the fake HOME
make_ssh_key() {
  local name="${1:-id_ed25519}"
  mkdir -p "$HOME/.ssh"
  ssh-keygen -t ed25519 -f "$HOME/.ssh/$name" -N "" -C "test@example.com" -q
}
