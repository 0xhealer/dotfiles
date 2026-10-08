#!/usr/bin/env bash
# qylock "sword" SDDM theme, shared by the display-manager and qylock steps.
# Needs helper.sh sourced and detect_platform already run.

qylock_repo="${DOTS_QYLOCK_REPO:-https://github.com/Darkkal44/qylock}"
qylock_ref="${DOTS_QYLOCK_REF:-f6561e2ceae33f26e5e660742a5df2f725cbe514}"
qylock_src="$HOME/.cache/dotfiles/qylock"
qylock_dest=/usr/share/sddm/themes/sword

is_vmware() { [[ "${DOTS_VIRT:-$(systemd-detect-virt 2>/dev/null || true)}" == vmware ]]; }
have_qt6_greeter() { command -v sddm-greeter-qt6 >/dev/null 2>&1 || [[ -x /usr/lib/sddm/sddm-greeter-qt6 ]]; }

# the sword video is H.264; Fedora's ffmpeg-free cannot decode it, so use RPM Fusion's ffmpeg
fedora_full_ffmpeg() {
  [[ "$DOTS_FAMILY" == fedora ]] || return 0
  rpm -q ffmpeg >/dev/null 2>&1 && return 0
  if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
    log_warn "RPM Fusion is not enabled, sword's video may stay black"
    return 0
  fi
  sudo_run dnf swap -y ffmpeg-free ffmpeg --allowerasing ||
    log_warn "could not swap to RPM Fusion ffmpeg, if the login background is black run: sudo dnf swap ffmpeg-free ffmpeg --allowerasing"
}

# returns 0 when sword is installed and usable, 1 when the caller should keep the dots theme
install_qylock() {
  [[ "$DOTS_FAMILY" == debian ]] && return 1
  if is_vmware; then
    log_info "VMware: keeping the dots SDDM theme"
    return 1
  fi
  local pkgs
  mapfile -t pkgs < <(pkg_list "$DOTS_ROOT/packages/qylock-$DOTS_FAMILY.txt")
  pkg_install "${pkgs[@]}"
  if ! have_qt6_greeter && ! is_dry; then
    log_warn "no Qt6 SDDM greeter, qylock sword needs it, keeping the dots theme"
    return 1
  fi
  if [[ "$(cat "$qylock_dest/.dots-ref" 2>/dev/null)" == "$qylock_ref" && -f "$qylock_dest/Main.qml" ]] && ! is_dry; then
    fedora_full_ffmpeg
    log_ok "qylock sword already installed"
    return 0
  fi
  run rm -rf "$qylock_src"
  run mkdir -p "$(dirname "$qylock_src")"
  if ! is_dry; then
    {
      git init -q "$qylock_src" &&
        git -C "$qylock_src" remote add origin "$qylock_repo" &&
        git -C "$qylock_src" sparse-checkout set themes/sword &&
        GIT_TERMINAL_PROMPT=0 git -C "$qylock_src" fetch -q --depth 1 --filter=blob:none origin "$qylock_ref" &&
        git -C "$qylock_src" checkout -q FETCH_HEAD
    } || { log_warn "could not fetch qylock, keeping the dots theme"; return 1; }
    [[ -f "$qylock_src/themes/sword/Main.qml" ]] || { log_warn "qylock sword theme missing, keeping the dots theme"; return 1; }
  else
    printf '    [dry-run] fetch qylock %s (themes/sword)\n' "$qylock_ref"
  fi
  sudo_run rm -rf "$qylock_dest"
  sudo_run mkdir -p "$qylock_dest"
  sudo_run cp -r "$qylock_src/themes/sword/." "$qylock_dest/"
  printf '%s\n' "$qylock_ref" | sudo_run tee "$qylock_dest/.dots-ref" >/dev/null
  sudo_run chmod -R a+rX "$qylock_dest"
  fedora_full_ffmpeg
  log_ok "qylock sword installed"
  return 0
}
