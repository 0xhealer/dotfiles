#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

log_step "Fonts"

dest="$HOME/.local/share/fonts/dotfiles"
mapfile -t fonts < <(find "$DOTS_ROOT/assets/fonts" -type f \( -iname '*.ttf' -o -iname '*.otf' \) | sort)
((${#fonts[@]})) || die "no fonts found in assets/fonts"

run mkdir -p "$dest"
for f in "${fonts[@]}"; do
  run cp -f "$f" "$dest/"
done

if has fc-cache; then
  run fc-cache -f "$dest"
else
  log_warn "fc-cache not found, font cache not refreshed"
fi

log_ok "installed ${#fonts[@]} font files"
