bindkey -e

bindkey '^L' clear-screen

bindkey '^[[A' history-beginning-search-backward
bindkey '^[[B' history-beginning-search-forward

bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char

bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[1;3C' forward-word
bindkey '^[[1;3D' backward-word

bindkey '^H' backward-kill-word
bindkey '^[[3;5~' kill-word
