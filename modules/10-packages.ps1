$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'helper') 'helper.ps1')

Write-Step 'Packages (winget)'

$ids = @(Get-PackageList -Path (Get-RepoPath 'packages/windows.txt'))
$failed = @()
foreach ($id in $ids) {
    if (-not (Install-WingetPackage -Id $id)) { $failed += $id }
}
Update-SessionPath

$pwshPath = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
if (-not (Test-DryRun) -and -not (Test-Path -LiteralPath $pwshPath)) {
    Write-Warn 'PowerShell 7 is still missing, installing the MSI directly'
    try {
        Install-PowerShell7Msi
        Update-SessionPath
        if (Test-Path -LiteralPath $pwshPath) { Write-Ok 'installed PowerShell 7' } else { Write-Warn 'PowerShell 7 MSI ran but pwsh.exe was not found' }
    } catch {
        Write-Warn "could not install PowerShell 7: $($_.Exception.Message)"
    }
}

# winget's Docker.DockerDesktop often fails (stale installer hash). Fall back to Docker's own signed installer.
$dockerExe = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
if (($ids -contains 'Docker.DockerDesktop') -and -not (Test-DryRun) -and -not (Test-Path -LiteralPath $dockerExe)) {
    Write-Warn "winget did not install Docker Desktop, using Docker's official installer"
    $installer = Join-Path $env:TEMP 'DockerDesktopInstaller.exe'
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
        Invoke-WebRequest -UseBasicParsing -Uri "https://desktop.docker.com/win/main/$arch/Docker%20Desktop%20Installer.exe" -OutFile $installer
        $sig = Get-AuthenticodeSignature -FilePath $installer
        if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'Docker') {
            throw "signature check failed ($($sig.Status))"
        }
        $p = Start-Process -FilePath $installer -ArgumentList 'install', '--quiet', '--accept-license', '--backend=wsl-2' -Wait -PassThru
        if ($p.ExitCode -in 0, 3010) {
            Write-Ok 'installed Docker Desktop, reboot before first start'
            $failed = @($failed | Where-Object { $_ -ne 'Docker.DockerDesktop' })
        } else {
            Write-Warn "Docker installer exited with $($p.ExitCode)"
        }
    } catch {
        Write-Warn "Docker Desktop fallback failed: $($_.Exception.Message)"
    } finally {
        Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
    }
}

if ($failed.Count -gt 0) {
    Write-Warn ("packages that failed: " + ($failed -join ', '))
} else {
    Write-Ok "$($ids.Count) packages present"
}
