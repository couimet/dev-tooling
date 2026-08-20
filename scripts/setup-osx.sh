#!/bin/zsh
# shellcheck shell=bash  # linted as bash; zsh-only lines carry their own disables

# Bootstrap script for a macOS development environment.
# Installs the day-to-day tooling for Node.js and API work: Homebrew,
# Git, nvm/Node, a handful of applications, and GitHub SSH access.
# Every step checks first, so re-running the script is safe: anything
# already present is reported as such and nothing is reinstalled. The
# whole run is mirrored to a timestamped log file in the directory the
# script is invoked from (see the shared start_run_log helper).

# --- Configuration ----------------------------------------------------------

# Major version of Node.js to install and keep current through nvm.
NODE_MAJOR_VERSION=24

# Base URL the script refreshes its shared helpers from when it runs
# from a raw pipe instead of a checkout; point it at a fork to test.
HELPERS_BASE_URL="https://raw.githubusercontent.com/couimet/dev-tooling/main/scripts"

# --- Shared helpers --------------------------------------------------------

# Resolve the directory holding the shared helpers. When this script runs
# from a checkout, utils.sh sits right next to it. The README quick
# install pipes the script straight from GitHub, in which case
# ${(%):-%x} is not a real file ("zsh") and dirname would resolve to the
# current directory; that directory must not be used, or a local utils.sh
# could be picked up by accident. The helpers are then fetched into a
# scratch directory under $TMPDIR so the script stays self-sufficient.
SCRIPT_DIR=""
# shellcheck disable=SC2296  # zsh-specific script path expansion
if [[ -f "${(%):-%x}" ]]; then
    # shellcheck disable=SC2296  # zsh-specific script path expansion
    SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" 2>/dev/null && pwd)"
fi

if [[ ! -f "$SCRIPT_DIR/utils.sh" ]]; then
    SCRIPT_DIR="${TMPDIR:-/tmp}/dev-tooling-scripts"
    mkdir -p "$SCRIPT_DIR"
    for helper in utils.sh setup-github-ssh.sh; do
        # Download to a temporary file first so a failed refresh never
        # leaves a half-written helper in place, and abort on any
        # transfer error instead of silently reusing a stale copy.
        if ! curl -fsSL "$HELPERS_BASE_URL/$helper" -o "$SCRIPT_DIR/$helper.tmp"; then
            echo "ERROR: could not download the shared helpers; aborting." >&2
            exit 1
        fi
    done
    # Every download succeeded; replace the cached helpers now.
    for helper in utils.sh setup-github-ssh.sh; do
        mv "$SCRIPT_DIR/$helper.tmp" "$SCRIPT_DIR/$helper"
    done
fi

# shellcheck disable=SC1091  # helper lives next to the script
source "$SCRIPT_DIR/utils.sh"

# The GitHub SSH script may have arrived without the executable bit,
# depending on how it got to this machine.
if [[ -f "$SCRIPT_DIR/setup-github-ssh.sh" && ! -x "$SCRIPT_DIR/setup-github-ssh.sh" ]]; then
    chmod +x "$SCRIPT_DIR/setup-github-ssh.sh"
fi

# --- Command line options ---------------------------------------------------

# Flag values for the choices the script would otherwise prompt for.
# Empty means "ask interactively".
ARG_IDE=""
ARG_PASSWORD_MANAGER=""

