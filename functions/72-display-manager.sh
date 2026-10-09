#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

case "$DOTS_FAMILY" in
  debian) [[ -n "$DOTS_EXTRA_DE" ]] || exit 0 ;;
  arch | fedora) ;;
  *) exit 0 ;;
esac

log_step "Display manager"

source "$(dirname "${BASH_SOURCE[0]}")/../helper/qylock.sh"

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
  local theme=dots
  install_qylock && theme="$(qylock_choose_theme)"
  sudo_run mkdir -p /etc/sddm.conf.d
  sudo_run rm -f /etc/sddm.conf.d/10-dotfiles.conf
  [[ "$DOTS_FAMILY" == debian ]] && remove_virtual_keyboard
  if [[ -f /etc/sddm.conf ]] && ! is_dry; then
    sudo sed -i -E '/^[[:space:]]*(Current|InputMethod)=/d' /etc/sddm.conf
  fi
  sudo_run rm -rf /usr/share/sddm/themes/dots
  sudo_run mkdir -p /usr/share/sddm/themes/dots
  sudo_run cp "$DOTS_ROOT"/configs/sddm/dots/* /usr/share/sddm/themes/dots/
  if have_qt6_greeter; then
    printf 'QtVersion=6\n' | sudo_run tee -a /usr/share/sddm/themes/dots/metadata.desktop >/dev/null
  fi
  sudo_run cp "$DOTS_ROOT/assets/wallpapers/001.jpg" /usr/share/sddm/themes/dots/background.jpg
  sudo_run chmod -R a+rX /usr/share/sddm/themes/dots

  # try the qylock theme; if it does not load, fall back to dots; if that fails too, leave the distro default
  if [[ "$theme" != dots ]] && ! sddm_gate "$theme"; then theme=dots; fi
  if [[ "$theme" == dots ]] && ! sddm_gate dots; then
    return 1
  fi
  # InputMethod=compose is only needed on Debian/Ubuntu (it avoids the virtual keyboard crash on X11)
  local general=""
  if [[ "$DOTS_FAMILY" == debian ]]; then
    general="[General]
DisplayServer=x11
InputMethod=compose

"
  elif [[ "$DOTS_FAMILY" == fedora ]]; then
    # Fedora ships GDM; SDDM's default Wayland greeter needs kwin, which is not installed. Use the X11 greeter.
    general="[General]
DisplayServer=x11

"
  fi
  write_root_file /etc/sddm.conf.d/zz-dotfiles.conf "${general}[Theme]
Current=$theme"
}

if [[ "$DOTS_FAMILY" != debian ]]; then
  pkg_install sddm
  [[ "$DOTS_FAMILY" == fedora ]] && pkg_install sddm-x11 xorg-x11-server-Xorg xorg-x11-xinit xorg-x11-drv-libinput
  if ! install_greeter && [[ "$DOTS_FAMILY" == fedora ]]; then
    log_warn "SDDM greeter could not be verified, keeping the current display manager (GDM). Run from a terminal inside your desktop, or DOTS_SDDM_FORCE=1 to override"
    exit 0
  fi
  sudo_run systemctl enable --force sddm.service
  if [[ "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" != */sddm.service ]] && ! is_dry; then
    log_warn "display-manager.service does not point at sddm, check: systemctl status display-manager"
  fi
  if ! is_dry; then
    log_info "effective SDDM theme: $(grep -rh '^Current=' /etc/sddm.conf /etc/sddm.conf.d 2>/dev/null | tail -1)"
  fi
  log_ok "SDDM is the display manager from the next boot"
  exit 0
fi

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
