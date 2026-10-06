$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'helper') 'helper.ps1')

Write-Step 'Debloat (apps, OneDrive, Edge, Copilot, Recall, ads, telemetry)'

if (-not (Test-IsWindowsHost)) { Write-Info 'not Windows, skipping'; return }

# Kept on purpose: Teams, Photos, Store, App Installer (winget), Terminal, Notepad, Paint, Calculator,
# Snipping Tool, Clock, WhatsApp. Edge WebView2 is never touched, other apps depend on it.

function Set-Reg {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    if (Test-DryRun) { Write-Host "    [dry-run] reg $Path\$Name = $Value"; return }
    try {
        if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
        New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
    } catch {
        Write-Warn "registry write failed: $Path\$Name ($($_.Exception.Message))"
    }
}

# ---------------------------------------------------------------- 1. Store apps
Write-Info 'removing preinstalled apps'

if ($PSVersionTable.PSEdition -eq 'Core') {
    foreach ($m in 'Appx', 'Dism') { Import-Module $m -UseWindowsPowerShell -WarningAction SilentlyContinue -ErrorAction SilentlyContinue }
}

# wildcard patterns; anything not matching one of these is left alone
$bloat = @(
    '*Copilot*', 'Microsoft.Windows.Ai.Copilot*', 'MicrosoftWindows.Client.AIX', 'MicrosoftWindows.Client.CoPilot', 'Microsoft.OneDriveSync', '*Recall*', 'Microsoft.MicrosoftOfficeHub*',
    'Microsoft.549981C3F5F10',                 # Cortana
    'Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.BingSearch', 'Microsoft.BingFinance', 'Microsoft.BingSports',
    'Clipchamp.Clipchamp', 'Microsoft.Todos', 'Microsoft.GetHelp', 'Microsoft.Getstarted', 'Microsoft.WindowsFeedbackHub',
    'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.MicrosoftStickyNotes', 'Microsoft.People', 'Microsoft.SkypeApp',
    'Microsoft.WindowsMaps', 'Microsoft.WindowsSoundRecorder', 'microsoft.windowscommunicationsapps',
    'Microsoft.OutlookForWindows', 'Microsoft.YourPhone', 'MicrosoftWindows.CrossDevice', 'Microsoft.Windows.DevHome',
    'Microsoft.PowerAutomateDesktop', 'Microsoft.Whiteboard', 'Microsoft.MicrosoftJournal', 'Microsoft.ZuneMusic',
    'Microsoft.ZuneVideo', 'Microsoft.MixedReality.Portal', 'Microsoft.Microsoft3DViewer', 'Microsoft.Print3D',
    'Microsoft.3DBuilder', 'Microsoft.OneConnect', 'Microsoft.Wallet', 'Microsoft.Office.OneNote', 'Microsoft.Office.Desktop*',
    'Microsoft.MicrosoftFamily*', 'MicrosoftCorporationII.MicrosoftFamily', 'MicrosoftCorporationII.QuickAssist',
    'Microsoft.Edge.GameAssist', 'MicrosoftWindows.Client.WebExperience',   # Widgets
    'Microsoft.Xbox*', 'Microsoft.GamingApp', 'Microsoft.XboxGamingOverlay', 'Microsoft.XboxGameOverlay',
    'Microsoft.XboxIdentityProvider', 'Microsoft.XboxSpeechToTextOverlay',
    'Microsoft.LinkedIn', '*LinkedInforWindows*', '*SpotifyAB*', '*Disney*', '*Netflix*', '*TikTok*', '*Instagram*',
    '*Facebook*', '*Twitter*', '*AmazonPrime*', '*PrimeVideo*', '*CandyCrush*', '*Duolingo*', '*Roblox*', '*HiddenCity*',
    '*MarchofEmpires*', '*FarmVille*', '*BubbleWitch*', '*McAfee*', '*Norton*', '*ExpressVPN*', '*Dolby*'
)

function Test-Bloat {
    param([string]$Name)
    foreach ($p in $bloat) { if ($Name -like $p) { return $true } }
    return $false
}

