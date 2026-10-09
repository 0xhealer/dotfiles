#!/usr/bin/env bash
# VMware Workstation Pro on Linux (free for personal use).
# Broadcom only hands out the installer behind a login, so download it yourself first:
#   support.broadcom.com -> My Downloads -> VMware Workstation Pro -> Linux (VMware-Workstation-Full-*.bundle)
#
# Usage: tools/vmware-workstation.sh [-n] [install|modules|status]
#   install  deps + the .bundle + kernel modules + services (default)
#   modules  rebuild the kernel modules (run this after every kernel update)
#   status   installed version, loaded modules, Secure Boot
# Env: VMWARE_BUNDLE (path to the .bundle; default: newest in ~/Downloads)
set -Eeuo pipefail

if [[ "${1:-}" == -n ]]; then
  export DOTS_DRY_RUN=1
  shift
fi
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

modules_repo=https://github.com/mkubecek/vmware-host-modules.git
src="$HOME/.cache/dotfiles/vmware-host-modules"

install_deps() {
  log_step "Build dependencies"
  local base
  case "$DOTS_FAMILY" in
    arch)
      # headers must match the running kernel package (linux-cachyos, linux-zen, ...)
      base="$(cat "/usr/lib/modules/$(uname -r)/pkgbase" 2>/dev/null || echo linux)"
      pkg_install base-devel git "${base}-headers" ;;
    fedora) pkg_install gcc gcc-c++ make git elfutils-libelf-devel "kernel-devel-$(uname -r)" kernel-headers ;;
    debian) pkg_install build-essential git "linux-headers-$(uname -r)" ;;
    *) die "unsupported distro: $DOTS_FAMILY" ;;
  esac
}

find_bundle() {
  local b="${VMWARE_BUNDLE:-}"
  [[ -n "$b" ]] || b="$(ls -t "$HOME"/Downloads/VMware-Workstation-Full-*.bundle 2>/dev/null | head -n1 || true)"
  if [[ -z "$b" || ! -f "$b" ]]; then
    if is_dry; then echo "$HOME/Downloads/VMware-Workstation-Full-X.bundle"; return 0; fi
    log_err "no installer found. Download VMware-Workstation-Full-*.bundle from support.broadcom.com"
    log_err "into ~/Downloads, or set VMWARE_BUNDLE=/path/to/file.bundle"
    return 1
  fi
  echo "$b"
}

installed_version() { { vmware-installer -l 2>/dev/null || true; } | awk '$1=="vmware-workstation"{print $2; exit}'; }

install_bundle() {
  log_step "VMware Workstation Pro"
  if has vmware && [[ -n "$(installed_version)" ]]; then
    log_ok "already installed ($(installed_version))"
    return 0
  fi
  local b
  b="$(find_bundle)" || return 1
  log_info "installer: $b"
  sudo_run chmod +x "$b"
  sudo_run "$b" --eulas-agreed --required --console
}

build_modules() {
  log_step "Kernel modules (mkubecek/vmware-host-modules)"
  local ver branch
  ver="$(installed_version | cut -d. -f1-3)"
  if [[ -z "$ver" ]]; then
    is_dry && ver=17.6.0 || die "VMware Workstation is not installed (run: $0 install)"
  fi
  branch="workstation-$ver"
  if ! is_dry && ! git ls-remote --exit-code --heads "$modules_repo" "$branch" >/dev/null 2>&1; then
    log_warn "no branch '$branch' upstream, using the newest workstation-* branch"
    branch="$(git ls-remote --heads "$modules_repo" 'workstation-*' | awk -F/ '{print $NF}' | sort -V | tail -n1)"
  fi
  run rm -rf "$src"
  run mkdir -p "$(dirname "$src")"
  run git clone --depth 1 --branch "$branch" "$modules_repo" "$src"
  if is_dry; then
    printf '    [dry-run] make -C %s && sudo make install\n' "$src"
  else
    make -C "$src"
    sudo make -C "$src" install
  fi
  sudo_run systemctl restart vmware.service || log_warn "could not restart vmware.service"
}

enable_services() {
  log_step "Services"
  local s
  for s in vmware.service vmware-networks.service vmware-usbarbitrator.service; do
    if is_dry || systemctl list-unit-files "$s" 2>/dev/null | grep -q "$s"; then
      sudo_run systemctl enable --now "$s" || log_warn "could not enable $s"
    fi
  done
}

secure_boot_note() {
  if has mokutil && mokutil --sb-state 2>/dev/null | grep -qi enabled; then
    log_warn "Secure Boot is on: the vmmon/vmnet modules are unsigned and will not load."
    log_warn "Disable Secure Boot in the firmware, or sign them (mokutil --import with your own key)."
  fi
}

status() {
  log_step "VMware status"
  printf 'version:      %s\n' "$(installed_version || true)"
  printf 'modules:      %s\n' "$(lsmod | awk '/^vmmon|^vmnet/{printf "%s ", $1}')"
  printf 'secure boot:  %s\n' "$(mokutil --sb-state 2>/dev/null || echo unknown)"
  printf 'kernel:       %s\n' "$(uname -r)"
}

case "${1:-install}" in
  install)
    install_deps
    install_bundle
    build_modules
    enable_services
    secure_boot_note
    log_ok "done. Start it with: vmware   (rebuild modules after kernel updates: $0 modules)" ;;
  modules)
    install_deps
    build_modules
    secure_boot_note ;;
  status) status ;;
  *) die "unknown command: $1 (install|modules|status)" ;;
esac
