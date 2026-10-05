#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

log_step "Shell (zsh, fish)"

link_config "$DOTS_ROOT/configs/zsh/zshrc" "$HOME/.zshrc"
link_config "$DOTS_ROOT/configs/fish/config.fish" "$HOME/.config/fish/config.fish"
for fn in "$DOTS_ROOT"/configs/fish/functions/*.fish; do
  link_config "$fn" "$HOME/.config/fish/functions/$(basename "$fn")"
done
for fn in "$DOTS_ROOT"/configs/fish/conf.d/*.fish; do
  link_config "$fn" "$HOME/.config/fish/conf.d/$(basename "$fn")"
done
rm -f "$HOME/.config/zsh/functions.zsh"
while IFS= read -r -d '' fn; do
  rel="${fn#"$DOTS_ROOT"/configs/zsh/}"
  link_config "$fn" "$HOME/.config/zsh/$rel"
done < <(find "$DOTS_ROOT/configs/zsh" -name '*.zsh' -print0)
link_config "$DOTS_ROOT/configs/shell/gh.sh" "$HOME/.config/shell/gh.sh"

if ! has zoxide; then
  log_info "installing zoxide from upstream"
  tmp="$(mktemp)"
  fetch "https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh" "$tmp"
  run bash "$tmp"
  rm -f "$tmp"
fi

login_shell="${DOTS_LOGIN_SHELL:-zsh}"
if has "$login_shell"; then
  shell_path="$(command -v "$login_shell")"
  current="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ "$current" == "$shell_path" ]]; then
    log_info "login shell already $shell_path"
  else
    if ! grep -qx "$shell_path" /etc/shells 2>/dev/null; then
      sudo_run sh -c "echo '$shell_path' >> /etc/shells"
    fi
    sudo_run usermod -s "$shell_path" "$USER"
    log_ok "login shell set to $shell_path"
  fi
else
  log_warn "$login_shell not installed, login shell unchanged"
fi