$removed = 0
if (Test-DryRun) {
    Write-Host '    [dry-run] Remove-AppxPackage / Remove-AppxProvisionedPackage for the bloat list'
} else {
    $installed = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { Test-Bloat $_.Name })
    $deprov = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned'
    $inbox = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\InboxApplications'
    foreach ($pkg in $installed) {
        # mark deprovisioned first so updates and new accounts never bring it back, and so "non-removable" in-box apps can go
        Set-Reg "$deprov\$($pkg.PackageFamilyName)" 'Purged' 1
        if ($pkg.NonRemovable) {
            Get-ChildItem -Path $inbox -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like "$($pkg.Name)_*" } |
                ForEach-Object { Remove-Item -LiteralPath $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue }
        }
        try {
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
            Write-Ok "removed $($pkg.Name)"
            $removed++
            Remove-Item -LiteralPath (Join-Path $env:LOCALAPPDATA "Packages\$($pkg.PackageFamilyName)") -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                Write-Ok "removed $($pkg.Name) (current user)"
                $removed++
            } catch {
                Write-Warn "could not remove $($pkg.Name): $($_.Exception.Message.Split("`n")[0])"
            }
        }
    }
    # provisioned copies, so new accounts do not get them back
    foreach ($prov in @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { Test-Bloat $_.DisplayName })) {
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction Stop | Out-Null
            Write-Ok "deprovisioned $($prov.DisplayName)"
        } catch {
            Write-Warn "could not deprovision $($prov.DisplayName)"
        }
    }
    if ($removed -eq 0) { Write-Info 'no removable preinstalled apps left' }
}

# ---------------------------------------------------------------- 2. Copilot, Recall, AI
Write-Info 'disabling Copilot, Recall and AI features'
$wpol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows'
$upol = 'HKCU:\Software\Policies\Microsoft\Windows'
Set-Reg "$wpol\WindowsCopilot" 'TurnOffWindowsCopilot' 1
Set-Reg "$upol\WindowsCopilot" 'TurnOffWindowsCopilot' 1
Set-Reg "$wpol\WindowsAI" 'DisableAIDataAnalysis' 1          # Recall snapshots
Set-Reg "$upol\WindowsAI" 'DisableAIDataAnalysis' 1
Set-Reg "$wpol\WindowsAI" 'AllowRecallEnablement' 0
Set-Reg "$wpol\WindowsAI" 'DisableClickToDo' 1
Set-Reg "$upol\WindowsAI" 'DisableClickToDo' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\WindowsNotepad' 'DisableAIFeatures' 1
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' 0
Set-Reg "$wpol\Windows Search" 'AllowCortana' 0

if (-not (Test-DryRun)) {
    try {
        $recall = Get-WindowsOptionalFeature -Online -FeatureName Recall -ErrorAction Stop
        if ($recall.State -ne 'Disabled') {
            Disable-WindowsOptionalFeature -Online -FeatureName Recall -Remove -NoRestart -ErrorAction Stop | Out-Null
            Write-Ok 'Recall feature disabled'
        } else { Write-Info 'Recall already disabled' }
    } catch { Write-Info 'Recall feature not present on this build' }
}

# ---------------------------------------------------------------- 3. OneDrive
Write-Info 'removing OneDrive'
Set-Reg "$wpol\OneDrive" 'DisableFileSyncNGSC' 1
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSyncProviderNotifications' 0
Set-Reg 'HKCU:\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' 'System.IsPinnedToNameSpaceTree' 0
if (-not (Test-DryRun)) {
    Get-Process OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    # point Desktop/Documents/Pictures back at the local profile, copying (never deleting) anything that lives in OneDrive
    $usf = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
    $known = @(
        @{ Name = 'Desktop';     Value = 'Desktop';   Local = 'Desktop' },
        @{ Name = 'Personal';    Value = 'Personal';  Local = 'Documents' },
        @{ Name = 'My Pictures'; Value = 'My Pictures'; Local = 'Pictures' }
    )
    foreach ($k in $known) {
        $cur = (Get-ItemProperty -Path $usf -Name $k.Value -ErrorAction SilentlyContinue).($k.Value)
        if (-not $cur) { continue }
        $curExp = [Environment]::ExpandEnvironmentVariables($cur)
        if ($curExp -notlike '*OneDrive*') { continue }
        $dest = Join-Path $env:USERPROFILE $k.Local
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        if (Test-Path -LiteralPath $curExp) {
            $null = Invoke-Native { & robocopy $curExp $dest /E /XO /R:1 /W:1 /NFL /NDL /NJH /NJS /NP }
        }
        Set-ItemProperty -Path $usf -Name $k.Value -Value ('%USERPROFILE%\' + $k.Local) -Type ExpandString
        Write-Ok "$($k.Local) moved back to $dest"
    }

    $setup = @("$env:SystemRoot\SysWOW64\OneDriveSetup.exe", "$env:SystemRoot\System32\OneDriveSetup.exe") |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($setup) {
        $null = Start-Process -FilePath $setup -ArgumentList '/uninstall' -Wait -PassThru -WindowStyle Hidden
    }
    $null = Invoke-Native { & winget uninstall --id Microsoft.OneDrive --silent --disable-interactivity --accept-source-agreements }
    foreach ($d in @("$env:LOCALAPPDATA\Microsoft\OneDrive", "$env:ProgramData\Microsoft OneDrive", "$env:ProgramFiles\Microsoft OneDrive", "${env:ProgramFiles(x86)}\Microsoft OneDrive")) {
        if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }
    }
    $odUser = Join-Path $env:USERPROFILE 'OneDrive'
    if (Test-Path -LiteralPath $odUser) {
        if (Get-ChildItem -LiteralPath $odUser -Force -ErrorAction SilentlyContinue | Select-Object -First 1) {
            Write-Warn "left $odUser in place, delete it yourself once you have checked it (its files were copied out)"
        } else {
            Remove-Item -LiteralPath $odUser -Force -ErrorAction SilentlyContinue
        }
    }
    Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'OneDrive' -ErrorAction SilentlyContinue
    Get-ScheduledTask -TaskName 'OneDrive*' -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
    $still = (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") -or (Test-Path "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe")
    if ($still) { Write-Warn 'OneDrive files still present after uninstall, re-run after a reboot' } else { Write-Ok 'OneDrive removed' }
}

# ---------------------------------------------------------------- 4. Edge
Write-Info 'removing Microsoft Edge'
# stop it coming back through Windows Update / Edge Update
$eu = 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate'
Set-Reg $eu 'InstallDefault' 0
Set-Reg $eu 'Install{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}' 0
Set-Reg $eu 'UpdateDefault' 0
Set-Reg 'HKLM:\SOFTWARE\Microsoft\EdgeUpdate' 'DoNotUpdateToEdgeWithChromium' 1
Set-Reg 'HKLM:\SOFTWARE\Microsoft\EdgeUpdateDev' 'AllowUninstall' 1
# nag-free in case it survives
$ep = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
Set-Reg $ep 'HubsSidebarEnabled' 0
Set-Reg $ep 'CopilotPageContext' 0
Set-Reg $ep 'EdgeEntraCopilotPageContext' 0
Set-Reg $ep 'StartupBoostEnabled' 0
Set-Reg $ep 'BackgroundModeEnabled' 0
Set-Reg $ep 'HideFirstRunExperience' 1

$edgeRoot = Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application'
$brave = @(
    (Join-Path $env:ProgramFiles 'BraveSoftware\Brave-Browser\Application\brave.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'BraveSoftware\Brave-Browser\Application\brave.exe'),
    (Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\Application\brave.exe')
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (Test-DryRun) {
    Write-Host '    [dry-run] uninstall Edge via its setup.exe (only if Brave is installed)'
} elseif (-not (Test-Path -LiteralPath $edgeRoot)) {
    Write-Info 'Edge not installed'
} elseif (-not $brave) {
    Write-Warn 'Brave is not installed yet, keeping Edge so the machine is not left without a browser'
} else {
    $edgeSetup = Get-ChildItem -Path $edgeRoot -Recurse -Filter setup.exe -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -like '*\Installer\setup.exe' } | Sort-Object FullName -Descending | Select-Object -First 1
    if (-not $edgeSetup) {
        Write-Warn 'Edge setup.exe not found, cannot uninstall'
    } else {
        Get-Process msedge, MicrosoftEdgeUpdate -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        $p = Start-Process -FilePath $edgeSetup.FullName -Wait -PassThru -WindowStyle Hidden `
            -ArgumentList '--uninstall', '--system-level', '--verbose-logging', '--force-uninstall'
        $stillThere = Get-ChildItem -Path $edgeRoot -Filter msedge.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $stillThere) {
            Write-Ok 'Edge uninstalled'
            Get-ScheduledTask -TaskName 'MicrosoftEdgeUpdate*' -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
            foreach ($lnk in @("$env:PUBLIC\Desktop\Microsoft Edge.lnk", "$env:USERPROFILE\Desktop\Microsoft Edge.lnk")) {
                Remove-Item -LiteralPath $lnk -Force -ErrorAction SilentlyContinue
            }
        } else {
            Write-Warn "Edge uninstall did not remove it (exit $($p.ExitCode)), policies are set so it stays quiet"
        }
    }
}

