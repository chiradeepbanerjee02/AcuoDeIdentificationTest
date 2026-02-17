#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Pre-requisites script for DeIdentification tests

.DESCRIPTION
    This script performs the following pre-requisite operations before running tests:
    1. Force deletes all subdirectories and files inside "C:\deidentification\output\DIR_OPTION"
    2. Force deletes all files inside "C:\deidentification\inputwatch"
    3. Restarts the "AcuoDeidentification" Windows service
    4. Clears all contents of "Deidentify.txt" present in "C:\Windows\tracing\DeidentifyLog"

.EXAMPLE
    .\PreRequisites.ps1

.NOTES
    - This script requires Administrator privileges
    - Run this script before InputWatchTest.ps1 to ensure clean test environment
#>

[CmdletBinding()]
param()

# Set error action preference
$ErrorActionPreference = "Stop"

# Define paths
$outputDirPath = "C:\deidentification\output\DIR_OPTION"
$inputWatchPath = "C:\deidentification\inputwatch"
$deidentifyLogPath = "C:\Windows\tracing\DeidentifyLog\Deidentify.txt"
$serviceName = "AcuoDeidentification"

# Function to write colored output
function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "INFO" { Write-Host $logMessage -ForegroundColor Cyan }
        default { Write-Host $logMessage }
    }
}

# Function to check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to force delete subdirectories and files
function Remove-OutputDirectory {
    param([string]$Path)
    
    Write-ColoredOutput "Cleaning output directory..." "INFO"
    Write-ColoredOutput "Target path: $Path" "INFO"
    
    if (-not (Test-Path $Path)) {
        Write-ColoredOutput "Directory does not exist: $Path" "WARNING"
        Write-ColoredOutput "Creating directory for future use..." "INFO"
        try {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            Write-ColoredOutput "Directory created successfully" "SUCCESS"
        }
        catch {
            Write-ColoredOutput "Failed to create directory: $_" "ERROR"
            throw
        }
        return
    }
    
    try {
        # Get all items (subdirectories and files) in the target directory
        $items = Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
        
        if ($items.Count -eq 0) {
            Write-ColoredOutput "Directory is already empty" "SUCCESS"
            return
        }
        
        Write-ColoredOutput "Found $($items.Count) items to delete" "INFO"
        
        # Force delete all subdirectories and files
        Remove-Item -Path "$Path\*" -Recurse -Force -ErrorAction Stop
        
        Write-ColoredOutput "Successfully deleted all subdirectories and files" "SUCCESS"
        
        # Verify deletion
        $remainingItems = Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue
        if ($remainingItems.Count -eq 0) {
            Write-ColoredOutput "Verification: Directory is now empty" "SUCCESS"
        }
        else {
            Write-ColoredOutput "Warning: $($remainingItems.Count) items still remain" "WARNING"
        }
    }
    catch {
        Write-ColoredOutput "Error deleting directory contents: $_" "ERROR"
        throw
    }
}

# Function to force delete all files in inputwatch directory
function Remove-InputWatchDirectory {
    param([string]$Path)
    
    Write-ColoredOutput "Cleaning inputwatch directory..." "INFO"
    Write-ColoredOutput "Target path: $Path" "INFO"
    
    if (-not (Test-Path $Path)) {
        Write-ColoredOutput "Directory does not exist: $Path" "WARNING"
        Write-ColoredOutput "Creating directory for future use..." "INFO"
        try {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            Write-ColoredOutput "Directory created successfully" "SUCCESS"
        }
        catch {
            Write-ColoredOutput "Failed to create directory: $_" "ERROR"
            throw
        }
        return
    }
    
    try {
        # Get all items (files only) in the target directory
        $items = Get-ChildItem -Path $Path -File -Force -ErrorAction SilentlyContinue
        
        if ($items.Count -eq 0) {
            Write-ColoredOutput "Directory is already empty" "SUCCESS"
            return
        }
        
        Write-ColoredOutput "Found $($items.Count) file(s) to delete" "INFO"
        
        # Force delete all files
        Remove-Item -Path "$Path\*" -Force -ErrorAction Stop
        
        Write-ColoredOutput "Successfully deleted all files" "SUCCESS"
        
        # Verify deletion
        $remainingItems = Get-ChildItem -Path $Path -File -Force -ErrorAction SilentlyContinue
        if ($remainingItems.Count -eq 0) {
            Write-ColoredOutput "Verification: Directory is now clean" "SUCCESS"
        }
        else {
            Write-ColoredOutput "Warning: $($remainingItems.Count) file(s) still remain" "WARNING"
        }
    }
    catch {
        Write-ColoredOutput "Error deleting files: $_" "ERROR"
        throw
    }
}

