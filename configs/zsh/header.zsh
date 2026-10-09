# One-line session banner in the ButterZsh layout, values only:
#   — host · ip · wm · shell —

_dots_header() {
  local wm w host ip shell_ver
  wm="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
  if [[ -z $wm ]]; then
    for w in i3 niri sway hyprland openbox bspwm xfwm4 kwin_x11 kwin_wayland mutter awesome qtile xmonad; do
      pgrep -x "$w" >/dev/null 2>&1 && { wm=$w; break; }
    done
  fi
  wm="${wm:-tty}"

  host="${HOST%%.*}"
  ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  [[ -n $ip ]] || ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1)}')
  shell_ver="zsh ${ZSH_VERSION}"

  printf '\e[38;5;212m—\e[0m \e[1;97m%s\e[0m' "$host"
  [[ -n $ip ]] && printf ' \e[2m·\e[0m \e[97m%s\e[0m' "$ip"
  printf ' \e[2m·\e[0m \e[38;5;114m%s\e[0m \e[2m·\e[0m \e[38;5;213m%s\e[0m \e[38;5;212m—\e[0m\n\n' "$wm" "$shell_ver"
}

if [[ -o interactive && -t 1 && -z ${_DOTS_HEADER_SHOWN:-} && $TERM != dumb ]]; then
  _DOTS_HEADER_SHOWN=1
  export _DOTS_HEADER_SHOWN
  _dots_header
fi
