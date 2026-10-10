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

# fallback when the AUR package is broken: Microsoft's own tarball, no root needed
install_vscode_tarball() {
  local ch=stable dir="$HOME/.local/opt/$DOTS_CODE_BIN" tmp
  [[ "$DOTS_CODE_BIN" == *insiders* ]] && ch=insider
  if is_dry; then
    printf '    [dry-run] download the %s tarball to %s\n' "$ch" "$dir"
    return 0
  fi
  [[ "$(uname -m)" == x86_64 ]] || { log_warn "tarball fallback is x86_64 only"; return 1; }
  tmp="$(mktemp -d)"
  if curl -fsSL "https://code.visualstudio.com/sha/download?build=${ch}&os=linux-x64" | tar -xz -C "$tmp"; then
    rm -rf "$dir" && mkdir -p "$(dirname "$dir")" "$HOME/.local/bin" "$HOME/.local/share/applications"
    mv "$tmp"/VSCode-linux-x64 "$dir"
    ln -sf "$dir/bin/$DOTS_CODE_BIN" "$HOME/.local/bin/$DOTS_CODE_BIN"
    cat >"$HOME/.local/share/applications/$DOTS_CODE_BIN.desktop" <<D
[Desktop Entry]
Name=Visual Studio Code ($ch)
Exec=$dir/$DOTS_CODE_BIN %F
Icon=$dir/resources/app/resources/linux/code.png
Type=Application
Categories=Utility;TextEditor;Development;IDE;
MimeType=text/plain;inode/directory;
StartupWMClass=$DOTS_CODE_BIN
D
    export PATH="$HOME/.local/bin:$PATH"
    log_ok "installed from the official tarball (updates: rerun this step)"
  else
    log_warn "could not download the VS Code tarball"
  fi
  rm -rf "$tmp"
}

if ! has "$DOTS_CODE_BIN"; then
  case "$DOTS_FAMILY" in
    debian) install_vscode_deb ;;
    fedora) install_vscode_rpm ;;
    arch)
      log_warn "$DOTS_CODE_BIN missing: the AUR package failed or was skipped, using Microsoft's tarball"
      install_vscode_tarball || true
      ;;
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

if [[ "$DOTS_CODE_BIN" != code ]] && has "$DOTS_CODE_BIN"; then
  run mkdir -p "$HOME/.local/bin"
  run ln -sf "$(command -v "$DOTS_CODE_BIN")" "$HOME/.local/bin/code"
fi
