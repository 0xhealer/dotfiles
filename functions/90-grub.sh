#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

log_step "GRUB"

grub_default=/etc/default/grub
conf="$DOTS_ROOT/configs/grub/grub.conf"

if [[ ! -f "$grub_default" ]]; then
  log_warn "$grub_default not found; GRUB does not appear to be the bootloader, skipping"
  exit 0
fi

if has bootctl && bootctl is-installed >/dev/null 2>&1; then
  log_warn "systemd-boot is the active bootloader, leaving GRUB settings alone"
  exit 0
fi
if [[ "$DOTS_FAMILY" == arch && ! -f /boot/grub/grub.cfg ]]; then
  log_warn "/boot/grub/grub.cfg not found, GRUB is not the active bootloader, skipping"
  exit 0
fi

# GRUB cannot write grubenv on btrfs ("sparse file not allowed" at every boot), so no saved default there
boot_fs="$(findmnt -no FSTYPE --target /boot 2>/dev/null || true)"
tmp="$(mktemp)"
cp "$grub_default" "$tmp"
while IFS='=' read -r key value; do
  [[ -z "$key" ]] && continue
  if [[ "$boot_fs" == btrfs ]]; then
    case "$key" in
      GRUB_DEFAULT) value=0 ;;
      GRUB_SAVEDEFAULT) value=false ;;
    esac
  fi
  if grep -qE "^#?[[:space:]]*${key}=" "$tmp"; then
    sed -i -E "s|^#?[[:space:]]*${key}=.*|${key}=${value}|" "$tmp"
  else
    printf '%s=%s\n' "$key" "$value" >>"$tmp"
  fi
done < <(pkg_list "$conf")

if cmp -s "$tmp" "$grub_default"; then
  log_info "GRUB defaults already up to date"
  rm -f "$tmp"
  exit 0
fi

sudo_run cp -n "$grub_default" "$grub_default.dots.bak"
sudo_run install -m 644 "$tmp" "$grub_default"
rm -f "$tmp"

case "$DOTS_FAMILY" in
  debian) has update-grub && sudo_run update-grub ;;
  fedora) has grub2-mkconfig && sudo_run grub2-mkconfig -o /boot/grub2/grub.cfg ;;
  arch) has grub-mkconfig && sudo_run grub-mkconfig -o /boot/grub/grub.cfg ;;
esac
log_ok "GRUB configured"
