#!/bin/zsh
# shellcheck shell=bash  # linted as bash; zsh-only lines carry their own disables

# Bootstrap script for a macOS development environment.
# Installs the day-to-day tooling for a development machine: Homebrew,
# Git, nvm/Node, command-line tools for Kubernetes, Terraform, testing,
# and scanning, a handful of applications, and GitHub SSH access.
# Every step checks first, so re-running the script is safe: anything
# already present is reported as such and nothing is reinstalled. The
# whole run is mirrored to a timestamped log file in the directory the
# script is invoked from (see the shared start_run_log helper).

# --- Configuration ----------------------------------------------------------

# Major version of Node.js to install and keep current through nvm.
NODE_MAJOR_VERSION=24

# IDE extensions installed through both the VS Code and Cursor CLIs.
# The IDs are shared between the two: VS Code Marketplace addresses an
# extension as publisher.name, Open VSX as publisher/name, but both
# CLIs accept the dot form, so one list works for both.
IDE_EXTENSIONS=(
    esbenp.prettier-vscode
    dbaeumer.vscode-eslint
    eamodio.gitlens
    pflannery.vscode-versionlens
    bierner.markdown-mermaid
    couimet.rangelink-vscode-extension
)

# Chrome extensions force-loaded for the current user by writing the
# per-user "External Extensions" JSON preference files Chrome reads on
# launch. Each entry is "<extension-id>;<display name>": the id is the
# 32-hex-char Web Store identifier, the display name is what the run
# summary shows. Newly written files only take effect once Chrome
# restarts and the extension is enabled in chrome://extensions, so a
# fresh write records both actions as a follow-up.
CHROME_EXTENSIONS=(
    "fmkadmapgofadopljbjfkapdkoienihi;React Developer Tools"
    "chklaanhfefbnpoihckbnefhakgolnmc;JSONVue"
    "aeblfdkhhhdcdjpifhhbdiojplfjncoa;1Password"
    "lmhkpmbekcpmknklioeibfkpmmfibljd;Redux DevTools"
    "nhdogjmejiglipccpnnnanhbledajbpd;Vue.js devtools"
)

# Base URL the script refreshes its shared helpers from when it runs
# from a raw pipe instead of a checkout; point it at a fork to test.
HELPERS_BASE_URL="https://raw.githubusercontent.com/couimet/dev-tooling/main/scripts"

# Stamped CalVer version: replaced on every push to main by the
# stamp-version-calver workflow. The seed placeholder is never shipped.
# Each script carries its own copy so a stale script reports its own
# version instead of inheriting a fresh one from the sourced helpers.
VERSION="2026.08.28@228156f"

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
  --version                   Print the stamped version and exit

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

# Report this script's own stamped CalVer@SHA version so piped runs
# (curl | zsh) show what they executed, and a stale script copy reports
# its own stamp rather than a fresh one from the sourced helpers.
report "info" "dev-tooling setup scripts ${VERSION}"

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

# Picks the version out of a version probe's output. Tools answering a
# `version` subcommand often print a header line first: velero leads with
# "Client:" and puts "Version: v1.18.2" on the line below, so taking the
# first line would record the header and throw the version away. Takes
# the first line carrying something version-shaped instead, trims the
# indentation such lines usually have, and falls back to the first line
# when nothing matches.
first_version_line() {
    awk '
        /[0-9]+\.[0-9]+/ {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "")
            print
            found = 1
            exit
        }
        NR == 1 { first = $0 }
        END {
            if (!found) {
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", first)
                print first
            }
        }
    '
}

