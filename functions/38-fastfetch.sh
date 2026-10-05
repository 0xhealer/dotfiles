#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

log_step "Fastfetch"

if ! has fastfetch; then
  if [[ "$DOTS_DISTRO" == ubuntu && "$DOTS_OS_ID" == ubuntu ]]; then
    sudo_run add-apt-repository -y ppa:zhangsongcui3371/fastfetch
    pkg_refresh
    pkg_install fastfetch
  else
    log_warn "fastfetch is not installed and no repository provides it here"
  fi
fi

ensure_executable "$DOTS_ROOT"/configs/fastfetch/scripts/*.sh
dest="$HOME/.config/fastfetch"
if [[ -L "$dest" ]]; then backup_path "$dest"; fi
run mkdir -p "$dest"
for item in "$DOTS_ROOT"/configs/fastfetch/*; do
  link_config "$item" "$dest/$(basename "$item")"
done
link_config "$DOTS_ROOT/assets/fastfetch-logos" "$dest/logos"
