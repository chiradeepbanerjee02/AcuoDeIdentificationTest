#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Uninstalls existing AcuoDeIdentification and installs it from AcuoDeIdentificationSetup.msi with custom configuration.

.DESCRIPTION
    This script performs the following actions:
    1. Uninstalls any existing AcuoDeIdentification installation from the system
    2. Silently installs AcuoDeIdentification from AcuoDeIdentificationSetup.msi
    3. Replaces the AcuoDeidentificationService.exe.config file with the version from this repository
    4. Starts the AcuoDeIdentification Windows service if it is stopped

.EXAMPLE
    .\Install-AcuoDeIdentification.ps1

.NOTES
    - This script requires Administrator privileges
    - Run this script from the repository directory where AcuoDeIdentificationSetup.msi and AcuoDeidentificationService.exe.config are located
#>

[CmdletBinding()]
param()

# Set error action preference
$ErrorActionPreference = "Stop"

# Define paths
$scriptDir = $PSScriptRoot
$msiPath = Join-Path $scriptDir "AcuoDeIdentificationSetup.msi"
$configPath = Join-Path $scriptDir "AcuoDeidentificationService.exe.config"
$installDir = "C:\Program Files\Acuo Technologies\AcuoDeIdentification"
$targetConfigPath = Join-Path $installDir "AcuoDeidentificationService.exe.config"

# Log file path
$logDir = Join-Path $env:TEMP "AcuoDeIdentificationInstall"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $logDir "Install-AcuoDeIdentification-$timestamp.log"

# Function to write log messages
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Add-Content -Path $logFile -Value $logMessage
    
    switch ($Level) {
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        "WARNING" { Write-Host $Message -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        default { Write-Host $Message }
    }
}

