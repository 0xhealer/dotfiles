#!/usr/bin/env bash

[[ -n "${DOTS_HELPER_LOADED:-}" ]] && return 0
DOTS_HELPER_LOADED=1

DOTS_ROOT="${DOTS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DOTS_DRY_RUN="${DOTS_DRY_RUN:-0}"
DOTS_BACKUP_DIR="${DOTS_BACKUP_DIR:-$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)}"
DOTS_OS_RELEASE="${DOTS_OS_RELEASE:-/etc/os-release}"
export DOTS_ROOT DOTS_DRY_RUN DOTS_BACKUP_DIR

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
else
  C_RESET='' C_BOLD='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE=''
fi

log_step() { printf '\n%s==> %s%s\n' "$C_BOLD$C_BLUE" "$*" "$C_RESET"; }
log_info() { printf '  %s\n' "$*"; }
log_ok() { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
log_warn() { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
log_err() { printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die() {
  log_err "$*"
  exit 1
}

has() { command -v "$1" >/dev/null 2>&1; }
is_dry() { [[ "$DOTS_DRY_RUN" == 1 ]]; }

run() {
  if is_dry; then
    printf '    [dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

sudo_run() {
  if ((EUID == 0)); then
    run "$@"
  else
    run sudo "$@"
  fi
}

require_user() {
  if ((EUID == 0)) && ! is_dry; then
    die "Run as a regular user with sudo access, not as root."
  fi
}

detect_platform() {
  [[ -n "${DOTS_DISTRO:-}" ]] && return 0
  [[ "$(uname -s)" == Linux ]] || die "install.sh supports Linux only. Use install.ps1 on Windows."
  [[ -r "$DOTS_OS_RELEASE" ]] || die "Cannot read $DOTS_OS_RELEASE"

  local id like ver
  # shellcheck disable=SC1090
  id="$(. "$DOTS_OS_RELEASE" && printf '%s' "${ID:-}")"
  # shellcheck disable=SC1090
  like="$(. "$DOTS_OS_RELEASE" && printf '%s' "${ID_LIKE:-}")"
  # shellcheck disable=SC1090
  ver="$(. "$DOTS_OS_RELEASE" && printf '%s' "${VERSION_ID:-}")"

  DOTS_EXTRA_DE=""
  case " $id $like " in
    *" kali "*) DOTS_DISTRO=kali DOTS_FAMILY=debian DOTS_WM=i3 DOTS_EXTRA_DE=kde ;;
    *" cachyos "*) DOTS_DISTRO=cachyos DOTS_FAMILY=arch DOTS_WM=niri ;;
    *" fedora "*) DOTS_DISTRO=fedora DOTS_FAMILY=fedora DOTS_WM=niri ;;
    *" arch "*) DOTS_DISTRO=cachyos DOTS_FAMILY=arch DOTS_WM=niri ;;
    *" ubuntu "* | *" debian "*) DOTS_DISTRO=ubuntu DOTS_FAMILY=debian DOTS_WM=i3 DOTS_EXTRA_DE=gnome ;;
    *) die "Unsupported distribution: ID=$id ID_LIKE=$like" ;;
  esac

  DOTS_OS_ID="$id"
  DOTS_OS_VERSION_ID="$ver"
  DOTS_PKG_FILE="$DOTS_ROOT/packages/$DOTS_DISTRO.txt"
  DOTS_ARCH="$(uname -m)"
  if [[ "$DOTS_WM" == niri ]]; then
    DOTS_CODE_BIN=code-insiders DOTS_CODE_DIR="Code - Insiders" DOTS_CODE_EXT=.vscode-insiders
  else
    DOTS_CODE_BIN=code DOTS_CODE_DIR=Code DOTS_CODE_EXT=.vscode
  fi
  export DOTS_CODE_BIN DOTS_CODE_DIR DOTS_CODE_EXT
  export DOTS_DISTRO DOTS_FAMILY DOTS_WM DOTS_EXTRA_DE DOTS_OS_ID DOTS_OS_VERSION_ID DOTS_PKG_FILE DOTS_ARCH
}

