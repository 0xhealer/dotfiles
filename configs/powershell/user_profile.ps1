[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

# --- Safe module bootstrap & import for user_profile.ps1 ---

$ErrorActionPreference = 'Continue'

function Ensure-NuGetProvider {
  if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
    Write-Host "Installing NuGet package provider..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser
  }
}

function Ensure-PSGalleryTrusted {
  $repo = Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue
  if (-not $repo) {
    Register-PSRepository -Default
    $repo = Get-PSRepository -Name 'PSGallery'
  }
  if ($repo.InstallationPolicy -ne 'Trusted') {
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
  }
}

function Ensure-Module {
  param(
    [Parameter(Mandatory)]
    [string]$Name,
    [string]$MinimumVersion
  )

  # Already available?
  $available = Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending | Select-Object -First 1
  $needsInstall = -not $available -or ($MinimumVersion -and ([version]$available.Version -lt [version]$MinimumVersion))

  if ($needsInstall) {
    Ensure-NuGetProvider
    Ensure-PSGalleryTrusted
    Write-Host "Installing PowerShell module: $Name"
    $params = @{
      Name         = $Name
      Scope        = 'CurrentUser'
      Force        = $true
      AllowClobber = $true
    }
    if ($MinimumVersion) { $params['MinimumVersion'] = $MinimumVersion }
    Install-Module @params
  }

  # Import (silently succeeds if already imported)
  Import-Module $Name -ErrorAction Stop
}

try {
  Ensure-Module -Name 'posh-git'
  Ensure-Module -Name 'PSFzf'
  Ensure-Module -Name 'Terminal-Icons'

  # Optional: nicer editing experience
  if (-not (Get-Module -Name PSReadLine -ErrorAction SilentlyContinue)) {
    Import-Module PSReadLine -ErrorAction SilentlyContinue
  }

  # Initialize posh-git prompt (once imported)
  if (Get-Command 'Set-PoshPrompt' -ErrorAction SilentlyContinue) {
    # If using oh-my-posh; skip if not present
  }
  elseif (Get-Command 'Import-PoshGitScript' -ErrorAction SilentlyContinue) {
    Import-PoshGitScript
  }

  # Initialize PSFzf defaults (works cross-platform)
  if (Get-Command 'Set-PsFzfOption' -ErrorAction SilentlyContinue) {
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' | Out-Null
  }

}
catch {
  Write-Warning "Module bootstrap failed: $($_.Exception.Message)"
}


# Functions

## Package Management
function Ensure-Scoop {

  if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Scoop  not found....." -ForegroundColor Yellow
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    Write-Host "Scoop is installed.." -ForegroundColor Green
  }
}

if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
  function scoop {
    Write-Host "Scoop command not found. Intalling Scoop.." -Foregroundcolor Yellow
    Ensure-Scoop

    Remove-Item function:scoop -ErrorAction SilentlyContinue

    $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'User') + ';' + [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
  }
  $null = Get-Command scoop -ErrorAction SilentlyContinue
  if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host "Scoop is ready! Re-running your command..." -ForegroundColor Green
    & scoop @args
  }
}
if (Test-Path "$env:USERPROFILE\scoop\shims") {
  $env:PATH = "$env:USERPROFILE\scoop\shims;$env:PATH"
}



## Custom Functions
function GotoWorkspace {
  Set-Location ~/workspace; Get-ChildItem
}

## System Utilities
function admin {
  if ($args.Count -gt 0) {
    $argList = $args -join ' '
    Start-Process wt -Verb runAs -ArgumentList "pwsh.exe -NoExit -Command $argList"
  }
  else {
    Start-Process wt -Verb runAs
  }
}

# Enhanced PSReadLine Configuration
$PSReadLineOptions = @{
  EditMode                      = 'Windows'
  HistoryNoDuplicates           = $true
  HistorySearchCursorMovesToEnd = $true
  Colors                        = @{
    Command   = '#87CEEB'  # SkyBlue (pastel)
    Parameter = '#98FB98'  # PaleGreen (pastel)
    Operator  = '#FFB6C1'  # LightPink (pastel)
    Variable  = '#DDA0DD'  # Plum (pastel)
    String    = '#FFDAB9'  # PeachPuff (pastel)
    Number    = '#B0E0E6'  # PowderBlue (pastel)
    Type      = '#F0E68C'  # Khaki (pastel)
    Comment   = '#D3D3D3'  # LightGray (pastel)
    Keyword   = '#8367c7'  # Violet (pastel)
    Error     = '#FF6347'  # Tomato (keeping it close to red for visibility)
  }
  PredictionSource              = 'History'
  PredictionViewStyle           = 'ListView'
  BellStyle                     = 'None'
}
Set-PSReadLineOption @PSReadLineOptions

