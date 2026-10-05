#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

log_step "Wallpapers"

dest="$HOME/Pictures/Wallpapers"
shopt -s nullglob
files=("$DOTS_ROOT"/assets/wallpapers/*)
((${#files[@]})) || die "no wallpapers in assets/wallpapers"

run mkdir -p "$dest"

declare -A repo_hash=()
for f in "${files[@]}"; do
  repo_hash["$(md5sum "$f" | cut -d' ' -f1)"]="$(basename "$f")"
done

# Drop copies left behind when a wallpaper was renamed or removed in the repo.
for f in "$dest"/*; do
  [[ -f "$f" ]] || continue
  name="$(basename "$f")"
  [[ -e "$DOTS_ROOT/assets/wallpapers/$name" ]] && continue
  sum="$(md5sum "$f" | cut -d' ' -f1)"
  if [[ -n "${repo_hash[$sum]:-}" ]]; then
    run rm -f "$f"
  fi
done

for f in "${files[@]}"; do
  cmp -s "$f" "$dest/$(basename "$f")" 2>/dev/null || run cp "$f" "$dest/"
done
# Wallpapers removed from the repo because they were duplicates or broken.
[[ -e "$DOTS_ROOT/assets/wallpapers/071.jpg" ]] || run rm -f "$dest/071.jpg"
log_ok "${#files[@]} wallpapers available in $dest"
