# Enable completions
autoload -Uz compinit && compinit

# OS-specific settings
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # Dotfiles location
  export DOTFILES=~/src/tilde/dotfiles/zsh
  # ZSH Customs folder
  ZSH_CUSTOM=~/src/tilde/assets
  # History and completion management
  HISTFILE=~/src/tilde/assets/.zsh-history
  compinit -d ~/src/tilde/assets
elif [[ "$OSTYPE" == "darwin"* ]]; then
  # Dotfiles location
  export DOTFILES=~/Repositories/tilde/dotfiles/zsh
  # ZSH Customs folder
  ZSH_CUSTOM=~/Repositories/tilde/assets
  # History and completion management
  HISTFILE=~/Repositories/tilde/assets/.zsh-history
  compinit -d ~/Repositories/tilde/assets
fi

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Minimal - Theme Settings
export MNML_INSERT_CHAR=">"
export MNML_PROMPT=(mnml_git mnml_keymap)
export MNML_RPROMPT=('mnml_cwd 20')

# Terminal theme
ZSH_THEME="minimal"

source $ZSH/oh-my-zsh.sh

# You may need to manually set your language environment
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

source ~/.zsh/exports.zsh
source ~/.zsh/aliases.zsh
source ~/.zsh/functions.zsh

# Vi mappings
bindkey -v

# Reverse and forward searches
bindkey '^r' history-incremental-search-backward
bindkey '^R' history-incremental-pattern-search-backward

# Common plug-ins
plugins=(git fzf-zsh-plugin)


# Python Virtual Environments
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  ;
elif [[ "$OSTYPE" == "darwin"* ]]; then
  # Python virtual environments
  VIRTUALENVWRAPPER_PYTHON=/opt/homebrew/bin/python3
  source /opt/homebrew/bin/virtualenvwrapper.sh
fi

# Launching SSH agent
if [ -z "$SSH_AUTH_SOCK" ] ; then
  eval `ssh-agent -s`
  ssh-add
fi

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
