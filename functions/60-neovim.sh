#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

log_step "Neovim"

NVIM_MIN=0.12

nvim_ok() {
  has nvim || return 1
  local v
  v="$(program_version nvim)"
  [[ -n "$v" ]] && version_ge "$v" "$NVIM_MIN"
}

install_nvim_tarball() {
  local asset tmp dest="$HOME/.local/opt/nvim"
  case "$(uname -m)" in
    x86_64) asset=nvim-linux-x86_64.tar.gz ;;
    aarch64 | arm64) asset=nvim-linux-arm64.tar.gz ;;
    *) die "unsupported architecture for Neovim: $(uname -m)" ;;
  esac
  tmp="$(mktemp --suffix=.tar.gz)"
  fetch "https://github.com/neovim/neovim/releases/latest/download/$asset" "$tmp"
  run rm -rf "$dest"
  run mkdir -p "$dest" "$HOME/.local/bin"
  run tar -xzf "$tmp" -C "$dest" --strip-components=1
  rm -f "$tmp"
  run ln -sf "$dest/bin/nvim" "$HOME/.local/bin/nvim"
  log_ok "Neovim installed to $dest"
}

if nvim_ok; then
  log_info "Neovim $(program_version nvim) satisfies >= $NVIM_MIN"
else
  log_info "Neovim >= $NVIM_MIN required (vim.pack), installing upstream release"
  install_nvim_tarball
fi

if ! has tree-sitter; then
  if has npm; then
    run npm install -g --prefix "$HOME/.local" tree-sitter-cli
  else
    log_warn "npm not found, tree-sitter-cli not installed"
  fi
fi

# vim is replaced by nvim (the vim/vi aliases point at it); vim-tiny / vim-minimal stay, the system needs a vi
for p in vim vim-enhanced vim-gtk3 gvim; do
  pkg_installed "$p" || continue
  case "$DOTS_FAMILY" in
    arch)
      # something else needs it (cachyos-zsh-config pulls vim): keep the package, the vim alias already points at nvim
      req="$(pacman -Qi "$p" 2>/dev/null | sed -n 's/^Required By *: *//p')"
      if [[ -n "$req" && "$req" != None ]]; then
        log_info "keeping $p, required by: $req (the vim alias runs nvim)"
      else
        sudo_run pacman -Rns --noconfirm "$p" || log_warn "could not remove $p"
      fi
      ;;
    fedora) sudo_run dnf remove -y "$p" || log_warn "could not remove $p" ;;
    debian) sudo_run apt-get remove -y "$p" || log_warn "could not remove $p" ;;
  esac
done

link_config "$DOTS_ROOT/configs/nvim" "$HOME/.config/nvim"
log_info "first launch of nvim downloads plugins, treesitter parsers and LSP servers"
