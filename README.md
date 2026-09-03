# dev-tooling

[![CodeRabbit Pull Request Reviews](https://img.shields.io/coderabbit/prs/github/couimet/dev-tooling?label=CodeRabbit+Reviews)](https://coderabbit.ai)

This repo contains a collection of tools/snippets that I've written (or _borrowed_ 😉) over the years.

## Scripts

### `setup-osx.sh`

[This script](./scripts/setup-osx.sh) is an opinionated macOS development machine setup: Homebrew, Git and GitHub SSH, `nvm` and `Node.js`, a broad set of command-line tools, and browser and communication apps. It is safe to re-run: every step is idempotent, so re-running only installs what is still missing.

The run ends with a combined summary, and the full run is captured to a timestamped log, `setup-osx-YYYY-MM-DD-HH-MM-SS.log`, written into the directory where the script is invoked.

For an unattended run, pass `--ide <vscode|cursor|both|skip>` and `--password-manager <macpass|1password|both|skip>`; without the flags the script asks both questions up front, before it installs anything. Beyond those two menus the run proceeds on its own, though an install or command step may still prompt (for example sudo or Homebrew).

The script also installs the recommended IDE extensions into every IDE it finds on disk (VS Code and Cursor), independently of the `--ide` choice. Likewise, the 1Password CLI (`op`) is installed on every run, independently of the `--password-manager` choice, which covers the GUI apps only.

The script force-loads a set of developer-focused Chrome extensions by writing Chrome's per-user "External Extensions" preference files. The exact list lives in the `CHROME_EXTENSIONS` array at the top of the script. The write is idempotent; extensions a fresh write adds take effect only after Chrome restarts and you enable them in chrome://extensions, which the run summary lists as a follow-up.

The script also writes the nvm loader into `~/.zshrc` (`NVM_DIR` plus the `nvm.sh` and `bash_completion` sources), so the Node.js versions it installs stay available in every new terminal. It enables `yarn` through corepack (which ships with Node.js), so yarn stays under the nvm-managed Node rather than pulling in a separate Homebrew Node.

The script sets up a starship prompt too: it installs starship through Homebrew along with the FiraCode Nerd Font that the starship site lists as a prerequisite, writes its opinionated `~/.config/starship.toml` when none exists (and warns, without overwriting, when an existing one has drifted from it), and adds the `eval "$(starship init zsh)"` line to `~/.zshrc`. Enabling the Nerd Font in each terminal (iTerm2, VS Code, or Cursor) is left as a documented follow-up step.

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

The setup scripts are stamped with a `CalVer@SHA` version (e.g. `2026.08.19@a1b2c3d`): the CalVer date comes from the top entry of [CHANGELOG.md](./CHANGELOG.md) and the SHA is the git commit the version was stamped with. Every setup script prints its version in the start banner and also prints it on demand via `--version`. `scripts/utils.sh` carries its own stamp under the name `VERSION_UTILS`, so each file reports its own version.

The [stamp-version-calver workflow](./.github/workflows/stamp-version-calver.yml) drives a local composite action ([.github/actions/stamp-version-calver](./.github/actions/stamp-version-calver)) that re-stamps the scripts on every push to main, so the version you see is always the latest released one.

## Manual macOS tweaks

Settings applied by hand in System Settings. The setup scripts leave these to you because they are per-app and per-user.

### Chrome: keyboard shortcut for `Move Tab to New Window`

Give Chrome's `Move Tab to New Window` menu item a keyboard shortcut:

1. Open **System Settings** from the Apple menu.
2. Click **Keyboard** in the sidebar.
3. Click the **Keyboard Shortcuts** button.
4. Select **App Shortcuts** from the left list.
5. Click the **plus (+)** button to add a new shortcut.
6. Choose **Google Chrome** as the application, or choose **All Applications** if the same menu title should apply everywhere.
7. Type the exact **Menu Title**, `Move Tab to New Window`; it must match the app's menu bar precisely, including capitalization and punctuation.
8. Click into the **Keyboard Shortcut** field and press the key combination you want to assign.
9. Click **Done**. Chrome picks the shortcut up without a restart as of Tahoe 26.6.2.

## Frequently Used Applications

Once you have Homebrew installed (or better yet, run the `setup-osx.sh` script), you can install the following SQL and NoSQL tools. The script installs neither one, so pick whichever you prefer.

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
