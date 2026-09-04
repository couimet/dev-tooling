# Changelog

<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.

This project uses [Calendar Versioning](https://calver.org/) with the format `YYYY.0M.0D` (e.g., `2026.08.19`). When multiple versions land on the same day, a micro suffix is appended: `2026.08.19.2`, `2026.08.19.3`, etc.

Entries are organized using [Keep a Changelog](https://keepachangelog.com/) categories: **Added**, **Changed**, **Fixed**, **Removed**. Not every release uses every category; include only the ones that apply.

## 2026.09.04

### Added

- `setup-osx.sh` now accepts `--skip <id[,id...]>` to install everything except the listed tools and apps, and `--pick <id[,id...]>` to install only the listed ones. Every installable application and CLI tool in the catalog has a stable identifier; the ids are listed (sorted) by `--help`, each flag takes one or more comma-separated ids and may be repeated, and the two flags are mutually exclusive. A `--pick` run skips the up-front IDE and password-manager menus and rejects `--ide`/`--password-manager`; a `--skip` run still asks them for the members it did not skip. Leaving an app out also leaves its extension injection alone (Chrome, VS Code, Cursor). Units left out by either flag are reported at their step and listed under a new Skipped section of the run summary; the base toolchain (Homebrew, Git, git identity and GitHub SSH, nvm/Node, yarn, and the shell setup) always installs, and brew still resolves each package's own dependencies. ([issues/14](https://github.com/couimet/dev-tooling/issues/14))

## 2026.09.03

### Changed

- `setup-osx.sh` now asks the IDE and password-manager questions at the very start of the run, before anything is installed, so they are answered up front and no longer interrupt the run after installation has started; install and command steps may still prompt on their own. The `--ide` and `--password-manager` flags continue to bypass both menus entirely; only the interactive path moves the questions up front. ([issues/35](https://github.com/couimet/dev-tooling/issues/35))

## 2026.08.28

### Added

- `setup-osx.sh` now force-loads a set of developer-focused Chrome extensions by writing Chrome's per-user "External Extensions" preference files under `~/Library/Application Support/Google/Chrome/External Extensions/`, one JSON file per extension pointing at the Chrome Web Store update URL. The list covers React Developer Tools, JSONVue, 1Password, Redux DevTools, and Vue.js devtools. The write is idempotent, so an already present extension is reported rather than rewritten; newly added extensions take effect only after Chrome restarts and are enabled in chrome://extensions, which the run summary flags as a follow-up. ([issues/17](https://github.com/couimet/dev-tooling/issues/17))

## 2026.08.27.1

### Added

- `setup-osx.sh` now installs [starship](https://starship.rs/), an opinionated cross-shell prompt, through Homebrew. The Nerd Font prerequisite listed on the starship site is covered by installing the FiraCode Nerd Font cask, leaving the per-terminal font selection as a documented follow-up. When no `~/.config/starship.toml` exists, the script writes its own opinionated prompt config; a config that has drifted from it is reported and left untouched, never overwritten. The `eval "$(starship init zsh)"` line is added to `~/.zshrc` so the prompt loads in every new shell. ([issues/19](https://github.com/couimet/dev-tooling/issues/19))

## 2026.08.27

### Added

- `setup-osx.sh` now enables `yarn` through corepack, the package manager bundled with Node.js, so yarn runs under the nvm-managed Node instead of a Homebrew install that would drag in its own Node.js. The existing Homebrew warning now also flags a brew-installed yarn, which would shadow the version corepack manages, matching the existing pnpm warning. ([issues/26](https://github.com/couimet/dev-tooling/issues/26))

## 2026.08.26.2

### Added

- setup-osx.sh now completes the nvm install by writing the nvm loader into `~/.zshrc`: it creates `~/.nvm`, exports `NVM_DIR`, and sources `nvm.sh` plus its bash completion, so nvm and the Node.js versions it manages load in every new shell instead of only the setup run. A pre-existing Homebrew-installed nvm is detected from the `brew --prefix nvm` opt path and honored with the matching brew loader instead of being reinstalled. ([issues/20](https://github.com/couimet/dev-tooling/issues/20))

## 2026.08.26.1

### Added

- `setup-osx.sh` now installs the 1Password CLI (`op`, from the `1password-cli` cask) on every run, independently of the `--password-manager` choice, which continues to govern only the GUI password apps. The CLI is what automation and scripts reach for, so it is installed as a default tool rather than something you opt into. ([issues/25](https://github.com/couimet/dev-tooling/issues/25))
- CLIs distributed as Homebrew casks are now installed through the same path as every other command-line tool, so they report the same "Already present" and version lines in the run summary and produce the same manual-install follow-up when the cask install fails. Claude Code and Docker, which each previously had their own hand-written install block, now go through that path too; Docker keeps reporting the version of its GUI app on a fresh install, as it always has. ([issues/25](https://github.com/couimet/dev-tooling/issues/25))

## 2026.08.26

### Added

- `setup-osx.sh` now installs a batch of Kubernetes, Terraform, testing, and scanning CLIs alongside the existing tooling: kubectl, helm, kustomize, argocd, velero, yq, pre-commit, trivy, terraform, tflint, terraform-docs, and bats (the `bats-core` formula), which the repo's own test suite runs under. terraform and tflint have left homebrew-core, so they are installed from their projects' own taps (`hashicorp/tap` and `terraform-linters/tap`), which the script adds only when the command is actually missing; note that terraform ships under the Business Source License. ([issues/23](https://github.com/couimet/dev-tooling/issues/23))
- The run summary now reports real versions for tools that expose their version through a `version` subcommand rather than a `--version` flag (kubectl, helm, kustomize, argocd, velero), so those lines no longer read "unknown". The client-scoped form is used where one exists, so the check never waits on a cluster or a server. ([issues/23](https://github.com/couimet/dev-tooling/issues/23))

## 2026.08.24.2

### Fixed

- setup-osx.sh now installs oh-my-zsh with the installer's `--unattended` flag, so it no longer launches an interactive zsh that hijacks the rest of the run on a fresh machine. ([issues/15](https://github.com/couimet/dev-tooling/issues/15))

## 2026.08.24.1

### Added

- setup-osx.sh now installs a shared list of recommended extensions for VS Code and Cursor (including rangelink-vscode-extension) into every IDE found on disk, independently of the `--ide` selection. ([issues/11](https://github.com/couimet/dev-tooling/issues/11))

## 2026.08.24

### Added

- Claude Code added to the tools `setup-osx.sh` installs via the `claude-code` cask, with a `claude` command presence check, granular per-tool feedback, and a manual-install follow-up when the cask install fails. ([issues/10](https://github.com/couimet/dev-tooling/issues/10))

## 2026.08.19

### Added

- Version stamping for the setup scripts: the local [stamp-version-calver action](.github/actions/stamp-version-calver) derives a `CalVer@SHA` version string from the top entry of this changelog plus the current git SHA and stamps it into the scripts (with flexibility about paths and destination variables). Each file carries its own copy (the entry scripts under `VERSION`, `utils.sh` under `VERSION_UTILS`), so a stale script reports its own stamp instead of inheriting a fresh one from the shared helpers. The `.github/workflows/stamp-version-calver.yml` workflow re-stamps the scripts on every push to main and commits the result with `[skip ci]`, so the shipped scripts always carry the latest version. ([issues/3](https://github.com/couimet/dev-tooling/issues/3))

## 2026.08.18

### Added

- `setup-osx.sh` reworked around shared helpers in `scripts/utils.sh` with idempotency as a first-class property: every step checks before it acts, re-runs report "Already present" with versions, a freshness check guards against stale copies, and each run ends with a combined summary and a timestamped, color-free log. ([PR #2](https://github.com/couimet/dev-tooling/pull/2))
- Standalone `scripts/setup-github-ssh.sh` for GitHub SSH setup: writes the `github.com` block to `~/.ssh/config`, enables SSH commit signing only when unset, and appends to `allowed_signers` without clobbering other signers; supports `--key` and `--help` and logs its own runs.
- Non-interactive flags on `setup-osx.sh`: `--ide <vscode|cursor|both|skip>` and `--password-manager <macpass|1password|both|skip>`, with the interactive prompts kept as fallback.
- Browser and communication apps (Chrome, Slack, Discord, Telegram, Signal, WhatsApp) added to the setup.
- A BATS suite of 88 tests covering every branch of the three scripts, a CI workflow that runs it on every push and PR to main with a sticky PR comment, a shellcheck linting job with zsh directives, and a zsh syntax check on the macOS job.

### Changed

- Helper downloads are checked after every transfer and cached copies are replaced only when all of them succeed; nvm is reported as installed only when the installer actually ran and exited cleanly; a leading `~/` in the Git SSH signers path is normalized to `$HOME` before the file is created.
- `setup-osx.sh` warns about pnpm installed via brew and checks which Git brew owns.

## 2025.02.20

### Added

- `setup-osx.sh` script to set up a macOS dev laptop for an [upcoming role at Octav Labs](https://ouimet.info/#changelog-7-0-0).
