#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

# qylock sword on its own: CachyOS and Fedora (SDDM + Qt6), not Debian or VMware
case "$DOTS_FAMILY" in
  arch | fedora) ;;
  *) log_info "qylock is only set up on CachyOS and Fedora"; exit 0 ;;
esac

log_step "qylock (SDDM sword theme)"
# shellcheck source=../helper/qylock.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/qylock.sh"

pkg_install sddm
if install_qylock; then
  sudo_run mkdir -p /etc/sddm.conf.d
  if [[ -f /etc/sddm.conf ]] && ! is_dry; then
    sudo sed -i -E '/^[[:space:]]*Current=/d' /etc/sddm.conf
  fi
  write_root_file /etc/sddm.conf.d/zz-dotfiles.conf "[General]
InputMethod=compose

[Theme]
Current=sword"
  sudo_run systemctl enable --force sddm.service
  log_ok "SDDM greeter set to sword, takes effect after a reboot"
else
  log_warn "qylock was not installed, the greeter is unchanged"
fi
