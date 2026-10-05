#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

log_step "Packages ($DOTS_DISTRO)"

setup_fedora_repos() {
  if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
    sudo_run dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" ||
      log_warn "could not add RPM Fusion, vlc will be skipped"
  fi
  sudo_run dnf copr enable -y scottames/vicinae
  sudo_run dnf copr enable -y pgdev/ghostty
}

if [[ "$DOTS_FAMILY" == fedora ]]; then
  setup_fedora_repos
fi

install_packages_from_file "$DOTS_PKG_FILE"

if [[ "$DOTS_FAMILY" == debian ]]; then
  run mkdir -p "$HOME/.local/bin"
  if has fdfind && ! has fd; then run ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"; fi
  if has batcat && ! has bat; then run ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"; fi
fi

log_ok "packages installed"
