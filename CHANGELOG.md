# Changelog

<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.

This project uses [Calendar Versioning](https://calver.org/) with the format `YYYY.0M.0D` (e.g., `2026.08.19`). When multiple versions land on the same day, a micro suffix is appended: `2026.08.19.2`, `2026.08.19.3`, etc.

Entries are organized using [Keep a Changelog](https://keepachangelog.com/) categories: **Added**, **Changed**, **Fixed**, **Removed**. Not every release uses every category; include only the ones that apply.

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
