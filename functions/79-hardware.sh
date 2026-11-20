#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

case "$DOTS_DISTRO" in
  kali) ;;
  *) exit 0 ;;
esac

log_step "Android Studio (Flatpak)"

# Android Studio comes from Flathub where there is no package
apps=(com.google.AndroidStudio)
pkg_install flatpak
sudo_run flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
for app in "${apps[@]}"; do
  if ! is_dry && flatpak info "$app" >/dev/null 2>&1; then
    log_info "$app already installed"
  else
    sudo_run flatpak install --system -y flathub "$app" || log_warn "could not install $app"
  fi
done

log_ok "Android Studio ready"
