#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

[[ "$DOTS_DISTRO" == kali ]] || exit 0

log_step "Sway + Noctalia (Kali)"

ref="${DOTS_NOCTALIA_REF:-v5.2.1}"
prefix="$HOME/.local"
src="$HOME/.cache/dotfiles/noctalia"
marker="$prefix/share/noctalia/.dotfiles-ref"
c="$DOTS_ROOT/configs"

mapfile -t pkgs < <(pkg_list "$DOTS_ROOT/packages/kali-sway.txt")
pkg_install "${pkgs[@]}"

build_noctalia() {
  if [[ -x "$prefix/bin/noctalia" && "$(cat "$marker" 2>/dev/null || true)" == "$ref" ]]; then
    log_info "Noctalia $ref already installed in $prefix"
    return 0
  fi
  if ! is_dry; then
    has meson || { log_warn "meson missing, skipping the Noctalia build"; return 1; }
    pkg-config --exists wireplumber-0.5 || { log_warn "libwireplumber-0.5-dev is not available, update Kali and re-run: ./install.sh sway"; return 1; }
    local gcc_major
    gcc_major="$(g++ -dumpversion 2>/dev/null | cut -d. -f1)"
    [[ "${gcc_major:-0}" -ge 13 ]] || { log_warn "g++ 13 or newer is required (found ${gcc_major:-none})"; return 1; }
  fi
  log_info "building Noctalia $ref from source, this takes a while"
  run rm -rf "$src"
  run mkdir -p "$(dirname "$src")"
  run env GIT_TERMINAL_PROMPT=0 git clone --depth 1 --branch "$ref" https://github.com/noctalia-dev/noctalia "$src" ||
    { log_warn "could not clone Noctalia $ref"; return 1; }
  is_dry && return 0
  (
    cd "$src"
    meson setup build --buildtype=release -Dcpp_std=c++23 -Dtests=disabled --prefix "$prefix" &&
      meson compile -C build noctalia &&
      meson install -C build
  ) >"$HOME/.cache/dotfiles/noctalia-build.log" 2>&1 ||
    { log_warn "Noctalia build failed, see ~/.cache/dotfiles/noctalia-build.log"; return 1; }
  mkdir -p "$(dirname "$marker")"
  printf '%s\n' "$ref" >"$marker"
  log_ok "Noctalia $ref installed in $prefix"
}

noctalia_ok=1
build_noctalia || noctalia_ok=0

run mkdir -p "$HOME/.local/bin" "$HOME/Pictures/Screenshots" "$HOME/.config/noctalia"
ensure_executable "$c"/scripts/*
for s in wallpaper-set wallpaper-rotate keyhelp; do
  link_config "$c/scripts/$s" "$HOME/.local/bin/$s"
done

link_config "$c/sway/config" "$HOME/.config/sway/config"
[[ -f "$HOME/.config/sway/noctalia" ]] || { is_dry || : >"$HOME/.config/sway/noctalia"; }
link_config "$c/noctalia/dotfiles-sway.toml" "$HOME/.config/noctalia/dotfiles.toml"
if [[ -x "$prefix/bin/noctalia" ]] && ! "$prefix/bin/noctalia" config validate >/dev/null 2>&1; then
  log_warn "noctalia rejected configs/noctalia/dotfiles-sway.toml, removing the copy"
  run rm -f "$HOME/.config/noctalia/dotfiles.toml"
fi

[[ -f /usr/share/wayland-sessions/sway.desktop ]] || log_warn "no sway session file found, is sway installed?"
if ((noctalia_ok)); then
  log_ok "pick the Sway session on the login screen; i3 is untouched. Colours follow the wallpaper through matugen"
else
  log_warn "sway is installed but Noctalia is not; fix the warning above and re-run: ./install.sh sway"
fi
