#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

# Linux version of Chris Titus' winutil "Debloat Brave" tweak: the same managed policies, written to
# /etc/brave/policies/managed instead of HKLM\SOFTWARE\Policies\BraveSoftware\Brave.
# Undo: sudo rm /etc/brave/policies/managed/dotfiles-debloat.json
log_step "Brave debloat (managed policies)"

policy_dir=/etc/brave/policies/managed
policy_file="$policy_dir/dotfiles-debloat.json"

sudo_run mkdir -p "$policy_dir"
write_root_file "$policy_file" '{
  "BraveRewardsDisabled": true,
  "BraveWalletDisabled": true,
  "BraveVPNDisabled": true,
  "BraveAIChatEnabled": false,
  "BraveStatsPingEnabled": false,
  "BraveP3AEnabled": false,
  "MetricsReportingEnabled": false
}'
sudo_run chmod 644 "$policy_file"

# make Brave the default browser when it is installed
brave_desktop=""
for d in brave-browser.desktop brave-bin.desktop brave.desktop; do
  if [[ -f "/usr/share/applications/$d" ]]; then brave_desktop="$d"; break; fi
done
if [[ -n "$brave_desktop" ]] && ! is_dry && has xdg-settings; then
  xdg-settings set default-web-browser "$brave_desktop" 2>/dev/null || log_warn "could not set Brave as the default browser"
fi

log_ok "Brave policies applied (restart Brave, check brave://policy)"
