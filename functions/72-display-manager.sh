#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

case "$DOTS_FAMILY" in
  debian) [[ -n "$DOTS_EXTRA_DE" ]] || exit 0 ;;
  arch | fedora) ;;
  *) exit 0 ;;
esac

log_step "Display manager"

is_vmware() { [[ "${DOTS_VIRT:-$(systemd-detect-virt 2>/dev/null || true)}" == vmware ]]; }
have_qt6_greeter() { command -v sddm-greeter-qt6 >/dev/null 2>&1 || [[ -x /usr/lib/sddm/sddm-greeter-qt6 ]]; }

remove_virtual_keyboard() {
  is_dry && return 0
  local pkg
  while read -r pkg; do
    [[ -n "$pkg" ]] || continue
    if apt-get -s remove "$pkg" 2>/dev/null | grep -Eq '^Remv sddm'; then
      log_warn "keeping $pkg, removing it would remove sddm"
    else
      sudo apt-get remove -y "$pkg" >/dev/null || log_warn "could not remove $pkg"
    fi
  done < <(dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 2>/dev/null | awk '$1 ~ /^ii/ && $2 ~ /virtualkeyboard/ {print $2}')
}

qylock_repo="${DOTS_QYLOCK_REPO:-https://github.com/Darkkal44/qylock}"
qylock_ref="${DOTS_QYLOCK_REF:-f6561e2ceae33f26e5e660742a5df2f725cbe514}"
qylock_src="$HOME/.cache/dotfiles/qylock"

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
  sudo_run rm -rf /usr/share/sddm/themes/sword
  sudo_run mkdir -p /usr/share/sddm/themes/sword
  sudo_run cp -r "$qylock_src/themes/sword/." /usr/share/sddm/themes/sword/
  sudo_run chmod -R a+rX /usr/share/sddm/themes/sword
  if [[ "$DOTS_FAMILY" == fedora ]]; then
    log_info "Fedora: sword's video is H.264, if the login background is black run: sudo dnf swap ffmpeg-free ffmpeg --allowerasing (RPM Fusion)"
  fi
  log_ok "qylock sword installed"
  return 0
}

install_greeter() {
  local theme=dots
  install_qylock && theme=sword
  sudo_run mkdir -p /etc/sddm.conf.d
  sudo_run rm -f /etc/sddm.conf.d/10-dotfiles.conf
  [[ "$DOTS_FAMILY" == debian ]] && remove_virtual_keyboard
  if [[ -f /etc/sddm.conf ]] && ! is_dry; then
    sudo sed -i -E '/^[[:space:]]*(Current|InputMethod)=/d' /etc/sddm.conf
  fi
  local display_server=""
  [[ "$DOTS_FAMILY" == debian ]] && display_server="DisplayServer=x11
"
  write_root_file /etc/sddm.conf.d/zz-dotfiles.conf "[General]
${display_server}InputMethod=compose

[Theme]
Current=$theme"
  sudo_run rm -rf /usr/share/sddm/themes/dots
  sudo_run mkdir -p /usr/share/sddm/themes/dots
  sudo_run cp "$DOTS_ROOT"/configs/sddm/dots/* /usr/share/sddm/themes/dots/
  if have_qt6_greeter; then
    printf 'QtVersion=6\n' | sudo_run tee -a /usr/share/sddm/themes/dots/metadata.desktop >/dev/null
  fi
  sudo_run cp "$DOTS_ROOT/assets/wallpapers/001.jpg" /usr/share/sddm/themes/dots/background.jpg
  sudo_run chmod -R a+rX /usr/share/sddm/themes/dots
}

if [[ "$DOTS_FAMILY" != debian ]]; then
  pkg_install sddm
  install_greeter
  sudo_run systemctl enable --force sddm.service
  if [[ "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" != */sddm.service ]] && ! is_dry; then
    log_warn "display-manager.service does not point at sddm, check: systemctl status display-manager"
  fi
  if ! is_dry; then
    log_info "effective SDDM theme: $(grep -rh '^Current=' /etc/sddm.conf /etc/sddm.conf.d 2>/dev/null | tail -1)"
  fi
  log_ok "SDDM is the display manager from the next boot"
  exit 0
fi

if [[ "$(cat /etc/X11/default-display-manager 2>/dev/null)" == */sddm ]] && systemctl is-enabled sddm.service >/dev/null 2>&1; then
  log_info "SDDM is already the display manager"
  install_greeter
  exit 0
fi

if ! is_dry; then
  printf 'sddm shared/default-x-display-manager select sddm\n' | sudo debconf-set-selections
fi
sudo_run env DEBIAN_FRONTEND=noninteractive apt-get install -y sddm xserver-xorg xserver-xorg-input-libinput xinit x11-xserver-utils
install_greeter
[[ -x /usr/bin/sddm || -x /usr/sbin/sddm ]] && write_root_file /etc/X11/default-display-manager "$(command -v sddm || echo /usr/bin/sddm)"
sudo_run systemctl enable --force sddm.service

if ! is_dry; then
  log_info "effective SDDM theme: $(grep -rh '^Current=' /etc/sddm.conf /etc/sddm.conf.d 2>/dev/null | tail -1)"
fi
log_ok "SDDM is the display manager from the next boot; it lists i3, GNOME and KDE sessions"
