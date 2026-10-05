#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

log_step "Starship"

minimum="1.23.0"
need_upstream=1
if has starship; then
  current="$(starship --version 2>/dev/null | awk 'NR==1 {print $2}')"
  if [[ -n "$current" && "$(printf '%s\n%s\n' "$minimum" "$current" | sort -V | head -n1)" == "$minimum" ]]; then
    need_upstream=0
  fi
fi

if ((need_upstream)); then
  log_info "installing starship from upstream (the packaged one is missing newer modules)"
  tmp="$(mktemp)"
  fetch "https://starship.rs/install.sh" "$tmp"
  run mkdir -p "$HOME/.local/bin"
  run sh "$tmp" --yes --bin-dir "$HOME/.local/bin"
  rm -f "$tmp"
fi

link_config "$DOTS_ROOT/configs/starship/starship.toml" "$HOME/.config/starship.toml"
