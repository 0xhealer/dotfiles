(( $+commands[fzf] )) || return 0

export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --info=inline"

if (( $+commands[fd] )); then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi

if fzf --zsh >/dev/null 2>&1; then
  source <(fzf --zsh)
else
  for f in /usr/share/doc/fzf/examples/key-bindings.zsh /usr/share/fzf/key-bindings.zsh \
    /usr/share/doc/fzf/examples/completion.zsh /usr/share/fzf/completion.zsh; do
    [[ -r $f ]] && source "$f"
  done
fi

[[ -r $HOME/.config/matugen/generated/fzf-colors.sh ]] && source "$HOME/.config/matugen/generated/fzf-colors.sh"

vf() {
  local file
  file=$(fzf --preview 'bat --color=always {} 2>/dev/null || cat {}') && ${EDITOR:-vim} "$file"
}

fkill() {
  local pid
  pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')
  [[ -n $pid ]] && echo "$pid" | xargs kill -${1:-9}
}
