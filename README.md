# dotfiles

Portable dotfiles and a modular installer for Linux (Ubuntu, Kali, CachyOS, Fedora) and Windows, for remote or borrowed machines.

## Install

Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/0xhealer/dotfiles/main/bootstrap.sh | bash
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/0xhealer/dotfiles/main/bootstrap.ps1 | iex
```

The bootstrap fetches this repo into `~/dotfiles` (set `DOTS_DIR` to change it), then runs the installer. On Windows it sets the execution policy for its own process only and unblocks the downloaded files, so no system setting changes.

Installer options, after cloning or through the bootstrap:

```bash
./install.sh --list                # list steps
./install.sh shell starship        # run selected steps
./install.sh --skip grub           # skip steps
./install.sh --dry-run             # show what would run

curl -fsSL https://raw.githubusercontent.com/0xhealer/dotfiles/main/bootstrap.sh | bash -s -- --dry-run
```

```powershell
.\install.ps1 -List
.\install.ps1 -Modules starship,git
.\install.ps1 -Skip packages
.\install.ps1 -DryRun
.\install.ps1 -NoElevate

& ([scriptblock]::Create((irm https://raw.githubusercontent.com/0xhealer/dotfiles/main/bootstrap.ps1))) -DryRun
```

Configs are copied, not linked: edit the repo and re-run the step to apply. Replaced files go to `~/.dotfiles-backup/<timestamp>`. Windows asks for UAC once.

## Layout

```
bootstrap.sh / .ps1        one-command installers
install.sh / install.ps1   entry points
functions/                 numbered Linux steps
modules/                   numbered Windows steps
packages/                  package lists per distro
configs/                   one folder per application
assets/                    wallpapers
```

## Extras

- Keybindings: [KEYBINDINGS.md](KEYBINDINGS.md)
- `ghclone <repo>` and `ghcreate [name] [-p]` clone into and create repos under `~/workspace/github` (needs `gh auth login` once).

## Login screen themes (CachyOS and Fedora)

`./install.sh qylock` installs the qylock SDDM themes `ninja_gaiden` (default), `enfield`, `pixel-sakura`, `wuwa` and `sword`. Switch with `qylock-theme list`, `qylock-theme <name>` or `qylock-theme preview <name>`; a choice made that way survives re-running the installer. VMware keeps the plain dots theme.

## Google Drive and Obsidian (Linux)

```bash
tools/gdrive-obsidian.sh          # install rclone, sign in once, mount ~/GoogleDrive, create the Obsidian vault
tools/gdrive-obsidian.sh status
```

Google has no Linux client, so Drive is an rclone mount run as a systemd user service (`rclone-gdrive.service`, full VFS cache so notes stay readable offline). The vault lives in `~/GoogleDrive/Obsidian`; Flatpak Obsidian is given access to the mount. Set `GDRIVE_CLIENT_ID` and `GDRIVE_CLIENT_SECRET` to use your own Google API client instead of rclone's shared one.

