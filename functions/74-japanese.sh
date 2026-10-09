#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

# Japanese input (fcitx5 + Mozc) and Japanese glyph preference. CJK fonts come from packages/<distro>.txt.
log_step "Japanese input and fonts"

case "$DOTS_FAMILY" in
  arch) pkg_install fcitx5 fcitx5-mozc fcitx5-gtk fcitx5-qt fcitx5-configtool ;;
  fedora) pkg_install fcitx5 fcitx5-mozc fcitx5-gtk fcitx5-qt fcitx5-configtool ;;
  debian) pkg_install fcitx5 fcitx5-mozc fcitx5-frontend-gtk3 fcitx5-frontend-qt5 fcitx5-config-qt ;;
esac

run mkdir -p "$HOME/.config/environment.d" "$HOME/.config/fcitx5" "$HOME/.config/fontconfig/conf.d"

im_env='GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx'
if ! is_dry; then
  printf '%s\n' "$im_env" >"$HOME/.config/environment.d/92-fcitx5.conf"
  # X11 sessions (i3) started by SDDM read ~/.xprofile, not environment.d
  {
    printf '# dotfiles: fcitx5\n'
    sed 's/^/export /' <<<"$im_env"
  } >"$HOME/.xprofile.dotfiles"
  if ! grep -qs 'xprofile.dotfiles' "$HOME/.xprofile" 2>/dev/null; then
    printf '[ -f "$HOME/.xprofile.dotfiles" ] && . "$HOME/.xprofile.dotfiles"\n' >>"$HOME/.xprofile"
  fi
  if [[ ! -f "$HOME/.config/fcitx5/profile" ]]; then
    cat >"$HOME/.config/fcitx5/profile" <<'PROFILE'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=mozc

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=mozc
Layout=

[GroupOrder]
0=Default
PROFILE
  fi
  cat >"$HOME/.config/fontconfig/conf.d/64-dotfiles-ja.conf" <<'FC'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <!-- Japanese glyph shapes for Han characters, not the Chinese ones -->
  <match>
    <test name="lang" compare="contains"><string>ja</string></test>
    <test name="family"><string>sans-serif</string></test>
    <edit name="family" mode="prepend" binding="strong"><string>Noto Sans CJK JP</string></edit>
  </match>
  <alias>
    <family>sans-serif</family>
    <prefer><family>Noto Sans CJK JP</family></prefer>
  </alias>
  <alias>
    <family>monospace</family>
    <accept><family>Noto Sans Mono CJK JP</family></accept>
  </alias>
</fontconfig>
FC
else
  printf '    [dry-run] write fcitx5 env, ~/.xprofile hook, fcitx5 profile (mozc), fontconfig ja rule\n'
fi
has fc-cache && run fc-cache -f

log_ok "Japanese input ready after re-login; switch with Ctrl+Space (fcitx5), configure with fcitx5-configtool"
