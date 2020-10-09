# Path to your dotfiles.
export DOTFILES=~/src/tilde/dotfiles/zsh

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

HIST_STAMPS="dd/mm/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
ZSH_CUSTOM=~/src/tilde/assets

source $ZSH/oh-my-zsh.sh

# You may need to manually set your language environment
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

source ~/.zsh/exports.zsh
source ~/.zsh/aliases.zsh
source ~/.zsh/functions.zsh

# History and completion management
HISTFILE=~/src/tilde/assets/.zsh-history
compinit -d ~/src/tilde/assets
bindkey -v
plugins=(git)

if [[ "$OSTYPE" == "darwin"* ]]; then
  # Launching tmux
  if [[ "$TMUX" == "" ]]; then
    tmux attach -t base || tmux new -s base; exit
  fi

  if [ -z "$SSH_AUTH_SOCK" ] ; then
    eval `ssh-agent -s`
    ssh-add
  fi
fi
