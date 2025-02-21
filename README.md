# dev-tooling

This repo contains a collection of tools/snippets that I've written (or _borrowed_ 😉) over the years.

## Scripts

### `setup-osx.sh`

[This script](./scripts/setup-osx.sh) is designed to install a variety of tools on a macOS system. It checks for the presence of various applications and tools, and installs them if they are not found.

The script is opinionated on the tools that are installed; they are focused on `Node.js` and API development (with a few productivity tools thrown in).

#### Quick Install

If you want to run it as is -- without even downloading it -- you can do so by running the following command:

```bash
curl -sSL https://raw.githubusercontent.com/couimet/dev-tooling/main/scripts/setup-osx.sh | zsh
```

⚠️ **Security Note**: Always review scripts before running them directly from the internet. The command above downloads and executes code from GitHub. Make sure you trust the source and have reviewed the script's contents.
