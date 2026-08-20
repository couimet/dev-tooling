# Changelog

<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.

This project uses [Calendar Versioning](https://calver.org/) with the format `YYYY.0M.0D` (e.g., `2026.08.19`). When multiple versions land on the same day, a micro suffix is appended: `2026.08.19.2`, `2026.08.19.3`, etc.

Entries are organized using [Keep a Changelog](https://keepachangelog.com/) categories: **Added**, **Changed**, **Fixed**, **Removed**. Not every release uses every category; include only the ones that apply.

## 2026.08.19

### Added

- Version stamping for the setup scripts: the local [stamp-version-calver action](.github/actions/stamp-version-calver) derives a `CalVer@SHA` version string from the top entry of this changelog plus the current git SHA and stamps it into the scripts (with flexibility about paths and destination variables). Each file carries its own copy (the entry scripts under `VERSION`, `utils.sh` under `VERSION_UTILS`), so a stale script reports its own stamp instead of inheriting a fresh one from the shared helpers. The `.github/workflows/stamp-version-calver.yml` workflow re-stamps the scripts on every push to main and commits the result with `[skip ci]`, so the shipped scripts always carry the latest version. ([issues/3](https://github.com/couimet/dev-tooling/issues/3))

