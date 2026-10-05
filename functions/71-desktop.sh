#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

[[ -n "$DOTS_EXTRA_DE" ]] || exit 0

log_step "Desktop environment ($DOTS_EXTRA_DE)"

c="$DOTS_ROOT/configs"
ensure_executable "$c"/scripts/*
run mkdir -p "$HOME/.local/bin"
for script in "$c"/scripts/*; do
  link_config "$script" "$HOME/.local/bin/$(basename "$script")"
done

gsettings_set() {
  is_dry && { printf '    [dry-run] gsettings set %s\n' "$*"; return 0; }
  gsettings set "$@" 2>/dev/null || log_warn "gsettings failed: $*"
}

setup_gnome() {
  if ! has gsettings; then
    log_warn "gsettings not found, GNOME keybindings skipped"
    return 0
  fi
  if ! is_dry && ! gsettings list-schemas 2>/dev/null | grep -q '^org.gnome.desktop.wm.keybindings$'; then
    log_warn "GNOME schemas not available, GNOME keybindings skipped"
    return 0
  fi
  if ! is_dry && [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    log_warn "no session bus; run './install.sh desktop' from a terminal inside the GNOME session to apply keybindings"
    return 0
  fi

  local wm=org.gnome.desktop.wm.keybindings shell=org.gnome.shell.keybindings mk=org.gnome.settings-daemon.plugins.media-keys i
  gsettings_set $wm close "['<Super>q']"
  gsettings_set $wm toggle-fullscreen "['<Super>f']"
  gsettings_set $wm toggle-maximized "['<Super>m']"
  gsettings_set $wm switch-windows "['<Super>Tab','<Alt>Tab']"
  gsettings_set $wm switch-input-source "['XF86Keyboard']"
  gsettings_set $wm switch-input-source-backward "[]"
  gsettings_set $wm switch-to-workspace-up "['<Super>Page_Up']"
  gsettings_set $wm switch-to-workspace-down "['<Super>Page_Down']"
  gsettings_set $wm move-to-workspace-up "['<Super><Shift>Page_Up']"
  gsettings_set $wm move-to-workspace-down "['<Super><Shift>Page_Down']"
  for i in 1 2 3 4 5 6 7 8 9; do
    gsettings_set $shell switch-to-application-$i "[]"
    gsettings_set $wm switch-to-workspace-$i "['<Super>$i']"
    gsettings_set $wm move-to-workspace-$i "['<Super><Shift>$i']"
  done
  gsettings_set $shell toggle-overview "['<Super>o']"
  gsettings_set $shell toggle-application-view "['<Super>d','<Super>space']"
  gsettings_set $shell toggle-message-tray "[]"
  gsettings_set $shell show-screenshot-ui "['Print','<Super><Shift>s']"
  gsettings_set $mk screensaver "['<Super><Alt>l']"
  gsettings_set $mk logout "['<Super><Shift>e']"

  local paths=() n=0 name cmd accel path
  while IFS='|' read -r name cmd accel; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/dots-$n/"
    cmd="${cmd/#\~/$HOME}"
    gsettings_set "$mk.custom-keybinding:$path" name "$name"
    gsettings_set "$mk.custom-keybinding:$path" command "$cmd"
    gsettings_set "$mk.custom-keybinding:$path" binding "$accel"
    paths+=("'$path'")
    n=$((n + 1))
  done <"$c/gnome/keybindings.tsv"
  local joined
  joined="$(IFS=,; printf '%s' "${paths[*]}")"
  gsettings_set $mk custom-keybindings "[$joined]"
  log_ok "GNOME keybindings applied ($n custom commands)"
}

kwrite() {
  local tool=kwriteconfig6
  if is_dry; then
    run "$tool" --file kglobalshortcutsrc "$@"
    return 0
  fi
  has kwriteconfig6 || tool=kwriteconfig5
  if ! has "$tool"; then
    log_warn "kwriteconfig not found, KDE shortcuts skipped"
    return 1
  fi
  run "$tool" --file kglobalshortcutsrc "$@"
}

setup_kde() {
  has kwriteconfig6 || has kwriteconfig5 || is_dry || {
    log_warn "KDE tools not found, install kali-desktop-kde first; KDE shortcuts skipped"
    return 0
  }
  local i
  kwrite --group kwin --key "Window Close" "Meta+Q,Alt+F4,Close Window"
  kwrite --group kwin --key "Window Fullscreen" "Meta+F,none,Make Window Fullscreen"
  kwrite --group kwin --key "Window Maximize" "Meta+M,Meta+PgUp,Maximize Window"
  kwrite --group kwin --key "Overview" "Meta+O,Meta+W,Toggle Overview"
  kwrite --group kwin --key "Walk Through Windows" "Meta+Tab"$'\t'"Alt+Tab,Alt+Tab,Walk Through Windows"
  kwrite --group kwin --key "Switch to Next Desktop" "Meta+PgDown,none,Switch to Next Desktop"
  kwrite --group kwin --key "Switch to Previous Desktop" "Meta+PgUp,none,Switch to Previous Desktop"
  for i in 1 2 3 4 5 6 7 8 9; do
    kwrite --group kwin --key "Switch to Desktop $i" "Meta+$i,Ctrl+F$i,Switch to Desktop $i"
    kwrite --group kwin --key "Window to Desktop $i" "Meta+Shift+$i,none,Window to Desktop $i"
  done
  kwrite --group kwin --key "Switch Window Left" "Meta+Left,none,Switch to Window to the Left"
  kwrite --group kwin --key "Switch Window Right" "Meta+Right,none,Switch to Window to the Right"
  kwrite --group kwin --key "Switch Window Up" "Meta+Up,none,Switch to Window Above"
  kwrite --group kwin --key "Switch Window Down" "Meta+Down,none,Switch to Window Below"
  kwrite --group kwin --key "Window Quick Tile Left" "Meta+Shift+Left,none,Quick Tile Window to the Left"
  kwrite --group kwin --key "Window Quick Tile Right" "Meta+Shift+Right,none,Quick Tile Window to the Right"
  kwrite --group ksmserver --key "Lock Session" "Meta+Alt+L,Meta+L,Lock Session"
  kwrite --group ksmserver --key "Log Out" "Meta+Shift+E,Ctrl+Alt+Del,Log Out"

  local apps="$HOME/.local/share/applications" id name cmd key
  run mkdir -p "$apps"
  while IFS='|' read -r id name cmd key; do
    [[ -z "$id" || "$id" == \#* ]] && continue
    if ! is_dry; then
      printf '[Desktop Entry]\nType=Application\nName=%s\nExec=%s\nNoDisplay=true\nX-KDE-GlobalAccel-CommandShortcut=true\n' "$name" "$cmd" >"$apps/$id.desktop"
    fi
    kwrite --group services --group "$id.desktop" --key _launch "$key"
  done <"$c/kde/shortcuts.tsv"
  log_ok "KDE shortcuts written; log out and back in to activate them"
}

case "$DOTS_EXTRA_DE" in
  gnome) setup_gnome ;;
  kde) setup_kde ;;
esac
