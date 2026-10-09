#!/usr/bin/env bash
# qylock SDDM themes, shared by the display-manager and qylock steps.
# Needs helper.sh sourced and detect_platform already run.

qylock_repo="${DOTS_QYLOCK_REPO:-https://github.com/Darkkal44/qylock}"
qylock_ref="${DOTS_QYLOCK_REF:-f6561e2ceae33f26e5e660742a5df2f725cbe514}"
qylock_src="$HOME/.cache/dotfiles/qylock"
qylock_themes_dir=/usr/share/sddm/themes
# Themes to install. One by default (ninja_gaiden is a static image: no video, no codecs, least to go wrong);
# for more: DOTS_QYLOCK_THEMES="ninja_gaiden enfield pixel-sakura wuwa sword" ./install.sh qylock
# switch later with: qylock-theme <name>
read -r -a qylock_themes <<<"${DOTS_QYLOCK_THEMES:-ninja_gaiden}"
qylock_default="${DOTS_QYLOCK_THEME:-${qylock_themes[0]}}"
case " ${qylock_themes[*]} " in
  *" $qylock_default "*) ;;
  *) qylock_themes+=("$qylock_default") ;;
esac

is_vmware() { [[ "${DOTS_VIRT:-$(systemd-detect-virt 2>/dev/null || true)}" == vmware ]]; }
have_qt6_greeter() { command -v sddm-greeter-qt6 >/dev/null 2>&1 || [[ -x /usr/lib/sddm/sddm-greeter-qt6 ]]; }

# the theme to put in sddm.conf: keep a choice made with qylock-theme (marker file), else the default
qylock_choose_theme() {
  local cur t
  [[ -f /etc/sddm.conf.d/.qylock-user-choice ]] || { printf '%s\n' "$qylock_default"; return 0; }
  cur="$(grep -rh '^Current=' /etc/sddm.conf.d/zz-dotfiles.conf 2>/dev/null | tail -1 | cut -d= -f2)"
  for t in "${qylock_themes[@]}"; do
    [[ "$cur" == "$t" ]] && { printf '%s\n' "$cur"; return 0; }
  done
  printf '%s\n' "$qylock_default"
}

# the video themes are H.264; Fedora's ffmpeg-free cannot decode it, so use RPM Fusion's ffmpeg
fedora_full_ffmpeg() {
  [[ "$DOTS_FAMILY" == fedora ]] || return 0
  rpm -q ffmpeg >/dev/null 2>&1 && return 0
  if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
    log_warn "RPM Fusion is not enabled, the video themes may stay black"
    return 0
  fi
  sudo_run dnf swap -y ffmpeg-free ffmpeg --allowerasing ||
    log_warn "could not swap to RPM Fusion ffmpeg, if the login background is black run: sudo dnf swap ffmpeg-free ffmpeg --allowerasing"
}

qylock_all_current() {
  local t
  for t in "${qylock_themes[@]}"; do
    [[ "$(cat "$qylock_themes_dir/$t/.dots-ref" 2>/dev/null)" == "$qylock_ref" && -f "$qylock_themes_dir/$t/Main.qml" ]] || return 1
  done
}

