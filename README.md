# terminal-bootstrap

Rebuilds my iTerm2 + zsh look and feel on a Mac. It holds no secrets, passwords, keys,
or anything tied to a person or machine (no git name/email, no hostnames, no home paths).

## Run it

```bash
git clone <this repo> ~/terminal-bootstrap   # or copy the folder over
cd ~/terminal-bootstrap
./install.sh
```

Run it from macOS Terminal.app with iTerm2 **closed**, then open iTerm2. Re-running is safe.

| Option | Effect |
|---|---|
| `--dotfiles-only` | Skip all downloads/installs (Xcode tools, Homebrew, oh-my-zsh, nvm); only link dotfiles |
| `--no-iterm` | Leave iTerm2 settings untouched |

## What it sets up

| Piece | Details |
|---|---|
| iTerm2 | Default profile, Snazzy colors, Hack Nerd Font Mono 12, key mappings, gestures |
| Shell | oh-my-zsh, powerlevel10k (classic style), `git` plugin |
| Tools | `Brewfile`: iTerm2, Hack Nerd Font, gh, git-lfs, pyenv, wget |
| Runtimes | pyenv + pyenv-virtualenv, nvm |
| Dotfiles | `.zshrc`, `.zprofile`, `.p10k.zsh` (plain copies; this folder can be deleted afterwards) |
| Git | Enables git-lfs; sets `init.defaultBranch=main` and `pager.branch=false` only if unset. Your `~/.gitconfig`, name and email are never replaced |

## On a work laptop (or any machine with existing settings)

Nothing is thrown away:

- Your previous `.zshrc` / `.zprofile` are moved into `~/.zshrc.local` and
  `~/.zprofile.local`, which keep loading. Only lines that would load oh-my-zsh or
  powerlevel10k a second time are disabled. Review those files once after installing.
- Current iTerm2 settings are exported before the import; the script prints the undo command.
- Originals go to `~/.terminal-bootstrap-backup/<timestamp>/`.
- No SSH agent is started if one is already running (macOS or a company tool).
- Homebrew is found on Apple Silicon or Intel. Without admin rights, Homebrew steps are skipped.
- `--dotfiles-only` avoids downloading install scripts, if your company doesn't allow that.

Check your company's policy on installing tools and cloning personal repositories first.

## Left out on purpose

- iTerm2 AI settings (the API key lives in the macOS Keychain)
- Window positions, update-check state, install IDs and other machine-specific iTerm2 state
- `~/.ssh`, `~/.aws`, `~/.npmrc`, `~/.docker`, `~/.config/gh`, `~/.gitconfig`, shell history

Secrets and machine-only settings go in `~/.zshrc.local` / `~/.zprofile.local`, never in this repo.

## Updating the snapshot

The installed files are plain copies, so editing `~/.zshrc` on a laptop doesn't change this repo.
To update the snapshot, copy the changed file back into `shell/` (or re-export iTerm2 settings into
`iterm/`), then commit and push.
