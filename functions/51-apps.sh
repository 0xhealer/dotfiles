#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

# CachyOS gets brave, teams-for-linux and obsidian from packages/cachyos.txt
[[ "$DOTS_FAMILY" == arch ]] && exit 0

log_step "Brave, Teams and Obsidian"

install_brave_deb() {
  local tmp
  tmp="$(mktemp)"
  fetch "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg" "$tmp"
  sudo_run install -m 644 "$tmp" /usr/share/keyrings/brave-browser-archive-keyring.gpg
  rm -f "$tmp"
  write_root_file /etc/apt/sources.list.d/brave-browser-release.list \
    "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"
  pkg_refresh
  pkg_install brave-browser
}

install_brave_rpm() {
  if ! is_dry; then
    sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo 2>/dev/null ||
      sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo ||
      { log_warn "could not add the Brave repo"; return 0; }
  else
    printf '    [dry-run] add the Brave dnf repo\n'
  fi
  pkg_install brave-browser
}

if ! has brave-browser; then
  case "$DOTS_FAMILY" in
    debian) install_brave_deb ;;
    fedora) install_brave_rpm ;;
  esac
fi

pkg_install flatpak
sudo_run flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
for app in com.github.IsmaelMartinez.teams_for_linux md.obsidian.Obsidian; do
  if ! is_dry && flatpak info "$app" >/dev/null 2>&1; then
    log_info "$app already installed"
  else
    sudo_run flatpak install --system -y flathub "$app" || log_warn "could not install $app"
  fi
done
log_ok "Brave, Teams (teams-for-linux) and Obsidian installed"
