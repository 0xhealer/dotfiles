# Mirrors configs/powershell/powershell/aliases.ps1
status is-interactive; or return

abbr -a .. 'cd ..'
abbr -a ... 'cd ../..'
abbr -a .... 'cd ../../..'

if type -q eza
    alias l 'eza -l --group --color=always --group-directories-first'
    alias ls 'eza -al --group --header --icons --group-directories-first'
    alias ll 'eza -la --group --icons --group-directories-first'
    alias la 'eza -la --group --icons --group-directories-first'
    alias lt 'eza --tree --level=2 --icons'
    alias lh 'eza -la --group --sort=modified --reverse'
    alias tree 'eza --tree --level=4 --icons --long'
else
    alias l 'ls -lh --color=auto'
    alias ls 'ls -alh --color=auto'
    alias ll 'ls -lah --color=auto'
    alias la 'ls -lah --color=auto'
    alias lh 'ls -lahtr --color=auto'
end

alias cp 'cp -iv'
alias mv 'mv -iv'
alias rm 'rm -Iv'
alias rf 'command rm -rf'
alias mkdir 'mkdir -pv'
alias grep 'grep --color=auto'

alias df 'df -h'
alias du 'du -h'
alias free 'free -h'
alias mem 'ps -eo comm,rss --sort=-rss | head -6'
alias cpu 'ps -eo comm,%cpu --sort=-%cpu | head -6'
alias ports 'ss -tulpn'
alias listening 'ss -ltnp'

abbr -a g git
abbr -a gs 'git status'
abbr -a ga 'git add'
abbr -a gaa 'git add -A'
abbr -a gc 'git commit'
abbr -a gcm 'git commit -m'
abbr -a gp 'git push'
abbr -a gpu 'git push -u origin HEAD'
abbr -a gpl 'git pull'
abbr -a gco 'git checkout'
abbr -a gb 'git branch'
abbr -a gd 'git diff'
abbr -a gl 'git log --oneline --graph --decorate'
abbr -a gclone 'git clone'

abbr -a v nvim
abbr -a vv 'nvim .'
alias vim nvim
alias vi nvim
alias e micro
alias n nano
abbr -a c clear
abbr -a ff fastfetch
alias reload 'source ~/.config/fish/config.fish; echo "Reloaded config.fish"'
alias editrc '$EDITOR ~/.config/fish/config.fish'
alias nvimrc '$EDITOR ~/.config/nvim/init.lua'

alias g. 'cd ~/.config'
alias conf 'cd ~/.config'
alias projects 'cd ~/workspace/github; and ls'
alias workspace 'cd ~/workspace; and ls'
alias weather 'curl -s "wttr.in?u"'
alias dl 'cd ~/Downloads'
alias doc 'cd ~/Documents'
alias vid 'cd ~/Videos'

alias x exit
alias h history
alias j 'jobs -l'
alias which 'type -a'
alias now 'date +"%Y-%m-%d %T"'
alias week 'date +%V'
alias egrep 'egrep --color=auto'
alias fgrep 'fgrep --color=auto'
alias biggest 'du -h --max-depth=1 | sort -h'
alias k9 'kill -9'
alias killall 'killall -v'
alias untar 'tar -xvf'
alias ungz 'tar -xzvf'
alias unbz2 'tar -xjvf'
alias fishrc '$EDITOR ~/.config/fish/config.fish'

if type -q code-insiders
    alias code code-insiders
end
alias treesitter tree-sitter

# docker compose (run inside a compose project, or use start-homelab)
alias dcu 'docker compose up -d'
alias dcd 'docker compose down'
alias dcr 'docker compose restart'
alias dcp 'docker compose ps'
alias dcl 'docker compose logs -f --tail=100'
alias dcpull 'docker compose pull'
alias dcup 'docker compose pull; and docker compose up -d'
alias homelab 'cd ~/containers/homelab'

function start-homelab
    cd ~/containers/homelab; and docker compose up -d $argv
end

function stop-homelab
    cd ~/containers/homelab; and docker compose down $argv
end
