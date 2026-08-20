#!/usr/bin/env bats

load test_helper

setup() {
  setup_common
  copy_scripts
  make_ssh_key
  # Baseline git identity; the script derives the allowed_signers principal
  # from user.email, so tests that don't exercise the prompt path need it.
  git config --global user.name "Test User"
  git config --global user.email "test@example.com"
  GSSH="$TEST_SCRIPTS/setup-github-ssh.sh"
}

# --- CLI ------------------------------------------------------------------

@test "--help prints usage and exits 0" {
  run zsh "$GSSH" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: setup-github-ssh.sh"* ]]
}

@test "-h prints usage and exits 0" {
  run zsh "$GSSH" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: setup-github-ssh.sh"* ]]
}

@test "unknown option exits 1" {
  run zsh "$GSSH" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "--key without a value exits 1" {
  run zsh "$GSSH" --key
  [ "$status" -eq 1 ]
  [[ "$output" == *"--key requires a path argument"* ]]
}

@test "--key=PATH equals form is accepted" {
  run zsh "$GSSH" "--key=$HOME/.ssh/id_ed25519"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found an ED25519 key"* ]]
}

# --- key validation -------------------------------------------------------

@test "missing key file exits 1" {
  run zsh "$GSSH" --key "$HOME/.ssh/nope"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No SSH key found"* ]]
}

@test "unreadable key exits 1" {
  echo "not a key" > "$HOME/badkey"
  echo "not a public key" > "$HOME/badkey.pub"
  run zsh "$GSSH" --key "$HOME/badkey"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not read the key"* ]]
}

@test "non-ED25519 key aborts on 'n'" {
  ssh-keygen -t rsa -f "$HOME/.ssh/id_rsa" -N "" -C "test@example.com" -q
  run zsh "$GSSH" --key "$HOME/.ssh/id_rsa" <<< "n"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not ED25519"* ]]
  [[ "$output" == *"Aborting"* ]]
  [ ! -f "$HOME/.ssh/config" ]
}

@test "non-ED25519 key continues on 'y'" {
  ssh-keygen -t rsa -f "$HOME/.ssh/id_rsa" -N "" -C "test@example.com" -q
  run zsh "$GSSH" --key "$HOME/.ssh/id_rsa" <<< "y"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Continuing with the non-ED25519 key"* ]]
  grep -q "Host github.com" "$HOME/.ssh/config"
}

# --- ssh config -----------------------------------------------------------

@test "appends the github.com block when no config exists" {
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found an ED25519 key"* ]]
  [[ "$output" == *"Appended a github.com block"* ]]
  grep -q "Host github.com" "$HOME/.ssh/config"
  grep -q "IdentityFile $HOME/.ssh/id_ed25519" "$HOME/.ssh/config"
  [ "$(stat -f '%Lp' "$HOME/.ssh/config")" = "600" ]
}

@test "leaves an existing github.com block untouched" {
  cat > "$HOME/.ssh/config" <<EOF
Host github.com
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile $HOME/.ssh/id_ed25519
EOF
  chmod 600 "$HOME/.ssh/config"
  before="$(cat "$HOME/.ssh/config")"
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 0 ]
  [[ "$output" == *"leaving it untouched"* ]]
  [ "$(cat "$HOME/.ssh/config")" = "$before" ]
}

@test "leaves a github.com block untouched when github.com is not the first Host token" {
  cat > "$HOME/.ssh/config" <<EOF
Host personal.github.com github.com
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile $HOME/.ssh/id_ed25519
EOF
  chmod 600 "$HOME/.ssh/config"
  before="$(cat "$HOME/.ssh/config")"
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 0 ]
  [[ "$output" == *"leaving it untouched"* ]]
  [[ "$output" != *"Appended a github.com block"* ]]
  [ "$(cat "$HOME/.ssh/config")" = "$before" ]
}

