#!/bin/zsh
# shellcheck shell=bash  # linted as bash; zsh-only lines carry their own disables

# Shared helpers sourced by the setup-* scripts in this repo.
# Not meant to be executed on its own.

# Stamped CalVer version: replaced on every push to main by the
# stamp-version-calver workflow. The seed placeholder is never shipped.
# Uses a distinct name so sourcing this file cannot clobber the entry
# scripts' own VERSION assignments.
# shellcheck disable=SC2034  # stamped metadata, inspected manually; not read at runtime
VERSION_UTILS="2026.08.27.1@84ec93b"

# --- Colors and text styles --------------------------------------------

BOLD='\033[1m'
GREEN='\033[32m'
BLUE='\033[34m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

# --- Status reporting ---------------------------------------------------

# report <level> <message>
# Prints a single status line. Levels: info, success, warning, error.
report() {
    local level="$1"
    local message="$2"

    case "$level" in
        info)    echo "ℹ️  ${BLUE}INFO${RESET}    ${message}" ;;
        success) echo "✅ ${GREEN}SUCCESS${RESET} ${message}" ;;
        warning) echo "⚠️  ${YELLOW}WARNING${RESET} ${message}" ;;
        error)   echo "❌ ${RED}ERROR${RESET}   ${message}" ;;
        *)       echo "${message}" ;;
    esac
}

# --- Environment checks -------------------------------------------------

# Pause the run until the user presses Enter.
press_enter() {
    local message="${1:-Press Enter to continue...}"
    report "info" "$message"
    read -r
}

# ensure_fresh <path-in-repo> <display-name>
# Verifies the running script matches origin/main. Prompts to continue or
# abort when it does not. No-op when not inside a git clone or offline.
ensure_fresh() {
    local script_path="$1"
    local display_name="$2"
    local repo_root
    # shellcheck disable=SC2296  # zsh-specific script path expansion
    repo_root="$(cd "$(dirname "${(%):-%x}")/.." && pwd)" || return 0

    report "info" "Checking if ${display_name} is up-to-date with the remote..."
    git -C "$repo_root" rev-parse --is-inside-work-tree &>/dev/null || return 0
    # The check only means anything when the clone actually tracks this
    # script; on piped runs repo_root resolves outside the real checkout
    # and an unrelated clone must not be fetched from or diffed.
    [[ -f "$repo_root/$script_path" ]] || return 0

    if ! git -C "$repo_root" fetch origin &>/dev/null; then
        report "warning" "Could not reach the remote; skipping the version check."
        return 0
    fi

    if git -C "$repo_root" diff --quiet "origin/main" -- "$script_path"; then
        report "success" "${display_name} is up-to-date."
        return 0
    fi

    report "warning" "${display_name} has updates on the remote."
    report "info" "Abort to pull the latest version, or continue with this copy? (abort/continue)"
    local answer
    read -r answer
    if [[ "$answer" =~ ^(abort|a|n|no)$ ]]; then
        report "info" "Aborting. Run 'git pull origin main' in ${repo_root} and try again."
        exit 1
    fi
    report "warning" "Continuing with the current copy."
}

# --- Run logging --------------------------------------------------------

# start_run_log <log-basename>
# Mirrors the rest of the run to the console and to a timestamped log file
# in the invocation directory. Escape codes are stripped from the file so
# run-to-run diffs stay readable. Prints the log path.
LOG_FILE=""

start_run_log() {
    local basename="$1"
    local esc=$'\033'
    LOG_FILE="$(pwd)/${basename}-$(date +%Y-%m-%d-%H-%M-%S).log"
    # macOS ships BSD sed, which rejects GNU's -u and would leave the
    # log empty; -l is its line-buffered equivalent.
    exec > >(tee >(sed -l -E "s/${esc}\[[0-9;]*[A-Za-z]//g" > "$LOG_FILE")) 2>&1
    report "info" "Run log: ${GREEN}${LOG_FILE}${RESET}"
    echo
}

# --- Summary tracking ---------------------------------------------------

SUMMARY_ADDED=()
SUMMARY_PRESENT=()
SUMMARY_FOLLOWUPS=()

note_added()    { SUMMARY_ADDED+=("$1"); }
note_present()  { SUMMARY_PRESENT+=("$1"); }
note_followup() { SUMMARY_FOLLOWUPS+=("$1"); }

# print_run_summary
# Renders the recorded actions as a final block. Sections are omitted
# when they have nothing to show.
print_run_summary() {
    echo
    echo "${BOLD}${BLUE}════ Run summary ════${RESET}"
    echo

    if (( ${#SUMMARY_ADDED} > 0 )); then
        echo "${BOLD}Installed:${RESET}"
        for item in "${SUMMARY_ADDED[@]}"; do
            echo "  ${GREEN}✔${RESET} $item"
        done
        echo
    fi

    if (( ${#SUMMARY_PRESENT} > 0 )); then
        echo "${BOLD}Already present:${RESET}"
        for item in "${SUMMARY_PRESENT[@]}"; do
            echo "  - $item"
        done
        echo
    fi

    if (( ${#SUMMARY_FOLLOWUPS} > 0 )); then
        echo "${BOLD}Follow-ups:${RESET}"
        for item in "${SUMMARY_FOLLOWUPS[@]}"; do
            echo "  ${BLUE}→${RESET} $item"
        done
        echo
    fi

    if [[ -n "$LOG_FILE" ]]; then
        echo "${BOLD}Run log:${RESET} ${GREEN}${LOG_FILE}${RESET}"
        echo
    fi
}
