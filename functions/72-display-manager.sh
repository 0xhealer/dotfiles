#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

[[ "$DOTS_FAMILY" == debian && -n "$DOTS_EXTRA_DE" ]] || exit 0

log_step "Display manager"

remove_virtual_keyboard() {
  is_dry && return 0
  local pkg
  while read -r pkg; do
    [[ -n "$pkg" ]] || continue
    if apt-get -s remove "$pkg" 2>/dev/null | grep -Eq '^Remv sddm'; then
      log_warn "keeping $pkg, removing it would remove sddm"
    else
      sudo apt-get remove -y "$pkg" >/dev/null || log_warn "could not remove $pkg"
    fi
  done < <(dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 2>/dev/null | awk '$1 ~ /^ii/ && $2 ~ /virtualkeyboard/ {print $2}')
}

install_greeter() {
  sudo_run mkdir -p /etc/sddm.conf.d
  sudo_run rm -f /etc/sddm.conf.d/10-dotfiles.conf
  remove_virtual_keyboard
  if [[ -f /etc/sddm.conf ]] && ! is_dry; then
    sudo sed -i -E '/^[[:space:]]*(Current|InputMethod)=/d' /etc/sddm.conf
  fi
  write_root_file /etc/sddm.conf.d/zz-dotfiles.conf "[General]
DisplayServer=x11
InputMethod=compose

[Theme]
Current=dots"
  sudo_run rm -rf /usr/share/sddm/themes/dots
  sudo_run mkdir -p /usr/share/sddm/themes/dots
  sudo_run cp "$DOTS_ROOT"/configs/sddm/dots/* /usr/share/sddm/themes/dots/
  if command -v sddm-greeter-qt6 >/dev/null 2>&1 || [[ -x /usr/lib/sddm/sddm-greeter-qt6 ]]; then
    printf 'QtVersion=6\n' | sudo_run tee -a /usr/share/sddm/themes/dots/metadata.desktop >/dev/null
  fi
  sudo_run cp "$DOTS_ROOT/assets/wallpapers/001.jpg" /usr/share/sddm/themes/dots/background.jpg
  sudo_run chmod -R a+rX /usr/share/sddm/themes/dots
}

if [[ "$(cat /etc/X11/default-display-manager 2>/dev/null)" == */sddm ]] && systemctl is-enabled sddm.service >/dev/null 2>&1; then
  log_info "SDDM is already the display manager"
  install_greeter
  exit 0
fi

if ! is_dry; then
  printf 'sddm shared/default-x-display-manager select sddm\n' | sudo debconf-set-selections
fi
sudo_run env DEBIAN_FRONTEND=noninteractive apt-get install -y sddm xserver-xorg xserver-xorg-input-libinput xinit x11-xserver-utils
install_greeter
[[ -x /usr/bin/sddm || -x /usr/sbin/sddm ]] && write_root_file /etc/X11/default-display-manager "$(command -v sddm || echo /usr/bin/sddm)"
sudo_run systemctl enable --force sddm.service

if ! is_dry; then
  log_info "effective SDDM theme: $(grep -rh '^Current=' /etc/sddm.conf /etc/sddm.conf.d 2>/dev/null | tail -1)"
fi
log_ok "SDDM is the display manager from the next boot; it lists i3, GNOME and KDE sessions"