usage() {
    cat <<'EOF'
Usage: setup-osx.sh [options]

Bootstraps a macOS development environment: Homebrew, Git, nvm/Node,
applications, and GitHub SSH access. Safe to re-run.

Options:
  --ide <choice>               vscode | cursor | both | skip
  --password-manager <choice>  macpass | 1password | both | skip
  -h, --help                   Show this help message and exit

When a flag is omitted, the script prompts for that choice interactively.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ide)
            if (( $# < 2 )); then
                report "error" "--ide requires a choice (vscode, cursor, both, or skip)."
                exit 1
            fi
            ARG_IDE="$2"
            shift 2
            ;;
        --password-manager)
            if (( $# < 2 )); then
                report "error" "--password-manager requires a choice (macpass, 1password, both, or skip)."
                exit 1
            fi
            ARG_PASSWORD_MANAGER="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            report "error" "Unknown option: $1"
            report "info" "Run with --help to see the usage."
            exit 1
            ;;
    esac
done

# Validate the flag values up front so a typo fails fast instead of
# mid-run, before any log file is created.
case "$ARG_IDE" in
    ""|vscode|cursor|both|skip) ;;
    *) report "error" "Unknown --ide choice: ${ARG_IDE}"; exit 1 ;;
esac
case "$ARG_PASSWORD_MANAGER" in
    ""|macpass|1password|both|skip) ;;
    *) report "error" "Unknown --password-manager choice: ${ARG_PASSWORD_MANAGER}"; exit 1 ;;
esac

# Mirror the run to a timestamped log (path is printed by the helper).
start_run_log "setup-osx"

# Safety net against running an outdated copy of this script.
ensure_fresh "scripts/setup-osx.sh" "setup-osx.sh"

# --- Helpers ---------------------------------------------------------------

# Prints the "checking" line that precedes each tool check.
# The optional second parameter overrides the default "is installed" text.
print_check_message() {
    local tool_name="$1"
    local display_text="${2:-is installed}"
    report "info" "Checking if ${tool_name} ${display_text}..."
}

# Utility function to check if a command exists.
# `command -v` is used instead of a plain -x test because it also finds
# shell functions such as nvm, which live in the shell environment and
# are not files on disk.
# Returns 0 when the command is present (and prints its version), and
# 1 when it is missing so the caller can run the install step.
# The version it found is left in CHECKED_VERSION so the caller can
# carry it into the run summary.
check_command() {
    local cmd="$1"
    CHECKED_VERSION=""
    # FORCE_COMMAND_MISSING (test-only): a space-separated list of command
    # names to treat as absent so the install paths can be exercised on
    # machines where those tools already exist.
    if [[ " ${FORCE_COMMAND_MISSING:-} " == *" $cmd "* ]]; then
        report "info" "Installing ${cmd}..."
        return 1
    fi
    if ! command -v "$cmd" &>/dev/null; then
        report "info" "Installing ${cmd}..."
        return 1
    fi

    local version=""
    # Try the common version flag patterns.
    if $cmd --version &>/dev/null; then
        version="$($cmd --version | head -n 1)"
    elif $cmd -v &>/dev/null; then
        version="$($cmd -v | head -n 1)"
    elif $cmd -V &>/dev/null; then
        version="$($cmd -V | head -n 1)"
    fi
    CHECKED_VERSION="${version:-unknown}"

    report "success" "${cmd} is installed"
    if [[ -n "$version" ]]; then
        echo "  → version: ${GREEN}${version}${RESET}"
    else
        echo "  → version: unknown"
    fi
    echo
    return 0
}

# Utility function to check if a macOS application is installed.
# Returns 0 when the app exists in /Applications (and prints the version
# from its Info.plist), and 1 when it is missing.
# Like check_command, the version is left in CHECKED_VERSION.
check_app() {
    local app_name="$1"
    # APPS_DIR lets tests point the checks at a fake Applications
    # directory; real runs keep the default.
    local app_path="${APPS_DIR:-/Applications}/${app_name}.app"
    local display_name="${2:-$app_name}"
    CHECKED_VERSION=""

    if [[ ! -d "$app_path" ]]; then
        report "info" "Installing ${display_name}..."
        return 1
    fi

    report "success" "${display_name} is installed"
    if [[ -f "${app_path}/Contents/Info.plist" ]]; then
        local version
        version="$(defaults read "${app_path}/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null)"
        CHECKED_VERSION="${version:-unknown}"
        echo "  → version: ${GREEN}${version:-unknown}${RESET}"
    else
        echo "  → version: unknown"
    fi
    echo
    return 0
}