pkg_list() {
  sed -e 's/#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"
}

pkg_refresh() {
  case "$DOTS_FAMILY" in
    debian) sudo_run apt-get update ;;
    arch) sudo_run pacman -Syu --noconfirm ;;
    fedora) sudo_run dnf makecache ;;
  esac
}

pkg_upgrade() {
  case "$DOTS_FAMILY" in
    debian) sudo_run env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y ;;
    arch) sudo_run pacman -Syu --noconfirm ;;
    fedora) sudo_run dnf upgrade -y --refresh ;;
  esac
}

pkg_installed() {
  case "$DOTS_FAMILY" in
    debian) dpkg -s "$1" >/dev/null 2>&1 ;;
    arch) pacman -Qi "$1" >/dev/null 2>&1 ;;
    fedora) rpm -q "$1" >/dev/null 2>&1 ;;
  esac
}

pkg_available() {
  case "$DOTS_FAMILY" in
    debian)
      local cand
      cand="$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}')"
      [[ -n "$cand" && "$cand" != "(none)" ]]
      ;;
    arch) pacman -Si "$1" >/dev/null 2>&1 ;;
    fedora) return 0 ;;
  esac
}

dnf_skip_flag() {
  if dnf install --help 2>&1 | grep -q -- '--skip-unavailable'; then
    printf '%s' '--skip-unavailable'
  else
    printf '%s' '--setopt=strict=0'
  fi
}

PKG_MISSING=()

