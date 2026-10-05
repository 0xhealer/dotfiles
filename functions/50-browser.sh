#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

log_step "Browser (Helium)"

install_helium_tarball() {
  local key url tmp dest="$HOME/.local/opt/helium" bin
  case "$(uname -m)" in
    x86_64) key=x86_64 ;;
    aarch64 | arm64) key=arm64 ;;
    *) log_warn "unsupported architecture for Helium: $(uname -m)"; return 0 ;;
  esac
  url="$(github_asset_url imputnet/helium-linux "${key}_linux\\.tar\\.xz$")"
  if [[ -z "$url" ]]; then
    log_warn "no Helium tarball found for $key"
    return 0
  fi
  tmp="$(mktemp --suffix=.tar.xz)"
  fetch "$url" "$tmp"
  run rm -rf "$dest"
  run mkdir -p "$dest" "$HOME/.local/bin" "$HOME/.local/share/applications"
  run tar -xJf "$tmp" -C "$dest" --strip-components=1
  rm -f "$tmp"
  if is_dry; then return 0; fi
  bin="$(find "$dest" -maxdepth 2 -type f \( -name helium -o -name chrome \) -perm -u+x | head -n1)"
  if [[ -z "$bin" ]]; then
    log_warn "Helium binary not found in tarball"
    return 0
  fi
  ln -sf "$bin" "$HOME/.local/bin/helium"
  cat >"$HOME/.local/share/applications/helium.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Helium
Comment=Web browser
Exec=$HOME/.local/bin/helium %U
Icon=web-browser
Terminal=false
Categories=Network;WebBrowser;
MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
DESKTOP
  log_ok "Helium installed to $dest"
}

install_helium_deb() {
  local tmp
  tmp="$(mktemp)"
  fetch "https://raw.githubusercontent.com/imputnet/helium-linux/main/pubkey.asc" "$tmp"
  sudo_run gpg --dearmor --yes -o /usr/share/keyrings/helium.gpg "$tmp"
  rm -f "$tmp"
  write_root_file /etc/apt/sources.list.d/helium.list \
    "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/helium.gpg] https://pkg.helium.computer/deb stable main"
  pkg_refresh
  pkg_install helium-bin
}

install_helium_rpm() {
  sudo_run dnf copr enable -y imput/helium
  sudo_run dnf install -y helium-bin
}

helium_installed() {
  has helium || has helium-browser || has helium-bin || pkg_installed helium-bin
}

if helium_installed; then
  log_info "Helium already installed"
else
  case "$DOTS_FAMILY" in
    debian) install_helium_deb ;;
    fedora) install_helium_rpm ;;
    arch) install_helium_tarball ;;
  esac
fi

if ! is_dry && has xdg-settings; then
  desktop="$(find /usr/share/applications "$HOME/.local/share/applications" -maxdepth 1 -iname 'helium*.desktop' 2>/dev/null | head -n1)"
  if [[ -n "$desktop" ]]; then
    xdg-settings set default-web-browser "$(basename "$desktop")" 2>/dev/null || log_warn "could not set Helium as default browser"
  fi
fi
