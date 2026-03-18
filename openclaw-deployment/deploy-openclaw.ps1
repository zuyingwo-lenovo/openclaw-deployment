<#
.SYNOPSIS
OpenClaw AI Agent Deployment Script for Windows (WSL2)

.DESCRIPTION
This script prepares the Windows environment for OpenClaw. It ensures WSL2 is enabled,
installs Ubuntu if missing, configures systemd, and triggers the internal bash deployment script.

.NOTES
Requires Administrator privileges.
#>

$ErrorActionPreference = "Stop"
$LogFile = "$PSScriptRoot\deploy-openclaw.log"

Function Write-Log {
    param([string]$Message, [string]$Level="INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage
}

# 1. Check Administrator Privileges
Write-Log "Checking for Administrator privileges..."
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    Write-Log "This script must be run as Administrator. Please restart PowerShell as Administrator." "ERROR"
    exit 1
}
Write-Log "Administrator privileges confirmed."

# 2. Check and Enable WSL2
Write-Log "Checking WSL status..."
try {
    $wslStatus = wsl --status 2>&1
    Write-Log "WSL is already installed."
} catch {
    Write-Log "WSL not found. Installing WSL2..." "WARN"
    wsl --install --no-distribution
    Write-Log "WSL2 base installed. A reboot may be required before continuing." "WARN"
}

# 3. Check and Install Ubuntu
$DistroName = "Ubuntu-24.04"
Write-Log "Checking for Ubuntu distribution ($DistroName)..."
$installedDistros = wsl --list --quiet 2>&1
if ($installedDistros -notmatch "Ubuntu") {
    Write-Log "Ubuntu not found. Installing $DistroName..."
    wsl --install -d $DistroName
    Write-Log "Ubuntu installation completed."
} else {
    Write-Log "Ubuntu distribution found."
}

# Ensure WSL default version is 2
wsl --set-default-version 2 | Out-Null

# 4. Configure systemd in WSL (Required for OpenClaw Gateway)
Write-Log "Ensuring systemd is enabled in WSL..."
$wslConfCommand = "if [ ! -f /etc/wsl.conf ] || ! grep -q 'systemd=true' /etc/wsl.conf; then echo -e '[boot]\nsystemd=true' | sudo tee -a /etc/wsl.conf > /dev/null; echo 'systemd enabled, requires restart'; fi"
$sysdResult = wsl -d Ubuntu -- bash -c $wslConfCommand
if ($sysdResult -match "requires restart") {
    Write-Log "systemd was just enabled. Shutting down WSL to apply changes..." "WARN"
    wsl --shutdown
    Start-Sleep -Seconds 5
    Write-Log "WSL restarted."
}

# 5. Copy installation files to WSL
Write-Log "Copying deployment assets to WSL..."
$WslHome = "\\wsl$\Ubuntu\home\$(wsl -d Ubuntu -- bash -c 'whoami' | Out-String).Trim()"
$TargetDir = "$WslHome\openclaw-setup"

if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir | Out-Null
}

# Copy scripts
Copy-Item -Path "$PSScriptRoot\bootstrap-openclaw.sh" -Destination $TargetDir -Force
Copy-Item -Path "$PSScriptRoot\verify-openclaw.sh" -Destination $TargetDir -Force
Copy-Item -Path "$PSScriptRoot\skills-manifest.yaml" -Destination $TargetDir -Force
Copy-Item -Path "$PSScriptRoot\install-skills.sh" -Destination $TargetDir -Force
Copy-Item -Path "$PSScriptRoot\.env.example" -Destination $TargetDir -Force
Copy-Item -Path "$PSScriptRoot\openclaw.base.json" -Destination $TargetDir -Force

# Convert line endings to LF just in case
wsl -d Ubuntu -- bash -c "sudo apt-get update && sudo apt-get install -y dos2unix; dos2unix ~/openclaw-setup/*.sh" | Out-Null
wsl -d Ubuntu -- bash -c "chmod +x ~/openclaw-setup/*.sh" | Out-Null

# 6. Execute WSL deployment script
Write-Log "Executing WSL bootstrap script..."
wsl -d Ubuntu -- bash -c "cd ~/openclaw-setup && ./bootstrap-openclaw.sh"

if ($LASTEXITCODE -ne 0) {
    Write-Log "WSL bootstrap script failed with exit code $LASTEXITCODE." "ERROR"
    exit $LASTEXITCODE
}

# 7. Setup Auto-start for WSL Gateway
Write-Log "Setting up Windows Scheduled Task for OpenClaw Gateway auto-start..."
$TaskName = "OpenClaw WSL Boot"
$TaskExists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $TaskExists) {
    schtasks /create /tn $TaskName /tr "wsl.exe -d Ubuntu --exec /bin/true" /sc onstart /ru SYSTEM | Out-Null
    Write-Log "Scheduled task '$TaskName' created."
} else {
    Write-Log "Scheduled task '$TaskName' already exists."
}

Write-Log "Deployment script completed successfully. Please check verify-openclaw.sh output in WSL to confirm health."