# Version of an installed .app, read from its Info.plist.
# Prints "unknown" when the app is not installed.
app_version() {
    local version
    version="$(defaults read "${APPS_DIR:-/Applications}/$1.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null)"
    [[ -n "$version" ]] && echo "$version" || echo "unknown"
}

# First line of the version output of an installed command.
# Prints "unknown" when the command is missing or silent.
cmd_version() {
    local version
    version="$("$1" --version 2>/dev/null | head -n 1)"
    [[ -n "$version" ]] && echo "$version" || echo "unknown"
}

# Runs brew install and lets the caller record success only afterwards;
# on failure it reports the error and leaves a manual follow-up so the
# run summary never records an install that did not happen.
brew_install() {
    if brew install "$@"; then
        return 0
    fi
    report "error" "brew install $* failed."
    note_followup "Install it manually: brew install $*"
    return 1
}

# Checks for a Homebrew cask app and installs it when missing, recording
# the outcome in the run summary. The app name is the /Applications
# bundle used for the check and the version probe; the display name is
# what the summary shows; the cask is the Homebrew package.
install_app() {
    local app="$1" display="$2" cask="$3"
    print_check_message "$display"
    if ! check_app "$app" "$display"; then
        if brew_install --cask "$cask"; then
            note_added "$display $(app_version "$app")"
        fi
    else
        note_present "$display ${CHECKED_VERSION}"
    fi
}

# Same as install_app for brew formulae that expose a command. The
# display name and formula default to the command name, so a plain
# "install_cmd jq" covers the common case.
install_cmd() {
    local command="$1"
    local display="${2:-$command}" formula="${3:-$command}"
    print_check_message "$display"
    if ! check_command "$command"; then
        if brew_install "$formula"; then
            note_added "$display $(cmd_version "$command")"
        fi
    else
        note_present "$display ${CHECKED_VERSION}"
    fi
}

# Branch and commit of the local oh-my-zsh install; "unknown" when absent.
omz_version() {
    local branch commit
    if [[ -d "$HOME/.oh-my-zsh/.git" ]]; then
        branch="$(cd "$HOME/.oh-my-zsh" && git rev-parse --abbrev-ref HEAD 2>/dev/null)"
        commit="$(cd "$HOME/.oh-my-zsh" && git rev-parse --short HEAD 2>/dev/null)"
    fi
    if [[ -n "$branch" && -n "$commit" ]]; then
        echo "${branch} (${commit})"
    else
        echo "unknown"
    fi
}

# Prompt for which IDE(s) to install. An invalid choice falls back to
# VS Code, matching the historical behavior.
select_ides() {
    report "info" "IDE Selection"
    echo "Which IDE(s) would you like to install?"
    echo "1) VS Code"
    echo "2) Cursor"
    echo "3) Both"
    echo "4) Skip IDE installation"
    echo -n "Enter your choice (1-4): "

    read -r ide_choice

    case $ide_choice in
        1) install_vscode=true; install_cursor=false ;;
        2) install_vscode=false; install_cursor=true ;;
        3) install_vscode=true; install_cursor=true ;;
        4) install_vscode=false; install_cursor=false ;;
        *) report "warning" "Invalid choice. Installing VS Code by default."; install_vscode=true; install_cursor=false ;;
    esac
}

# Prompt for which password manager(s) to install. An invalid choice
# falls back to MacPass, matching the historical behavior.
select_password_managers() {
    report "info" "Password Manager Selection"
    echo "Which password manager(s) would you like to install?"
    echo "1) MacPass"
    echo "2) 1Password"
    echo "3) Both"
    echo "4) Skip password manager installation"
    echo -n "Enter your choice (1-4): "

    read -r pm_choice

    case $pm_choice in
        1) install_macpass=true; install_1password=false ;;
        2) install_macpass=false; install_1password=true ;;
        3) install_macpass=true; install_1password=true ;;
        4) install_macpass=false; install_1password=false ;;
        *) report "warning" "Invalid choice. Installing MacPass by default."; install_macpass=true; install_1password=false ;;
    esac
}

