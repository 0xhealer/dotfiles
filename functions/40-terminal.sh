#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

log_step "Terminal (kitty)"

if ! has kitty; then
  log_warn "kitty is not installed"
fi

link_config "$DOTS_ROOT/configs/kitty" "$HOME/.config/kitty"
# the ghostty config stays in the repo and is linked, but ghostty itself is no longer installed
link_config "$DOTS_ROOT/configs/ghostty" "$HOME/.config/ghostty"

is_dry || "$DOTS_ROOT/configs/scripts/font" apply || log_warn "could not apply the saved font"
