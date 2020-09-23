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

if [[ "$OSTYPE" == "darwin"* ]]; then
  # PATH 
  export PATH=$PATH:/Library/TeX/Distributions/.DefaultTeX/Contents/Programs/texbin
  export PATH="/usr/local/opt/python/libexec/bin:$PATH"
  export PATH=$PATH:/opt/boxen/homebrew/opt/go/libexec/bin
  export PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"
  # GPG
  export GPG_TTY=`tty`
fi