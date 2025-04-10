alias vi=vim
alias svi='sudo vim'
alias tree='tree -lsh --du'

alias ipython='clear; ipython2 --classic --no-banner'
alias whereami='uname -n'

alias docker-stop-all='docker stop $(docker ps -aq)'
alias docker-rmi-all='docker rmi $(docker images -q)'
alias docker-rm-all='docker rm $(docker ps -aq)'

alias update='sudo apt -y update; sudo apt -y upgrade; sudo apt autoremove; sudo apt autoclean'

alias grep='grep --color=auto'

alias mkdir='mkdir -p'

# Tools
alias ls="eza"
alias ll="eza -lh --icons"
alias lla="eza -alh --icons"
alias tree="eza --tree"
alias cat="bat"
