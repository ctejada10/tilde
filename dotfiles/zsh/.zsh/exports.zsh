# Setup terminal, and turn on colors
export TERM=xterm-256color
export CLICOLOR=1
export LSCOLORS=Gxfxcxdxbxegedabagacad

# Defaults
export LESS='--ignore-case --raw-control-chars'
export PAGER='less'
export EDITOR='vim'

# CTAGS Sorting in VIM/Emacs is better behaved with this in place
export LC_COLLATE=C
export LC_ALL=C

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  export PATH="/opt/plex/bin:$PATH"
  export PATH="/home/$USER/.local/bin:$PATH"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  # PATH 
  export PATH="$HOME/bin:$PATH" # Custom binaries
  export PATH="/Library/TeX/Distributions/.DefaultTeX/Contents/Programs/texbin:$PATH"
  export PATH="/usr/local/opt/python/libexec/bin:$PATH"
  export PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"
  export PATH="/opt/homebrew/bin:$PATH"

  # GPG
  export GPG_TTY=`tty`
  # Brew autoupdate
  export HOMEBREW_NO_AUTO_UPDATE=1
  # Python virtual environments
  export WORKON_HOME=$HOME/Repositories/.virtualenvs
  export PROJECT_HOME=$HOME/Repositories
  # Brew
  export PATH="/opt/homebrew/sbin:$PATH"
fi
