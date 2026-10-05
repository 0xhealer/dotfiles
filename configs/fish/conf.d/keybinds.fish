status is-interactive; or return

bind \cl 'clear; commandline -f repaint'
bind \b backward-kill-word
bind \e\[3\;5~ kill-word
bind \e\[1\;5C forward-word
bind \e\[1\;5D backward-word
bind \e\[1\;3C forward-word
bind \e\[1\;3D backward-word
bind \e\[A history-prefix-search-backward
bind \e\[B history-prefix-search-forward
