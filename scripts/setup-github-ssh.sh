#!/bin/zsh
# shellcheck shell=bash  # linted as bash; zsh-only lines carry their own disables

# setup-github-ssh.sh
#
# Standalone GitHub-over-SSH setup. This script:
#   - appends a github.com block to ~/.ssh/config
#   - enables SSH commit signing in the global git config
#   - registers the public key in ~/.config/git/allowed_signers
#
# Every step is idempotent: existing configuration is detected and left
# untouched, so a second run changes nothing and only confirms what is
# already in place.

# Stamped CalVer version: replaced on every push to main by the
# stamp-version-calver workflow. The seed placeholder is never shipped.
# Each script carries its own copy so a stale script reports its own
# version instead of inheriting a fresh one from the sourced helpers.
VERSION="2026.08.27.1@cf0e6fd"

# shellcheck disable=SC2296  # zsh-specific script path expansion
SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
# shellcheck disable=SC1091  # helper lives next to the script
source "$SCRIPT_DIR/utils.sh"

KEY_PATH="$HOME/.ssh/id_ed25519"

# --- Help ----------------------------------------------------------------

usage() {
    cat <<'EOF'
Usage: setup-github-ssh.sh [options]

Configures GitHub access over SSH on this machine:
  - writes the github.com block into ~/.ssh/config
  - turns on SSH commit signing in the global git config
  - registers the public key in ~/.config/git/allowed_signers

All steps are idempotent; existing settings are detected and left as-is.

Options:
  --key PATH   Path to the SSH key to configure (default: ~/.ssh/id_ed25519)
  -h, --help   Show this help message and exit
  --version   Print the stamped version and exit
EOF
}

# --- Argument parsing ----------------------------------------------------
# Options are consumed before any logging so --help always works cleanly.

