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
  # a COPR without a build for this Fedora release 404s and breaks every later dnf call,
  # so each one is probed and dropped when it has nothing for us
  enable_copr scottames/vicinae || skip_pkg vicinae
  enable_copr scottames/ghostty || enable_copr pgdev/ghostty || skip_pkg ghostty
}

skip_pkg() {
  log_warn "$1 is not available from a COPR on Fedora $(rpm -E %fedora 2>/dev/null || echo ?), skipping it"
  DOTS_SKIP_PKGS="${DOTS_SKIP_PKGS:-} $1"
  export DOTS_SKIP_PKGS
}

enable_copr() {
  local repo="$1" id
  if is_dry; then sudo_run dnf copr enable -y "$repo"; return 0; fi
  id="copr:copr.fedorainfracloud.org:${repo/\//:}"
  if sudo dnf copr enable -y "$repo" && sudo dnf makecache --repo "$id" >/dev/null 2>&1; then
    return 0
  fi
  sudo dnf copr disable -y "$repo" >/dev/null 2>&1 || true
  sudo rm -f "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:${repo/\//:}.repo" || true
  return 1
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
