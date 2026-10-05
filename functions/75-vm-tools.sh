#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

virt="${DOTS_VIRT:-$(systemd-detect-virt 2>/dev/null || true)}"

enable_first() {
  local unit
  for unit in "$@"; do
    if systemctl list-unit-files "$unit" 2>/dev/null | grep -q "^$unit"; then
      sudo_run systemctl enable --now "$unit" || log_warn "could not start $unit"
      return 0
    fi
  done
  return 0
}

case "$virt" in
  vmware)
    log_step "VM guest tools (VMware)"
    case "$DOTS_FAMILY" in
      debian | fedora) pkg_install open-vm-tools open-vm-tools-desktop ;;
      arch) pkg_install open-vm-tools gtkmm3 ;;
    esac
    enable_first open-vm-tools.service vmtoolsd.service
    ;;
  kvm | qemu)
    log_step "VM guest tools (SPICE)"
    pkg_install spice-vdagent
    enable_first spice-vdagentd.service spice-vdagent.service
    ;;
  oracle)
    log_step "VM guest tools (VirtualBox)"
    case "$DOTS_FAMILY" in
      debian) pkg_install virtualbox-guest-utils virtualbox-guest-x11 ;;
      fedora) pkg_install virtualbox-guest-additions ;;
      arch) pkg_install virtualbox-guest-utils ;;
    esac
    enable_first vboxservice.service virtualbox-guest-utils.service
    ;;
  *)
    exit 0
    ;;
esac

log_ok "guest tools installed; log out and back in so the display follows the window size"