# Applies a --ide flag value to the same variables the interactive
# prompt sets, so both paths share one set of outcomes.
apply_ide_flag() {
    case "$1" in
        vscode) install_vscode=true; install_cursor=false ;;
        cursor) install_vscode=false; install_cursor=true ;;
        both)   install_vscode=true; install_cursor=true ;;
        skip)   install_vscode=false; install_cursor=false ;;
    esac
}

# Applies a --password-manager flag value the same way.
apply_password_manager_flag() {
    case "$1" in
        macpass)   install_macpass=true; install_1password=false ;;
        1password) install_macpass=false; install_1password=true ;;
        both)      install_macpass=true; install_1password=true ;;
        skip)      install_macpass=false; install_1password=false ;;
    esac
}

# Returns 0 when zsh is already the default shell, 1 when chsh changed
# it, and 2 when chsh failed, so the caller can report each outcome
# differently instead of claiming success on a failed change.
check_default_shell() {
    if [[ $SHELL != */zsh ]]; then
        report "info" "zsh is not the default shell; switching with chsh..."
        if chsh -s "$(which zsh)"; then
            return 1
        fi
        report "error" "chsh failed; the default shell was not changed."
        return 2
    fi
    report "success" "zsh is already the default shell."
    return 0
}

# Checks the oh-my-zsh install and prints its version when present.
# Returns 1 when it needs to be installed.
check_oh_my_zsh() {
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        report "info" "Installing oh-my-zsh..."
        return 1
    fi
    report "success" "oh-my-zsh is installed"
    echo "  → version: ${GREEN}$(omz_version)${RESET}"
    echo "  → zsh version: ${GREEN}${ZSH_VERSION}${RESET}"
    echo
    return 0
}

# --- Homebrew --------------------------------------------------------------

print_check_message "Homebrew"
if ! check_command brew; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # A fresh install leaves the current shell without brew in PATH, so
    # pick up its shellenv from the architecture's install prefix before
    # any later brew call. Tests point BREW_BIN_DIR at the stub bin.
    brew_bin=""
    if [[ -n "${BREW_BIN_DIR:-}" ]]; then
        # Test hook: when set, it is authoritative and has no fallback,
        # so failure paths are exercisable on machines with real brew.
        [[ -x "$BREW_BIN_DIR/brew" ]] && brew_bin="$BREW_BIN_DIR"
    else
        for candidate in /opt/homebrew/bin /usr/local/bin; do
            [[ -x "$candidate/brew" ]] && brew_bin="$candidate" && break
        done
    fi
    if [[ -n "$brew_bin" ]]; then
        eval "$("$brew_bin/brew" shellenv)"
    fi
    if [[ -n "$brew_bin" ]] && command -v brew &>/dev/null; then
        note_added "Homebrew ($(cmd_version brew))"
    else
        report "error" "Homebrew was installed but its shell environment could not be initialized."
        note_followup "Open a new terminal and re-run this script so brew is on PATH"
    fi
else
    note_present "Homebrew (${CHECKED_VERSION})"
fi

# --- Git -------------------------------------------------------------------

print_check_message "Git"
if ! check_command git; then
    if brew_install git; then
        note_added "Git $(brew list --versions git | awk '{print $NF}') (Homebrew)"
    fi
elif ! brew list --versions git &>/dev/null; then
    # macOS ships git at /usr/bin/git; prefer the Homebrew build so the
    # machine gets the latest version.
    report "warning" "System Git detected; installing the Homebrew version..."
    if brew_install git; then
        note_added "Git $(brew list --versions git | awk '{print $NF}') (Homebrew)"
    fi
else
    note_present "Git $(brew list --versions git | awk '{print $NF}') (Homebrew)"
    report "info" "  → Homebrew version: ${GREEN}$(brew list --versions git)${RESET}"
fi

