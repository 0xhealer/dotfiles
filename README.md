# dotfiles

Public, portable edition of my dotfiles and modular installer for Windows and Linux, for use on remote or borrowed machines. Same layout and installer as my private set, with freely licensed fonts (JetBrainsMono Nerd Font, Hack Nerd Font) and the Catppuccin Mocha theme.

| Target | Desktop | Terminals | Shell | Browser | Editors |
| --- | --- | --- | --- | --- | --- |
| Ubuntu | i3 + GNOME; polybar, rofi, dmenu, picom, matugen | kitty, ghostty | zsh, fish, starship | Helium | VS Code, Neovim |
| Kali | i3 + KDE Plasma; polybar, rofi, dmenu, picom, matugen | kitty, ghostty | zsh, fish, starship | Helium | VS Code, Neovim |
| CachyOS | niri, noctalia v5, vicinae | kitty, ghostty | zsh, fish, starship | Helium | VS Code, Neovim |
| Fedora | niri, noctalia v5, vicinae | kitty, ghostty | zsh, fish, starship | Helium | VS Code, Neovim |
| Windows | - | Windows Terminal | PowerShell 7, starship | Brave | VS Code, Neovim |

GRUB is configured on Linux when `/etc/default/grub` exists. Terminals, polybar, rofi and dunst use 0.85 opacity; blur comes from picom (i3), niri 26.04+ (niri) and Windows Terminal acrylic.

## Layout

```
install.sh / install.ps1   entry points
helper/                    helper.sh, helper.ps1
functions/                 numbered Linux steps (bash)
modules/                   numbered Windows steps (PowerShell)
packages/                  one package list per distro, windows.txt, vscode-extensions.txt
configs/                   one folder per application
assets/wallpapers, assets/fonts
```

## Linux

```bash
./install.sh                 # everything, distro detected from /etc/os-release
./install.sh --list
./install.sh shell starship  # selected steps
./install.sh --skip grub
./install.sh --dry-run
```

Configs are copied into `$HOME`; edit the repo and re-run the installer (or the step) to apply changes. Replaced files are moved to `~/.dotfiles-backup/<timestamp>`. Logs go to `~/.local/state/dotfiles`.

Environment: `DOTS_LOGIN_SHELL` (default `zsh`), `DOTS_UPGRADE=1` (full upgrade first), `GIT_NAME` / `GIT_EMAIL`.

## Windows

Run `install.cmd` (double-click it, or `.\install.cmd` in a terminal). A repo downloaded as a zip is tagged "from the internet", so PowerShell refuses to run `install.ps1` directly ("not digitally signed") and the script can't fix that from inside itself. `install.cmd` isn't subject to the execution policy: it unblocks every file, then starts `install.ps1` with the policy bypassed for that run only. It takes the same arguments, e.g. `.\install.cmd -DryRun`.

Manual equivalent, if you prefer:

```powershell
Get-ChildItem -Recurse -File | Unblock-File
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1
```

If your organisation manages the policy ("Security error"), use `install.cmd` or the one-liner below.

```powershell
pwsh -ExecutionPolicy Bypass -File .\install.ps1
.\install.ps1 -List
.\install.ps1 -Modules starship,git
.\install.ps1 -Skip packages
.\install.ps1 -DryRun
.\install.ps1 -NoElevate
```

`install.ps1` asks for UAC once if not elevated.

Everything is copied, so re-run the module after editing a config in the repo.

## GitHub helpers

`ghclone <repo|owner/repo|url> [dir]` clones with `gh` into `~/workspace/github` (override with `GH_CLONE_DIR`) and changes into it. A bare name uses your own account.

`ghcreate [name] [-p] [-d description]` creates a private repo (public with `-p`). With a name it makes `~/workspace/github/<name>` with a first commit and pushes it; without one it publishes the current git repo.

Both exist in zsh, bash (`~/.config/shell/gh.sh`), fish and PowerShell. Run `gh auth login` once first.

## Notes

- Keybindings are identical across distros, see [KEYBINDINGS.md](KEYBINDINGS.md).
- Polybar (i3): wallpaper picker button, workspaces, window title, clock, VPN address, brightness, notification toggle, volume, CPU, RAM, disk, Wi-Fi (SSID, signal, speeds, IP), ethernet, battery with percentage and time, tray, power menu. Modules for missing hardware (Wi-Fi, battery) are left out automatically.

