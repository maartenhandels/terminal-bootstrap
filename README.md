# terminal-bootstrap

Rebuilds my iTerm2 + zsh setup on a new Mac. No secrets, passwords or keys are stored here.

## On the new laptop

```bash
git clone <this repo> ~/terminal-bootstrap   # or copy the folder over
cd ~/terminal-bootstrap
./install.sh
```

Run it with iTerm2 **closed** (run it from macOS Terminal.app), then open iTerm2.

## What it sets up

| Piece | Details |
|---|---|
| iTerm2 | Default profile, Snazzy colors, Hack Nerd Font Mono 12, key mappings, gestures |
| Shell | oh-my-zsh, powerlevel10k (classic style), `git` plugin |
| Tools | Homebrew packages from `Brewfile`: gh, git-lfs, pyenv, wget |
| Runtimes | pyenv + pyenv-virtualenv, nvm |
| Dotfiles | `.zshrc`, `.zprofile`, `.p10k.zsh`, `.aliases`, `.gitconfig` (symlinked to this folder) |

Existing files are moved to `~/.terminal-bootstrap-backup/<timestamp>/` before linking.

## What is deliberately left out

- iTerm2 AI settings (model, endpoint); the API key lives in the macOS Keychain and never left it
- Window positions, update-check state, install IDs and other machine-specific iTerm2 state
- `~/.ssh`, `~/.aws`, `~/.npmrc`, `~/.docker`, `~/.config/gh` and anything else holding credentials
- Shell history

Secrets and machine-only settings go in `~/.zshrc.local`, which `.zshrc` sources and which is not in this repo.

## Updating the snapshot

Dotfiles are symlinks, so edits on either machine land here automatically.
For iTerm2 changes, re-export from the old machine and re-run the sanitising step, or point
iTerm2 at this folder: *Settings → General → Settings → Load settings from a custom folder*.
