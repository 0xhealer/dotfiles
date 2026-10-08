#!/usr/bin/env bash
# Google Drive on Linux (rclone mount as a systemd user service) and an Obsidian vault inside it.
# There is no official Google Drive client for Linux, so this uses rclone.
#
# Usage: tools/gdrive-obsidian.sh [-n] [setup|auth|service|vault|status|unmount]
#   setup    everything below, in order (default)
#   auth     create the rclone "gdrive" remote (opens a browser once)
#   service  install and start the mount at ~/GoogleDrive
#   vault    create ~/GoogleDrive/Obsidian, let Obsidian see it, register it as a vault
#   status   show the remote, the mount and the vault
#   unmount  stop the mount service
# Env: GDRIVE_REMOTE (gdrive), GDRIVE_MOUNT (~/GoogleDrive), OBSIDIAN_VAULT_DIR (<mount>/Obsidian),
#      GDRIVE_CLIENT_ID / GDRIVE_CLIENT_SECRET (your own Google API client, avoids rclone's shared rate limit)
set -Eeuo pipefail

if [[ "${1:-}" == -n ]]; then
  export DOTS_DRY_RUN=1
  shift
fi
# shellcheck source=../helper/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helper/helper.sh"
require_user
detect_platform

remote="${GDRIVE_REMOTE:-gdrive}"
mount_dir="${GDRIVE_MOUNT:-$HOME/GoogleDrive}"
vault_dir="${OBSIDIAN_VAULT_DIR:-$mount_dir/Obsidian}"
unit="rclone-gdrive.service"
unit_path="$HOME/.config/systemd/user/$unit"

have_remote() { rclone listremotes 2>/dev/null | grep -qx "$remote:"; }
# the remote must be a plain Google Drive one; a "crypt" remote (or a leftover from an earlier attempt)
# would show scrambled file and folder names in Obsidian
remote_type() { rclone config show "$remote" 2>/dev/null | awk -F' *= *' '$1=="type"{print $2; exit}'; }
check_plain_remote() {
  local t
  t="$(remote_type)"
  if [[ "$t" != drive ]]; then
    log_err "rclone remote '$remote' has type '${t:-unknown}', not 'drive' (that is what encrypts names and contents)"
    log_err "remove it with: rclone config delete $remote   (or use another name: GDRIVE_REMOTE=gdrive-plain $0)"
    return 1
  fi
}
mounted() { mountpoint -q "$mount_dir" 2>/dev/null; }

install_rclone() {
  log_step "rclone"
  if has rclone && { has fusermount3 || has fusermount; }; then
    log_ok "rclone and FUSE already installed"
    return 0
  fi
  case "$DOTS_FAMILY" in
    arch) pkg_install rclone fuse3 ;;
    fedora) pkg_install rclone fuse3 ;;
    debian) pkg_install rclone fuse3 ;;
    *) die "unsupported distro: $DOTS_FAMILY" ;;
  esac
  has rclone || is_dry || die "rclone did not install"
  log_ok "rclone installed"
}

do_auth() {
  log_step "Google Drive login"
  if have_remote; then
    check_plain_remote || return 1
    log_ok "rclone remote '$remote' already exists (plain Google Drive, not encrypted)"
    return 0
  fi
  if is_dry; then
    printf '    [dry-run] rclone config create %s drive scope=drive\n' "$remote"
    return 0
  fi
  local args=(config create "$remote" drive scope=drive)
  [[ -n "${GDRIVE_CLIENT_ID:-}" ]] && args+=(client_id="$GDRIVE_CLIENT_ID")
  [[ -n "${GDRIVE_CLIENT_SECRET:-}" ]] && args+=(client_secret="$GDRIVE_CLIENT_SECRET")
  log_info "a browser window opens, sign in and allow access (rclone listens on 127.0.0.1:53682)"
  if ! rclone "${args[@]}"; then
    log_err "login failed; on a machine without a browser run 'rclone authorize \"drive\"' elsewhere and 'rclone config' here"
    return 1
  fi
  have_remote || { log_err "remote '$remote' was not created"; return 1; }
  log_ok "remote '$remote' created"
}

