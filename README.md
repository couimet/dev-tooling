# dev-tooling

This repo contains a collection of tools/snippets that I've written (or _borrowed_ 😉) over the years.

## Scripts

### `setup-osx.sh`

[This script](./scripts/setup-osx.sh) is designed to install a variety of tools on a macOS system. It checks for the presence of various applications and tools, and installs them if they are not found.

The script is opinionated on the tools that are installed; they are focused on `Node.js` and API development (with a few productivity tools thrown in).

#### Quick Install

If you want to run it as is -- without even downloading it -- you can do so by running the following command:

```bash
/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/couimet/dev-tooling/main/scripts/setup-osx.sh)"
```

⚠️ **Security Note**: Always review scripts before running them directly from the internet. The command above downloads and executes code from GitHub. Make sure you trust the source and have reviewed the script's contents.

## Frequently Used Applications

Once you have Homebrew installed (or better yet, run the `setup-osx.sh` script), you can install the following applications by running the following commands.

### Chrome

```bash
brew install --cask google-chrome
```

### Slack

```bash
brew install --cask slack
```

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
