#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

log_step "Spotify and Spicetify"

spotify_path=""
prefs_path="$HOME/.config/spotify/prefs"

install_spotify_deb() {
  local tmp
  tmp="$(mktemp)"
  fetch "https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.asc" "$tmp"
  sudo_run gpg --dearmor --yes -o /usr/share/keyrings/spotify.gpg "$tmp"
  rm -f "$tmp"
  write_root_file /etc/apt/sources.list.d/spotify.list \
    "deb [signed-by=/usr/share/keyrings/spotify.gpg] https://repository.spotify.com stable non-free"
  pkg_refresh
  pkg_install spotify-client
}

install_spotify_flatpak() {
  pkg_install flatpak
  sudo_run flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  run flatpak install --user -y flathub com.spotify.Client
}

case "$DOTS_FAMILY" in
  debian)
    has spotify || install_spotify_deb
    spotify_path="/usr/share/spotify"
    ;;
  arch)
    has spotify || aur_install spotify
    spotify_path="/opt/spotify"
    ;;
  fedora)
    flatpak list --user 2>/dev/null | grep -q com.spotify.Client || install_spotify_flatpak
    spotify_path="$HOME/.local/share/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify"
    prefs_path="$HOME/.var/app/com.spotify.Client/config/spotify/prefs"
    ;;
esac

if ! has spicetify && [[ ! -x "$HOME/.spicetify/spicetify" ]]; then
  case "$(uname -m)" in
    aarch64 | arm64) arch_pat='linux-arm64' ;;
    *) arch_pat='linux-amd64' ;;
  esac
  url="$(github_asset_url spicetify/cli "${arch_pat}\\.tar\\.gz\$")"
  if [[ -z "$url" ]]; then
    log_warn "no spicetify release found for $arch_pat"
    exit 0
  fi
  tmp="$(mktemp -d)"
  fetch "$url" "$tmp/spicetify.tar.gz"
  run mkdir -p "$HOME/.spicetify" "$HOME/.local/bin"
  run tar -xzf "$tmp/spicetify.tar.gz" -C "$HOME/.spicetify"
  run ln -sf "$HOME/.spicetify/spicetify" "$HOME/.local/bin/spicetify"
  rm -rf "$tmp"
fi

if is_dry; then
  exit 0
fi

export PATH="$HOME/.local/bin:$HOME/.spicetify:$PATH"
spicetify_dir="$HOME/.config/spicetify"
mkdir -p "$spicetify_dir/Themes"

if [[ ! -d "$spicetify_dir/Themes/Sleek" ]]; then
  tmp="$(mktemp -d)"
  if git clone --depth 1 -q https://github.com/spicetify/spicetify-themes "$tmp/themes"; then
    cp -a "$tmp"/themes/*/ "$spicetify_dir/Themes/" 2>/dev/null || true
  else
    log_warn "could not download the Spicetify themes"
  fi
  rm -rf "$tmp"
fi

if [[ -d "$spotify_path" && "$DOTS_FAMILY" != fedora ]]; then
  sudo chmod a+wr "$spotify_path"
  sudo chmod -R a+wr "$spotify_path/Apps"
fi

spicetify config spotify_path "$spotify_path" prefs_path "$prefs_path" >/dev/null 2>&1 || true
if [[ "$DOTS_WM" == niri && -d "$spicetify_dir/Themes/text" ]]; then
  # text theme + overlay; Noctalia's user template writes the wallpaper colours into Themes/text/color.ini
  theme="$spicetify_dir/Themes/text"
  [[ -f "$theme/user.css.orig" ]] || cp "$theme/user.css" "$theme/user.css.orig"
  cat "$theme/user.css.orig" "$DOTS_ROOT/configs/spicetify/overlay.css" >"$theme/user.css"
  grep -q '^\[Noctalia\]' "$theme/color.ini" 2>/dev/null || cp "$DOTS_ROOT/configs/spicetify/color.ini" "$theme/color.ini"
  spicetify config current_theme text color_scheme Noctalia inject_css 1 replace_colors 1 overwrite_assets 1 inject_theme_js 1 >/dev/null 2>&1 || true
else
  spicetify config current_theme Sleek color_scheme Catppuccin inject_css 1 replace_colors 1 overwrite_assets 1 >/dev/null 2>&1 || true
fi

if [[ -f "$prefs_path" ]]; then
  if spicetify backup apply >/dev/null 2>&1; then
    log_ok "Spicetify theme applied"
  else
    log_warn "spicetify apply failed, run: spicetify backup apply"
  fi
else
  log_info "Open Spotify once and log in, then run: spicetify backup apply"
fi
log_info "After a Spotify update, re-apply the theme with: spicetify restore backup apply"