@test "appends a github.com block when a Host line has no github.com token" {
  cat > "$HOME/.ssh/config" <<EOF
Host personal.github.com
    IdentityFile $HOME/.ssh/id_ed25519
Host github.comx
    IdentityFile $HOME/.ssh/id_ed25519
EOF
  chmod 600 "$HOME/.ssh/config"
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Appended a github.com block"* ]]
  grep -q "^Host github.com$" "$HOME/.ssh/config"
}

@test "warns about a commented-out github.com block" {
  cat > "$HOME/.ssh/config" <<EOF
#Host github.com
#    IdentityFile $HOME/.ssh/id_ed25519
EOF
  chmod 600 "$HOME/.ssh/config"
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519" <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"commented out"* ]]
  [[ "$output" == *"Uncomment the github.com block"* ]]
  grep -q "^#Host github.com" "$HOME/.ssh/config"
}

# --- commit signing -------------------------------------------------------

@test "sets commit signing config when unset" {
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 0 ]
  [ "$(git config --global --get gpg.format)" = "ssh" ]
  [ "$(git config --global --get user.signingkey)" = "$HOME/.ssh/id_ed25519" ]
  [ "$(git config --global --get commit.gpgsign)" = "true" ]
  [[ "$output" == *"gpg.format = ssh"* ]]
}

@test "keeps existing commit signing config" {
  git config --global gpg.format ssh
  git config --global user.signingkey "$HOME/.ssh/id_ed25519"
  git config --global commit.gpgsign true
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 0 ]
  [[ "$output" == *"is already 'ssh'; leaving it"* ]]
  [[ "$output" == *"Already present:"* ]]
}

@test "skips SSH signing settings when gpg.format is not ssh" {
  git config --global gpg.format openpgp
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 0 ]
  [ "$(git config --global --get gpg.format)" = "openpgp" ]
  [ -z "$(git config --global --get user.signingkey)" ]
  [ -z "$(git config --global --get commit.gpgsign)" ]
  [[ "$output" == *"gpg.format is 'openpgp'"* ]]
  [[ "$output" == *"skipping the SSH signing settings"* ]]
}

# --- allowed_signers ------------------------------------------------------

@test "registers the public key in allowed_signers" {
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Registered the key"* ]]
  grep -q "test@example.com" "$HOME/.config/git/allowed_signers"
  grep -qF "$(cat "$HOME/.ssh/id_ed25519.pub")" "$HOME/.config/git/allowed_signers"
}

@test "appends without clobbering other signers" {
  mkdir -p "$HOME/.config/git"
  echo "someone-else ssh-ed25519 AAAAfakeexistingkey" > "$HOME/.config/git/allowed_signers"
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 0 ]
  grep -q "someone-else" "$HOME/.config/git/allowed_signers"
  grep -q "test@example.com" "$HOME/.config/git/allowed_signers"
  grep -qF "$(cat "$HOME/.ssh/id_ed25519.pub")" "$HOME/.config/git/allowed_signers"
}

@test "skips registration when the key is already a signer" {
  mkdir -p "$HOME/.config/git"
  echo "test@example.com $(cat "$HOME/.ssh/id_ed25519.pub")" > "$HOME/.config/git/allowed_signers"
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already registered"* ]]
}

@test "skips registration when the same key is registered with a different comment" {
  mkdir -p "$HOME/.config/git"
  local pub
  pub="$(cat "$HOME/.ssh/id_ed25519.pub")"
  # Same key type and body, different trailing comment than the one the
  # key file carries; only the type and body must be compared.
  echo "test@example.com ${pub% *} some-other-comment" > "$HOME/.config/git/allowed_signers"
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already registered"* ]]
  [ "$(wc -l < "$HOME/.config/git/allowed_signers" | tr -d ' ')" = "1" ]
}

@test "missing public key exits 1" {
  rm "$HOME/.ssh/id_ed25519.pub"
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No public key"* ]]
}

