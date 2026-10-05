#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

case "$DOTS_DISTRO" in
  cachyos | fedora | kali) ;;
  *) exit 0 ;;
esac

log_step "Arduino and hardware tools"

# serial ports: uucp on Arch, dialout elsewhere
serial_group=dialout
[[ "$DOTS_FAMILY" == arch ]] && serial_group="uucp"
if getent group "$serial_group" >/dev/null 2>&1 || is_dry; then
  sudo_run usermod -aG "$serial_group" "$(id -un)"
fi

# arduino-cli: packaged on Arch, upstream script elsewhere
if ! has arduino-cli && [[ "$DOTS_FAMILY" != arch ]]; then
  if is_dry; then
    printf '    [dry-run] install arduino-cli from upstream\n'
  else
    run mkdir -p "$HOME/.local/bin"
    tmp="$(mktemp)"
    if fetch "https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh" "$tmp"; then
      BINDIR="$HOME/.local/bin" sh "$tmp" || log_warn "could not install arduino-cli"
    else
      log_warn "could not download the arduino-cli installer"
    fi
    rm -f "$tmp"
  fi
fi
if ! is_dry && { has arduino-cli || [[ -x "$HOME/.local/bin/arduino-cli" ]]; }; then
  export PATH="$HOME/.local/bin:$PATH"
  arduino-cli core update-index >/dev/null 2>&1 || log_warn "arduino-cli index update failed"
  arduino-cli core install arduino:avr >/dev/null 2>&1 || log_warn "arduino:avr core not installed, run: arduino-cli core install arduino:avr"
fi

# Arduino IDE 2 and Android Studio come from Flathub where there is no package
apps=()
case "$DOTS_DISTRO" in
  fedora) apps=(cc.arduino.IDE2) ;;
  kali) apps=(cc.arduino.IDE2 com.google.AndroidStudio) ;;
esac
if ((${#apps[@]})); then
  pkg_install flatpak
  sudo_run flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  for app in "${apps[@]}"; do
    if ! is_dry && flatpak info "$app" >/dev/null 2>&1; then
      log_info "$app already installed"
    else
      sudo_run flatpak install --system -y flathub "$app" || log_warn "could not install $app"
    fi
  done
fi

log_ok "hardware tools ready; log out and in once for serial port access ($serial_group)"
