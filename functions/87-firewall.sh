#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

# Make Tailscale work through whichever host firewall is already running. It never turns a firewall on:
# firewalld (Fedora) and ufw are configured only when they are active; with none active nothing is needed.
log_step "Firewall rules for Tailscale"

ts_if=tailscale0
ts_port=41641

configure_firewalld() {
  log_info "firewalld is active"
  local fw=(sudo_run firewall-cmd --permanent)
  "${fw[@]}" --zone=trusted --add-interface="$ts_if" || log_warn "could not trust $ts_if"
  "${fw[@]}" --zone=public --add-port="$ts_port/udp" || log_warn "could not open udp/$ts_port"
  sudo_run firewall-cmd --reload || log_warn "firewall-cmd --reload failed"
  log_ok "firewalld: $ts_if is in the trusted zone, udp/$ts_port is open"
}

configure_ufw() {
  log_info "ufw is active"
  sudo_run ufw allow in on "$ts_if" comment 'tailscale' || log_warn "could not allow $ts_if"
  sudo_run ufw allow "$ts_port/udp" comment 'tailscale direct connections' || log_warn "could not open udp/$ts_port"
  # forwarded traffic (exit node, subnet router, containers reaching the tailnet) is dropped by default
  sudo_run ufw route allow in on "$ts_if" || log_warn "could not allow routing from $ts_if"
  sudo_run ufw route allow out on "$ts_if" || log_warn "could not allow routing to $ts_if"
  sudo_run ufw reload || log_warn "ufw reload failed"
  log_ok "ufw: traffic on $ts_if is allowed, udp/$ts_port is open"
}

if is_dry; then
  printf '    [dry-run] detect firewalld/ufw, trust %s, open udp/%s, loose rp_filter\n' "$ts_if" "$ts_port"
else
  if has firewall-cmd && systemctl is-active --quiet firewalld; then
    configure_firewalld
  elif has ufw && sudo ufw status 2>/dev/null | grep -q '^Status: active'; then
    configure_ufw
  else
    log_info "no active firewalld or ufw, nothing to open (raw nftables rules, if any, are yours to manage)"
  fi
fi

# strict reverse-path filtering drops replies that come back over tailscale0 (exit node, subnet routes);
# loose mode (2) is what Tailscale recommends
write_root_file /etc/sysctl.d/99-tailscale.conf "# written by dotfiles: Tailscale exit node and subnet routing need loose reverse-path filtering
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2"
is_dry || sudo sysctl --system >/dev/null 2>&1 || true

# MagicDNS needs a resolver Tailscale can configure
if ! is_dry; then
  if systemctl is-active --quiet systemd-resolved || systemctl is-active --quiet NetworkManager; then
    log_ok "resolver is managed (MagicDNS names resolve once 'sudo tailscale up' has run)"
  else
    log_warn "neither systemd-resolved nor NetworkManager is running, MagicDNS may not work"
  fi
fi
