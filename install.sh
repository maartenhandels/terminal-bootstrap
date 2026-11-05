#!/usr/bin/env bash
# Rebuilds the terminal setup on a Mac. Safe to re-run, and safe on a machine
# that already has its own (e.g. work) settings: nothing is thrown away.
#
# Usage: ./install.sh [--dotfiles-only] [--no-iterm]
#   --dotfiles-only  skip Xcode tools, Homebrew, oh-my-zsh, nvm downloads
#   --no-iterm       leave iTerm2 settings untouched
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.terminal-bootstrap-backup/$(date +%Y%m%d-%H%M%S)"
DOTFILES_ONLY=0; NO_ITERM=0
for arg in "$@"; do
  case "$arg" in
    --dotfiles-only) DOTFILES_ONLY=1 ;;
    --no-iterm) NO_ITERM=1 ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '  \033[1;33m! %s\033[0m\n' "$*"; }
backup() { mkdir -p "$BACKUP"; cp -p "$1" "$BACKUP/"; }
MARK="# Installed by terminal-bootstrap. Safe to edit; this file no longer depends on the repo."
ours() { [ -L "$1" ] || head -1 "$1" 2>/dev/null | grep -qF "$MARK"; }  # a file this script put there earlier

# Copy an existing zsh file into a *.local file so its settings keep loading.
# Lines that would load oh-my-zsh / powerlevel10k a second time become no-ops.
migrate_zsh() {  # migrate_zsh <old file> <local file>
  local old="$1" dst="$2"
  { [ -f "$old" ] && ! ours "$old"; } || return 0
  if [ -s "$dst" ]; then warn "$dst already exists; old $(basename "$old") is only in the backup folder"; return 0; fi
  { echo "# Moved here from your previous $(basename "$old") by terminal-bootstrap on $(date +%F)."
    echo "# Review it: some lines may now duplicate what the bootstrap .zshrc/.zprofile already does."
    sed -E '/^[[:space:]]*ZSH_THEME=/s/^/: # [bootstrap: handled by main .zshrc] /;
            /(source|\.)[[:space:]].*(oh-my-zsh\.sh|p10k)/s/^/: # [bootstrap: handled by main .zshrc] /' "$old"
  } > "$dst"
  if ! zsh -n "$dst" 2>/dev/null; then
    sed -i '' 's/^/# /' "$dst"; warn "$dst had syntax issues after migration, so it is fully commented out; please review"
  fi
  echo "  previous $(basename "$old") -> $dst (still loaded)"
}

put() {  # put <source in repo> <target in home>: copies the file (no link back to this folder)
  local src="$DIR/$1" dst="$2"
  if [ -L "$dst" ]; then rm "$dst"
  elif [ -f "$dst" ] && ! ours "$dst"; then backup "$dst"
  fi
  { echo "$MARK"; cat "$src"; } > "$dst"; echo "  wrote $dst"
}

find_brew() { for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && { echo "$b"; return; }; done; }

if [ "$DOTFILES_ONLY" = 0 ]; then
  say "Xcode command line tools"
  xcode-select -p >/dev/null 2>&1 || { xcode-select --install; echo "Re-run this script once the install finishes."; exit 1; }

  say "Homebrew"
  BREW="$(find_brew || true)"
  if [ -z "$BREW" ]; then
    if id -Gn | tr ' ' '\n' | grep -qx admin; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      BREW="$(find_brew)"
    else
      warn "No Homebrew and this account is not an administrator. Skipping Homebrew packages."
      warn "Ask IT for Homebrew (or your company's approved installer), then re-run."
    fi
  fi
  if [ -n "$BREW" ]; then
    eval "$("$BREW" shellenv)"
    brew bundle --file="$DIR/Brewfile" || warn "Some Brewfile items failed (e.g. iTerm2 already installed by IT). Continuing."
  fi

  say "oh-my-zsh + powerlevel10k"
  [ -d "$HOME/.oh-my-zsh" ] || RUNZSH=no KEEP_ZSHRC=yes CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  P10K="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
  [ -d "$P10K" ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K"

  say "nvm + pyenv-virtualenv"
  [ -d "$HOME/.nvm" ] || PROFILE=/dev/null bash -c "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh)"
  if command -v pyenv >/dev/null; then
    [ -d "$(pyenv root)/plugins/pyenv-virtualenv" ] || git clone https://github.com/pyenv/pyenv-virtualenv.git "$(pyenv root)/plugins/pyenv-virtualenv"
  else
    warn "pyenv not installed; skipping pyenv-virtualenv"
  fi
fi

say "Keeping this machine's existing settings"
migrate_zsh "$HOME/.zshrc"    "$HOME/.zshrc.local"
migrate_zsh "$HOME/.zprofile" "$HOME/.zprofile.local"
touch "$HOME/.zshrc.local"

say "Dotfiles (copied; you can delete this folder afterwards)"
put shell/zshrc    "$HOME/.zshrc"
put shell/zprofile "$HOME/.zprofile"
put shell/p10k.zsh "$HOME/.p10k.zsh"

say "Git preferences (your ~/.gitconfig, name and email are left alone)"
command -v git-lfs >/dev/null && git lfs install --skip-repo >/dev/null && echo "  git-lfs enabled"
[ -n "$(git config --global init.defaultBranch || true)" ] || git config --global init.defaultBranch main
[ -n "$(git config --global pager.branch || true)" ]       || git config --global pager.branch false
echo "  init.defaultBranch=$(git config --global init.defaultBranch), pager.branch=$(git config --global pager.branch) (only set if they were unset)"

if [ "$NO_ITERM" = 0 ]; then
  say "iTerm2 preferences"
  if pgrep -xq iTerm2; then
    warn "iTerm2 is running. Quit it (Cmd+Q) and re-run, or iTerm2 will overwrite the imported settings on quit."
  else
    if defaults read com.googlecode.iterm2 >/dev/null 2>&1; then
      mkdir -p "$BACKUP"; defaults export com.googlecode.iterm2 "$BACKUP/iterm2-prefs.plist"
      echo "  current iTerm2 settings saved to $BACKUP/iterm2-prefs.plist"
    fi
    TMP="$(mktemp)"; sed "s#__HOME__#$HOME#g" "$DIR/iterm/com.googlecode.iterm2.plist" > "$TMP"
    defaults import com.googlecode.iterm2 "$TMP" && rm "$TMP"
    echo "  Imported profile, colors (Snazzy), fonts and key mappings."
  fi
fi

say "Done. Open a new iTerm2 window. You can now delete $DIR if you like."
echo "  Machine-only / work / secret settings: ~/.zshrc.local, ~/.zprofile.local"
if [ -d "$BACKUP" ]; then
  echo "  Originals backed up to $BACKUP"
  if [ -f "$BACKUP/iterm2-prefs.plist" ]; then
    echo "  Undo iTerm2 import: defaults import com.googlecode.iterm2 $BACKUP/iterm2-prefs.plist"
  fi
fi
exit 0
