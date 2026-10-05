@echo off
rem Launcher: strips the downloaded-from-internet tag and runs install.ps1 with the policy bypassed.
powershell -NoProfile -Command "Get-ChildItem -LiteralPath '%~dp0' -Recurse -File | Unblock-File"
where pwsh >nul 2>nul && (set "PS=pwsh") || (set "PS=powershell")
%PS% -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
