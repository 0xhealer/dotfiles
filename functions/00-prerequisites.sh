#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

log_step "Prerequisites"

if ! has sudo && ! is_dry && ((EUID != 0)); then
  die "sudo is required"
fi

case "$DOTS_FAMILY" in
  debian) base=(ca-certificates curl wget git gnupg unzip zip tar xz-utils software-properties-common) ;;
  arch) base=(base-devel git curl wget unzip zip tar xz gnupg) ;;
  fedora) base=(git curl wget unzip zip tar xz gnupg2 dnf-plugins-core dnf5-plugins) ;;
esac

pkg_refresh
if [[ "${DOTS_UPGRADE:-0}" == 1 && "$DOTS_FAMILY" != arch ]]; then
  pkg_upgrade
fi
pkg_install "${base[@]}"

if [[ "$DOTS_FAMILY" == debian && "$DOTS_OS_ID" == ubuntu ]]; then
  sudo_run add-apt-repository -y universe
  pkg_refresh
fi

standard_dirs
log_ok "prerequisites ready"