# ---------------------------------------------------------------- 5. Widgets, ads, suggestions, telemetry
Write-Info 'disabling widgets, ads, suggestions and telemetry'
$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-Reg $adv 'TaskbarDa' 0                    # widgets button
Set-Reg $adv 'TaskbarMn' 0                    # chat button
Set-Reg $adv 'Start_IrisRecommendations' 0
Set-Reg $adv 'Start_AccountNotifications' 0
Set-Reg $adv 'Start_TrackDocs' 0
Set-Reg $adv 'ShowSyncProviderNotifications' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0
Set-Reg "$wpol\Windows Feeds" 'EnableFeeds' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'HideRecommendedSection' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\PolicyManager\current\device\Start' 'HideRecommendedSection' 1
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
Set-Reg "$wpol\CloudContent" 'DisableWindowsConsumerFeatures' 1
Set-Reg "$wpol\CloudContent" 'DisableSoftLanding' 1
Set-Reg "$wpol\CloudContent" 'DisableCloudOptimizedContent' 1
Set-Reg "$wpol\System" 'EnableActivityFeed' 0
Set-Reg "$wpol\System" 'PublishUserActivities' 0
Set-Reg "$wpol\DataCollection" 'AllowTelemetry' 0
Set-Reg "$wpol\DataCollection" 'DoNotShowFeedbackNotifications' 1
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0

