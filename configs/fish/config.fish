fish_add_path -g $HOME/.local/bin $HOME/.cargo/bin $HOME/go/bin

set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx PAGER less
set -gx STARSHIP_CONFIG $HOME/.config/starship.toml

set -gx LESS '-R -F -X -i -P %f (%i/%m) '
set -gx LESSHISTFILE /dev/null
set -gx LESS_TERMCAP_mb (printf '\e[1;32m')
set -gx LESS_TERMCAP_md (printf '\e[1;32m')
set -gx LESS_TERMCAP_me (printf '\e[0m')
set -gx LESS_TERMCAP_se (printf '\e[0m')
set -gx LESS_TERMCAP_so (printf '\e[01;33m')
set -gx LESS_TERMCAP_ue (printf '\e[0m')
set -gx LESS_TERMCAP_us (printf '\e[1;4;31m')

set -g fish_greeting

if status is-interactive

    type -q zoxide; and zoxide init fish | source
    type -q fzf; and fzf --fish 2>/dev/null | source
    test -r $HOME/.config/matugen/generated/fzf-colors.fish; and source $HOME/.config/matugen/generated/fzf-colors.fish
    type -q starship; and starship init fish | source
end

if test -r $HOME/.config/fish/local.fish
    source $HOME/.config/fish/local.fish
end
