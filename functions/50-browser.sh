#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

# Brave is the main browser (51-apps.sh, or packages/cachyos.txt); Firefox is the fallback.
log_step "Browser (Firefox fallback)"

if has firefox || has firefox-esr; then
  log_info "Firefox already installed"
  exit 0
fi

if [[ "$DOTS_FAMILY" == debian ]] && is_dry; then
  pkg_install firefox-esr
elif [[ "$DOTS_FAMILY" == debian ]] && ! pkg_available firefox-esr; then
  pkg_install firefox
elif [[ "$DOTS_FAMILY" == debian ]]; then
  pkg_install firefox-esr
else
  pkg_install firefox
fi
log_ok "Firefox installed (fallback)"
