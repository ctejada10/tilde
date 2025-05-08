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
  #compinit -d ~/Repositories/tilde/assets
fi

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Minimal - Theme Settings
export MNML_INSERT_CHAR=">"
export MNML_PROMPT=(mnml_git mnml_keymap)
export MNML_RPROMPT=('mnml_cwd 20')

# Terminal theme
ZSH_THEME="minimal"
# source "/opt/homebrew/opt/spaceship/spaceship.zsh"

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
plugins=(git)


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

# FZF setup
source <(fzf --zsh)

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/homebrew/Caskroom/miniconda/base/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh" ]; then
        . "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh"
    else
        export PATH="/opt/homebrew/Caskroom/miniconda/base/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

