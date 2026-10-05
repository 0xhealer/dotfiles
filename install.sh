#!/usr/bin/env bash
set -Eeuo pipefail

DOTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTS_ROOT
# shellcheck source=helper/helper.sh
source "$DOTS_ROOT/helper/helper.sh"

CRITICAL_STEPS=(prerequisites packages)

usage() {
  cat <<USAGE
Usage: ./install.sh [options] [step ...]

Options:
  -l, --list           list available steps
  -n, --dry-run        print what would run without changing anything
  -s, --skip a,b       skip the given steps
  -h, --help           show this help

With no steps given, every step runs in order.
Examples:
  ./install.sh
  ./install.sh shell starship
  ./install.sh --skip grub,wallpapers
  ./install.sh -n
USAGE
}

step_name() {
  local n
  n="$(basename "$1" .sh)"
  printf '%s' "${n#[0-9][0-9]-}"
}

list_steps() {
  local f
  for f in "$DOTS_ROOT"/functions/[0-9][0-9]-*.sh; do
    printf '  %s\n' "$(step_name "$f")"
  done
}

contains() {
  local needle="$1" x
  shift
  for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done
  return 1
}

only=()
skip=()
while (($#)); do
  case "$1" in
    -l | --list)
      list_steps
      exit 0
      ;;
    -n | --dry-run) DOTS_DRY_RUN=1 ;;
    -s | --skip)
      shift
      [[ $# -gt 0 ]] || die "--skip needs a value"
      IFS=',' read -r -a more <<<"$1"
      skip+=("${more[@]}")
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*) die "unknown option: $1" ;;
    *) only+=("$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')") ;;
  esac
  shift
done
export DOTS_DRY_RUN

require_user
detect_platform

if [[ ! -t 0 ]] && ! is_dry; then
  die "stdin is not a terminal; run ./install.sh from an interactive shell."
fi

log_step "Platform"
log_info "distro:   $DOTS_DISTRO (id=$DOTS_OS_ID ${DOTS_OS_VERSION_ID})"
log_info "family:   $DOTS_FAMILY"
log_info "desktop:  $DOTS_WM"
log_info "packages: $DOTS_PKG_FILE"
log_info "backups:  $DOTS_BACKUP_DIR"
is_dry && log_warn "dry-run: nothing will be changed"

LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
if ! is_dry; then
  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
  exec > >(tee -a "$LOG_FILE") 2>&1
  log_info "log:      $LOG_FILE"

  if has sudo && ((EUID != 0)); then
    log_info "requesting sudo (once)"
    sudo -v
    (while true; do
      sudo -n true
      sleep 50
      kill -0 "$$" 2>/dev/null || exit
    done) &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
  fi
fi

mapfile -t all_steps < <(compgen -G "$DOTS_ROOT/functions/[0-9][0-9]-*.sh" | sort)
((${#all_steps[@]})) || die "no steps found in $DOTS_ROOT/functions"

if ((${#only[@]})); then
  known=()
  for f in "${all_steps[@]}"; do known+=("$(step_name "$f")"); done
  for o in "${only[@]}"; do
    contains "$o" "${known[@]}" || die "unknown step '$o' (see ./install.sh --list)"
  done
fi

failed=()
for f in "${all_steps[@]}"; do
  name="$(step_name "$f")"
  if ((${#only[@]})) && ! contains "$name" "${only[@]}"; then continue; fi
  if ((${#skip[@]})) && contains "$name" "${skip[@]}"; then
    log_info "skipping $name"
    continue
  fi

  if bash "$f"; then
    :
  else
    log_err "step failed: $name"
    failed+=("$name")
    if contains "$name" "${CRITICAL_STEPS[@]}"; then
      die "critical step '$name' failed, aborting"
    fi
  fi
done

log_step "Summary"
if ((${#failed[@]})); then
  log_warn "failed steps: ${failed[*]}"
  exit 1
fi
log_ok "all steps completed"
log_info "log out and back in (or reboot) to pick up the new shell and session"