# Custom key handlers
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Chord 'Alt+d' -Function DeleteWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Function Redo

# Custom functions for PSReadLine
Set-PSReadLineOption -AddToHistoryHandler {
  param($line)
  $sensitive = @('password', 'secret', 'token', 'apikey', 'connectionstring')
  $hasSensitive = $sensitive | Where-Object { $line -match $_ }
  return ($null -eq $hasSensitive)
}
function Set-PredictionSource {
  # If function "Set-PredictionSource_Override" is defined in profile.ps1 file
  # then call it instead.
  if (Get-Command -Name "Set-PredictionSource_Override" -ErrorAction SilentlyContinue) {
    Set-PredictionSource_Override;
  }
  else {
    # Improved prediction settings
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -MaximumHistoryCount 10000
  }
}
Set-PredictionSource


function Clear-Cache {
  if (Get-Command -Name "Clear-Cache_Override" -ErrorAction SilentlyContinue) {
    Clear-Cache_Override
  }
  else {
    # add clear cache logic here
    Write-Host "Clearing cache..." -ForegroundColor Cyan

    # Clear Windows Prefetch
    Write-Host "Clearing Windows Prefetch..." -ForegroundColor Yellow
    Remove-Item -Path "$env:SystemRoot\Prefetch\*" -Force -ErrorAction SilentlyContinue

    # Clear Windows Temp
    Write-Host "Clearing Windows Temp..." -ForegroundColor Yellow
    Remove-Item -Path "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

    # Clear User Temp
    Write-Host "Clearing User Temp..." -ForegroundColor Yellow
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

    # Clear Internet Explorer Cache
    Write-Host "Clearing Internet Explorer Cache..." -ForegroundColor Yellow
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "Cache clearing completed." -ForegroundColor Green
  }
}

