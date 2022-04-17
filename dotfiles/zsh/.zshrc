# Path to your dotfiles.
export DOTFILES=~/Repositories/tilde/dotfiles/zsh

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.omz

# Enable completions
autoload -Uz compinit && compinit

# Minimal - Theme Settings
export MNML_INSERT_CHAR=">"
export MNML_PROMPT=(mnml_git mnml_keymap)
export MNML_RPROMPT=('mnml_cwd 20')

# Terminal theme
ZSH_THEME="minimal"
# Hiding Vi-mode status
SPACESHIP_VI_MODE_SHOW=false

HIST_STAMPS="dd/mm/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
ZSH_CUSTOM=~/Repositories/tilde/assets

source $ZSH/oh-my-zsh.sh

# You may need to manually set your language environment
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

source ~/.zsh/exports.zsh
source ~/.zsh/aliases.zsh
source ~/.zsh/functions.zsh

# History and completion management
HISTFILE=~/Repositories/tilde/assets/.zsh-history
compinit -d ~/Repositories/tilde/assets

# Vi mappings
bindkey -v

# Reverse and forward searches
bindkey '^r' history-incremental-search-backward
bindkey '^R' history-incremental-pattern-search-backward

# Common plug-ins
plugins=(git)

# Python virtual environments
VIRTUALENVWRAPPER_PYTHON=/opt/homebrew/bin/python3
source /opt/homebrew/bin/virtualenvwrapper.sh
# Launching tmux
if [[ -z "$TMUX" && -z "$INVOCATION_ID" ]] ; then
  ID="$(tmux ls 2> /dev/null | grep -vm1 attached | cut -d: -f1)"
  if [[ -z "$ID" ]] ; then
      :
  else
      exec tmux attach-session -t "$ID"
  fi
fi

if [ -z "$SSH_AUTH_SOCK" ] ; then
  eval `ssh-agent -s`
  ssh-add
fi