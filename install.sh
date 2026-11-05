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

# .zshrc / .zprofile: the repo's settings live in one marked block inside your
# own file. Everything outside the block is yours and is never rewritten.
BEGIN="# >>> terminal-bootstrap >>> (re-running install.sh replaces this block; edit outside it)"
END="# <<< terminal-bootstrap <<<"

# Prints the existing file with the block placed where it used to load
# oh-my-zsh (or at the end). Lines that would load oh-my-zsh, a theme or
# powerlevel10k a second time become no-ops, so nothing loads twice.
place_block() {  # place_block <block file> <existing file>
  awk -v f="$1" '
    function emit(  l) { while ((getline l < f) > 0) print l; done = 1 }
    /^[[:space:]]*#/ { print; next }               # leave comments alone
    !done && /(source|\.)[[:space:]].*oh-my-zsh\.sh/ {
      print "# [terminal-bootstrap] oh-my-zsh now loads in the block below. Was: " $0; emit(); next }
    /^[[:space:]]*ZSH_THEME=/ || /(source|\.)[[:space:]].*(oh-my-zsh\.sh|p10k)/ {
      print ": # [terminal-bootstrap: handled by its block] " $0; next }
    { print }
    END { if (!done) { print ""; emit() } }' "$2"
}

install_block() {  # install_block <source in repo> <target in home>
  local src="$DIR/$1" dst="$2" block new how
  block="$(mktemp)"; new="$(mktemp)"
  { echo "$BEGIN"; cat "$src"; echo "$END"; } > "$block"
  [ -L "$dst" ] && rm "$dst"
  if [ ! -s "$dst" ]; then
    cp "$block" "$new"; how="wrote"
  elif grep -qxF "$BEGIN" "$dst"; then             # re-run: swap in the current block
    awk -v b="$BEGIN" -v e="$END" -v f="$block" '
      $0 == b { while ((getline l < f) > 0) print l; skip = 1; next }
      skip && $0 == e { skip = 0; next }
      !skip' "$dst" > "$new"; how="updated block in"
  elif head -1 "$dst" | grep -qF "$MARK"; then     # whole file written by an older version
    backup "$dst"; cp "$block" "$new"; how="rewrote"
    local loc="${dst##*/}.local"                   # that version kept machine settings in ~/.zshrc.local etc.
    [ -s "$HOME/$loc" ] && printf '\n[ -f ~/%s ] && source ~/%s\n' "$loc" "$loc" >> "$new"
  else                                             # this machine's own file: keep it, add the block
    backup "$dst"; place_block "$block" "$dst" > "$new"; how="added block to"
  fi
  if ! zsh -n "$new" 2>/dev/null; then
    warn "$dst would not parse after the change, so it was left as is; please add the block by hand"
  else
    cat "$new" > "$dst"; echo "  $how $dst"
  fi
  rm -f "$block" "$new"
}

put() {  # put <source in repo> <target in home>: copies the file (no link back to this folder)
  local src="$DIR/$1" dst="$2"
  if [ -L "$dst" ]; then rm "$dst"
  elif [ -f "$dst" ] && ! ours "$dst"; then backup "$dst"
  fi
  { echo "$MARK"; cat "$src"; } > "$dst"; echo "  wrote $dst"
}

# Download an install script completely, then run it with the given command.
# Stops the whole run if the download fails (e.g. blocked by a company proxy),
# instead of silently running an empty script.
run_remote() {  # run_remote <url> <command...>
  local url="$1" f; shift
  f="$(mktemp)"
  if ! curl -fsSL "$url" -o "$f" || [ ! -s "$f" ]; then
    rm -f "$f"
    echo "Download failed: $url"
    echo "Check your network/proxy and re-run, or use --dotfiles-only."
    exit 1
  fi
  "$@" "$f" || { local rc=$?; rm -f "$f"; return "$rc"; }
  rm -f "$f"
}

find_brew() { for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && { echo "$b"; return; }; done; }

if [ "$DOTFILES_ONLY" = 0 ]; then
  say "Xcode command line tools"
  xcode-select -p >/dev/null 2>&1 || { xcode-select --install; echo "Re-run this script once the install finishes."; exit 1; }

  say "Homebrew"
  BREW="$(find_brew || true)"
  if [ -z "$BREW" ]; then
    if id -Gn | tr ' ' '\n' | grep -qx admin; then
      run_remote https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh /bin/bash
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
  [ -d "$HOME/.oh-my-zsh" ] || run_remote https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh \
    env RUNZSH=no KEEP_ZSHRC=yes CHSH=no sh
  P10K="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
  [ -d "$P10K" ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K"

  say "nvm + pyenv-virtualenv"
  [ -d "$HOME/.nvm" ] || run_remote https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh env PROFILE=/dev/null bash
  if command -v pyenv >/dev/null; then
    [ -d "$(pyenv root)/plugins/pyenv-virtualenv" ] || git clone https://github.com/pyenv/pyenv-virtualenv.git "$(pyenv root)/plugins/pyenv-virtualenv"
  else
    warn "pyenv not installed; skipping pyenv-virtualenv"
  fi
fi

say "Dotfiles (copied; you can delete this folder afterwards)"
install_block shell/zshrc    "$HOME/.zshrc"
install_block shell/zprofile "$HOME/.zprofile"
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
echo "  Your own settings go in ~/.zshrc / ~/.zprofile, outside the terminal-bootstrap block."
if [ -d "$BACKUP" ]; then
  echo "  Originals backed up to $BACKUP"
  if [ -f "$BACKUP/iterm2-prefs.plist" ]; then
    echo "  Undo iTerm2 import: defaults import com.googlecode.iterm2 $BACKUP/iterm2-prefs.plist"
  fi
fi
exit 0
