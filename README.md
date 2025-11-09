<h1 align="center">Dotfiles</h1>
<p align="center">Cross-platform configuration and setup for Windows and Linux environments.</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Windows%20%7C%20Linux-blue" />
  <img src="https://img.shields.io/badge/Shell-PowerShell%20%7C%20Bash-yellow" />
  <img src="https://img.shields.io/badge/License-MIT-green" />
</p>

---

## Overview

This repository provides a consistent development environment setup for both Windows and Linux systems.
It installs and configures commonly used tools, utilities, and preferences to maintain a unified workflow across platforms.

---

## Requirements

- **Git**
- **PowerShell** (Windows)
- **Bash** (Linux)

---

## Installation
### Windows
#### Option 1 : Clone and Run

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser
git clone https://github.com/0xhealer/dotfiles.git
cd dotfiles
. .\install.ps1
```
#### Option 2 : Manual Download

1. Download the repository as a ZIP.
2. Extract to your preferred directory.
3. Open PowerShell in that directory.
4. Run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser
.\install.ps1
```

### Linux

```bash
git clone https://github.com/0xhealer/dotfiles.git
cd dotfiles
chmod +x install.sh
./install.sh
```

## Post-Installation
- Restart your terminal to apply profile changes.
- Modify editor and shell configuration files as desired.

**Note: These configurations reflect personal preferences and may require adjustments based on your workflow**
