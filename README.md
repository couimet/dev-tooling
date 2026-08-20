# dev-tooling

This repo contains a collection of tools/snippets that I've written (or _borrowed_ 😉) over the years.

## Scripts

### `setup-osx.sh`

[This script](./scripts/setup-osx.sh) is an opinionated macOS dev setup focused on `Node.js` and API work, plus browser and communication apps. It is safe to re-run: every step is idempotent, so re-running only installs what is still missing.

The run ends with a combined summary, and the full run is captured to a timestamped log, `setup-osx-YYYY-MM-DD-HH-MM-SS.log`, written into the directory where the script is invoked.

For an unattended run, pass `--ide <vscode|cursor|both|skip>` and `--password-manager <macpass|1password|both|skip>`; without the flags the script prompts for those choices.

#### Quick Install

If you want to run it as is -- without even downloading it -- you can do so by running the following command:

```bash
/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/couimet/dev-tooling/main/scripts/setup-osx.sh)"
```

⚠️ **Security Note**: Always review scripts before running them directly from the internet. The command above downloads and executes code from GitHub. Make sure you trust the source and have reviewed the script's contents.

### `setup-github-ssh.sh`

[This script](./scripts/setup-github-ssh.sh) is a standalone GitHub SSH setup. It adds the `github.com` block to `~/.ssh/config`, enables SSH commit signing, and registers the key in `allowed_signers`.

```bash
./scripts/setup-github-ssh.sh --key ~/.ssh/id_ed25519
```

When run standalone, it logs to `setup-github-ssh-YYYY-MM-DD-HH-MM-SS.log` in the invocation directory.

### `utils.sh`

Shared helpers sourced by both scripts above: status printing, the freshness check against `origin/main`, and other common functions.

### Versioning

The setup scripts are stamped with a `CalVer@SHA` version (e.g. `2026.08.19@a1b2c3d`): the CalVer date comes from the top entry of [CHANGELOG.md](./CHANGELOG.md) and the SHA is the git commit the version was stamped with. Every setup script prints its version in the start banner and also print it on demand via `--version`. `scripts/utils.sh` carries its own stamp under the name `VERSION_UTILS`, so each file reports its own version.

The [stamp-version-calver workflow](./.github/workflows/stamp-version-calver.yml) drives a local composite action ([.github/actions/stamp-version-calver](./.github/actions/stamp-version-calver)) that re-stamps the scripts on every push to main, so the version you see is always the latest released one.

## Frequently Used Applications

Once you have Homebrew installed (or better yet, run the `setup-osx.sh` script), you can install the following SQL and NoSQL tools. The script covers the browser and communication apps.

### SQL Tool

```bash
brew install --cask pgadmin4
```

or

```bash
brew install --cask dbeaver-community
```

### NoSQL Tool

```bash
brew install --cask studio-3t
```
