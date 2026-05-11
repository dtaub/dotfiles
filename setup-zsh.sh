#!/usr/bin/env zsh
# Install antidote and configure zsh plugins on a new machine.

set -euo pipefail

SCRIPT_DIR=${0:A:h}

backup() {
  local f=$1
  if [[ -e $f ]]; then
    local bak="${f}.bak.$(date +%Y%m%d%H%M%S)"
    print "Backing up existing $f -> $bak"
    mv "$f" "$bak"
  fi
}

install_file() {
  local src=$1 dst=$2
  backup "$dst"
  print "Installing $src -> $dst"
  cp "$src" "$dst"
}

# Merge managed prepend + append blocks into ~/.zshrc, preserving any
# user-authored content between them. Idempotent: re-running replaces the
# contents of each marker block in place.
merge_zshrc() {
  local zshrc=$HOME/.zshrc
  local prepend_src=$SCRIPT_DIR/zsh/zshrc.prepend
  local append_src=$SCRIPT_DIR/zsh/zshrc.append
  local pb="# >>> setup-zsh prepend (managed) >>>"
  local pe="# <<< setup-zsh prepend (managed) <<<"
  local ab="# >>> setup-zsh append (managed) >>>"
  local ae="# <<< setup-zsh append (managed) <<<"

  local middle=""
  if [[ -f $zshrc ]]; then
    local bak="${zshrc}.bak.$(date +%Y%m%d%H%M%S)"
    print "Backing up existing $zshrc -> $bak"
    cp "$zshrc" "$bak"
    # Strip any existing managed blocks (lines between markers, inclusive)
    # and trim leading/trailing blank lines so re-runs stay stable.
    middle=$(awk -v pb="$pb" -v pe="$pe" -v ab="$ab" -v ae="$ae" '
      $0 == pb || $0 == ab { skip = 1; next }
      $0 == pe || $0 == ae { skip = 0; next }
      !skip { lines[++n] = $0 }
      END {
        s = 1; while (s <= n && lines[s] ~ /^[[:space:]]*$/) s++
        e = n; while (e >= 1 && lines[e] ~ /^[[:space:]]*$/) e--
        for (i = s; i <= e; i++) print lines[i]
      }
    ' "$zshrc")
  fi

  print "Updating $zshrc (managed blocks)"
  {
    print -r -- "$pb"
    cat "$prepend_src"
    print -r -- "$pe"
    if [[ -n $middle ]]; then
      print ""
      print -r -- "$middle"
    fi
    print ""
    print -r -- "$ab"
    cat "$append_src"
    print -r -- "$ae"
  } > "$zshrc.new"
  mv "$zshrc.new" "$zshrc"
}

# 1. Install antidote via Homebrew
if ! command -v brew >/dev/null 2>&1; then
  print -u2 "Error: Homebrew not found. Install it from https://brew.sh first."
  exit 1
fi

for pkg in antidote fzf bat rg; do
  if brew list --formula "$pkg" >/dev/null 2>&1; then
    print "$pkg already installed via brew — skipping"
  else
    print "Installing $pkg via brew"
    brew install "$pkg"
  fi
done

# Install fzf shell integration (~/.fzf.zsh, key bindings, completion)
if [[ ! -f $HOME/.fzf.zsh ]]; then
  print "Setting up fzf shell integration"
  "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc
fi

# 2-3. Auxiliary files (fully managed — overwritten with backup)
install_file "$SCRIPT_DIR/zsh/zsh_plugins.txt" "$HOME/.zsh_plugins.txt"
install_file "$SCRIPT_DIR/zsh/zsh_functions"   "$HOME/.zsh_functions"

# 4. .zshrc — merge prepend/append blocks, preserve user content
merge_zshrc

print ""
print "Done. Open a new zsh session (or 'exec zsh') to load plugins."
print "Run 'p10k configure' to set up the powerlevel10k prompt."
