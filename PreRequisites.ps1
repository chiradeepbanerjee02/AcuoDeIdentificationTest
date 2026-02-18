#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Pre-requisites script for DeIdentification tests

.DESCRIPTION
    This script performs the following pre-requisite operations before running tests:
    1. Force deletes all subdirectories and files inside "C:\deidentification\output\DIR_OPTION" (uses multiple deletion attempts including rmdir for robustness)
    2. Force deletes all files inside "C:\deidentification\inputwatch" (uses multiple deletion attempts for robustness)
    3. Restarts the "AcuoDeidentification" Windows service
    4. Stops the "AcuoDeidentification" Windows service, backs up "DeidentifyLog.txt" with timestamp, deletes the log file, and starts the service again

.EXAMPLE
    .\PreRequisites.ps1

.NOTES
    - This script requires Administrator privileges
    - Run this script before InputWatchTest.ps1 to ensure clean test environment
    - The deletion process now uses multiple attempts to handle locked/in-use files more robustly
#>

[CmdletBinding()]
param()

# Set error action preference
$ErrorActionPreference = "Stop"

# Define paths
$outputDirPath = "C:\deidentification\output"
$inputWatchPath = "C:\deidentification\inputwatch"
$deidentifyLogPath = "C:\Windows\tracing\DeidentifyLog\DeidentifyLog.txt"
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
        
        # Attempt 1: Force delete all subdirectories and files using Remove-Item
        Write-ColoredOutput "Attempting to delete using Remove-Item..." "INFO"
        Remove-Item -Path "$Path\*" -Recurse -Force -ErrorAction SilentlyContinue
        
        # Check if there are remaining items
        $remainingItems = Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue
        
        if ($remainingItems.Count -eq 0) {
            Write-ColoredOutput "Successfully deleted all subdirectories and files" "SUCCESS"
            Write-ColoredOutput "Verification: Directory is now empty" "SUCCESS"
            return
        }
        
        # Attempt 2: If items remain, try using cmd /c rmdir for more forceful deletion
        Write-ColoredOutput "Warning: $($remainingItems.Count) items still remain after first attempt" "WARNING"
        Write-ColoredOutput "Attempting forceful deletion using rmdir..." "INFO"
        
        # Use cmd /c rmdir /s /q which can be more aggressive on Windows
        $cmdOutput = cmd /c "rmdir /s /q `"$Path`"" 2>&1
        
        # Recreate the directory since rmdir removes it entirely
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            Write-ColoredOutput "Directory recreated after rmdir" "INFO"
        }
        
        # Final verification
        $finalCheck = Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue
        if ($finalCheck.Count -eq 0) {
            Write-ColoredOutput "Successfully force deleted all contents" "SUCCESS"
            Write-ColoredOutput "Verification: Directory is now empty" "SUCCESS"
        }
        else {
            Write-ColoredOutput "Warning: $($finalCheck.Count) items still remain after all attempts" "WARNING"
            Write-ColoredOutput "Some files may be locked or in use by other processes" "WARNING"
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
        
        # Attempt 1: Force delete all files using Remove-Item
        Write-ColoredOutput "Attempting to delete using Remove-Item..." "INFO"
        Remove-Item -Path "$Path\*" -Force -ErrorAction SilentlyContinue
        
        # Check if there are remaining items
        $remainingItems = Get-ChildItem -Path $Path -File -Force -ErrorAction SilentlyContinue
        
        if ($remainingItems.Count -eq 0) {
            Write-ColoredOutput "Successfully deleted all files" "SUCCESS"
            Write-ColoredOutput "Verification: Directory is now clean" "SUCCESS"
            return
        }
        
        # Attempt 2: If files remain, try deleting them individually with more force
        Write-ColoredOutput "Warning: $($remainingItems.Count) file(s) still remain after first attempt" "WARNING"
        Write-ColoredOutput "Attempting to delete remaining files individually..." "INFO"
        
        foreach ($item in $remainingItems) {
            try {
                # Remove read-only attribute if present
                if ($item.IsReadOnly) {
                    $item.IsReadOnly = $false
                }
                Remove-Item -Path $item.FullName -Force -ErrorAction SilentlyContinue
            }
            catch {
                Write-ColoredOutput "Could not delete: $($item.Name)" "WARNING"
            }
        }
        
        # Final verification
        $finalCheck = Get-ChildItem -Path $Path -File -Force -ErrorAction SilentlyContinue
        if ($finalCheck.Count -eq 0) {
            Write-ColoredOutput "Successfully force deleted all files" "SUCCESS"
            Write-ColoredOutput "Verification: Directory is now clean" "SUCCESS"
        }
        else {
            Write-ColoredOutput "Warning: $($finalCheck.Count) file(s) still remain after all attempts" "WARNING"
            Write-ColoredOutput "Some files may be locked or in use by other processes" "WARNING"
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

# Function to backup and delete the Deidentify.txt log file
function Backup-AndDeleteDeidentifyLog {
    param(
        [string]$LogPath,
        [string]$ServiceName
    )
    
    Write-ColoredOutput "Processing Deidentify log file..." "INFO"
    Write-ColoredOutput "Log file path: $LogPath" "INFO"
    
    # Step 1: Stop the service
    Write-ColoredOutput "Stopping $ServiceName service..." "INFO"
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        
        if ($null -eq $service) {
            Write-ColoredOutput "$ServiceName service not found" "WARNING"
        }
        elseif ($service.Status -eq 'Running' -or $service.Status -eq 'StartPending' -or $service.Status -eq 'Paused') {
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
                    break
                }
                
                if ($service.Status -eq 'Stopped') {
                    Write-ColoredOutput "$ServiceName service stopped successfully" "SUCCESS"
                    break
                }
            }
            
            # Check if service stopped
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if ($null -ne $service -and $service.Status -ne 'Stopped') {
                Write-ColoredOutput "Service did not stop within $timeout seconds. Current status: $($service.Status)" "WARNING"
            }
        }
        else {
            Write-ColoredOutput "$ServiceName service is already stopped" "INFO"
        }
    }
    catch {
        Write-ColoredOutput "Error stopping $ServiceName service: $_" "ERROR"
        throw
    }
    
    # Step 2: Backup the log file if it exists
    if (-not (Test-Path $LogPath)) {
        Write-ColoredOutput "Log file does not exist: $LogPath" "WARNING"
        Write-ColoredOutput "No backup needed" "INFO"
    }
    else {
        try {
            # Get file size
            $fileSize = (Get-Item $LogPath).Length
            Write-ColoredOutput "Current file size: $fileSize bytes" "INFO"
            
            # Create backup filename with timestamp
            $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            $logDir = Split-Path -Path $LogPath -Parent
            $logFileName = Split-Path -Path $LogPath -Leaf
            $logFileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($logFileName)
            $logFileExt = [System.IO.Path]::GetExtension($logFileName)
            $backupFileName = "${logFileNameWithoutExt}_${timestamp}${logFileExt}"
            $backupPath = Join-Path $logDir $backupFileName
            
            Write-ColoredOutput "Creating backup: $backupFileName" "INFO"
            
            # Copy the file to backup
            Copy-Item -Path $LogPath -Destination $backupPath -Force -ErrorAction Stop
            
            Write-ColoredOutput "Backup created successfully: $backupPath" "SUCCESS"
            
            # Verify backup file exists
            if (Test-Path $backupPath) {
                $backupSize = (Get-Item $backupPath).Length
                Write-ColoredOutput "Backup file size: $backupSize bytes" "SUCCESS"
            }
        }
        catch {
            Write-ColoredOutput "Error creating backup: $_" "ERROR"
            Write-ColoredOutput "WARNING: Backup failed, but continuing with deletion. Original log data may be lost!" "WARNING"
            # Continue with deletion even if backup fails
        }
    }
    
    # Step 3: Delete the original log file
    if (Test-Path $LogPath) {
        try {
            Write-ColoredOutput "Deleting original log file: $LogPath" "INFO"
            Remove-Item -Path $LogPath -Force -ErrorAction Stop
            Write-ColoredOutput "Log file deleted successfully" "SUCCESS"
            
            # Verify deletion
            if (-not (Test-Path $LogPath)) {
                Write-ColoredOutput "Verification: Log file has been deleted" "SUCCESS"
            }
            else {
                Write-ColoredOutput "Warning: Log file still exists after deletion attempt" "WARNING"
            }
        }
        catch {
            Write-ColoredOutput "Error deleting log file: $_" "ERROR"
            throw
        }
    }
    
    # Step 4: Start the service
    Write-ColoredOutput "Starting $ServiceName service..." "INFO"
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        
        if ($null -eq $service) {
            Write-ColoredOutput "$ServiceName service not found" "WARNING"
            return
        }
        
        if ($service.Status -eq 'Stopped') {
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
                    Write-ColoredOutput "$ServiceName service started successfully" "SUCCESS"
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
        Write-ColoredOutput "Error starting $ServiceName service: $_" "ERROR"
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
    
    # Step 4: Backup and delete Deidentify.txt log file
    Write-Host "`n[Step 4/4] Backing up and deleting Deidentify.txt log file..." -ForegroundColor Cyan
    Backup-AndDeleteDeidentifyLog -LogPath $deidentifyLogPath -ServiceName $serviceName
    
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