while [[ $# -gt 0 ]]; do
    case "$1" in
        --key=*)
            KEY_PATH="${1#*=}"
            shift
            ;;
        --key)
            if (( $# < 2 )); then
                report "error" "--key requires a path argument."
                exit 1
            fi
            KEY_PATH="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --version)
            echo "$VERSION"
            exit 0
            ;;
        *)
            report "error" "Unknown option: $1"
            report "info" "Run with --help to see the usage."
            exit 1
            ;;
    esac
done

# Interactive runs are teed to a timestamped log and checked against
# origin/main; piped runs (curl | zsh) skip both and go straight to work.
# FORCE_INTERACTIVE is a test-only escape hatch to exercise the
# interactive path without a terminal.
if [[ -t 1 || "$FORCE_INTERACTIVE" == "1" ]]; then
    start_run_log "setup-github-ssh"
    ensure_fresh "scripts/setup-github-ssh.sh" "setup-github-ssh.sh"
fi

# Report this script's own stamped CalVer@SHA version, so a stale copy
# reports its own stamp rather than a fresh one from the sourced helpers.
report "info" "dev-tooling setup scripts ${VERSION}"

# --- Key checks ----------------------------------------------------------

if [[ ! -f "$KEY_PATH" ]]; then
    report "error" "No SSH key found at ${KEY_PATH}."
    report "info" "Generate one first, e.g.: ssh-keygen -t ed25519 -f ${KEY_PATH}"
    exit 1
fi

if [[ ! -f "$KEY_PATH.pub" ]]; then
    report "error" "No public key found at ${KEY_PATH}.pub."
    exit 1
fi

key_info="$(ssh-keygen -l -f "$KEY_PATH" 2>&1)" || {
    report "error" "Could not read the key at ${KEY_PATH}."
    exit 1
}

if [[ "$key_info" == *"ED25519"* ]]; then
    report "success" "Found an ED25519 key at ${KEY_PATH}."
else
    report "warning" "The key at ${KEY_PATH} is not ED25519: ${key_info}"
    report "warning" "GitHub access and SSH commit signing generally work best with an ED25519 key."
    report "info" "Continue anyway? (y/n)"
    read -r answer
    if [[ "${answer:l}" =~ ^(y|yes)$ ]]; then
        report "warning" "Continuing with the non-ED25519 key."
    else
        report "info" "Aborting; no changes were made."
        exit 1
    fi
fi

# --- SSH config ----------------------------------------------------------

SSH_CONFIG="$HOME/.ssh/config"
mkdir -p "$HOME/.ssh"

if [[ -f "$SSH_CONFIG" ]] && grep -qiE '^[[:space:]]*Host[[:space:]]+(.*[[:space:]])?github\.com([[:space:]]|$)' "$SSH_CONFIG"; then
    report "info" "A github.com block already exists in ${SSH_CONFIG}; leaving it untouched."
    note_present "github.com block in ~/.ssh/config"
elif [[ -f "$SSH_CONFIG" ]] && grep -qiE '^[[:space:]]*#.*Host[[:space:]]+(.*[[:space:]])?github\.com([[:space:]]|$)' "$SSH_CONFIG"; then
    report "warning" "A github.com block exists in ${SSH_CONFIG} but is commented out."
    note_followup "Uncomment the github.com block in ~/.ssh/config"
    press_enter "Please uncomment it now, then press Enter to continue."
else
    cat >> "$SSH_CONFIG" <<EOF

Host github.com
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile ${KEY_PATH}
EOF
    chmod 600 "$SSH_CONFIG"
    report "success" "Appended a github.com block to ${SSH_CONFIG}."
    note_added "github.com block in ~/.ssh/config"
fi

# --- SSH commit signing --------------------------------------------------
# Each setting is applied only when the global git config does not already
# carry a value, so existing choices are never clobbered.

set_git_config_if_unset() {
    local config_key="$1"
    local value="$2"
    local current
    current="$(git config --global --get "$config_key")"
    if [[ -n "$current" ]]; then
        report "info" "git config ${config_key} is already '${current}'; leaving it."
        note_present "git config ${config_key} = ${current}"
    else
        git config --global "$config_key" "$value"
        report "success" "git config ${config_key} = ${value}"
        note_added "git config ${config_key} = ${value}"
    fi
}

set_git_config_if_unset "gpg.format" "ssh"

gpg_format="$(git config --global --get gpg.format)"
if [[ -n "$gpg_format" && "$gpg_format" != "ssh" ]]; then
    report "warning" "gpg.format is '${gpg_format}', not 'ssh'; skipping the SSH signing settings (user.signingkey, commit.gpgsign)."
    note_followup "Enable SSH signing by switching gpg.format, e.g. 'git config --global gpg.format ssh', then re-run this script."
else
    set_git_config_if_unset "user.signingkey" "${KEY_PATH}"
    set_git_config_if_unset "commit.gpgsign" "true"
fi

# --- allowed_signers -----------------------------------------------------
# The signer's principal is the global git user.email, since that is the
# identity git will match when verifying signatures; without one we ask
# interactively. The file is only appended to, so signers registered by
# other tools or machines are preserved.

principal="$(git config --global --get user.email)"
if [[ -z "$principal" ]]; then
    report "info" "No git user.email is configured; enter the email to register as the signer principal:"
    read -r principal
    if [[ -z "$principal" ]]; then
        report "error" "No email provided; cannot register a signer without a principal."
        exit 1
    fi
fi

ALLOWED_SIGNERS="$(git config --global --get gpg.ssh.allowedSignersFile)"
if [[ -z "$ALLOWED_SIGNERS" ]]; then
    ALLOWED_SIGNERS="$HOME/.config/git/allowed_signers"
    set_git_config_if_unset "gpg.ssh.allowedSignersFile" "$ALLOWED_SIGNERS"
fi

# git expands a leading ~/ in path-typed config values, but the raw
# value read above keeps it literal; normalize it so the file is created
# where git will actually look for it.
# shellcheck disable=SC2088  # the leading ~ is a literal match, not an expansion
if [[ "$ALLOWED_SIGNERS" == "~/"* ]]; then
    ALLOWED_SIGNERS="$HOME/${ALLOWED_SIGNERS#\~/}"
fi

mkdir -p "$(dirname "$ALLOWED_SIGNERS")"
touch "$ALLOWED_SIGNERS"

pubkey="$(cat "$KEY_PATH.pub")"
# The trailing comment is cosmetic; an equivalent key registered with a
# different comment must not produce a duplicate signer entry, so only
# the key type and body are compared.
key_body="$(awk '{print $1" "$2}' "$KEY_PATH.pub")"
signer_line="${principal} ${pubkey}"

if grep -qF "$key_body" "$ALLOWED_SIGNERS"; then
    report "info" "The public key is already registered in ${ALLOWED_SIGNERS}."
    note_present "Public key registered in ${ALLOWED_SIGNERS}"
else
    echo "$signer_line" >> "$ALLOWED_SIGNERS"
    report "success" "Registered the key in ${ALLOWED_SIGNERS}."
    note_added "Public key registered in ${ALLOWED_SIGNERS}"
fi

# --- Wrap up -------------------------------------------------------------

note_followup "Test the SSH connection: ssh -T git@github.com"
note_followup "Verify signing: make a throwaway signed commit (e.g. 'git commit --allow-empty -S -m test') and confirm GitHub shows it as Verified"

print_run_summary
exit 0
