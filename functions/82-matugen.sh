#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

log_step "Theme colors"

gen="$HOME/.config/matugen/generated"
run mkdir -p "$gen"
# Rose Pine is the only theme: the colour files are pre-rendered in configs/matugen/fallback
fb="$DOTS_ROOT/configs/matugen/fallback"
for f in dmenurc fzf-colors.fish fzf-colors.sh ghostty-colors i3-colors.conf kitty-colors.conf polybar-colors.ini rofi-colors.rasi; do
  run cp "$fb/$f" "$gen/$f"
done

if [[ "$DOTS_WM" != i3 ]]; then
  # Noctalia's kitty and ghostty templates supply the colours, so the static fallback must not override them
  if ! is_dry; then
    : >"$gen/kitty-colors.conf"
    : >"$gen/ghostty-colors"
  fi
  log_info "niri desktop: Noctalia applies the Rose Pine palette to every app (see configs/noctalia/dotfiles.toml)"
  exit 0
fi

run mkdir -p "$HOME/.config/dunst/dunstrc.d" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" \
  "$HOME/.config/qt5ct/colors" "$HOME/.config/qt6ct/colors" "$HOME/.config/btop/themes"
run cp "$fb/dunst-colors.conf" "$HOME/.config/dunst/dunstrc.d/90-matugen.conf"
run cp "$fb/gtk3.css" "$HOME/.config/gtk-3.0/gtk.css"
run cp "$fb/gtk4.css" "$HOME/.config/gtk-4.0/gtk.css"
run cp "$fb/qt-colors.conf" "$HOME/.config/qt5ct/colors/matugen.conf"
run cp "$fb/qt-colors.conf" "$HOME/.config/qt6ct/colors/matugen.conf"
run cp "$fb/btop.theme" "$HOME/.config/btop/themes/matugen.theme"

c="$DOTS_ROOT/configs"
ensure_executable "$c"/scripts/*
run mkdir -p "$HOME/.config/matugen" "$HOME/.local/bin"
for script in "$c"/scripts/*; do
  link_config "$script" "$HOME/.local/bin/$(basename "$script")"
done

install_waypaper() {
  has waypaper && return 0
  if has pipx; then
    run pipx install --system-site-packages waypaper || log_warn "waypaper install failed; wallpaper-select falls back to a rofi grid"
  else
    log_warn "pipx not found, waypaper not installed; wallpaper-select falls back to a rofi grid"
  fi
}
install_waypaper

wp_conf="$HOME/.config/waypaper/config.ini"
if [[ ! -f "$wp_conf" ]]; then
  run mkdir -p "$(dirname "$wp_conf")"
  if ! is_dry; then
    sed "s|@HOME@|$HOME|g" "$c/waypaper/config.ini" >"$wp_conf"
    log_ok "waypaper configured"
  fi
else
  log_info "waypaper config exists, left untouched"
fi

setup_app_theming() {
  local gtk v qt
  for gtk in gtk-3.0 gtk-4.0; do
    if [[ ! -f "$HOME/.config/$gtk/settings.ini" ]]; then
      run mkdir -p "$HOME/.config/$gtk"
      is_dry || printf '[Settings]\ngtk-application-prefer-dark-theme=1\ngtk-theme-name=Adwaita-dark\n' >"$HOME/.config/$gtk/settings.ini"
    fi
  done
  if has gsettings; then
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark 2>/dev/null || true
  fi

  for v in 5 6; do
    qt="$HOME/.config/qt${v}ct"
    if [[ ! -f "$qt/qt${v}ct.conf" ]]; then
      run mkdir -p "$qt/colors"
      is_dry || printf '[Appearance]\ncolor_scheme_path=%s/colors/matugen.conf\ncustom_palette=true\nstyle=Fusion\n' "$qt" >"$qt/qt${v}ct.conf"
    fi
  done
  run mkdir -p "$HOME/.config/environment.d"
  is_dry || printf 'QT_QPA_PLATFORMTHEME=qt6ct\n' >"$HOME/.config/environment.d/90-dotfiles-qt.conf"

  local btop="$HOME/.config/btop/btop.conf"
  if [[ -f "$btop" ]]; then
    sed -i 's/^color_theme *=.*/color_theme = "matugen"/' "$btop"
  fi
}
setup_app_theming

if has feh && [[ -d "$HOME/Pictures/Wallpapers" ]] && [[ -n "${DISPLAY:-}" ]] && ! is_dry; then
  wallpaper-set || log_warn "initial wallpaper failed"
else
  log_info "wallpaper changes on Super+w (pick) or Super+Shift+w (random); the colours are always Rose Pine"
fi