# On machines where /usr/bin precedes the Homebrew bin directory in PATH,
# the shell keeps picking the system git even though Homebrew's is
# installed. Flag it so the PATH order can be fixed.
if brew list --versions git &>/dev/null && [[ "$(which git)" == "/usr/bin/git" ]]; then
    note_followup "Homebrew's git is shadowed by /usr/bin/git; check the PATH order in your shell profile"
fi

# --- Git identity ----------------------------------------------------------

# The GitHub SSH key further down is generated with the git email, so
# an incomplete identity is a hard stop.
print_check_message "Git Configuration"
if [[ -z "$(git config --global user.name)" ]] || [[ -z "$(git config --global user.email)" ]]; then
    report "error" "Git configuration is incomplete."
    echo "Please configure git with:"
    echo "${GREEN}git config --global user.name \"Your Name\""
    echo "git config --global user.email \"your.email@example.com\"${RESET}"
    exit 1
fi
report "success" "Git identity is configured."
GIT_EMAIL="$(git config --global --get user.email)"
note_present "Git identity (user.name / user.email)"

# --- GitHub SSH setup ------------------------------------------------------

print_check_message "GitHub SSH key"
SSH_KEY="$HOME/.ssh/id_ed25519"

if [[ ! -f "$SSH_KEY" ]]; then
    # No key yet: create a fresh ed25519 key (ssh-keygen never overwrites),
    # load it into the ssh-agent, and copy the public half to the clipboard
    # so it can be pasted straight into GitHub's settings page.
    report "info" "No SSH key found; generating a new ed25519 key..."
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$SSH_KEY" -N ""
    eval "$(ssh-agent -s)"
    ssh-add "$SSH_KEY"
    pbcopy < "$SSH_KEY.pub"

    report "info" "The new public key has been copied to the clipboard."
    report "info" "Add it to GitHub at: ${GREEN}https://github.com/settings/keys${RESET}"
    press_enter "Press Enter once you have added the key to GitHub..."

    # Apply the GitHub SSH configuration (config block, commit signing,
    # allowed signers) via the standalone script, when it is present.
    # Its output is captured so it can be shown right away and repeated
    # in the final summary. A missing or failing helper is not fatal:
    # the key is already in place, so the run just ends with a follow-up.
    if [[ ! -x "$SCRIPT_DIR/setup-github-ssh.sh" ]]; then
        report "error" "setup-github-ssh.sh not found; the GitHub SSH configuration was skipped."
        note_added "GitHub SSH key (id_ed25519)"
        note_followup "Run scripts/setup-github-ssh.sh --key=$SSH_KEY to finish the GitHub SSH configuration"
    elif SECURE_OUTPUT="$("$SCRIPT_DIR/setup-github-ssh.sh" --key="$SSH_KEY" 2>&1)"; then
        echo
        echo "$SECURE_OUTPUT"
        echo
        note_added "GitHub SSH key (id_ed25519) and SSH configuration"
        note_followup "Verify GitHub access: ssh -T git@github.com"
    else
        echo
        echo "$SECURE_OUTPUT"
        echo
        report "error" "The GitHub SSH setup script failed; the SSH configuration was not applied."
        note_added "GitHub SSH key (id_ed25519)"
        note_followup "Re-run scripts/setup-github-ssh.sh --key=$SSH_KEY once the error is fixed"
    fi
else
    # Key exists: just make sure the agent has this specific key loaded,
    # and leave the SSH configuration hint for the final summary.
    report "success" "SSH key already exists at ~/.ssh/id_ed25519"
    # Any other ed25519 key already loaded by the agent must not count;
    # compare this key's fingerprint against the agent's listing.
    key_fingerprint="$(ssh-keygen -lf "$SSH_KEY.pub" 2>/dev/null | awk '{print $2}')"
    if [[ -z "$key_fingerprint" ]] || ! ssh-add -l 2>/dev/null | grep -qF "$key_fingerprint"; then
        eval "$(ssh-agent -s)"
        ssh-add "$SSH_KEY"
    fi
    echo
    note_present "GitHub SSH key (id_ed25519)"
    note_followup "To configure GitHub SSH (config block, signing, signers), run: $SCRIPT_DIR/setup-github-ssh.sh --key=$SSH_KEY"