function uptime {
  try {
    # find date/time format
    $dateFormat = [System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat.ShortDatePattern
    $timeFormat = [System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat.LongTimePattern

    # check powershell version
    if ($PSVersionTable.PSVersion.Major -eq 5) {
      $lastBoot = (Get-WmiObject win32_operatingsystem).LastBootUpTime
      $bootTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($lastBoot)

      # reformat lastBoot
      $lastBoot = $bootTime.ToString("$dateFormat $timeFormat")
    }
    else {
      # the Get-Uptime cmdlet was introduced in PowerShell 6.0
      $lastBoot = (Get-Uptime -Since).ToString("$dateFormat $timeFormat")
      $bootTime = [System.DateTime]::ParseExact($lastBoot, "$dateFormat $timeFormat", [System.Globalization.CultureInfo]::InvariantCulture)
    }

    # Format the start time
    $formattedBootTime = $bootTime.ToString("dddd, MMMM dd, yyyy HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture) + " [$lastBoot]"
    Write-Host "System started on: $formattedBootTime" -ForegroundColor DarkGray

    # calculate uptime
    $uptime = (Get-Date) - $bootTime

    # Uptime in days, hours, minutes, and seconds
    $days = $uptime.Days
    $hours = $uptime.Hours
    $minutes = $uptime.Minutes
    $seconds = $uptime.Seconds

    # Uptime output
    Write-Host ("Uptime: {0} days, {1} hours, {2} minutes, {3} seconds" -f $days, $hours, $minutes, $seconds) -ForegroundColor Blue

  }
  catch {
    Write-Error "An error occurred while retrieving system uptime."
  }
}

function reload-profile {
  & $PROFILE
}

function unzip ($file) {
  Write-Output("Extracting", $file, "to", $pwd)
  $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
  Expand-Archive -Path $fullFile -DestinationPath $pwd
}

function sysinfo {
  Get-ComputerInfo
}

function touch($file) { "" | Out-File $file -Encoding ASCII }
function ff($name) {
  Get-ChildItem -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Output "$($_.FullName)"
  }
}


function Update-PowerShell {
  # If function "Update-PowerShell_Override" is defined in profile.ps1 file
  # then call it instead.
  if (Get-Command -Name "Update-PowerShell_Override" -ErrorAction SilentlyContinue) {
    Update-PowerShell_Override;
  }
  else {
    try {
      Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan
      $updateNeeded = $false
      $currentVersion = $PSVersionTable.PSVersion.ToString()
      $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
      $latestReleaseInfo = Invoke-RestMethod -Uri $gitHubApiUrl
      $latestVersion = $latestReleaseInfo.tag_name.Trim('v')
      if ($currentVersion -lt $latestVersion) {
        $updateNeeded = $true
      }

      if ($updateNeeded) {
        Write-Host "Updating PowerShell..." -ForegroundColor Yellow
        Start-Process powershell.exe -ArgumentList "-NoProfile -Command winget upgrade Microsoft.PowerShell --accept-source-agreements --accept-package-agreements" -Wait -NoNewWindow
        Write-Host "PowerShell has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
      }
      else {
        Write-Host "Your PowerShell is up to date." -ForegroundColor Green
      }
    }
    catch {
      Write-Error "Failed to update PowerShell. Error: $_"
    }
  }
}


function grep($regex, $dir) {
  if ( $dir ) {
    Get-ChildItem $dir | select-string $regex
    return
  }
  $input | select-string $regex
}

function df {
  get-volume
}

function sed($file, $find, $replace) {
  (Get-Content $file).replace("$find", $replace) | Set-Content $file
}

function which($name) {
  Get-Command $name | Select-Object -ExpandProperty Definition
}

function export($name, $value) {
  set-item -force -path "env:$name" -value $value;
}

function pkill($name) {
  Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

function pgrep($name) {
  Get-Process $name
}

function head {
  param($Path, $n = 10)
  Get-Content $Path -Head $n
}

function tail {
  param($Path, $n = 10, [switch]$f = $false)
  Get-Content $Path -Tail $n -Wait:$f
}

function trash($path) {
  $fullPath = (Resolve-Path -Path $path).Path

  if (Test-Path $fullPath) {
    $item = Get-Item $fullPath

    if ($item.PSIsContainer) {
      # Handle directory
      $parentPath = $item.Parent.FullName
    }
    else {
      # Handle file
      $parentPath = $item.DirectoryName
    }

    $shell = New-Object -ComObject 'Shell.Application'
    $shellItem = $shell.NameSpace($parentPath).ParseName($item.Name)

    if ($item) {
      $shellItem.InvokeVerb('delete')
      Write-Host "Item '$fullPath' has been moved to the Recycle Bin."
    }
    else {
      Write-Host "Error: Could not find the item '$fullPath' to trash."
    }
  }
  else {
    Write-Host "Error: Item '$fullPath' does not exist."
  }
}

# Clipboard Utilities
function cpy { Set-Clipboard $args[0] }

function pst { Get-Clipboard }

## Network Utilities
function Get-PubIP { (Invoke-WebRequest http://ifconfig.me/ip).Content }

function flushdns {
  Clear-DnsClientCache
  Write-Host "DNS has been flushed"
}

## Github & Git
function gcom {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Message
  )
  git add .
  git commit -m ($Message -join ' ')
}


function gs { git status }
function gaa { git add . }
function gc {
  param($Message)
  git commit -m "$Message"
}
function gpush { git push }
function gpull { git pull }

function lazyg {
  git add .
  git commit -m "$args"
  git push origin main
}

function ghcreate {
  param (
    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [Parameter(Mandatory = $true)]
    [ValidateSet("public", "private")]
    [string]$Visibility,

    [string]$Username = "0xhealer"  # Default to '0xhealer' if not provided
  )
  # Check if GitHub CLI is authenticated
  if (-not (gh auth status)) {
    Write-Host "Run 'gh auth login' to configure GitHub CLI"
  }

  if ($PSCmdlet.MyInvocation.BoundParameters.Count -lt 2) {
    Write-Host "Usage: ghcreate <repository> <visibility> [<username>]"
    return 1
  }

  try {
    # Create the repository on GitHub
    gh repo create $Repository --$Visibility

    # Clone the repository
    gh repo clone "$Username/$Repository"; Set-Location $Repository

  }
  catch {
    Write-Host "Error: $($_.Exception.Message)"
  }

}


function ghclone {
  param(
    [Parameter(Mandatory = $true, Position = 1)]
    [string]$Repository,

    [Parameter(Position = 0)]
    [string]$Username = "0xhealer" # Default to 0xhealer if not provided
  )
  if (-not (gh auth status)) {
    Write-Host "Run 'gh auth login' to configure Github CLI"
  }
  if ($PSCmdlet.MyInvocation.BoundParameters.Count -lt 1) {
    Write-Host "Usage: ghclone  <username>/<repository>"
    return 1
  }

  try {
    if (Test-Path -Path $Repository) {
      Set-Location $Repository
    }
    else {
      gh repo clone "$Username/$Repository"; Set-Location $Repository
    }
  }
  catch {
    Write-Host "Error: $($_.Exception.Message)"
  }
}

function Update-Dotfiles {
  [CmdletBinding()]
  param(
    [string]$Repo = "$HOME\workspace\dotfiles",
    [switch]$SkipPackages,
    [switch]$SkipFonts,
    [switch]$SkipConfigs,
    [switch]$SkipWallpaper
  )

  $ErrorActionPreference = 'Continue'

  $install = Join-Path $Repo 'install.ps1'
  if (-not (Test-Path $install)) {
    Write-Error "install.ps1 not found at: $install"
    return
  }

  Push-Location $Repo
  try {
    # Ensure this session can run scripts (README already tells users to do this, but safe here too)
    try { Set-ExecutionPolicy Bypass -Scope Process -Force } catch {}

    & $install `
      -Update `
      -SkipPackages:$SkipPackages `
      -SkipFonts:$SkipFonts `
      -SkipConfigs:$SkipConfigs `
      -SkipWallpaper:$SkipWallpaper
  }
  finally {
    Pop-Location
  }
}

## Directory Listing
function ll { Get-ChildItem -Force | Format-Table -AutoSize }
function la { Get-ChildItem | Format-Table -AutoSize }
function mcd { param($dir) mkdir $dir -Force; Set-Location $dir }

function docs {
  $docs = if (([Environment]::GetFolderPath("MyDocuments"))) { ([Environment]::GetFolderPath("MyDocuments")) } else { $HOME + "\Documents" }
  Set-Location -Path $docs
}

function dtop {
  $dtop = if ([Environment]::GetFolderPath("Desktop")) { [Environment]::GetFolderPath("Desktop") } else { $HOME + "\Documents" }
  Set-Location -Path $dtop
}

function dload {
  $dtop = if ([Environment]::GetFolderPath("Downloads")) { [Environment]::GetFolderPath("Downloads") } else { $HOME + "\Documents" }
  Set-Location -Path $dtop
}

# Admin Check and Prompt Customization
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
function prompt {
  if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()


function k9 { Stop-Process -Name $args[0] }


## Zoxide
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
  Invoke-Expression (& { (zoxide init --cmd z powershell | Out-String) })
}
else {
  Write-Host "zoxide not found. Attempting installation..."

  # Check for winget
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Using winget to install zoxide..."
    winget install -e --id ajeetdsouza.zoxide
  }
  else {
    Write-Host "winget not available."

    # Check for choco
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
      Write-Host "Chocolatey not found. Installing Chocolatey first..."
      Set-ExecutionPolicy Bypass -Scope Process -Force
      [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
      Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }

    Write-Host "Installing zoxide using Chocolatey..."
    choco install zoxide -y
  }

  if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Write-Host "zoxide installed successfully. Initializing..."
    Invoke-Expression (& { (zoxide init --cmd z powershell | Out-String) })
  }
  else {
    Write-Error "Installation failed."
  }
}


$scriptblock = {
  param($wordToComplete, $commandAst, $cursorPosition)
  $customCompletions = @{
    'git' = @('status', 'add', 'commit', 'push', 'pull', 'clone', 'checkout')
    'npm' = @('install', 'start', 'run', 'test', 'build')
    # 'deno' = @('run', 'compile', 'bundle', 'test', 'lint', 'fmt', 'cache', 'info', 'doc', 'upgrade')
  }

  $command = $commandAst.CommandElements[0].Value
  if ($customCompletions.ContainsKey($command)) {
    $customCompletions[$command] | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
      [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
  }
}
Register-ArgumentCompleter -Native -CommandName git, npm, deno -ScriptBlock $scriptblock

$scriptblock = {
  param($wordToComplete, $commandAst, $cursorPosition)
  dotnet complete --position $cursorPosition $commandAst.ToString() |
  ForEach-Object {
    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
  }
}
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $scriptblock

if (Get-Command -Name "Get-Theme_Override" -ErrorAction SilentlyContinue) {
  Get-Theme_Override;
}
else {
  oh-my-posh init pwsh --config https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/robbyrussell.omp.json | Invoke-Expression
}

function Edit-Profile {
  # Ensure the profile file exists
  if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
  }

  # Detect editor in order of preference: neovim → VS Code → notepad
  if (Get-Command nvim -ErrorAction SilentlyContinue) {
    $editor = "nvim"
    # For neovim in a new console window (optional):
    # Start-Process nvim -ArgumentList $PROFILE; return
  }
  elseif (Get-Command code -ErrorAction SilentlyContinue) {
    $editor = "code"
    # Open in existing window:
    # $editorArgs = "-r"
    # But default is fine for most setups
  }
  else {
    $editor = "notepad.exe"
  }

  & $editor $PROFILE
}


# Aliases
Set-Alias -Name vim -Value nvim
Set-Alias -Name cat -Value bat
Set-Alias -Name su -Value admin
Set-Alias -Name workspace -Value GotoWorkspace

# Get-Help Commands
function Show-Help {
  $helpText = @"
$($PSStyle.Foreground.Cyan)PowerShell Profile Help$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)---------------------------------------$($PSStyle.Reset)
# $($PSStyle.Foreground.Green)Update-Profile$($PSStyle.Reset) - Checks for profile updates from a remote repository and updates if necessary.
$($PSStyle.Foreground.Green)Update-PowerShell$($PSStyle.Reset) - Checks for the latest PowerShell release and updates if a new version is available.
$($PSStyle.Foreground.Green)Edit-Profile$($PSStyle.Reset) - Opens the current user's profile for editing using the configured editor.

$($PSStyle.Foreground.Cyan)Git Shortcuts$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)---------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)g$($PSStyle.Reset) - Changes to the GitHub directory.
$($PSStyle.Foreground.Green)ga$($PSStyle.Reset) - Shortcut for 'git add .'.
$($PSStyle.Foreground.Green)gc$($PSStyle.Reset) <message> - Shortcut for 'git commit -m'.
$($PSStyle.Foreground.Green)gcom$($PSStyle.Reset) <message> - Adds all changes and commits with the specified message.
$($PSStyle.Foreground.Green)gp$($PSStyle.Reset) - Shortcut for 'git push'.
$($PSStyle.Foreground.Green)gs$($PSStyle.Reset) - Shortcut for 'git status'.
$($PSStyle.Foreground.Green)lazyg$($PSStyle.Reset) <message> - Adds all changes, commits with the specified message, and pushes to the remote repository.
$($PSStyle.Foreground.Green)ghclone$($PSStyle.Reset) <message> - clone a repository using github cli.
$($PSStyle.Foreground.Green)ghcreate$($PSStyle.Reset) <message> - create a repository using github cli.

$($PSStyle.Foreground.Cyan)Shortcuts$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)---------------------------------------$($PSStyle.Reset)
$($PSStyle.Foreground.Green)cpy$($PSStyle.Reset) <text> - Copies the specified text to the clipboard.
$($PSStyle.Foreground.Green)df$($PSStyle.Reset) - Displays information about volumes.
$($PSStyle.Foreground.Green)docs$($PSStyle.Reset) - Changes the current directory to the user's Documents folder.
$($PSStyle.Foreground.Green)dtop$($PSStyle.Reset) - Changes the current directory to the user's Desktop folder.
$($PSStyle.Foreground.Green)ep$($PSStyle.Reset) - Opens the profile for editing.
$($PSStyle.Foreground.Green)export$($PSStyle.Reset) <name> <value> - Sets an environment variable.
$($PSStyle.Foreground.Green)ff$($PSStyle.Reset) <name> - Finds files recursively with the specified name.
$($PSStyle.Foreground.Green)flushdns$($PSStyle.Reset) - Clears the DNS cache.
$($PSStyle.Foreground.Green)Get-PubIP$($PSStyle.Reset) - Retrieves the public IP address of the machine.
$($PSStyle.Foreground.Green)grep$($PSStyle.Reset) <regex> [dir] - Searches for a regex pattern in files within the specified directory or from the pipeline input.
$($PSStyle.Foreground.Green)hb$($PSStyle.Reset) <file> - Uploads the specified file's content to a hastebin-like service and returns the URL.
$($PSStyle.Foreground.Green)head$($PSStyle.Reset) <path> [n] - Displays the first n lines of a file (default 10).
$($PSStyle.Foreground.Green)k9$($PSStyle.Reset) <name> - Kills a process by name.
$($PSStyle.Foreground.Green)la$($PSStyle.Reset) - Lists all files in the current directory with detailed formatting.
$($PSStyle.Foreground.Green)ll$($PSStyle.Reset) - Lists all files, including hidden, in the current directory with detailed formatting.
$($PSStyle.Foreground.Green)mkcd$($PSStyle.Reset) <dir> - Creates and changes to a new directory.
$($PSStyle.Foreground.Green)nf$($PSStyle.Reset) <name> - Creates a new file with the specified name.
$($PSStyle.Foreground.Green)pgrep$($PSStyle.Reset) <name> - Lists processes by name.
$($PSStyle.Foreground.Green)pkill$($PSStyle.Reset) <name> - Kills processes by name.
$($PSStyle.Foreground.Green)gs$($PSStyle.Reset) - Shortcut for 'git status'.
$($PSStyle.Foreground.Green)ga$($PSStyle.Reset) - Shortcut for 'git add .'.
$($PSStyle.Foreground.Green)gc$($PSStyle.Reset) <message> - Shortcut for 'git commit -m'.
$($PSStyle.Foreground.Green)gpush$($PSStyle.Reset) - Shortcut for 'git push'.
$($PSStyle.Foreground.Green)gpull$($PSStyle.Reset) - Shortcut for 'git pull'.
$($PSStyle.Foreground.Green)g$($PSStyle.Reset) - Changes to the GitHub directory.
$($PSStyle.Foreground.Green)gcom$($PSStyle.Reset) <message> - Adds all changes and commits with the specified message.
$($PSStyle.Foreground.Green)lazyg$($PSStyle.Reset) <message> - Adds all changes, commits with the specified message, and pushes to the remote repository.
$($PSStyle.Foreground.Green)sysinfo$($PSStyle.Reset) - Displays detailed system information.
$($PSStyle.Foreground.Green)flushdns$($PSStyle.Reset) - Clears the DNS cache.
$($PSStyle.Foreground.Green)cpy$($PSStyle.Reset) <text> - Copies the specified text to the clipboard.
$($PSStyle.Foreground.Green)pst$($PSStyle.Reset) - Retrieves text from the clipboard.
$($PSStyle.Foreground.Green)reload-profile$($PSStyle.Reset) - Reloads the current user's PowerShell profile.
$($PSStyle.Foreground.Green)sed$($PSStyle.Reset) <file> <find> <replace> - Replaces text in a file.
$($PSStyle.Foreground.Green)sysinfo$($PSStyle.Reset) - Displays detailed system information.
$($PSStyle.Foreground.Green)tail$($PSStyle.Reset) <path> [n] - Displays the last n lines of a file (default 10).
$($PSStyle.Foreground.Green)touch$($PSStyle.Reset) <file> - Creates a new empty file.
$($PSStyle.Foreground.Green)unzip$($PSStyle.Reset) <file> - Extracts a zip file to the current directory.
$($PSStyle.Foreground.Green)uptime$($PSStyle.Reset) - Displays the system uptime.
$($PSStyle.Foreground.Green)which$($PSStyle.Reset) <name> - Shows the path of the command.
$($PSStyle.Foreground.Green)Update-Dotfiles$($PSStyle.Reset) - Pull the latest data from Github to my Personal Dotfiles under ~/workspace/dotfiles.
$($PSStyle.Foreground.Yellow)---------------------------------------$($PSStyle.Reset)

Use '$($PSStyle.Foreground.Magenta)Show-Help$($PSStyle.Reset)' to display this help message.
"@
  Write-Host $helpText
}

$PSStyle.FileInfo.Directory = "`e[38;2;255;255;255m"

# Fastfetch
# Fastfetch init block
if (-not (Get-Command fastfetch -ErrorAction SilentlyContinue)) {
  Write-Host "fastfetch not found. Attempting installation..."

  $installed = $false

  # Try winget first
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install -e --id fastfetch-cli.fastfetch --source winget -h 2>$null
    if (Get-Command fastfetch -ErrorAction SilentlyContinue) { $installed = $true }
  }

  # Fallback to Chocolatey
  if (-not $installed) {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
      Write-Host "Chocolatey not found. Installing Chocolatey..."
      Set-ExecutionPolicy Bypass -Scope Process -Force
      [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
      iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }

    choco install fastfetch -y 2>$null
    if (Get-Command fastfetch -ErrorAction SilentlyContinue) { $installed = $true }
  }

  # Final fallback to scoop (if user has scoop)
  if (-not $installed -and (Get-Command scoop -ErrorAction SilentlyContinue)) {
    scoop install fastfetch 2>$null
  }
}

# Now display fastfetch output if available
if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
  fastfetch -c "$env:USERPROFILE/.config/fastfetch/config.jsonc"
}