pkg_install() {
  local pkgs=() p
  PKG_MISSING=()
  for p in "$@"; do
    if is_dry || pkg_available "$p"; then
      pkgs+=("$p")
    else
      PKG_MISSING+=("$p")
    fi
  done
  ((${#PKG_MISSING[@]})) && log_warn "not in repositories, skipped: ${PKG_MISSING[*]}"
  ((${#pkgs[@]})) || return 0

  case "$DOTS_FAMILY" in
    debian) sudo_run env DEBIAN_FRONTEND=noninteractive apt-get install -y -o Acquire::Retries=3 -o Acquire::http::Timeout=30 -o Dpkg::Options::=--force-confold "${pkgs[@]}" ;;
    arch)
      # a mirror 404 or timeout is usually transient: refresh the db and retry once
      sudo_run pacman -S --needed --noconfirm "${pkgs[@]}" ||
        { is_dry || { log_warn "pacman failed, refreshing and retrying once"; sudo pacman -Sy --noconfirm >/dev/null 2>&1 || true; }
          sudo_run pacman -S --needed --noconfirm "${pkgs[@]}"; } ;;
    fedora) sudo_run dnf install -y --setopt=retries=5 --setopt=timeout=30 "$(dnf_skip_flag)" "${pkgs[@]}" ;;
  esac
}

aur_helper() {
  local h
  for h in paru yay; do
    has "$h" && {
      printf '%s' "$h"
      return 0
    }
  done
  return 1
}

aur_bootstrap() {
  aur_helper >/dev/null && return 0
  log_info "no AUR helper found, installing one"
  if pkg_available paru; then
    pkg_install paru
  elif pkg_available yay; then
    pkg_install yay
  else
    local tmp
    tmp="$(mktemp -d)"
    run git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && run makepkg -si --noconfirm)
    rm -rf "$tmp"
  fi
}

aur_install() {
  (($#)) || return 0
  is_dry || aur_bootstrap
  local helper
  helper="$(aur_helper || printf 'paru')"
  _aur_run() {
    case "$helper" in
      paru) run paru -S --needed --noconfirm --skipreview "$@" ;;
      yay) run yay -S --needed --noconfirm --answerdiff None --answerclean None "$@" ;;
    esac
  }
  # one broken AUR package (bad upstream PKGBUILD) must not sink the rest: retry one by one
  if ! _aur_run "$@"; then
    if (($# == 1)); then
      log_warn "AUR package failed (usually a broken upstream PKGBUILD or a conflict, retry later): $1"
      return 0
    fi
    local p failed=()
    for p in "$@"; do _aur_run "$p" || failed+=("$p"); done
    ((${#failed[@]})) && log_warn "AUR packages failed (usually a broken upstream PKGBUILD, retry later): ${failed[*]}"
  fi
  return 0
}

install_packages_from_file() {
  local file="$1" line repo=() aur=()
  [[ -r "$file" ]] || die "package list not found: $file"
  while IFS= read -r line; do
    [[ " ${DOTS_SKIP_PKGS:-} " == *" $line "* ]] && continue
    if [[ "$line" == aur:* ]]; then
      aur+=("${line#aur:}")
    else
      repo+=("$line")
    fi
  done < <(pkg_list "$file")

  ((${#repo[@]})) && pkg_install "${repo[@]}"
  if ((${#aur[@]})); then
    if [[ "$DOTS_FAMILY" == arch ]]; then
      aur_install "${aur[@]}"
    else
      log_warn "aur: entries ignored on $DOTS_DISTRO"
    fi
  fi
  return 0
}

backup_path() {
  local p="$1" rel dest
  [[ -e "$p" || -L "$p" ]] || return 0
  rel="${p#"$HOME"/}"
  rel="${rel#/}"
  dest="$DOTS_BACKUP_DIR/$rel"
  run mkdir -p "$(dirname "$dest")"
  run mv "$p" "$dest"
  log_info "backed up $p -> $dest"
}

link_config() {
  local src="$1" dst="$2"
  [[ -e "$src" ]] || die "missing source: $src"
  if [[ -e "$dst" && ! -L "$dst" ]] && diff -rq "$src" "$dst" >/dev/null 2>&1; then
    log_info "up to date: $dst"
    return 0
  fi
  run mkdir -p "$(dirname "$dst")"
  backup_path "$dst"
  run cp -a "$src" "$dst"
  log_ok "copied $dst"
}

copy_config() {
  local src="$1" dst="$2"
  [[ -e "$src" ]] || die "missing source: $src"
  run mkdir -p "$(dirname "$dst")"
  backup_path "$dst"
  run cp -a "$src" "$dst"
  log_ok "copied $dst"
}

fetch() {
  local url="$1" dest="$2"
  run mkdir -p "$(dirname "$dest")"
  run curl -fsSL --retry 3 --retry-delay 2 -o "$dest" "$url"
}

github_asset_url() {
  local slug="$1" pattern="$2"
  local -a auth=()
  [[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
  curl -fsSL "${auth[@]}" "https://api.github.com/repos/$slug/releases/latest" 2>/dev/null |
    grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]+"' |
    sed -E 's/.*"(https:[^"]+)"/\1/' |
    grep -E "$pattern" | head -n1 || true
}

version_ge() {
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]
}

program_version() {
  "$1" --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1
}

deb_arch() {
  case "$(uname -m)" in
    x86_64) printf 'amd64' ;;
    aarch64 | arm64) printf 'arm64' ;;
    *) uname -m ;;
  esac
}

ensure_executable() {
  local f
  for f in "$@"; do
    if [[ -e "$f" && ! -x "$f" ]]; then run chmod +x "$f"; fi
  done
  return 0
}

write_root_file() {
  local path="$1" content="$2"
  if is_dry; then
    printf '    [dry-run] write %s\n' "$path"
    return 0
  fi
  if ((EUID == 0)); then
    printf '%s\n' "$content" >"$path"
  else
    printf '%s\n' "$content" | sudo tee "$path" >/dev/null
  fi
}

standard_dirs() {
  run mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share" "$HOME/.local/opt" "$HOME/Pictures" "$HOME/workspace/github"
}