$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
foreach ($n in 'ContentDeliveryAllowed', 'FeatureManagementEnabled', 'OemPreInstalledAppsEnabled', 'PreInstalledAppsEnabled',
    'PreInstalledAppsEverEnabled', 'RotatingLockScreenOverlayEnabled', 'SilentInstalledAppsEnabled', 'SoftLandingEnabled',
    'SystemPaneSuggestionsEnabled', 'SubscribedContentEnabled', 'SubscribedContent-310093Enabled', 'SubscribedContent-338387Enabled',
    'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled', 'SubscribedContent-338393Enabled',
    'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled', 'SubscribedContent-353698Enabled',
    'SubscribedContent-88000326Enabled') {
    Set-Reg $cdm $n 0
}

if (-not (Test-DryRun)) {
    foreach ($svc in 'DiagTrack', 'dmwappushservice') {
        try {
            if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svc -StartupType Disabled -ErrorAction Stop
            }
        } catch { Write-Warn "could not disable service $svc" }
    }
    # restart Explorer so taskbar changes apply now
    Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------- 6. Purge leftovers
Write-Info 'purging leftovers, tasks and services'
if (-not (Test-DryRun)) {
    # Edge program files and profile (EdgeUpdate and WebView2 stay: other apps need them)
    if (-not (Get-ChildItem -Path $edgeRoot -Filter msedge.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1)) {
        foreach ($d in @((Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge'), "$env:LOCALAPPDATA\Microsoft\Edge")) {
            if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
    # telemetry, Recall and Xbox scheduled tasks
    $taskLike = @('\Microsoft\Windows\Application Experience\*', '\Microsoft\Windows\Customer Experience Improvement Program\*',
        '\Microsoft\Windows\Feedback\*', '\Microsoft\Windows\WindowsAI\*', '\Microsoft\XblGameSave\*',
        '\Microsoft\Windows\Windows Error Reporting\*')
    foreach ($t in @(Get-ScheduledTask -ErrorAction SilentlyContinue)) {
        $full = $t.TaskPath + $t.TaskName
        foreach ($pat in $taskLike) {
            if ($full -like $pat) { Disable-ScheduledTask -InputObject $t -ErrorAction SilentlyContinue | Out-Null; break }
        }
    }
    # services nobody asked for
    foreach ($svc in 'XblAuthManager', 'XblGameSave', 'XboxGipSvc', 'XboxNetApiSvc', 'RetailDemo', 'WerSvc', 'diagnosticshub.standardcollector.service') {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
        }
    }
    Write-Ok 'leftovers purged'
}

Write-Ok 'debloat done, sign out or reboot to finish'