fi

# --- nvm and Node.js -------------------------------------------------------

print_check_message "nvm"
if [[ -d "$HOME/.nvm" ]]; then
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091  # nvm.sh is sourced from the nvm install dir
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    version="$(nvm --version 2>/dev/null)"
    report "success" "nvm is installed"
    echo "  → version: ${GREEN}${version:-unknown}${RESET}"
    echo
    note_present "nvm ${version:-unknown}"
else
    report "info" "nvm not found; installing the latest release..."
    # The latest release tag comes from the GitHub API. Validate it
    # before building the installer URL from it, so a failed or empty
    # API response skips the install instead of curling a garbage URL.
    LATEST_NVM_VERSION="$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')"
    if [[ -z "$LATEST_NVM_VERSION" ]] || [[ ! "$LATEST_NVM_VERSION" =~ ^v[0-9]+(\.[0-9]+)*$ ]]; then
        report "error" "Could not resolve the latest nvm release tag; skipping the nvm install."
        note_followup "Install nvm manually: https://github.com/nvm-sh/nvm#installing-and-updating"
    else
        report "info" "Installing nvm ${LATEST_NVM_VERSION}..."
        # Download the installer to a unique temp file first so the
        # download result is known before any shell code runs and no
        # predictable path can be swapped underneath us; the install is
        # only recorded when the installer exits cleanly.
        NVM_INSTALLER="$(mktemp "${TMPDIR:-/tmp}/nvm-install.XXXXXX")"
        if curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${LATEST_NVM_VERSION}/install.sh" -o "$NVM_INSTALLER"; then
            if bash "$NVM_INSTALLER"; then
                export NVM_DIR="$HOME/.nvm"
                # shellcheck disable=SC1091  # nvm.sh is sourced from the nvm install dir
                [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
                # shellcheck disable=SC1091  # completion is sourced from the nvm install dir
                [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
                report "success" "nvm ${LATEST_NVM_VERSION} has been installed"
                note_added "nvm ${LATEST_NVM_VERSION}"
            else
                report "error" "The nvm installer failed; nvm was not installed."
                note_followup "Install nvm manually: https://github.com/nvm-sh/nvm#installing-and-updating"
            fi
        else
            report "error" "Could not download the nvm installer; skipping the nvm install."
            note_followup "Install nvm manually: https://github.com/nvm-sh/nvm#installing-and-updating"
        fi
        rm -f "$NVM_INSTALLER"
    fi
fi

print_check_message "Node.js"
node_major="$(node --version 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/')"
if ! check_command node || [[ "$node_major" != "$NODE_MAJOR_VERSION" ]]; then
    # nvm must be usable as a shell function before install/use/alias;
    # the nvm branches above source it after a successful install.
    if ! command -v nvm &>/dev/null; then
        report "error" "nvm is not available in this shell; skipping the Node.js install."
        note_followup "Install nvm first: https://github.com/nvm-sh/nvm#installing-and-updating"
    elif nvm install "$NODE_MAJOR_VERSION" && nvm use "$NODE_MAJOR_VERSION" && nvm alias default node; then
        note_added "Node.js $(cmd_version node) (via nvm)"
    else
        report "error" "nvm could not install or activate Node.js ${NODE_MAJOR_VERSION}."
        note_followup "Install Node.js manually: https://nodejs.org/en/download"
    fi
else
    note_present "Node.js ${CHECKED_VERSION}"
fi

# --- pnpm warning ----------------------------------------------------------

# pnpm installed through Homebrew sits outside corepack, the package
# manager that ships with Node.js, leaving two pnpm versions around.
# Surface it so it can be cleaned up when present.
if brew list pnpm &>/dev/null; then
    report "warning" "pnpm is installed through Homebrew, which can shadow the version managed by corepack."
    report "warning" "Suggested fix: brew uninstall pnpm, then enable it via corepack (corepack enable pnpm)."
fi

# --- Applications ----------------------------------------------------------

install_app iTerm iTerm2 iterm2

# IDE Selection
if [[ -n "$ARG_IDE" ]]; then
    apply_ide_flag "$ARG_IDE"
else
    select_ides
fi

if [[ "$install_vscode" = true ]]; then
    install_app "Visual Studio Code" "VS Code" visual-studio-code
fi

if [[ "$install_cursor" = true ]]; then
    install_app Cursor Cursor cursor
fi

# The presence check is the docker CLI but the install is the cask and
# the reported version is the GUI app's, so this stays a hybrid block
# rather than install_app or install_cmd.
print_check_message "Docker"
if ! check_command docker; then
    if brew_install --cask docker; then
        note_added "Docker $(app_version Docker)"
    fi
else
    note_present "Docker ${CHECKED_VERSION}"
fi

install_cmd docker-compose

install_cmd aws "AWS CLI" awscli

install_app Postman Postman postman

install_app Rectangle Rectangle rectangle

# Browser and communication apps
install_app "Google Chrome" "Google Chrome" google-chrome
install_app Slack Slack slack
install_app Discord Discord discord
install_app Telegram Telegram telegram
install_app Signal Signal signal
install_app WhatsApp WhatsApp whatsapp

install_cmd jq

# GitHub CLI
print_check_message "GitHub CLI"
if ! check_command gh; then
    if brew_install gh; then
        report "info" "After installation, run '${GREEN}gh auth login${RESET}' to authenticate with GitHub"
        report "info" "The CLI will request permissions including 'Full control of public keys', which is needed for SSH key management"
        report "info" "These permissions are safe and only affect your GitHub.com account, not your local system"
        note_added "GitHub CLI (gh) $(cmd_version gh)"
        GH_JUST_INSTALLED=true
    fi
else
    note_present "GitHub CLI (gh) ${CHECKED_VERSION}"
fi

# Password Manager Selection
if [[ -n "$ARG_PASSWORD_MANAGER" ]]; then
    apply_password_manager_flag "$ARG_PASSWORD_MANAGER"
else
    select_password_managers
fi

if [[ "$install_macpass" = true ]]; then
    install_app MacPass MacPass macpass
fi

if [[ "$install_1password" = true ]]; then
    install_app 1Password 1Password 1password
fi

# --- Shell setup -----------------------------------------------------------

# Check and set zsh as the default shell
print_check_message "zsh shell" "is the default shell"
check_default_shell
shell_status=$?
if (( shell_status == 2 )); then
    note_followup "Set zsh as the default shell manually: chsh -s $(which zsh)"
elif (( shell_status == 1 )); then
    report "warning" "Please restart your terminal after the script finishes for the shell change to take effect."
    note_added "zsh set as the default shell (${ZSH_VERSION})"
    note_followup "Restart the terminal to pick up the new default shell"
else
    note_present "zsh as the default shell (${ZSH_VERSION})"
fi

# Install oh-my-zsh if not present
print_check_message "oh-my-zsh"
if ! check_oh_my_zsh; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    note_added "oh-my-zsh $(omz_version)"
else
    note_present "oh-my-zsh $(omz_version)"
fi

# --- Summary ---------------------------------------------------------------

# Fold the GitHub SSH setup result into the final summary. This section
# only exists when the standalone script actually ran (new key branch).
if [[ -n "${SECURE_OUTPUT:-}" ]]; then
    echo
    echo "${BOLD}${BLUE}════ GitHub security ════${RESET}"
    echo
    echo "$SECURE_OUTPUT"
    echo
fi

if [[ "$GH_JUST_INSTALLED" = true ]]; then
    note_followup "Run 'gh auth login' to authenticate with GitHub"
fi

print_run_summary

echo
echo "${BOLD}Done!${RESET}"
