#!/usr/bin/env bash
# Rebuilds the terminal setup on a new Mac. Safe to re-run.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.terminal-bootstrap-backup/$(date +%Y%m%d-%H%M%S)"

say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

link() {  # link <source in repo> <target in home>; backs up anything already there
  local src="$DIR/$1" dst="$2"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then mkdir -p "$BACKUP"; mv "$dst" "$BACKUP/"; fi
  ln -sfn "$src" "$dst"; echo "  $dst -> $src"
}

say "Xcode command line tools"
xcode-select -p >/dev/null 2>&1 || { xcode-select --install; echo "Re-run this script once the install finishes."; exit 1; }

say "Homebrew"
command -v brew >/dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew bundle --file="$DIR/Brewfile"

say "oh-my-zsh + powerlevel10k"
[ -d "$HOME/.oh-my-zsh" ] || RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
P10K="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
[ -d "$P10K" ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K"

say "nvm + pyenv-virtualenv"
[ -d "$HOME/.nvm" ] || PROFILE=/dev/null bash -c "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh)"
[ -d "$(pyenv root)/plugins/pyenv-virtualenv" ] || git clone https://github.com/pyenv/pyenv-virtualenv.git "$(pyenv root)/plugins/pyenv-virtualenv"

say "Dotfiles"
link shell/zshrc    "$HOME/.zshrc"
link shell/zprofile "$HOME/.zprofile"
link shell/p10k.zsh "$HOME/.p10k.zsh"
link shell/aliases  "$HOME/.aliases"
link git/gitconfig  "$HOME/.gitconfig"
touch "$HOME/.zshrc.local"   # for secrets / machine-only settings, never in this repo
mkdir -p "$HOME/.npm-global"

say "iTerm2 preferences"
if pgrep -xq iTerm2; then
  echo "  iTerm2 is running. Quit it (Cmd+Q) and re-run, or prefs may be overwritten on quit."
else
  TMP="$(mktemp)"; sed "s#__HOME__#$HOME#g" "$DIR/iterm/com.googlecode.iterm2.plist" > "$TMP"
  defaults import com.googlecode.iterm2 "$TMP" && rm "$TMP"
  echo "  Imported profile, colors (Snazzy), fonts and key mappings."
fi

say "Done. Open iTerm2. Put any API keys / tokens in ~/.zshrc.local."
[ -d "$BACKUP" ] && echo "Old files backed up to $BACKUP"
