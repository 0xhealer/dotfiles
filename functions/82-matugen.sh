#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

log_step "Theme colors"

gen="$HOME/.config/matugen/generated"
run mkdir -p "$gen"
for f in "$DOTS_ROOT"/configs/matugen/fallback/*; do
  [[ -e "$gen/$(basename "$f")" ]] || run cp "$f" "$gen/"
done
if [[ -f "$gen/i3-colors.conf" ]] && ! grep -q '^client\.focused ' "$gen/i3-colors.conf"; then
  run cp "$DOTS_ROOT/configs/matugen/fallback/i3-colors.conf" "$gen/"
fi

if [[ "$DOTS_WM" != i3 ]]; then
  # Noctalia's kitty and ghostty templates supply the colours, so the static fallback must not override them
  if ! is_dry; then
    : >"$gen/kitty-colors.conf"
    : >"$gen/ghostty-colors"
  fi
  log_info "niri desktop: Noctalia themes every app from the wallpaper (see configs/noctalia/dotfiles.toml)"
  exit 0
fi

install_matugen() {
  local key url tmp bin
  has matugen && return 0
  case "$(uname -m)" in
    x86_64) key='(x86_64|amd64)' ;;
    aarch64 | arm64) key='(aarch64|arm64)' ;;
    *) key="$(uname -m)" ;;
  esac
  url="$(github_asset_url InioX/matugen "linux.*${key}.*\\.tar\\.gz\$|${key}.*linux.*\\.tar\\.gz\$")"
  if [[ -n "$url" ]]; then
    tmp="$(mktemp -d)"
    fetch "$url" "$tmp/matugen.tar.gz"
    run tar -xzf "$tmp/matugen.tar.gz" -C "$tmp"
    bin="$(find "$tmp" -type f -name matugen | head -n1)"
    if [[ -n "$bin" ]]; then
      run install -Dm755 "$bin" "$HOME/.local/bin/matugen"
      rm -rf "$tmp"
      log_ok "matugen installed from release"
      return 0
    fi
    rm -rf "$tmp"
  fi
  if has cargo; then
    log_info "building matugen with cargo (a few minutes)"
    run cargo install matugen --locked --root "$HOME/.local"
  else
    log_warn "could not install matugen (no release asset, no cargo); static palette stays in use"
  fi
}

install_matugen

c="$DOTS_ROOT/configs"
ensure_executable "$c"/scripts/*
run mkdir -p "$HOME/.config/matugen" "$HOME/.local/bin"
link_config "$c/matugen/config.toml" "$HOME/.config/matugen/config.toml"
link_config "$c/matugen/templates" "$HOME/.config/matugen/templates"
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
  local ext="$HOME/.vscode/extensions/dotfiles.matugen-theme" gtk v qt vs="$HOME/.config/Code/User/settings.json"
  run mkdir -p "$ext/themes"
  run cp "$DOTS_ROOT/configs/vscode-theme/package.json" "$ext/package.json"

  if [[ -f "$vs" ]] && ! is_dry; then
    sed -i 's/"workbench\.colorTheme": *"[^"]*"/"workbench.colorTheme": "Matugen"/' "$vs"
    log_ok "VS Code uses the generated Matugen theme"
  fi

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

if has matugen && has feh && [[ -d "$HOME/Pictures/Wallpapers" ]] && ! is_dry; then
  if [[ -n "${DISPLAY:-}" ]]; then
    wallpaper-set || log_warn "initial wallpaper/theme generation failed"
  else
    wall="$(find "$HOME/Pictures/Wallpapers" -maxdepth 1 -type f | shuf -n1)"
    matugen image "$wall" -m dark --source-color-index 0 >/dev/null 2>&1 ||
      matugen image "$wall" -m dark >/dev/null 2>&1 ||
      log_warn "initial theme generation failed"
    mkdir -p "$HOME/.cache"
    printf '%s\n' "$wall" >"$HOME/.cache/dotfiles-wallpaper"
  fi
else
  log_info "theme is generated on first wallpaper change: Super+w (pick) or Super+Shift+w (random)"
fi
