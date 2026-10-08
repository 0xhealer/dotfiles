#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

log_step "Terminals (kitty, ghostty)"

install_ghostty_appimage() {
  local url dest="$HOME/.local/opt/ghostty/Ghostty.AppImage"
  url="$(github_asset_url pkgforge-dev/ghostty-appimage "$(uname -m)\\.AppImage$")"
  if [[ -z "$url" ]]; then
    log_warn "no Ghostty AppImage found for $(uname -m)"
    return 0
  fi
  fetch "$url" "$dest"
  run chmod +x "$dest"
  run mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
  run ln -sf "$dest" "$HOME/.local/bin/ghostty"
  if ! is_dry; then
    cat >"$HOME/.local/share/applications/ghostty.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Ghostty
Comment=Terminal emulator
Exec=$HOME/.local/bin/ghostty
Icon=utilities-terminal
Terminal=false
Categories=System;TerminalEmulator;
DESKTOP
  fi
  log_ok "Ghostty AppImage installed"
}

install_ghostty_deb() {
  local url tmp
  if [[ "$DOTS_OS_ID" == ubuntu ]]; then
    url="$(github_asset_url mkasberg/ghostty-ubuntu "$(deb_arch)_${DOTS_OS_VERSION_ID}\\.deb$")"
    if [[ -n "$url" ]]; then
      tmp="$(mktemp --suffix=.deb)"
      fetch "$url" "$tmp"
      sudo_run env DEBIAN_FRONTEND=noninteractive apt-get install -y "$tmp"
      rm -f "$tmp"
      log_ok "Ghostty installed from .deb"
      return 0
    fi
  fi
  install_ghostty_appimage
}

if ! has kitty; then
  log_warn "kitty is not installed"
fi

if ! has ghostty; then
  case "$DOTS_FAMILY" in
    debian) install_ghostty_deb ;;
    fedora)
      pkg_install fuse-libs
      install_ghostty_appimage
      ;;
    *) log_warn "ghostty was not installed by the package step on $DOTS_DISTRO" ;;
  esac
fi

link_config "$DOTS_ROOT/configs/kitty" "$HOME/.config/kitty"
link_config "$DOTS_ROOT/configs/ghostty" "$HOME/.config/ghostty"
