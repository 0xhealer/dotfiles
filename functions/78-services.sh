#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

case "$DOTS_FAMILY" in
  arch | fedora) ;;
  *) exit 0 ;;
esac

log_step "Docker and Tailscale"

case "$DOTS_FAMILY" in
  arch)
    pkg_install docker docker-compose docker-buildx tailscale
    ;;
  fedora)
    if ! has tailscale && ! is_dry; then
      sudo dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo 2>/dev/null ||
        sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo ||
        log_warn "could not add the Tailscale repo"
    elif is_dry; then
      printf '    [dry-run] add the Tailscale dnf repo\n'
    fi
    pkg_install moby-engine docker-compose tailscale
    ;;
esac

sudo_run systemctl enable --now docker.service || log_warn "could not start docker"
sudo_run systemctl enable --now tailscaled.service || log_warn "could not start tailscaled"
sudo_run usermod -aG docker "$(id -un)"

log_ok "docker and tailscale installed; log out and in once for docker without sudo, then run: sudo tailscale up"