# Function to check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to uninstall AcuoDeIdentification
function Uninstall-AcuoDeIdentification {
    Write-Log "Checking for existing AcuoDeIdentification installation..."
    
    # Check registry for uninstall strings (more efficient than WMI)
    Write-Log "Checking registry for additional uninstall entries..."
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($regPath in $regPaths) {
        $uninstallKeys = Get-ItemProperty $regPath -ErrorAction SilentlyContinue | 
            Where-Object { $_.DisplayName -like "*AcuoDeIdentification*" }
        
        foreach ($key in $uninstallKeys) {
            Write-Log "Found registry entry: $($key.DisplayName)"
            if ($key.UninstallString) {
                Write-Log "Uninstall string: $($key.UninstallString)"
                
                # Extract MSI product code if present
                if ($key.UninstallString -match '\{[A-Fa-f0-9\-]+\}') {
                    $productCode = $matches[0]
                    Write-Log "Attempting to uninstall using product code: $productCode" -Level "WARNING"
                    
                    try {
                        $uninstallArgs = "/x `"$productCode`" /qn /norestart"
                        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $uninstallArgs -Wait -PassThru -NoNewWindow
                        
                        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 1605) {
                            # 0 = success, 1605 = product not found (already uninstalled)
                            Write-Log "Uninstall completed with exit code: $($process.ExitCode)" -Level "SUCCESS"
                            # Wait for 30 seconds
                            Start-Sleep -Seconds 30
                        } else {
                            Write-Log "Uninstall completed with exit code: $($process.ExitCode)" -Level "WARNING"
                        }
                    }
                    catch {
                        Write-Log "Error during MSI uninstall: $_" -Level "ERROR"
                    }
                }
            }
        }
    }
}

# Function to install AcuoDeIdentification
function Install-AcuoDeIdentification {
    param([string]$MsiPath)
    
    Write-Log "Starting AcuoDeIdentification installation..."
    Write-Log "MSI Path: $MsiPath"
    
    if (-not (Test-Path $MsiPath)) {
        Write-Log "MSI file not found at: $MsiPath" -Level "ERROR"
        throw "MSI file not found"
    }
    
    # Create log path for MSI installation
    $msiLogFile = Join-Path $logDir "AcuoDeIdentification-Install-$timestamp.log"
    
    # Silent install using msiexec
    # /i = install, /qn = quiet mode with no UI, /norestart = do not restart
    $installArgs = "/i `"$MsiPath`" /qn /norestart /l*v `"$msiLogFile`""
    
    Write-Log "Installing with arguments: msiexec.exe $installArgs"
    
    try {
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
        
        Write-Log "Installation completed with exit code: $($process.ExitCode)"
        
        # Check common MSI exit codes
        switch ($process.ExitCode) {
            0 { 
                Write-Log "Installation completed successfully!" -Level "SUCCESS"
            }
            3010 { 
                Write-Log "Installation completed successfully. System restart required." -Level "WARNING"
            }
            1641 { 
                Write-Log "Installation completed successfully. Installer initiated restart." -Level "WARNING"
            }
            default {
                Write-Log "Installation completed with exit code: $($process.ExitCode). Check log at: $msiLogFile" -Level "WARNING"
            }
        }
        
        # Wait for installation to settle
        Write-Log "Waiting for installation to complete..."
        Start-Sleep -Seconds 5
        
        # Verify installation directory exists
        if (Test-Path $installDir) {
            Write-Log "Installation directory verified at: $installDir" -Level "SUCCESS"
        } else {
            Write-Log "Installation directory not found at: $installDir" -Level "ERROR"
            Write-Log "Check MSI log for details: $msiLogFile" -Level "ERROR"
            throw "Installation directory not found after installation"
        }
    }
    catch {
        Write-Log "Error during installation: $_" -Level "ERROR"
        Write-Log "Check MSI log for details: $msiLogFile" -Level "ERROR"
        throw
    }
}

# Function to replace configuration file
function Copy-ConfigFile {
    param(
        [string]$SourcePath,
        [string]$TargetPath
    )
    
    Write-Log "Replacing configuration file..."
    Write-Log "Source: $SourcePath"
    Write-Log "Target: $TargetPath"
    
    if (-not (Test-Path $SourcePath)) {
        Write-Log "Source configuration file not found at: $SourcePath" -Level "ERROR"
        throw "Source configuration file not found"
    }
    
    # Backup existing config file if it exists
    if (Test-Path $TargetPath) {
        $backupPath = "$TargetPath.backup-$timestamp"
        Write-Log "Backing up existing configuration to: $backupPath"
        Copy-Item -Path $TargetPath -Destination $backupPath -Force
        Write-Log "Backup created successfully" -Level "SUCCESS"
    }
    
    # Copy new configuration file
    try {
        Copy-Item -Path $SourcePath -Destination $TargetPath -Force
        Write-Log "Configuration file replaced successfully!" -Level "SUCCESS"
        
        # Verify the file was copied
        if (Test-Path $TargetPath) {
            $sourceHash = (Get-FileHash -Path $SourcePath -Algorithm SHA256).Hash
            $targetHash = (Get-FileHash -Path $TargetPath -Algorithm SHA256).Hash
            
            if ($sourceHash -eq $targetHash) {
                Write-Log "Configuration file verified (SHA256 hash matches)" -Level "SUCCESS"
            } else {
                Write-Log "Warning: File hashes do not match!" -Level "WARNING"
            }
        }
    }
    catch {
        Write-Log "Error copying configuration file: $_" -Level "ERROR"
        throw
    }
}

# Function to start the AcuoDeIdentification service
function Start-AcuoDeIdentificationService {
    Write-Log "Checking AcuoDeIdentification service status..."
    
    try {
        $service = Get-Service -Name "AcuoDeIdentification" -ErrorAction SilentlyContinue
        
        if ($null -eq $service) {
            Write-Log "AcuoDeIdentification service not found" -Level "WARNING"
            return
        }
        
        Write-Log "Service status: $($service.Status)"
        
        # Configure service to run with specific credentials
        # Note: The AcuoServiceUser account must exist on the system and have
        # the 'Log on as a service' right for the service to start successfully
        Write-Log "Configuring service to run with AcuoServiceUser..."
        try {
            # Use hardcoded credentials for AcuoDeIdentification service
            $accountName = ".\AcuoServiceUser"
            $accountPassword = "`$ecureDefault2017"
            Write-Log "Configuring service to run as: $accountName"
            
            # Stop the service if it's running before reconfiguring
            if ($service.Status -eq 'Running') {
                Write-Log "Stopping service to reconfigure..."
                Stop-Service -Name "AcuoDeIdentification" -Force -ErrorAction Stop
                # Wait for service to stop
                $service.WaitForStatus('Stopped', '00:00:10')
            }
            
            # Configure service using sc.exe to change service configuration
            # Note: The space after 'obj=' is required by sc.exe syntax
            Write-Log "Setting service credentials..."
            
            # Configure with sc.exe with the specified credentials
            $scResult = & sc.exe config AcuoDeIdentification obj= $accountName password= $accountPassword
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Service configured to run as $accountName successfully" -Level "SUCCESS"
            } else {
                Write-Log "Warning: sc.exe returned exit code $LASTEXITCODE. Output: $scResult" -Level "WARNING"
                Write-Log "Attempting to grant 'Log on as a service' right to user..." -Level "WARNING"
            }
        }
        catch {
            Write-Log "Warning: Could not configure service user: $_" -Level "WARNING"
        }
        
        # Refresh service object
        $service = Get-Service -Name "AcuoDeIdentification" -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            Write-Log "AcuoDeIdentification service not found after configuration" -Level "WARNING"
            return
        }
        
        if ($service.Status -eq 'Running') {
            Write-Log "AcuoDeIdentification service is already running" -Level "SUCCESS"
        }
        elseif ($service.Status -eq 'Stopped') {
            Write-Log "Starting AcuoDeIdentification service..."
            
            try {
                Start-Service -Name "AcuoDeIdentification" -ErrorAction Stop
                
                # Wait for service to start with timeout
                $timeout = 30
                $elapsed = 0
                while ($elapsed -lt $timeout) {
                    Start-Sleep -Seconds 2
                    $elapsed += 2
                    
                    $service = Get-Service -Name "AcuoDeIdentification" -ErrorAction SilentlyContinue
                    if ($null -eq $service) {
                        Write-Log "AcuoDeIdentification service was removed during start attempt" -Level "WARNING"
                        return
                    }
                    
                    if ($service.Status -eq 'Running') {
                        Write-Log "AcuoDeIdentification service started successfully!" -Level "SUCCESS"
                        return
                    }
                }
                
                # If we get here, service didn't start within timeout
                # Refresh service status to get current state
                $service = Get-Service -Name "AcuoDeIdentification" -ErrorAction SilentlyContinue
                if ($null -ne $service) {
                    Write-Log "Service did not start within $timeout seconds. Current status: $($service.Status)" -Level "WARNING"
                } else {
                    Write-Log "Service did not start within $timeout seconds and is no longer found" -Level "WARNING"
                }
            }
            catch {
                Write-Log "Failed to start AcuoDeIdentification service: $_" -Level "WARNING"
            }
        }
        else {
            Write-Log "AcuoDeIdentification service is in '$($service.Status)' state" -Level "WARNING"
        }
    }
    catch {
        Write-Log "Error checking or starting AcuoDeIdentification service: $_" -Level "WARNING"
    }
}

# Main execution
try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "AcuoDeIdentification Installation Script" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    Write-Log "Installation script started"
    Write-Log "Log file: $logFile"
    
    # Check if running as Administrator
    if (-not (Test-Administrator)) {
        Write-Log "This script must be run as Administrator!" -Level "ERROR"
        throw "Administrator privileges required"
    }
    
    Write-Log "Administrator privileges verified" -Level "SUCCESS"
    
    # Validate required files exist
    if (-not (Test-Path $msiPath)) {
        Write-Log "AcuoDeIdentificationSetup.msi not found at: $msiPath" -Level "ERROR"
        throw "MSI file not found"
    }
    
    if (-not (Test-Path $configPath)) {
        Write-Log "AcuoDeidentificationService.exe.config not found at: $configPath" -Level "ERROR"
        throw "Configuration file not found"
    }
    
    Write-Log "Required files validated successfully" -Level "SUCCESS"
    
    # Step 1: Uninstall existing AcuoDeIdentification
    Write-Host "`n[Step 1/4] Uninstalling existing AcuoDeIdentification..." -ForegroundColor Cyan
    Uninstall-AcuoDeIdentification
    
    # Step 2: Install AcuoDeIdentification from MSI
    Write-Host "`n[Step 2/4] Installing AcuoDeIdentification from MSI..." -ForegroundColor Cyan
    Install-AcuoDeIdentification -MsiPath $msiPath
    
    # Step 3: Replace configuration file
    Write-Host "`n[Step 3/4] Replacing configuration file..." -ForegroundColor Cyan
    Copy-ConfigFile -SourcePath $configPath -TargetPath $targetConfigPath
    
    # Step 4: Start AcuoDeIdentification service if stopped
    Write-Host "`n[Step 4/4] Starting AcuoDeIdentification service..." -ForegroundColor Cyan
    Start-AcuoDeIdentificationService
    
    # Final summary
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "Installation Completed Successfully!" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Green
    
    Write-Log "Installation script completed successfully" -Level "SUCCESS"
    Write-Log "Log file saved to: $logFile"
    
    Write-Host "Log file: $logFile" -ForegroundColor Cyan
    Write-Host "Installation directory: $installDir" -ForegroundColor Cyan
    Write-Host "`nAcuoDeIdentification is now ready to use!`n" -ForegroundColor Green
    # Wait for 30 seconds
    Start-Sleep -Seconds 30
    exit 0
}
catch {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "Installation Failed!" -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Red
    
    Write-Log "Installation script failed: $_" -Level "ERROR"
    Write-Log "Log file: $logFile"
    
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "`nCheck the log file for details: $logFile`n" -ForegroundColor Yellow
    
    exit 1
}
