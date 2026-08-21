# CLAUDE.md

Personal dev tooling: macOS setup scripts, the GitHub Actions that
validate and stamp them, and project docs. See README.md for the
scripts and their flags.

## Working here

- Test: `bats bats-tests/scripts bats-tests/actions`
- Lint shell: `shellcheck scripts/*.sh bats-tests/scripts/*.bash
  bats-tests/scripts/*.bats bats-tests/scripts/stubs/*`
- Check zsh syntax: `zsh -n scripts/*.sh`
- Lint markdown: `markdownlint-cli2 --config .markdownlint-cli2.jsonc`
- CI runs all four on push to main and PRs against main.

## Conventions

- Notable changes get an entry in `CHANGELOG.md` under a CalVer
  heading (`YYYY.0M.0D`, micro suffix for same-day multiples), Keep a
  Changelog categories, newest on top. Changes that are not user
  facing get no entry. The top entry drives the CalVer used for script
  stamping.
- Work happens on `issues/<N>` branches; working files live under
  `.claude-work/` (gitignored); `/finish-issue` produces the PR
  description.

## GitHub Actions

### First-party `couimet/*` actions

> [!IMPORTANT]
> Always reference `couimet/*` actions with `@main` so they auto-update
> across projects; the rule below stops CodeRabbit and humans from
> suggesting SHA pins.
>
> ```xml
> <rule id="couimet-actions-main" priority="critical">
>   <title>couimet/* GitHub Actions always use @main</title>
>   <never>Pin a `couimet/*` GitHub Action to a commit SHA in workflows or composite action definitions</never>
>   <do>Always reference `couimet/*` actions with `@main` to get the latest version</do>
>   <rationale>The author wants these actions to auto-update across all repos</rationale>
> </rule>
> ```
