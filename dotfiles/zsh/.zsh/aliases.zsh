# Colorize output, add file type indicator, and put sizes in human readable format
alias ls='ls -GFh'

# Same as above, but in long listing format
alias ll='ls -GFhl'

alias vi=vim
alias svi='sudo vim'
alias tree='tree -lsh --du'

#alias ipython='clear; ipython2 --classic --no-banner'
alias whereami='uname -n'

alias docker-stop-all='docker stop $(docker ps -aq)'
alias docker-rmi-all='docker rmi $(docker images -q)'
alias docker-rm-all='docker rm $(docker ps -aq)'

alias update='sudo apt -y update; sudo apt -y upgrade; sudo apt autoremove; sudo apt autoclean'
alias subs='subliminal download -l'

alias grep='grep --color=auto'

alias mkdir='mkdir -p'

alias plex='docker-compose -f /home/ctejada/plex/etc/docker/docker-compose.yaml'

alias tmux='tmux -u'

# Tools
alias ls="exa"
alias ll="exa -lh"
alias lla="exa -alh"
alias tree="exa --tree"
alias cat="bat"
alias cd="z"
alias zz="z -"