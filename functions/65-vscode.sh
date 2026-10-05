#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

log_step "Visual Studio Code ($DOTS_CODE_BIN)"

install_vscode_deb() {
  local tmp
  tmp="$(mktemp)"
  fetch "https://packages.microsoft.com/keys/microsoft.asc" "$tmp"
  sudo_run gpg --dearmor --yes -o /usr/share/keyrings/packages.microsoft.gpg "$tmp"
  rm -f "$tmp"
  write_root_file /etc/apt/sources.list.d/vscode.list \
    "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main"
  pkg_refresh
  pkg_install code
}

install_vscode_rpm() {
  sudo_run rpm --import https://packages.microsoft.com/keys/microsoft.asc
  write_root_file /etc/yum.repos.d/vscode.repo "[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc"
  sudo_run dnf install -y "$DOTS_CODE_BIN"
}

if ! has "$DOTS_CODE_BIN"; then
  case "$DOTS_FAMILY" in
    debian) install_vscode_deb ;;
    fedora) install_vscode_rpm ;;
    arch) log_warn "VS Code comes from the AUR (visual-studio-code-insiders-bin) in packages/cachyos.txt" ;;
  esac
fi

user_dir="$HOME/.config/$DOTS_CODE_DIR/User"
link_config "$DOTS_ROOT/configs/vscode/settings.json" "$user_dir/settings.json"
link_config "$DOTS_ROOT/configs/vscode/keybindings.json" "$user_dir/keybindings.json"

if has "$DOTS_CODE_BIN"; then
  while IFS= read -r ext; do
    run "$DOTS_CODE_BIN" --install-extension "$ext" --force >/dev/null || log_warn "extension failed: $ext"
  done < <(pkg_list "$DOTS_ROOT/packages/vscode-extensions.txt")
else
  log_warn "$DOTS_CODE_BIN not found, extensions not installed"
fi