- Fonts: JetBrainsMono Nerd Font (primary) and Hack Nerd Font (fallback) everywhere, both SIL OFL, in `assets/fonts`. Theme: Catppuccin Mocha for Starship, Windows Terminal, VS Code, Neovim, dunst, dmenu, SDDM and the static fallback colours of every matugen-driven app.
- niri distros: Noctalia generates Material You colors from the wallpaper (`[theme] source = "wallpaper"` in `configs/noctalia/dotfiles.toml`) and renders them into niri (focus ring, borders), kitty, ghostty, GTK 3/4 (adw-gtk3), Qt (qt6ct), KColorScheme, btop, cava and the community templates for Vicinae, VS Code (`NoctaliaTheme`), Yazi, lazygit, Zathura, Obsidian, Discord, Telegram, Steam and Zen. Run `noctalia msg theme` to re-render; `Super+Shift+w` picks a new wallpaper and recolors everything. niri needs 3D acceleration in VMware (VM Settings > Display > Accelerate 3D graphics).
- i3 distros: matugen builds colors from the wallpaper into `~/.config/matugen/generated`, read by i3, polybar, rofi, kitty, ghostty, dunst and dmenu, and written straight into GTK 3/4, Qt (qt5ct/qt6ct), btop, fzf and a generated VS Code theme (`Matugen`; run `Developer: Reload Window` after a change). Starship, Neovim and the browser keep their own colors. Polybar logs to `~/.cache/polybar.log`. Polybar and matugen exist only in the i3 session: pick i3 on the login screen. `Super+w` opens waypaper (rofi grid fallback), `Super+Shift+w` picks a random one.
- `~/workspace/github` is created on every machine (where `ghclone` and `ghcreate` put repos). Kali also gets a flat `~/tools` from the `pentest-tools` step: tools from the Kali repos (`packages/kali-pentest.txt`) and PyPI (frida-tools, objection, apkleaks via pipx) install the normal way, and the GitHub tools (jwt_tool with its own venv and launcher, PEASS-ng, firmwalker, PayloadsAllTheThings) are cloned into `~/tools`. MobSF runs in Docker through the `mobsf` alias (web UI on port 8000, data in `~/.MobSF`). Packages missing from your repos are skipped with a warning.
- The `vm-tools` step installs the guest tools only when it runs inside a VM (open-vm-tools for VMware, spice-vdagent, VirtualBox additions), so the display follows the window size; i3 starts the matching helper at login.
- Ubuntu keeps GNOME and adds i3; Kali adds KDE Plasma (`kali-desktop-kde`) next to i3. The `display-manager` step switches both to SDDM from the next boot, because it lists Wayland sessions (GNOME, Plasma) and X11 sessions (i3) together; GDM on Ubuntu 26.04 hides i3 and LightDM hides the Wayland sessions. Skip it with `--skip display-manager`. The `desktop` step applies the shared keymap to GNOME (gsettings) and KDE (kglobalshortcutsrc); directional focus keys, split keys and the polybar are i3 only.
- niri distros: Noctalia v5 themes itself from the wallpaper. wallpaperCarousel is a Noctalia plugin (it cannot run on i3), toggled with `Super+W`.
- niri: `// @BLUR@` in `configs/niri/config.kdl` is replaced by `blur.kdl` only when `niri --version` is 26.04 or newer and `niri validate` accepts it.
- Noctalia: `configs/noctalia/dotfiles.toml` is copied into `~/.config/noctalia/` and checked with `noctalia config validate`.
- Vicinae: `configs/vicinae/settings.json` is only installed if no settings file exists. Check key names with `vicinae config default`.
- Session banner: every zsh, fish and PowerShell terminal prints a one-line `─ icon host · kernel · ip · wm · shell ─` header in the ButterZsh style. `ff` still runs the full fastfetch.
- Aliases and functions: `configs/zsh/` (`aliases`, `keybinds`, `header`, `fzf`, `zoxide`, `functions/`) and `configs/fish/conf.d/` (`aliases`, `functions`, `keybinds`, `header`) mirror `configs/powershell/powershell/aliases.ps1` and `functions/`. Package helpers (`update`, `upgrade`, `uplist`, `search`, `pinstall`, `remove`) pick apt, dnf, yay or pacman.
- Git identity lives in `~/.gitconfig.local`.

## Spotify and Spicetify

Linux only, Windows gets neither. The `spotify` step installs Spotify (Spotify's apt repo on Ubuntu and Kali, the AUR on CachyOS, the Flathub user flatpak on Fedora) and Spicetify with the Sleek theme in its Catppuccin colour scheme. Spicetify can only patch Spotify after it has run once, so open Spotify, log in, then run `spicetify backup apply`. After a Spotify update, run `spicetify restore backup apply`.

