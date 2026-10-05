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

## Quick install

One command, no clone needed. It fetches this repo into `~/dotfiles` (using `git`, or a tarball/zip when git is missing) and runs the installer.

Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/0xhealer/dotfiles/main/bootstrap.sh | bash
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/0xhealer/dotfiles/main/bootstrap.ps1 | iex
```

Pass installer options after `-s --` on Linux (`... | bash -s -- --dry-run shell starship`) or by running the script as a block on Windows (`& ([scriptblock]::Create((irm https://raw.githubusercontent.com/0xhealer/dotfiles/main/bootstrap.ps1))) -DryRun`). Set `DOTS_DIR` to install somewhere other than `~/dotfiles`.

## Layout

```
bootstrap.sh / .ps1        one-command installers
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
