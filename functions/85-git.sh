#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

log_step "Git"

name="${GIT_NAME:-$(git config --global user.name 2>/dev/null || true)}"
email="${GIT_EMAIL:-$(git config --global user.email 2>/dev/null || true)}"
local_cfg="$HOME/.gitconfig.local"

if [[ -n "$name" && -n "$email" && ! -f "$local_cfg" ]] && ! is_dry; then
  printf '[user]\n    name = %s\n    email = %s\n' "$name" "$email" >"$local_cfg"
  log_ok "identity saved to $local_cfg"
elif [[ ! -f "$local_cfg" ]]; then
  log_warn "no git identity found; set GIT_NAME/GIT_EMAIL or edit $local_cfg"
fi

# settings added on this machine (credential helper, signing key) live in ~/.gitconfig.local so that
# re-installing never loses them; anything found in an existing ~/.gitconfig is moved there first
preserve_machine_settings() {
  [[ -f "$HOME/.gitconfig" && ! -L "$HOME/.gitconfig" ]] || return 0
  is_dry && return 0
  local key val
  while IFS= read -r line; do
    key="${line%% *}"
    val="${line#* }"
    # skip what the repo config already provides
    case "$key" in credential.https://github.com.helper | credential.https://gist.github.com.helper) continue ;; esac
    git config --file "$local_cfg" --get-all "$key" 2>/dev/null | grep -qxF -- "$val" && continue
    git config --file "$local_cfg" --add "$key" "$val"
    log_info "kept $key in $local_cfg"
  done < <(git config --file "$HOME/.gitconfig" --get-regexp '^(credential\.|gpg\.|commit\.gpgsign|tag\.gpgsign|user\.signingkey|safe\.directory|url\.)' 2>/dev/null || true)
}
preserve_machine_settings

link_config "$DOTS_ROOT/configs/git/gitconfig" "$HOME/.gitconfig"

if has gh && ! gh auth status >/dev/null 2>&1; then
  log_info "run 'gh auth login' once; ghclone and ghcreate use it"
fi