do_service() {
  log_step "Google Drive mount ($mount_dir)"
  have_remote || is_dry || { log_err "no rclone remote '$remote', run: $0 auth"; return 1; }
  is_dry || check_plain_remote || return 1
  local rclone_bin fuse_umount
  rclone_bin="$(command -v rclone || echo /usr/bin/rclone)"
  fuse_umount="$(command -v fusermount3 || command -v fusermount || echo /usr/bin/fusermount3)"
  run mkdir -p "$mount_dir" "$(dirname "$unit_path")"
  if ! is_dry; then
    cat >"$unit_path" <<UNIT
[Unit]
Description=Google Drive (rclone mount)
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStartPre=/usr/bin/mkdir -p $mount_dir
ExecStart=$rclone_bin mount $remote: $mount_dir \\
  --vfs-cache-mode full --vfs-cache-max-size 5G --vfs-cache-max-age 168h \\
  --vfs-write-back 5s --dir-cache-time 5m --poll-interval 30s \\
  --drive-pacer-min-sleep 10ms --log-level NOTICE
ExecStop=$fuse_umount -u $mount_dir
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
UNIT
    log_ok "wrote $unit_path"
  else
    printf '    [dry-run] write %s\n' "$unit_path"
  fi
  run systemctl --user daemon-reload
  run systemctl --user enable --now "$unit"
  if ! is_dry; then
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do mounted && break; sleep 1; done
    if mounted; then
      log_ok "Google Drive mounted at $mount_dir"
    else
      log_warn "not mounted yet, check: systemctl --user status $unit; journalctl --user -u $unit"
      return 1
    fi
  fi
  # keep the mount up without an open login session
  has loginctl && run loginctl enable-linger "${USER:-$(id -un)}" || true
}

register_vault() {
  local cfg="$1" py
  [[ -f "$cfg" ]] || return 1
  py="$(command -v python3 || true)"
  [[ -n "$py" ]] || { log_warn "python3 missing, open $vault_dir from Obsidian with 'Open folder as vault'"; return 0; }
  pgrep -x obsidian >/dev/null 2>&1 && { log_warn "Obsidian is running, close it and re-run '$0 vault' to register the vault automatically"; return 0; }
  cp -a "$cfg" "$cfg.dotfiles-bak"
  "$py" -I - "$cfg" "$vault_dir" <<'PY'
import json, secrets, sys, time
cfg, path = sys.argv[1], sys.argv[2]
with open(cfg) as f:
    data = json.load(f)
vaults = data.setdefault("vaults", {})
if any(v.get("path") == path for v in vaults.values()):
    print("already registered")
else:
    vaults[secrets.token_hex(8)] = {"path": path, "ts": int(time.time() * 1000), "open": True}
    with open(cfg, "w") as f:
        json.dump(data, f)
    print("registered")
PY
}

do_vault() {
  log_step "Obsidian vault ($vault_dir)"
  if ! is_dry && ! mounted; then
    log_err "Google Drive is not mounted, run: $0 service"
    return 1
  fi
  run mkdir -p "$vault_dir"

  # Flatpak Obsidian (Fedora, Kali, Ubuntu) cannot see the mount without a permission
  if has flatpak && flatpak info md.obsidian.Obsidian >/dev/null 2>&1; then
    run flatpak override --user --filesystem="$mount_dir" md.obsidian.Obsidian
    log_ok "Flatpak Obsidian can now read $mount_dir"
  fi

  local cfg
  for cfg in "$HOME/.config/obsidian/obsidian.json" "$HOME/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json"; do
    if [[ -f "$cfg" ]] && ! is_dry; then
      register_vault "$cfg" && log_ok "vault registered in $cfg"
    fi
  done
  log_info "if the vault is not listed, in Obsidian choose 'Open folder as vault' and pick $vault_dir"
  log_info "tip: copy your existing vault into $vault_dir (rclone copy ~/Vault $remote:Obsidian) before opening it"
}

do_status() {
  if have_remote; then
    log_ok "remote '$remote' exists, type: $(remote_type)"
    check_plain_remote || true
  else
    log_warn "no remote '$remote'"
  fi
  mounted && log_ok "mounted at $mount_dir" || log_warn "not mounted"
  systemctl --user is-active "$unit" 2>/dev/null | sed 's/^/  service: /' || true
  [[ -d "$vault_dir" ]] && log_ok "vault dir: $vault_dir" || log_warn "no vault dir yet"
}

case "${1:-setup}" in
  setup)
    install_rclone
    do_auth
    do_service
    do_vault
    log_ok "done"
    ;;
  auth) install_rclone; do_auth ;;
  service) install_rclone; do_service ;;
  vault) do_vault ;;
  status) do_status ;;
  unmount) run systemctl --user disable --now "$unit" ;;
  *) sed -n '2,17p' "$0"; exit 2 ;;
esac
