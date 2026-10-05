#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

log_step "Desktop ($DOTS_WM)"

setup_i3() {
  local c="$DOTS_ROOT/configs"
  has i3 || log_warn "i3 is not installed"
  ensure_executable "$c/polybar/launch.sh" "$c/dmenu/dmenu-themed" "$c"/scripts/*

  link_config "$c/i3" "$HOME/.config/i3"
  link_config "$c/polybar" "$HOME/.config/polybar"
  link_config "$c/rofi" "$HOME/.config/rofi"
  link_config "$c/picom" "$HOME/.config/picom"
  run mkdir -p "$HOME/.config/dunst/dunstrc.d"
  link_config "$c/dunst/dunstrc" "$HOME/.config/dunst/dunstrc"
  link_config "$c/dmenu/dmenu-themed" "$HOME/.local/bin/dmenu-themed"
  local script
  for script in "$c"/scripts/*; do
    link_config "$script" "$HOME/.local/bin/$(basename "$script")"
  done
  [[ -f /usr/share/xsessions/i3.desktop ]] || log_warn "no i3 session file found, is i3 installed?"
  log_info "pick the i3 session on the login screen (gear icon)"
}

render_niri_config() {
  local src="$DOTS_ROOT/configs/niri/config.kdl" blur="$DOTS_ROOT/configs/niri/blur.kdl"
  local out="$1" with_blur="$2" inc
  # Noctalia renders niri's colours into noctalia.kdl; niri 25.11+ can include it
  inc='include "noctalia.kdl"'
  if [[ "$with_blur" == 1 ]]; then
    sed -e "/^\/\/ @BLUR@/{r $blur" -e 'd}' -e "s|^// @NOCTALIA@|$inc|" "$src" >"$out"
  else
    sed -e '/^\/\/ @BLUR@/d' -e "s|^// @NOCTALIA@|$inc|" "$src" >"$out"
  fi
}

niri_valid() {
  has niri || return 0
  niri validate -c "$1" >/dev/null 2>&1
}

setup_noctalia_theming() {
  # terminals: Noctalia's kitty/ghostty templates replace the static fallback palette
  local f
  for f in "$HOME/.config/matugen/generated/kitty-colors.conf" "$HOME/.config/matugen/generated/ghostty-colors"; do
    [[ -f "$f" ]] && ! is_dry && : >"$f"
  done
  # Qt apps read the colour scheme Noctalia writes for qt6ct
  run mkdir -p "$HOME/.config/environment.d"
  is_dry || printf 'QT_QPA_PLATFORMTHEME=qt6ct\n' >"$HOME/.config/environment.d/90-dotfiles-qt.conf"
  # GTK: adw-gtk3 is what Noctalia's gtk template recolours
  if has gsettings; then
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark 2>/dev/null || true
  fi
  # VS Code: the community template fills this extension with the generated colours
  local ext="$HOME/$DOTS_CODE_EXT/extensions/noctalia.noctaliatheme-0.0.5"
  run mkdir -p "$ext/themes"
  is_dry || printf '%s\n' '{ "name": "noctaliatheme", "displayName": "Noctalia", "publisher": "noctalia", "version": "0.0.5", "engines": { "vscode": "^1.80.0" }, "categories": ["Themes"], "contributes": { "themes": [ { "label": "NoctaliaTheme", "uiTheme": "vs-dark", "path": "./themes/NoctaliaTheme-color-theme.json" } ] } }' >"$ext/package.json"
  local vs="$HOME/.config/$DOTS_CODE_DIR/User/settings.json"
  if [[ -f "$vs" ]] && ! is_dry; then
    sed -i 's/"workbench\.colorTheme": *"[^"]*"/"workbench.colorTheme": "NoctaliaTheme"/' "$vs"
  fi
  log_info "colours follow the wallpaper; after the first login run: noctalia msg theme"
}

setup_default_apps() {
  local prefix=""
  if [[ -f /etc/xdg/menus/arch-applications.menu ]]; then
    prefix=arch-
  elif [[ -f /etc/xdg/menus/plasma-applications.menu ]]; then
    prefix=plasma-
  fi
  run mkdir -p "$HOME/.config/environment.d"
  if ! is_dry; then
    {
      printf 'TERMINAL=ghostty\n'
      [[ -n "$prefix" ]] && printf 'XDG_MENU_PREFIX=%s\n' "$prefix"
    } >"$HOME/.config/environment.d/91-dotfiles-defaults.conf"
    printf 'com.mitchellh.ghostty.desktop\n' >"$HOME/.config/xdg-terminals.list"
  fi
  # Dolphin needs a menu file to know the installed apps (Open With, default apps)
  if [[ -n "$prefix" ]] && has kbuildsycoca6; then
    run env XDG_MENU_PREFIX="$prefix" kbuildsycoca6 --noincremental
  fi
  if has xdg-mime; then
    run xdg-mime default org.kde.dolphin.desktop inode/directory
    run xdg-mime default com.mitchellh.ghostty.desktop x-scheme-handler/terminal
  fi
  if has kwriteconfig6; then
    run kwriteconfig6 --file kdeglobals --group General --key TerminalApplication ghostty
    run kwriteconfig6 --file kdeglobals --group General --key TerminalService com.mitchellh.ghostty.desktop
  fi
  log_info "defaults: Dolphin for folders, ghostty for terminals"
}

setup_niri() {
  local c="$DOTS_ROOT/configs" ver tmp blur=0

  has niri || log_warn "niri is not installed"
  ver="$(program_version niri || true)"
  if [[ "${DOTS_VIRT:-$(systemd-detect-virt 2>/dev/null || true)}" == vmware ]]; then
    log_info "VMware: niri needs VM > Settings > Display > Accelerate 3D graphics, without it niri has no outputs and the screen stays frozen"
  fi
  if [[ -n "$ver" ]] && version_ge "$ver" 26.04; then
    blur=1
  else
    log_warn "niri ${ver:-unknown} has no background blur (needs 26.04+), installing config without it"
  fi

  tmp="$(mktemp)"
  render_niri_config "$tmp" "$blur"
  if ! niri_valid "$tmp" && ((blur)); then
    log_warn "niri rejected the blur rule, falling back to config without blur"
    blur=0
    render_niri_config "$tmp" 0
  fi
  if ! niri_valid "$tmp"; then
    log_warn "niri validate failed for the rendered config; installing it anyway, check with: niri validate"
  fi
  copy_config "$tmp" "$HOME/.config/niri/config.kdl"
  rm -f "$tmp"
  # niri refuses a config whose include is missing, so create the file before Noctalia first writes it
  [[ -f "$HOME/.config/niri/noctalia.kdl" ]] || { is_dry || : >"$HOME/.config/niri/noctalia.kdl"; }
  run mkdir -p "$HOME/Pictures/Screenshots" "$HOME/.local/bin"
  ensure_executable "$c/scripts/wallpaper-rotate"
  link_config "$c/scripts/wallpaper-rotate" "$HOME/.local/bin/wallpaper-rotate"

  link_config "$c/noctalia/dotfiles.toml" "$HOME/.config/noctalia/dotfiles.toml"
  if has noctalia && ! noctalia config validate >/dev/null 2>&1; then
    log_warn "noctalia rejected configs/noctalia/dotfiles.toml, removing the copy"
    run rm -f "$HOME/.config/noctalia/dotfiles.toml"
  fi

  setup_noctalia_theming
  setup_default_apps

  local vs="$HOME/.config/vicinae/settings.json"
  if [[ -f "$vs" ]]; then
    log_info "vicinae settings exist, left untouched"
  else
    copy_config "$c/vicinae/settings.json" "$vs"
  fi
}

case "$DOTS_WM" in
  i3) setup_i3 ;;
  niri) setup_niri ;;
  *) die "unknown desktop: $DOTS_WM" ;;
esac