# Utility function to check if a command exists.
# `command -v` is used instead of a plain -x test because it also finds
# shell functions such as nvm, which live in the shell environment and
# are not files on disk.
# Returns 0 when the command is present (and prints its version), and
# 1 when it is missing so the caller can run the install step.
# The version it found is left in CHECKED_VERSION so the caller can
# carry it into the run summary.
# The optional second parameter is the argument list to ask for the
# version, given as a single string (for example "version --client").
# When set it replaces the --version / -v / -V ladder, which matters for
# tools whose bare version subcommand reaches for a cluster or a server.
# When absent the ladder is used, so existing callers are unaffected.
check_command() {
    local cmd="$1" version_argv="${2:-}"
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
    if [[ -n "$version_argv" ]]; then
        # zsh does not word-split an unquoted $var, so ${=version_argv}
        # is what turns "version --client" into two arguments instead of
        # one; without it every multi-word probe would fail silently and
        # report "unknown".
        # shellcheck disable=SC2086  # word splitting is the intent; ${=var} forces it in zsh
        if $cmd ${=version_argv} &>/dev/null; then
            # shellcheck disable=SC2086  # word splitting is the intent; ${=var} forces it in zsh
            version="$($cmd ${=version_argv} | first_version_line)"
        fi
    else
        # Try the common version flag patterns.
        if $cmd --version &>/dev/null; then
            version="$($cmd --version | head -n 1)"
        elif $cmd -v &>/dev/null; then
            version="$($cmd -v | head -n 1)"
        elif $cmd -V &>/dev/null; then
            version="$($cmd -V | head -n 1)"
        fi
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
# The optional second parameter is the argument list to ask for the
# version, in the same single-string form check_command takes (for
# example "version --client"); without it the command is asked for
# --version.
# Prints "unknown" when the command is missing or silent.
cmd_version() {
    local cmd="$1" version_argv="${2:-}"
    local version
    if [[ -n "$version_argv" ]]; then
        # As in check_command, ${=version_argv} is what makes zsh split a
        # multi-word probe into separate arguments.
        # shellcheck disable=SC2086  # word splitting is the intent; ${=var} forces it in zsh
        version="$("$cmd" ${=version_argv} 2>/dev/null | first_version_line)"
    else
        version="$("$cmd" --version 2>/dev/null | head -n 1)"
    fi
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

# Adds a Homebrew tap unless it is already there. `brew tap` with no
# arguments lists the tapped repos, so an already-tapped machine makes no
# network call. Reports and leaves a manual follow-up on failure, the way
# brew_install does, so the caller can skip an install that could not
# have resolved anyway.
brew_tap() {
    local tap="$1"
    if brew tap | grep -Fxq "$tap"; then
        return 0
    fi
    if brew tap "$tap"; then
        return 0
    fi
    report "error" "brew tap ${tap} failed."
    note_followup "Add the tap manually: brew tap ${tap}"
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
# The first three arguments are positional -- command, display, formula --
# and parsing stops at the first option, so a call can pass one, two, or
# three of them. These named options may follow and win over them:
#   --display <text>      what the run summary calls the tool
#   --formula <name>      the Homebrew formula to install
#   --cask <name>         the Homebrew cask to install instead of a
#                         formula, for a cask whose artifact is a
#                         command (mutually exclusive with --formula)
#   --version-cmd <argv>  argument list for the version probe, as a
#                         single string (see check_command)
#   --version-from-app <AppName>
#                         read the version a fresh install reports from
#                         that .app bundle instead of from the command,
#                         for a cask that installs a GUI app whose own
#                         version is the one worth recording
#   --tap <tap>           tap to add before installing, and only when the
#                         command turns out to be missing
install_cmd() {
    local command="" display="" formula="" cask="" version_argv="" tap="" version_from_app=""
    if [[ $# -gt 0 && "$1" != --* ]]; then
        command="$1"
        shift
    fi
    if [[ $# -gt 0 && "$1" != --* ]]; then
        display="$1"
        shift
    fi
    if [[ $# -gt 0 && "$1" != --* ]]; then
        formula="$1"
        shift
    fi
    while [[ $# -gt 0 ]]; do
        # Every option below takes a value. Without this guard a missing
        # one leaves $# at 1, "shift 2" then refuses to shift at all, and
        # the loop re-matches the same option forever. Treated like the
        # unknown-option case: one tool lost, the run carries on.
        case "$1" in
            --display|--formula|--cask|--version-cmd|--version-from-app|--tap)
                if (( $# < 2 )); then
                    report "error" "install_cmd ${command}: ${1} requires a value."
                    # a cask-only call has no formula to fall back on, so
                    # the hint has to name whichever of the two the call
                    # got as far as setting.
                    if [[ -n "$cask" ]]; then
                        note_followup "Install it manually: brew install --cask ${cask}"
                    else
                        note_followup "Install it manually: brew install ${formula:-$command}"
                    fi
                    return 1
                fi
                ;;
        esac
        case "$1" in
            --display)
                display="$2"
                shift 2
                ;;
            --formula)
                formula="$2"
                shift 2
                ;;
            --cask)
                cask="$2"
                shift 2
                ;;
            --version-cmd)
                version_argv="$2"
                shift 2
                ;;
            --version-from-app)
                version_from_app="$2"
                shift 2
                ;;
            --tap)
                tap="$2"
                shift 2
                ;;
            *)
                # An authoring mistake rather than a machine problem, so
                # give up on this one tool and keep going: silently
                # ignoring it could install the wrong formula, and
                # exiting would let one typo abort the whole run.
                report "error" "install_cmd ${command}: unknown option: $1"
                note_followup "Install it manually: brew install ${formula:-$command}"
                return 1
                ;;
        esac
    done
    # --formula and --cask name two different packages installed through
    # two different brew subcommands, so a call that passes both never
    # says which one it meant. Same treatment as an unknown option: lose
    # this one tool, keep the run going.
    if [[ -n "$formula" && -n "$cask" ]]; then
        report "error" "install_cmd ${command}: --formula and --cask are mutually exclusive."
        note_followup "Install it manually: brew install ${formula:-$command}"
        return 1
    fi
    display="${display:-$command}"
    # only a formula defaults to the command name. Defaulting one in for
    # a cask-only call would hand brew_install a package name nobody
    # asked for on top of the cask that was.
    if [[ -z "$cask" ]]; then
        formula="${formula:-$command}"
    fi

    print_check_message "$display"
    if ! check_command "$command" "$version_argv"; then
        # The tap is only worth adding when something has to be
        # installed. A failed tap skips the install too, since a formula
        # from a tap that is not there cannot resolve and trying anyway
        # would just stack a second, more confusing error on top.
        if [[ -n "$tap" ]] && ! brew_tap "$tap"; then
            return 1
        fi
        # a cask and a formula install through different brew
        # subcommands, and exactly one of the two is set by this point.
        # brew_install forwards "$@", so the --cask form carries into its
        # failure message and manual-install follow-up on its own.
        local -a install_args
        if [[ -n "$cask" ]]; then
            install_args=(--cask "$cask")
        else
            install_args=("$formula")
        fi
        if brew_install "${install_args[@]}"; then
            # A cask that installs a GUI app leaves two different
            # versions on the machine: the bundled command's and the
            # app's. --version-from-app picks the app's, which is the one
            # that matches what the cask just put in /Applications.
            if [[ -n "$version_from_app" ]]; then
                note_added "$display $(app_version "$version_from_app")"
            else
                note_added "$display $(cmd_version "$command" "$version_argv")"
            fi
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

# True when the profile has the literal line active: the line contains the
# literal and its first non-whitespace character is not a comment marker.
# A commented-out loader line must not be mistaken for a configured one,
# since the gate would then skip adding the active command. The literal is
# matched with index() so no regex escaping is needed for $, [, ] or $().
profile_has_active_line() {
    local profile="$1" literal="$2"
    awk -v pat="$literal" 'index($0, pat) && $0 !~ /^[[:space:]]*#/' "$profile" 2>/dev/null | grep -q .
}

# Resolves a path that is a symlink to the file it ultimately names, so an
# atomic write lands in the link target instead of replacing the link with a
# regular file. Follows chained links with plain readlink (readlink -f is
# unavailable before macOS 26), resolving relative targets against the link's
# directory and capping the chase at 40 hops so a circular chain cannot
# hang; a broken link resolves to its absent target, which the write
# functions then create. Echoes the resolved path. The parameter is not
# named `path` because zsh's `path` array backs PATH and shadowing it in a
# function breaks command lookup inside the function.
resolve_write_target() {
    local current="$1" target
    for _ in {1..40}; do
        [[ -L "$current" ]] || break
        target="$(readlink "$current" 2>/dev/null)" || break
        if [[ "$target" == /* ]]; then
            current="$target"
        else
            current="$(dirname "$current")/$target"
        fi
    done
    printf '%s\n' "$current"
}

# Appends a block to a file atomically: copies the file to a same-directory
# temp (or starts an empty temp when the file does not yet exist), appends
# stdin to the temp, then mv's it over the original, so an interrupted run
# leaves the original file intact and the next run repairs cleanly. A
# symlinked target resolves to the file it names, so the link stays intact
# and the block lands in its target. Returns nonzero when the target exists
# but is not a regular file, or when copying an existing target fails, so a
# write into a directory or a failed copy is reported instead of replacing
# the profile.
append_atomic() {
    local file="$1" tmp
    file="$(resolve_write_target "$file")"
    [[ -f "$file" || ! -e "$file" ]] || return 1
    tmp="${file}.tmp.$$"
    if ! cp "$file" "$tmp" 2>/dev/null; then
        [[ ! -e "$file" ]] || { rm -f "$tmp"; return 1; }
        : > "$tmp" || { rm -f "$tmp"; return 1; }
    fi
    if cat >> "$tmp" && mv "$tmp" "$file"; then
        return 0
    fi
    rm -f "$tmp"
    return 1
}

# Writes a block to a file atomically: writes stdin to a same-directory temp
# then mv's it over the target, so an interrupted run never leaves a
# truncated file that a re-run would mistake for existing content. A
# symlinked target resolves to the file it names, so the link stays intact
# and the block lands in its target. Returns nonzero when the target exists
# but is not a regular file, so a write into a directory path is reported as
# a failure instead of moving the temp into it.
atomic_write() {
    local file="$1" tmp
    file="$(resolve_write_target "$file")"
    [[ -f "$file" || ! -e "$file" ]] || return 1
    tmp="${file}.tmp.$$"
    if cat > "$tmp" && mv "$tmp" "$file"; then
        return 0
    fi
    rm -f "$tmp"
    return 1
}

# Makes nvm load in every new shell. nvm's own installer (and brew's
# caveat) require ~/.nvm to exist and the shell profile to export NVM_DIR
# and source nvm.sh plus its bash completion; the nvm block above only
# configures the current shell. Idempotent: appends the whole block only
# when any of the three loader lines is missing, so re-runs never
# duplicate a complete loader and a partial one (e.g. only the export,
# left by another tool) gets repaired instead of reported as configured.
ensure_nvm_profile() {
    mkdir -p "$HOME/.nvm"
    local profile="$HOME/.zshrc"
    if [[ "$NVM_LAYOUT" == "brew" ]]; then
        # Homebrew layout: NVM_DIR is still the data dir, but nvm.sh and
        # its completion live in the keg opt prefix, so the gate and the
        # written lines carry the concrete brew paths.
        # shellcheck disable=SC2016  # the literal $HOME in the export is the point
        if profile_has_active_line "$profile" 'export NVM_DIR="$HOME/.nvm"' \
            && profile_has_active_line "$profile" "[ -s \"$NVM_BREW_PREFIX/nvm.sh\" ]" \
            && profile_has_active_line "$profile" "[ -s \"$NVM_BREW_PREFIX/etc/bash_completion.d/nvm\" ]"; then
            report "success" "nvm shell profile is already configured in ~/.zshrc"
            note_present "nvm shell profile (~/.zshrc)"
            return 0
        fi
        # Unquoted heredoc so the brew paths interpolate now; $HOME is
        # escaped so NVM_DIR still resolves at login time. A failed append
        # is reported and returns nonzero so the run never records a
        # loader that did not land in the profile.
        if ! append_atomic "$profile" <<EOF

# nvm (added by the dev-tooling setup script)
export NVM_DIR="\$HOME/.nvm"
[ -s "$NVM_BREW_PREFIX/nvm.sh" ] && \. "$NVM_BREW_PREFIX/nvm.sh"  # This loads nvm
[ -s "$NVM_BREW_PREFIX/etc/bash_completion.d/nvm" ] && \. "$NVM_BREW_PREFIX/etc/bash_completion.d/nvm"  # This loads nvm bash_completion
EOF
        then
            report "error" "Failed to write the nvm loader to ~/.zshrc"
            note_followup "Add to ~/.zshrc: export NVM_DIR=\"\$HOME/.nvm\"; [ -s \"$NVM_BREW_PREFIX/nvm.sh\" ] && \. \"$NVM_BREW_PREFIX/nvm.sh\"; [ -s \"$NVM_BREW_PREFIX/etc/bash_completion.d/nvm\" ] && \. \"$NVM_BREW_PREFIX/etc/bash_completion.d/nvm\""
            return 1
        fi
        report "info" "Added the nvm loader to ~/.zshrc"
        note_added "nvm shell profile (~/.zshrc)"
        return 0
    fi
    # The export alone does not load nvm, so the gate is the whole trio:
    # a profile with only NVM_DIR set must be repaired, not reported as
    # configured. Each pattern is quoted so the literal $HOME and $NVM_DIR
    # are what is searched for in the profile.
    # shellcheck disable=SC2016  # the literal $HOME and $NVM_DIR are the point
    if profile_has_active_line "$profile" 'export NVM_DIR="$HOME/.nvm"' \
        && profile_has_active_line "$profile" '[ -s "$NVM_DIR/nvm.sh" ]' \
        && profile_has_active_line "$profile" '[ -s "$NVM_DIR/bash_completion" ]'; then
        report "success" "nvm shell profile is already configured in ~/.zshrc"
        note_present "nvm shell profile (~/.zshrc)"
        return 0
    fi
    # Quoted heredoc so the literal $HOME and $NVM_DIR land in the
    # profile and resolve at login time instead of during this run.
    # The append is atomic: the whole block is written to a same-directory
    # temp that is mv'd into place, so the export always lands before the
    # sources even when repairing a partial state, and an already-present
    # line is merely duplicated (same value, idempotent) rather than
    # reordered. A failed append is reported and returns nonzero so the run
    # never records a loader that did not land in the profile.
    if ! append_atomic "$profile" <<'EOF'

# nvm (added by the dev-tooling setup script)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
EOF
    then
        report "error" "Failed to write the nvm loader to ~/.zshrc"
        note_followup "Add to ~/.zshrc: export NVM_DIR=\"\$HOME/.nvm\"; [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"; [ -s \"\$NVM_DIR/bash_completion\" ] && \. \"\$NVM_DIR/bash_completion\""
        return 1
    fi
    report "info" "Added the nvm loader to ~/.zshrc"
    note_added "nvm shell profile (~/.zshrc)"
    return 0
}

# The opinionated starship.toml this script installs and compares against.
# Embedded here so the script is the source of truth: the config is written
# as-is when missing and drift is detected by byte comparison. Trailing
# whitespace is significant, so the heredoc is quoted and never edited.
starship_expected_config() {
    cat <<'EOF'
format = """
$username@$hostname:$directory \
$git_branch\
$git_status\
$nodejs\
$ruby\
$python\
$nix_shell\
$gcloud\
$time\
$line_break\
$character"""

[directory]
truncation_length = 10  # how many parent dirs to show
truncate_to_repo = false  # set to true if you want it to truncate at git repo root
format = "[$path]($style)"
style = "cyan bold"

[username]
show_always = true
format = "[$user]($style)"
style_user = "green bold"

[hostname]
ssh_only = false  # show even when not SSH
format = "[$hostname]($style)"
style = "green bold"

[git_status]
stashed = "" # "📦" # change the $ symbol
untracked = "🆕" # change the ? symbol

[python]
disabled = true

[nix_shell]
disabled = true

[gcloud]
disabled = true

[time]
disabled = false
format = '[$time]($style) '
time_format = '%T'
style = 'bold yellow'
EOF
}

# Appends the starship init line to ~/.zshrc so the prompt loads in every
# new shell. Idempotent: appends the block only when the eval line is
# missing, so re-runs never duplicate it. Modeled on ensure_nvm_profile;
# must run after the oh-my-zsh step, whose installer can replace ~/.zshrc.
ensure_starship_profile() {
    local profile="$HOME/.zshrc"
    # shellcheck disable=SC2016  # the literal $() in the profile line is the point
    if profile_has_active_line "$profile" 'eval "$(starship init zsh)"'; then
        report "success" "starship shell profile is already configured in ~/.zshrc"
        note_present "starship shell profile (~/.zshrc)"
        return 0
    fi
    if ! append_atomic "$profile" <<'EOF'

# Starship prompt (added by the dev-tooling setup script)
eval "$(starship init zsh)"
EOF
    then
        report "error" "Failed to write the starship init line to ~/.zshrc"
        note_followup "Add to ~/.zshrc: eval \"\$(starship init zsh)\""
        return 1
    fi
    report "info" "Added the starship init line to ~/.zshrc"
    note_added "starship shell profile (~/.zshrc)"
    return 0
}

# Resolves the extension CLI binary for an IDE (vscode or cursor): the
# command on PATH first, then the binary bundled inside the app so an
# IDE installed from a Homebrew cask (which does not add the CLI to
# PATH) is still found. Prints only the resolved path and returns 0, or
# prints nothing and returns 1 when the IDE is not on disk. APPS_DIR
# lets tests point the check at a fake Applications directory; real runs
# keep the default.
find_extension_cli() {
    local ide="$1"
    local cli app_path
    case "$ide" in
        vscode)
            cli="code"
            app_path="${APPS_DIR:-/Applications}/Visual Studio Code.app/Contents/Resources/app/bin/code"
            ;;
        cursor)
            cli="cursor"
            app_path="${APPS_DIR:-/Applications}/Cursor.app/Contents/Resources/app/bin/cursor"
            ;;
        *) return 1 ;;
    esac
    if command -v "$cli" &>/dev/null; then
        command -v "$cli"
        return 0
    fi
    if [[ -x "$app_path" ]]; then
        echo "$app_path"
        return 0
    fi
    return 1
}

# Installs the shared IDE extension list through every IDE found on
# disk, independent of which IDE the run was asked to install: both a
# pre-existing IDE and one installed earlier in the same run get the
# extensions. Each extension is reported in the run summary as present
# (already installed, from --list-extensions), added, or a manual
# install follow-up on failure. --install-extension is idempotent, so
# the already-installed case is reported, not re-installed.
install_ide_extensions() {
    local ide display cli installed id
    for ide in vscode cursor; do
        if [[ "$ide" == "vscode" ]]; then
            display="VS Code"
        else
            display="Cursor"
        fi
        if ! cli="$(find_extension_cli "$ide")"; then
            report "info" "No ${display} installation found; skipping its extensions."
            continue
        fi
        installed="$("$cli" --list-extensions 2>/dev/null)"
        for id in "${IDE_EXTENSIONS[@]}"; do
            if grep -qxF "$id" <<<"$installed"; then
                note_present "${display}: $id"
            elif "$cli" --install-extension "$id" &>/dev/null; then
                note_added "${display}: $id"
            else
                report "error" "Failed to install $id for ${display}."
                note_followup "Install it manually: $cli --install-extension $id"
            fi
        done
    done
}

# Force-loads the Chrome extension list through Chrome's per-user
# "External Extensions" preference directory: one JSON file per
# extension, named after its Web Store ID, pointing at the Web Store
# update URL. Writing the file is idempotent, so an existing file is
# reported as present rather than rewritten. Chrome picks the files up
# on launch, so a newly written file only takes effect once Chrome
# restarts and the extension is enabled in chrome://extensions; a fresh
# write records both as a follow-up. The step is skipped when Chrome is
# not on disk; APPS_DIR
# lets tests point the check at a fake Applications directory, real
# runs keep the default.
install_chrome_extensions() {
    local entry id name json_path added=0
    if [[ ! -d "${APPS_DIR:-/Applications}/Google Chrome.app" ]]; then
        report "info" "No Chrome installation found; skipping its extensions."
        return 0
    fi
    print_check_message "Chrome extensions"
    local ext_dir="$HOME/Library/Application Support/Google/Chrome/External Extensions"
    for entry in "${CHROME_EXTENSIONS[@]}"; do
        id="${entry%%;*}"
        name="${entry#*;}"
        json_path="$ext_dir/$id.json"
        if [[ -f "$json_path" ]]; then
            note_present "Chrome: $name"
            continue
        fi
        mkdir -p "$ext_dir"
        if printf '%s\n' '{"external_update_url": "https://clients2.google.com/service/update2/crx"}' > "$json_path.tmp" && mv "$json_path.tmp" "$json_path"; then
            note_added "Chrome: $name"
            added=1
        else
            rm -f "$json_path.tmp"
            report "error" "Failed to write the Chrome extension preference for $name."
            note_followup "Add it manually: https://chrome.google.com/webstore/detail/$id"
        fi
    done
    if (( added )); then
        note_followup "Restart Chrome, then enable the newly added extensions in chrome://extensions"
    fi
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
export NVM_DIR="$HOME/.nvm"
NVM_LAYOUT=""
NVM_BREW_PREFIX=""
if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
    # nvm-sh layout, the copy this script installs and manages. It wins
    # over a brew install when both exist so a machine with both keeps
    # the self-contained copy under $HOME.
    NVM_LAYOUT="nvm-sh"
    # shellcheck disable=SC1091  # nvm.sh is sourced from the nvm install dir
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    # shellcheck disable=SC1091  # completion is sourced from the nvm install dir
    [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
    version="$(nvm --version 2>/dev/null)"
    report "success" "nvm is installed"
    echo "  → version: ${GREEN}${version:-unknown}${RESET}"
    echo
    note_present "nvm ${version:-unknown}"
else
    # Homebrew nvm (keg-only formula): nvm.sh lives in the Cellar opt
    # prefix, not in ~/.nvm, so a machine that already got nvm via brew is
    # honored instead of being reinstalled or left broken. `brew --prefix
    # nvm` resolves even when the formula is only tapped, so the nvm.sh
    # presence check, not the exit code, decides.
    brew_prefix="$(brew --prefix nvm 2>/dev/null)"
    if [[ -n "$brew_prefix" && -s "$brew_prefix/nvm.sh" ]]; then
        NVM_LAYOUT="brew"
        NVM_BREW_PREFIX="$brew_prefix"
        mkdir -p "$NVM_DIR"
        # shellcheck disable=SC1091  # nvm.sh is sourced from the brew keg
        source "$brew_prefix/nvm.sh"
        # shellcheck disable=SC1091  # completion is sourced from the brew keg
        [[ -s "$brew_prefix/etc/bash_completion.d/nvm" ]] && source "$brew_prefix/etc/bash_completion.d/nvm"
        version="$(nvm --version 2>/dev/null)"
        report "success" "nvm is installed (via Homebrew)"
        echo "  → version: ${GREEN}${version:-unknown}${RESET}"
        echo
        note_present "nvm ${version:-unknown} (Homebrew)"
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
                    # shellcheck disable=SC1091  # nvm.sh is sourced from the nvm install dir
                    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
                    # shellcheck disable=SC1091  # completion is sourced from the nvm install dir
                    [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
                    NVM_LAYOUT="nvm-sh"
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
fi

# Set when the nvm-managed Node cannot be activated in the present
# branch below, so the yarn section skips corepack enable instead of
# landing the shim under a non-nvm Node.
YARN_ENABLE_SKIPPED=0

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
    # The active node already reports the target major, but it may be a
    # Homebrew or system install rather than the nvm-managed copy. When
    # nvm is available, switch to its node so the corepack enable below
    # lands the yarn shim next to nvm's node; a failed switch stops yarn
    # provisioning so the shim cannot land under whatever node is active.
    if command -v nvm &>/dev/null && [[ "$(command -v node)" != "$NVM_DIR/versions/node/"* ]]; then
        if ! nvm use "$NODE_MAJOR_VERSION" &>/dev/null; then
            report "warning" "Could not switch to the nvm-managed Node.js ${NODE_MAJOR_VERSION}; skipping the yarn install."
            YARN_ENABLE_SKIPPED=1
        fi
    fi
    note_present "Node.js ${CHECKED_VERSION}"
fi

# --- yarn via corepack -----------------------------------------------------

# corepack ships with Node.js and manages yarn's version, so enabling
# yarn through it keeps yarn under the nvm-managed Node rather than a
# Homebrew install that drags in its own Node.js. The corepack shim
# lands in Node's bin directory, so yarn is available wherever nvm's
# Node is.
print_check_message "yarn"
if check_command yarn; then
    note_present "yarn ${CHECKED_VERSION}"
elif [[ "$YARN_ENABLE_SKIPPED" == "1" ]]; then
    # The Node.js present branch sets this when the nvm-managed Node
    # could not be activated; enabling yarn here would land the shim
    # next to a non-nvm Node, so skip it and leave a manual path.
    report "error" "Skipping the yarn install because the nvm-managed Node.js ${NODE_MAJOR_VERSION} could not be activated."
    note_followup "Switch to the nvm-managed Node.js (nvm use ${NODE_MAJOR_VERSION}), then enable yarn with: corepack enable yarn"
else
    if ! command -v corepack &>/dev/null; then
        report "error" "corepack is not available; skipping the yarn install."
        note_followup "Install corepack (npm install -g corepack), then enable yarn with: corepack enable yarn"
    elif corepack enable yarn; then
        # corepack enable only creates the shim; the first yarn probe
        # downloads the pinned version and needs network access, so the
        # version can legitimately come back unknown. Only record the
        # install when a real version answered, and leave a manual
        # follow-up otherwise.
        yarn_version="$(cmd_version yarn)"
        if [[ "$yarn_version" == "unknown" ]]; then
            report "error" "corepack enabled yarn, but its version could not be determined; it may need network access on first use."
            note_followup "Verify yarn works manually: yarn --version"
        else
            note_added "yarn ${yarn_version}"
        fi
    else
        report "error" "corepack could not enable yarn."
        note_followup "Enable yarn manually: corepack enable yarn"
    fi
fi

# --- pnpm and yarn warnings -------------------------------------------------

# pnpm or yarn installed through Homebrew sits outside corepack, the
# package manager that ships with Node.js, leaving two versions around.
# Surface either one so it can be cleaned up when present.
if brew list pnpm &>/dev/null; then
    report "warning" "pnpm is installed through Homebrew, which can shadow the version managed by corepack."
    report "warning" "Suggested fix: brew uninstall pnpm, then enable it via corepack (corepack enable pnpm)."
fi
if brew list yarn &>/dev/null; then
    report "warning" "yarn is installed through Homebrew, which can shadow the version managed by corepack."
    report "warning" "Suggested fix: brew uninstall yarn, then enable it via corepack (corepack enable yarn)."
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

# Extensions go to every IDE found on disk, independent of the --ide
# choice, so both pre-existing and freshly installed IDEs are covered.
install_ide_extensions

# The presence check is the docker CLI but the install is the cask, and
# the version a fresh install reports is the GUI app's rather than the
# CLI's, which is what --version-from-app is for.
install_cmd docker Docker --cask docker --version-from-app Docker

install_cmd docker-compose

install_cmd aws "AWS CLI" awscli

install_app Postman Postman postman

install_app Rectangle Rectangle rectangle

# Browser and communication apps
install_app "Google Chrome" "Google Chrome" google-chrome

# The extensions go in right after Chrome, so a freshly installed Chrome
# picks them up on its first launch.
install_chrome_extensions

install_app Slack Slack slack
install_app Discord Discord discord
install_app Telegram Telegram telegram
install_app Signal Signal signal
install_app WhatsApp WhatsApp whatsapp

install_cmd jq

# The test runner this repo's own suite runs under. The formula is
# bats-core; the command it installs is plain "bats".
install_cmd bats --formula bats-core

# Kubernetes tooling. The client-scoped version probes are not a
# nicety: a bare "velero version" or "argocd version" reaches out for a
# server, so an unqualified probe would stall or fail partway through a
# run on a machine with no kubeconfig.
install_cmd kubectl --formula kubernetes-cli --version-cmd "version --client"
install_cmd helm --version-cmd "version --short"
install_cmd kustomize --version-cmd version
install_cmd argocd --version-cmd "version --client"
install_cmd velero --version-cmd "version --client-only"

# Data wrangling and scanning
install_cmd yq
install_cmd pre-commit
install_cmd trivy

# terraform and tflint have both left homebrew-core, so a bare
# "brew install terraform" no longer resolves. Each now lives in its
# own project's tap, which install_cmd adds only when the command turns
# out to be missing. The tap-qualified formula names below are required,
# not decoration: shortening them back to bare names breaks the install.
install_cmd terraform --tap hashicorp/tap --formula hashicorp/tap/terraform
install_cmd tflint --tap terraform-linters/tap --formula terraform-linters/tap/tflint
install_cmd terraform-docs

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

install_cmd claude "Claude Code" --cask claude-code

# The 1Password CLI goes on every machine, independent of the
# --password-manager choice below: that choice is about the GUI apps,
# and scripts reaching for "op" should not have to care which one of
# them a given machine happens to have.
install_cmd op "1Password CLI" --cask 1password-cli

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

# Install oh-my-zsh if not present. --unattended stops the installer's
# final `exec zsh -l` from replacing this shell with an interactive one.
print_check_message "oh-my-zsh"
if ! check_oh_my_zsh; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    note_added "oh-my-zsh $(omz_version)"
else
    note_present "oh-my-zsh $(omz_version)"
fi

# Persist the nvm loader in ~/.zshrc so every new terminal still has
# nvm. This runs after the oh-my-zsh step because that installer
# replaces ~/.zshrc on a fresh install (backing up the old one), which
# would drop lines written earlier in the run; the nvm block above only
# configures the current shell. NVM_LAYOUT is set there for whichever
# layout was found or installed, so either one gets its profile written.
if [[ -n "$NVM_LAYOUT" ]]; then
    print_check_message "nvm shell profile" "is configured in ~/.zshrc"
    ensure_nvm_profile
fi

# --- Starship prompt -------------------------------------------------------

# starship is the opinionated prompt: brew provides the binary, a Nerd Font
# is the prerequisite the starship site lists (installed here, enabled per
# terminal by the user), and ~/.config/starship.toml is written from the
# embedded starship_expected_config when missing. A config that differs is
# reported as drift and never overwritten.
print_check_message "Starship"
starship_present=false
if check_command starship; then
    starship_present=true
    note_present "starship ${CHECKED_VERSION}"
else
    if brew_install starship; then
        starship_present=true
        note_added "starship $(cmd_version starship)"
    fi
fi

if [[ "$starship_present" == true ]]; then
    # The starship website lists "a Nerd Font installed and enabled in your
    # terminal" as a prerequisite. The cask installs the font; enabling it
    # per terminal stays a manual step so this script does not rewrite
    # iTerm2 plists or IDE settings files.
    print_check_message "FiraCode Nerd Font" "is installed"
    if brew list --cask font-fira-code-nerd-font &>/dev/null; then
        note_present "FiraCode Nerd Font"
    else
        if brew_install --cask font-fira-code-nerd-font; then
            note_added "FiraCode Nerd Font"
            note_followup "Enable the Nerd Font in your terminals (iTerm2: Preferences -> Profiles -> Text -> Font = 'FiraCode Nerd Font Mono'; VS Code/Cursor: terminal.integrated.fontFamily = 'FiraCode Nerd Font Mono')."
        fi
    fi

    # Opinionated prompt config. Written only when missing; an existing file
    # that differs from the embedded config is user customization and is
    # surfaced as drift rather than clobbered.
    mkdir -p "$HOME/.config"
    if [[ ! -f "$HOME/.config/starship.toml" ]]; then
        if starship_expected_config | atomic_write "$HOME/.config/starship.toml"; then
            note_added "starship prompt config (~/.config/starship.toml)"
        else
            report "error" "Could not write the starship prompt config."
            note_followup "Write ~/.config/starship.toml from the setup script's starship_expected_config."
        fi
    elif cmp -s "$HOME/.config/starship.toml" <(starship_expected_config); then
        note_present "starship prompt config (~/.config/starship.toml)"
    else
        report "warning" "Your ~/.config/starship.toml has been customized; it has drifted from the opinionated starship config in setup-osx.sh."
        note_followup "Review ~/.config/starship.toml against the setup script's starship_expected_config; the custom version is left untouched."
    fi

    # Load starship in every new shell. Runs after the oh-my-zsh step (see
    # the nvm profile note), so the append lands in the final ~/.zshrc.
    print_check_message "starship shell profile" "is configured in ~/.zshrc"
    ensure_starship_profile
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
