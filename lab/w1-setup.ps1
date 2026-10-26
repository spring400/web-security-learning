#Requires -Version 5.1
<#
.SYNOPSIS
    W1 environment setup: WSL2 + Git + Docker Desktop (Windows 11).

.DESCRIPTION
    Run this script in an ELEVATED PowerShell:
        powershell -ExecutionPolicy Bypass -File .\lab\w1-setup.ps1

    It performs, in order:
      1. Admin check + virtualization check
      2. Enable/install WSL2 (no distro yet)
      3. Install Git for Windows (winget)
      4. Install Docker Desktop (winget)
      5. Write %USERPROFILE%\.wslconfig memory cap (only if RAM >= 8GB)

    It does NOT reboot, and does NOT install the Ubuntu distro (that is done
    after the reboot, see the printed next steps).

.PARAMETER SkipDocker
    Skip Docker Desktop installation.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\lab\w1-setup.ps1
#>
[CmdletBinding()]
param(
    [switch]$SkipDocker
)

$ErrorActionPreference = 'Stop'

function Write-Section { param([string]$Text) Write-Host "`n=== $Text ===" -ForegroundColor Cyan }
function Write-Ok      { param([string]$Text) Write-Host "  [OK]   $Text" -ForegroundColor Green }
function Write-Bad     { param([string]$Text) Write-Host "  [FAIL] $Text" -ForegroundColor Red }
function Write-Warn2   { param([string]$Text) Write-Host "  [WARN] $Text" -ForegroundColor Yellow }
function Write-Step    { param([string]$Text) Write-Host "  [..]   $Text" -ForegroundColor DarkGray }

# ---------------------------------------------------------------- 0. admin
Write-Section '0. Privileges'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Bad 'Not running as Administrator. Right-click Start -> Terminal (Admin), then rerun:'
    Write-Host '  powershell -ExecutionPolicy Bypass -File .\lab\w1-setup.ps1' -ForegroundColor DarkGray
    exit 1
}
Write-Ok "Administrator: $($identity.Name)"

# ---------------------------------------------------------------- 1. virtualization
Write-Section '1. Virtualization (needed by Docker Desktop / WSL2)'
try {
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $vm  = Get-CimInstance Win32_ComputerSystem
    if ($cpu.VirtualizationFirmwareEnabled) { Write-Ok 'VT-x / AMD-V enabled in firmware' }
    else { Write-Warn2 'Firmware virtualization not reported. Enable VT-x/AMD-V in BIOS, otherwise Docker will not start.' }
    $ramGB = [math]::Round($vm.TotalPhysicalMemory / 1GB, 1)
    Write-Ok "RAM: $ramGB GB"
    if ($ramGB -lt 8) { Write-Warn2 'Less than 8GB RAM recommended; close other apps while running labs.' }
}
catch {
    Write-Warn2 "Cannot query virtualization state: $($_.Exception.Message)"
    $ramGB = 0
}

# ---------------------------------------------------------------- 2. WSL2
Write-Section '2. WSL2'
$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wsl) { Write-Bad 'wsl.exe not found - is this Windows 10 2004+ / Windows 11?' ; exit 1 }

Write-Step 'wsl --install --no-distribution'
& wsl.exe --install --no-distribution
$wslExit = $LASTEXITCODE
if ($wslExit -ne 0 -and $wslExit -ne 3010) {
    Write-Warn2 "wsl --install --no-distribution failed (exit $wslExit), retrying plain 'wsl --install'"
    & wsl.exe --install
    $wslExit = $LASTEXITCODE
}
if ($wslExit -eq 0 -or $wslExit -eq 3010) {
    Write-Ok "WSL install command exited $wslExit" + $(if ($wslExit -eq 3010) { ' (reboot required)' } else { '' })
}
else {
    Write-Bad "wsl --install failed (exit $wslExit)"
}
& wsl.exe --set-default-version 2 2>$null | Out-Null

# ---------------------------------------------------------------- 3. Git
Write-Section '3. Git'
if (Get-Command git.exe -ErrorAction SilentlyContinue) {
    Write-Ok "Already installed: $(git --version)"
}
else {
    Write-Step 'winget install Git.Git'
    & winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -eq 0) { Write-Ok 'Git installed (open a new terminal to refresh PATH)' }
    else { Write-Bad "Git install failed (winget exit $LASTEXITCODE)" }
}

# ---------------------------------------------------------------- 4. Docker Desktop
Write-Section '4. Docker Desktop'
if ($SkipDocker) {
    Write-Warn2 'Skipped (-SkipDocker)'
}
elseif (Test-Path 'C:\Program Files\Docker\Docker\Docker Desktop.exe') {
    Write-Ok 'Docker Desktop already installed'
}
else {
    Write-Step 'winget install Docker.DockerDesktop (large download, be patient)'
    & winget install --id Docker.DockerDesktop -e --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -eq 0) { Write-Ok 'Docker Desktop installed' }
    else { Write-Bad "Docker Desktop install failed (winget exit $LASTEXITCODE) - try the official installer from docker.com" }
}

# ---------------------------------------------------------------- 5. .wslconfig
Write-Section '5. .wslconfig (memory cap)'
$wslConfig = Join-Path $env:USERPROFILE '.wslconfig'
if (Test-Path $wslConfig) {
    Write-Warn2 "Exists already, left untouched: $wslConfig"
}
elseif ($ramGB -ge 8) {
    $mem = if ($ramGB -ge 16) { 8 } elseif ($ramGB -ge 12) { 6 } else { 4 }
    @"
[wsl2]
memory=${mem}GB
processors=4
swap=2GB
"@ | Set-Content -LiteralPath $wslConfig -Encoding ascii
    Write-Ok "Created $wslConfig (memory=${mem}GB)"
}
else {
    Write-Warn2 'RAM < 8GB or unknown, .wslconfig not created'
}

# ---------------------------------------------------------------- next
Write-Section 'Done - next steps'
Write-Host @'

  1) REBOOT Windows now.
  2) After reboot, open an elevated PowerShell and run:
         wsl --install -d Ubuntu-22.04
     Then launch "Ubuntu 22.04" from the Start menu and set a UNIX username/password.
  3) Start Docker Desktop, wait until the tray icon is green / "Engine running".
  4) Open a NEW PowerShell and verify:
         wsl -l -v
         docker --version
         docker compose version
         docker run --rm hello-world
  5) Back in the lab folder:
         cd lab
         .\lab.ps1 check
         .\lab.ps1 up -Profile dvwa

'@ -ForegroundColor Gray