# returns 0 when the themes are installed and usable, 1 when the caller should keep the dots theme
install_qylock() {
  [[ "$DOTS_FAMILY" == debian ]] && return 1
  if is_vmware; then
    log_info "VMware: keeping the dots SDDM theme"
    return 1
  fi
  local pkgs t paths=()
  mapfile -t pkgs < <(pkg_list "$DOTS_ROOT/packages/qylock-$DOTS_FAMILY.txt")
  pkg_install "${pkgs[@]}"
  if ! have_qt6_greeter && ! is_dry; then
    log_warn "no Qt6 SDDM greeter, qylock needs it, keeping the dots theme"
    return 1
  fi
  if ! is_dry && qylock_all_current; then
    fedora_full_ffmpeg
    log_ok "qylock themes already installed (${qylock_themes[*]})"
    return 0
  fi
  for t in "${qylock_themes[@]}"; do paths+=("themes/$t"); done
  run rm -rf "$qylock_src"
  run mkdir -p "$(dirname "$qylock_src")"
  if ! is_dry; then
    {
      git init -q "$qylock_src" &&
        git -C "$qylock_src" remote add origin "$qylock_repo" &&
        git -C "$qylock_src" sparse-checkout set "${paths[@]}" &&
        GIT_TERMINAL_PROMPT=0 git -C "$qylock_src" fetch -q --depth 1 --filter=blob:none origin "$qylock_ref" &&
        git -C "$qylock_src" checkout -q FETCH_HEAD
    } || { log_warn "could not fetch qylock, keeping the dots theme"; return 1; }
  else
    printf '    [dry-run] fetch qylock %s (%s)\n' "$qylock_ref" "${paths[*]}"
  fi
  local installed=0
  for t in "${qylock_themes[@]}"; do
    if ! is_dry && [[ ! -f "$qylock_src/themes/$t/Main.qml" ]]; then
      log_warn "qylock theme '$t' is missing upstream, skipping it"
      continue
    fi
    sudo_run rm -rf "$qylock_themes_dir/$t"
    sudo_run mkdir -p "$qylock_themes_dir/$t"
    sudo_run cp -r "$qylock_src/themes/$t/." "$qylock_themes_dir/$t/"
    printf '%s\n' "$qylock_ref" | sudo_run tee "$qylock_themes_dir/$t/.dots-ref" >/dev/null
    sudo_run chmod -R a+rX "$qylock_themes_dir/$t"
    installed=$((installed + 1))
  done
  if ! is_dry && [[ ! -f "$qylock_themes_dir/$qylock_default/Main.qml" ]]; then
    log_warn "default qylock theme '$qylock_default' did not install, keeping the dots theme"
    return 1
  fi
  fedora_full_ffmpeg
  log_ok "qylock themes installed (${qylock_themes[*]}), default $(qylock_choose_theme)"
  return 0
}

# Does the SDDM greeter load this theme? Runs it in test mode for a few seconds in the current desktop
# session (a window flashes up). Returns 0 loads fine, 1 broken (output kept in $sddm_check_log),
# 2 cannot check (no Qt6 greeter, or no graphical session such as ssh or a tty).
sddm_theme_check() {
  local theme="$1" rc
  local greeter
  greeter="$(command -v sddm-greeter-qt6 || true)"
  [[ -n "$greeter" ]] || { [[ -x /usr/lib/sddm/sddm-greeter-qt6 ]] && greeter=/usr/lib/sddm/sddm-greeter-qt6; }
  [[ -n "$greeter" ]] || return 2
  [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]] || return 2
  [[ -f "$qylock_themes_dir/$theme/Main.qml" ]] || { sddm_check_log="theme '$theme' has no Main.qml"; return 1; }
  sddm_check_log="$(timeout 6 "$greeter" --test-mode --theme "$qylock_themes_dir/$theme" 2>&1)"
  rc=$?
  # a healthy greeter keeps running until timeout kills it (124); a crash or a QML error is a failure
  if ((rc != 0 && rc != 124)); then return 1; fi
  if grep -qiE 'is not installed|is not a type|cannot load|failed to load|ReferenceError|TypeError|unable to assign|Type .* unavailable' <<<"$sddm_check_log"; then
    return 1
  fi
  return 0
}

# Decide whether it is safe to point the greeter at $1. A black login screen is much worse than the
# default one, so an unverified or broken theme is not applied (DOTS_SDDM_FORCE=1 overrides).
# Returns 0 to apply, 1 to leave the distro default in place (and removes our config).
sddm_gate() {
  local theme="$1" verdict=0
  [[ "$DOTS_FAMILY" == debian ]] && return 0
  is_dry && return 0
  sddm_theme_check "$theme" || verdict=$?
  case "$verdict" in
    0) log_ok "SDDM greeter loads theme '$theme'"; return 0 ;;
    1)
      log_warn "SDDM theme '$theme' failed to load, leaving the default login screen. Greeter output:"
      printf '%s\n' "$sddm_check_log" | head -15 | sed 's/^/    /'
      ;;
    2)
      if [[ "${DOTS_SDDM_FORCE:-0}" == 1 ]]; then
        log_warn "cannot verify theme '$theme' (no graphical session), applying it because DOTS_SDDM_FORCE=1"
        return 0
      fi
      log_warn "cannot verify theme '$theme' (run this from a terminal inside your desktop), leaving the default login screen"
      ;;
  esac
  sudo_run rm -f /etc/sddm.conf.d/zz-dotfiles.conf
  return 1
}
