#!/usr/bin/env bash
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/polybar-launch.lock"
flock 9

pkill -x polybar 2>/dev/null
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 0.2; done

mkdir -p "$HOME/.cache"
# Keep colour emoji fonts out of polybar so missing glyphs never render as emoji.
export FONTCONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/polybar/fonts.conf"
config="${XDG_CONFIG_HOME:-$HOME/.config}/polybar/config.ini"

right=(vpn brightness dunst pulseaudio cpu memory filesystem)

wireless=""
for n in /sys/class/net/*; do
  [[ -d "$n/wireless" ]] && wireless=1
done
[[ -n "$wireless" ]] && right+=(wlan)
right+=(eth)

battery=""
adapter=""
for p in /sys/class/power_supply/*; do
  [[ -r "$p/type" ]] || continue
  case "$(<"$p/type")" in
    Battery) [[ -z "$battery" ]] && battery="$(basename "$p")" ;;
    Mains) [[ -z "$adapter" ]] && adapter="$(basename "$p")" ;;
  esac
done
if [[ -n "$battery" ]]; then
  right+=(battery)
  export POLYBAR_BATTERY="$battery"
  [[ -n "$adapter" ]] && export POLYBAR_ADAPTER="$adapter"
fi

POLYBAR_RIGHT_SECONDARY="${right[*]} powermenu"
POLYBAR_RIGHT="${right[*]} powermenu"
export POLYBAR_RIGHT POLYBAR_RIGHT_SECONDARY

command -v polybar >/dev/null || { notify-send -u critical "polybar not installed" "run: sudo apt install polybar" 2>/dev/null; exit 1; }

mapfile -t monitors < <(polybar --list-monitors | cut -d: -f1)
primary="$(xrandr --query 2>/dev/null | awk '/ primary/ {print $1; exit}')"
[[ -n $primary ]] || primary="${monitors[0]:-}"

if ((${#monitors[@]} == 0)); then
  polybar --reload -c "$config" main 9>&- >>"$HOME/.cache/polybar.log" 2>&1 &
  exit 0
fi

for m in "${monitors[@]}"; do
  if [[ $m == "$primary" ]]; then
    MONITOR=$m polybar --reload -c "$config" main 9>&- >>"$HOME/.cache/polybar.log" 2>&1 &
  else
    MONITOR=$m polybar --reload -c "$config" secondary 9>&- >>"$HOME/.cache/polybar.log" 2>&1 &
  fi
done
