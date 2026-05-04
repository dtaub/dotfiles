#!/usr/bin/env zsh
# Install antidote and configure zsh plugins on a new machine.

set -euo pipefail

backup() {
  local f=$1
  if [[ -e $f ]]; then
    local bak="${f}.bak.$(date +%Y%m%d%H%M%S)"
    print "Backing up existing $f -> $bak"
    mv "$f" "$bak"
  fi
}

# 1. Install antidote via Homebrew
if ! command -v brew >/dev/null 2>&1; then
  print -u2 "Error: Homebrew not found. Install it from https://brew.sh first."
  exit 1
fi

for pkg in antidote fzf bat; do
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

# 2. Plugin list
backup "$HOME/.zsh_plugins.txt"
cat > "$HOME/.zsh_plugins.txt" <<'EOF'
romkatv/powerlevel10k
mattmc3/ez-compinit
zsh-users/zsh-completions
zsh-users/zsh-autosuggestions
zdharma-continuum/fast-syntax-highlighting kind:defer
zsh-users/zsh-history-substring-search
jeffreytse/zsh-vi-mode
EOF

# 3. Custom zsh functions
backup "$HOME/.zsh_functions"
cat > "$HOME/.zsh_functions" <<'EOF'
killport() {
    port=$1
    pids=$(lsof -ti tcp:$port)

    if [ -z "$pids" ]; then
        echo "Error: No process is using port $port"
        return 1
    fi

    # Replace newlines with spaces so kill sees multiple PIDs correctly
    kill -9 $(echo "$pids" | tr '\n' ' ') && \
        echo "Killed process(es) on port $port:\n$pids"
}
EOF

# 4. Zsh-only .zshrc (no tool-specific env/PATH)
backup "$HOME/.zshrc"
cat > "$HOME/.zshrc" <<'EOF'
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source ~/.zsh_functions

# zsh-vi-mode config (consumed by jeffreytse/zsh-vi-mode plugin)
function zvm_config() {
  ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT
  ZVM_VI_INSERT_ESCAPE_BINDKEY=jk
}

# Load antidote and plugins listed in ~/.zsh_plugins.txt
source "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh"
antidote load

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# fzf shell integration (key bindings + completion)
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

# bat-powered preview pane for Ctrl-R history search
FZF_CTRL_R_OPTS="--preview='echo {} | bat --theme=ansi --language=zsh --color=always --style=plain' --preview-window=down"

# history-substring-search keybindings (up/down arrows)
autoload_history_substring_search_bindings() {
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
}

autoload -Uz add-zsh-hook

# Widget to run a history command immediately after fzf selection (defined but unbound)
fzf-and-run-widget() {
  fzf-history-widget
  zle accept-line
}
zle -N fzf-and-run-widget

# Bind Ctrl-R to fzf-history-widget in both vi modes (only if fzf is loaded)
autoload_fzf_bindings() {
  if zle -l | grep -q fzf-history-widget; then
    bindkey -M viins '^R' fzf-history-widget
    bindkey -M vicmd '^R' fzf-history-widget
  fi
}

add-zsh-hook precmd autoload_fzf_bindings
add-zsh-hook precmd autoload_history_substring_search_bindings
EOF

print ""
print "Done. Open a new zsh session (or 'exec zsh') to load plugins."
print "Run 'p10k configure' to set up the powerlevel10k prompt."
