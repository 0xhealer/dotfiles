#!/usr/bin/env bash
set -Eeuo pipefail

repo="${DOTS_REPO:-0xhealer/dotfiles}"
branch="${DOTS_BRANCH:-main}"
dest="${DOTS_DIR:-$HOME/dotfiles}"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "run as your normal user, not root (sudo is used where needed)"

if command -v git >/dev/null 2>&1; then
  if [[ -d "$dest/.git" ]]; then
    say "updating $dest"
    git -C "$dest" pull --ff-only
  else
    say "cloning $repo into $dest"
    git clone --depth 1 --branch "$branch" "https://github.com/$repo" "$dest"
  fi
else
  command -v tar >/dev/null 2>&1 || die "tar is required"
  say "git not found, downloading $repo ($branch) into $dest"
  mkdir -p "$dest"
  url="https://codeload.github.com/$repo/tar.gz/refs/heads/$branch"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" | tar -xz --strip-components=1 -C "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$url" | tar -xz --strip-components=1 -C "$dest"
  else
    die "need git, curl or wget"
  fi
fi

say "running install.sh $*"
if [[ ! -t 0 ]] && { : </dev/tty; } 2>/dev/null; then
  exec bash "$dest/install.sh" "$@" </dev/tty
fi
exec bash "$dest/install.sh" "$@"