# Function to restart the AcuoDeidentification service
function Restart-AcuoDeidentificationService {
    param([string]$ServiceName)
    
    Write-ColoredOutput "Restarting $ServiceName service..." "INFO"
    
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        
        if ($null -eq $service) {
            Write-ColoredOutput "$ServiceName service not found" "WARNING"
            return
        }
        
        Write-ColoredOutput "Current service status: $($service.Status)" "INFO"
        
        # Stop the service if it's running
        if ($service.Status -eq 'Running' -or $service.Status -eq 'StartPending' -or $service.Status -eq 'Paused') {
            Write-ColoredOutput "Stopping $ServiceName service..." "INFO"
            Stop-Service -Name $ServiceName -Force -ErrorAction Stop
            
            # Wait for service to stop with timeout
            $timeout = 30
            $elapsed = 0
            while ($elapsed -lt $timeout) {
                Start-Sleep -Seconds 2
                $elapsed += 2
                
                $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
                if ($null -eq $service) {
                    Write-ColoredOutput "$ServiceName service was removed" "WARNING"
                    return
                }
                
                if ($service.Status -eq 'Stopped') {
                    Write-ColoredOutput "$ServiceName service stopped successfully!" "SUCCESS"
                    break
                }
            }
            
            # Check if service stopped
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if ($null -ne $service -and $service.Status -ne 'Stopped') {
                Write-ColoredOutput "Service did not stop within $timeout seconds. Current status: $($service.Status)" "WARNING"
            }
        }
        
        # Start the service
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            Write-ColoredOutput "$ServiceName service was removed" "WARNING"
            return
        }
        
        if ($service.Status -eq 'Stopped') {
            Write-ColoredOutput "Starting $ServiceName service..." "INFO"
            Start-Service -Name $ServiceName -ErrorAction Stop
            
            # Wait for service to start with timeout
            $timeout = 30
            $elapsed = 0
            while ($elapsed -lt $timeout) {
                Start-Sleep -Seconds 2
                $elapsed += 2
                
                $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
                if ($null -eq $service) {
                    Write-ColoredOutput "$ServiceName service was removed" "WARNING"
                    return
                }
                
                if ($service.Status -eq 'Running') {
                    Write-ColoredOutput "$ServiceName service restarted successfully!" "SUCCESS"
                    return
                }
            }
            
            # If we get here, service didn't start within timeout
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if ($null -ne $service) {
                Write-ColoredOutput "Service did not start within $timeout seconds. Current status: $($service.Status)" "WARNING"
            }
        }
        else {
            Write-ColoredOutput "$ServiceName service is in '$($service.Status)' state" "INFO"
        }
    }
    catch {
        Write-ColoredOutput "Error restarting $ServiceName service: $_" "ERROR"
        throw
    }
}

# Function to clear the Deidentify.txt log file
function Clear-DeidentifyLog {
    param([string]$LogPath)
    
    Write-ColoredOutput "Clearing Deidentify log file..." "INFO"
    Write-ColoredOutput "Log file path: $LogPath" "INFO"
    
    if (-not (Test-Path $LogPath)) {
        Write-ColoredOutput "Log file does not exist: $LogPath" "WARNING"
        Write-ColoredOutput "Creating empty log file..." "INFO"
        try {
            # Ensure the directory exists
            $logDir = Split-Path -Path $LogPath -Parent
            if (-not (Test-Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
                Write-ColoredOutput "Created log directory: $logDir" "SUCCESS"
            }
            
            # Create empty file
            New-Item -Path $LogPath -ItemType File -Force | Out-Null
            Write-ColoredOutput "Created empty log file" "SUCCESS"
        }
        catch {
            Write-ColoredOutput "Failed to create log file: $_" "ERROR"
            throw
        }
        return
    }
    
    try {
        # Get file size before clearing
        $fileSize = (Get-Item $LogPath).Length
        Write-ColoredOutput "Current file size: $fileSize bytes" "INFO"
        
        # Clear the contents of the file
        Clear-Content -Path $LogPath -Force -ErrorAction Stop
        
        Write-ColoredOutput "Log file contents cleared successfully" "SUCCESS"
        
        # Verify the file is empty
        $newFileSize = (Get-Item $LogPath).Length
        if ($newFileSize -eq 0) {
            Write-ColoredOutput "Verification: File is now empty (0 bytes)" "SUCCESS"
        }
        else {
            Write-ColoredOutput "Warning: File size is $newFileSize bytes (expected 0)" "WARNING"
        }
    }
    catch {
        Write-ColoredOutput "Error clearing log file: $_" "ERROR"
        throw
    }
}

# Main execution
try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Pre-Requisites Script" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    Write-ColoredOutput "Pre-requisites script started" "INFO"
    
    # Check if running as Administrator
    if (-not (Test-Administrator)) {
        Write-ColoredOutput "This script must be run as Administrator!" "ERROR"
        throw "Administrator privileges required"
    }
    
    Write-ColoredOutput "Administrator privileges verified" "SUCCESS"
    
    # Step 1: Force delete subdirectories and files in DIR_OPTION
    Write-Host "`n[Step 1/4] Cleaning DIR_OPTION directory..." -ForegroundColor Cyan
    Remove-OutputDirectory -Path $outputDirPath
    
    # Step 2: Force delete all files in inputwatch directory
    Write-Host "`n[Step 2/4] Cleaning inputwatch directory..." -ForegroundColor Cyan
    Remove-InputWatchDirectory -Path $inputWatchPath
    
    # Step 3: Restart the AcuoDeidentification service
    Write-Host "`n[Step 3/4] Restarting AcuoDeidentification service..." -ForegroundColor Cyan
    Restart-AcuoDeidentificationService -ServiceName $serviceName
    
    # Step 4: Clear Deidentify.txt log file
    Write-Host "`n[Step 4/4] Clearing Deidentify.txt log file..." -ForegroundColor Cyan
    Clear-DeidentifyLog -LogPath $deidentifyLogPath
    
    # Final summary
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "Pre-Requisites Completed Successfully!" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Green
    
    Write-ColoredOutput "Pre-requisites script completed successfully" "SUCCESS"
    Write-ColoredOutput "Test environment is now ready" "SUCCESS"
    
    exit 0
}
catch {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "Pre-Requisites Script Failed!" -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Red
    
    Write-ColoredOutput "Pre-requisites script failed: $_" "ERROR"
    Write-Host "Error: $_" -ForegroundColor Red
    
    exit 1
}