@test "missing public key exits before changing git config" {
  rm "$HOME/.ssh/id_ed25519.pub"
  gitconfig_before="$(cat "$HOME/.gitconfig")"
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No public key"* ]]
  [ ! -f "$HOME/.ssh/config" ]
  [ "$(cat "$HOME/.gitconfig")" = "$gitconfig_before" ]
}

@test "uses a custom gpg.ssh.allowedSignersFile when configured" {
  custom="$HOME/.custom/signers"
  git config --global gpg.ssh.allowedSignersFile "$custom"
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 0 ]
  grep -q "test@example.com" "$custom"
  grep -qF "$(cat "$HOME/.ssh/id_ed25519.pub")" "$custom"
  [ "$(git config --global --get gpg.ssh.allowedSignersFile)" = "$custom" ]
  [ ! -f "$HOME/.config/git/allowed_signers" ]
}

@test "expands a leading tilde in gpg.ssh.allowedSignersFile" {
  local workdir="$BATS_TEST_TMPDIR/workdir"
  mkdir -p "$workdir"
  git config --global gpg.ssh.allowedSignersFile "~/.custom/signers"
  cd "$workdir"
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 0 ]
  grep -qF "$(cat "$HOME/.ssh/id_ed25519.pub")" "$HOME/.custom/signers"
  [ ! -e "$workdir/~" ]
}

@test "prompts for an email principal when git user.email is unset" {
  git config --global --unset user.email
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519" <<< "signer@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"enter the email to register as the signer principal"* ]]
  grep -q "signer@example.com" "$HOME/.config/git/allowed_signers"
  grep -qF "$(cat "$HOME/.ssh/id_ed25519.pub")" "$HOME/.config/git/allowed_signers"
}

@test "exits 1 when no email principal can be determined" {
  git config --global --unset user.email
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519" <<< ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"No email provided"* ]]
  [ ! -f "$HOME/.config/git/allowed_signers" ]
}

@test "SSH-signed commit verifies after the script runs" {
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 0 ]

  mkdir -p "$HOME/repo"
  git -C "$HOME/repo" init -q
  git -C "$HOME/repo" config user.name "Test User"
  git -C "$HOME/repo" config user.email "test@example.com"

  run git -C "$HOME/repo" commit --allow-empty -S -m test
  [ "$status" -eq 0 ]
  run git -C "$HOME/repo" verify-commit HEAD
  [ "$status" -eq 0 ]
  [[ "$output" == *"Good \"git\" signature"* ]]
}

# --- idempotency ----------------------------------------------------------

@test "second run changes nothing and reports everything as present" {
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 0 ]
  config_before="$(cat "$HOME/.ssh/config")"
  signers_before="$(cat "$HOME/.config/git/allowed_signers")"

  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Appended a github.com block"* ]]
  [[ "$output" != *"Registered the key"* ]]
  [ "$(cat "$HOME/.ssh/config")" = "$config_before" ]
  [ "$(cat "$HOME/.config/git/allowed_signers")" = "$signers_before" ]
}

# --- logging --------------------------------------------------------------

@test "writes its own timestamped log when forced interactive" {
  export FORCE_INTERACTIVE=1
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Run log:"* ]]
  [[ -n "$(find . -maxdepth 1 -name 'setup-github-ssh-*.log' | head -1)" ]]
}

@test "creates no log when piped" {
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 0 ]
  [ -z "$(find . -maxdepth 1 -name 'setup-github-ssh-*.log' | head -1)" ]
}

# --- version --------------------------------------------------------------

@test "start banner reports the stamped version" {
  run zsh "$GSSH" --key "$HOME/.ssh/id_ed25519"
  [ "$status" -eq 0 ]
  local clean; clean="$(plain "$output")"
  [[ "$clean" =~ dev-tooling\ setup\ scripts\ [0-9]{4}\.[0-9]{2}\.[0-9]{2}@[0-9a-f]{7,40} ]]
}

@test "--version prints the stamped version and exits 0" {
  run zsh "$GSSH" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}@[0-9a-f]{7,40}$ ]]
}
