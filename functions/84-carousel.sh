#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

log_step "Wallpaper Carousel (Noctalia)"

if [[ "$DOTS_WM" != niri ]]; then
  log_info "Wallpaper Carousel only runs inside Noctalia; i3 uses wallpaper-select (rofi), skipping"
  exit 0
fi

dest="$HOME/.local/share/noctalia/plugins/wallpaperCarousel"

if [[ -f "$dest/plugin.toml" ]]; then
  log_info "already installed: $dest"
else
  plugin_repo=https://github.com/motor-dev/wallpaperCarousel
  tmp="$(mktemp -d)"
  url="$(github_asset_url motor-dev/wallpaperCarousel '\.tar\.gz$')"
  if [[ -n "$url" ]]; then
    fetch "$url" "$tmp/plugin.tar.gz"
    run mkdir -p "$tmp/x"
    run tar -xzf "$tmp/plugin.tar.gz" -C "$tmp/x"
  else
    log_info "no release archive, cloning $plugin_repo instead"
    run env GIT_TERMINAL_PROMPT=0 git clone --depth 1 --quiet "$plugin_repo" "$tmp/x/wallpaperCarousel" ||
      { rm -rf "$tmp"; die "could not clone $plugin_repo"; }
  fi
  if is_dry; then
    rm -rf "$tmp"
    exit 0
  fi
  manifest="$(find "$tmp/x" -name plugin.toml | head -n1)"
  if [[ -z "$manifest" ]]; then
    rm -rf "$tmp"
    die "plugin.toml not found in the downloaded plugin"
  fi
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  cp -a "$(dirname "$manifest")" "$dest"
  rm -rf "$dest/.git" "$tmp"
  log_ok "installed to $dest"
fi

has qs || log_warn "quickshell (qs) is required by the plugin and was not found on PATH; Super+W falls back to a random wallpaper until it is installed"

if has noctalia && ! is_dry; then
  enabled=0
  for _ in 1 2 3 4 5; do
    if noctalia msg plugins list 2>/dev/null | grep -q 'wallpaperCarousel.*enabled'; then
      enabled=1
      break
    fi
    noctalia msg plugins enable yngwe/wallpaperCarousel >/dev/null 2>&1 || true
    sleep 2
  done
  if ((enabled)); then
    log_ok "Wallpaper Carousel plugin enabled"
  else
    log_warn "could not enable the plugin (is Noctalia running?), run: noctalia msg plugins enable yngwe/wallpaperCarousel"
  fi
fi
log_info "toggle with Super+W (niri keybind)"
