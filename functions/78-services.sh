#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

log_step "Docker, Tailscale and virtualization"

case "$DOTS_FAMILY" in
  arch)
    pkg_install docker docker-compose docker-buildx tailscale qemu-full virt-manager virt-install libvirt dnsmasq nftables edk2-ovmf swtpm dmidecode
    ;;
  debian)
    pkg_install docker.io docker-compose-v2 docker-compose qemu-system-x86 qemu-utils libvirt-daemon-system libvirt-clients virt-manager virtinst ovmf swtpm dnsmasq-base bridge-utils iptables
    if ! has tailscale; then
      if is_dry; then
        printf '    [dry-run] install Tailscale from tailscale.com/install.sh\n'
      else
        tmp="$(mktemp)"
        fetch "https://tailscale.com/install.sh" "$tmp"
        sudo sh "$tmp" || log_warn "could not install Tailscale"
        rm -f "$tmp"
      fi
    fi
    ;;
  fedora)
    if ! has tailscale && ! is_dry; then
      sudo dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo 2>/dev/null ||
        sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo ||
        log_warn "could not add the Tailscale repo"
    elif is_dry; then
      printf '    [dry-run] add the Tailscale dnf repo\n'
    fi
    pkg_install moby-engine docker-compose tailscale qemu-kvm libvirt virt-manager virt-install edk2-ovmf swtpm libvirt-daemon-config-network
    ;;
esac

sudo_run systemctl enable --now docker.service || log_warn "could not start docker"
sudo_run systemctl enable --now tailscaled.service || log_warn "could not start tailscaled"
sudo_run systemctl enable --now libvirtd.service || log_warn "could not start libvirtd"
if ! is_dry; then
  # libvirtd needs a moment before virsh can talk to it
  for _ in 1 2 3 4 5; do sudo virsh -c qemu:///system net-list --all >/dev/null 2>&1 && break; sleep 1; done
  if ! sudo virsh -c qemu:///system net-info default >/dev/null 2>&1; then
    log_warn "libvirt 'default' network missing, defining it"
    sudo virsh -c qemu:///system net-define /usr/share/libvirt/networks/default.xml || log_warn "could not define default network"
  fi
  sudo virsh -c qemu:///system net-autostart default >/dev/null 2>&1 || log_warn "could not autostart default network"
  sudo virsh -c qemu:///system net-start default >/dev/null 2>&1 ||
    sudo virsh -c qemu:///system net-info default 2>/dev/null | grep -q 'Active:.*yes' ||
    log_warn "default network not running (check dnsmasq and firewall); see: sudo virsh net-start default"
fi
# Docker sets the FORWARD policy to DROP, which silences VMs on libvirt's NAT bridge; let virbr0 through
write_root_file /etc/systemd/system/virbr0-docker.service "[Unit]
Description=Let libvirt NAT traffic pass Docker's firewall
After=docker.service libvirtd.service
Wants=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'for d in -i -o; do iptables -C DOCKER-USER \$d virbr0 -j ACCEPT 2>/dev/null || iptables -I DOCKER-USER \$d virbr0 -j ACCEPT; done; true'

[Install]
WantedBy=multi-user.target"
sudo_run systemctl daemon-reload
sudo_run systemctl enable --now virbr0-docker.service || log_warn "could not enable virbr0-docker.service"

run mkdir -p "$HOME/.local/bin"
for s in mkvm cachyos-vm; do
  ensure_executable "$DOTS_ROOT/configs/scripts/$s"
  link_config "$DOTS_ROOT/configs/scripts/$s" "$HOME/.local/bin/$s"
done

sudo_run usermod -aG docker,libvirt "$(id -un)"

log_ok "installed; log out and in once (docker and libvirt groups), then run: sudo tailscale up; VMs: virt-manager, or run cachyos-vm to create a CachyOS VM (downloads the ISO)"
