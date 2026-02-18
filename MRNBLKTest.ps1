#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    MRNBLK Test Script

.DESCRIPTION
    This script performs the following test operations:
    1. Copies "103_DefaultProfile_02182025.txt" to "C:\deidentification\inputwatch"
    2. Monitors the log file periodically for Job Id 103 (with timeout)
    3. Verifies the deidentification log for successful completion

.EXAMPLE
    .\MRNBLKTest.ps1

.NOTES
    - This script requires Administrator privileges
    - Run this script from the repository directory where 103_DefaultProfile_02182025.txt is located
#>

[CmdletBinding()]
param()

# Set error action preference
$ErrorActionPreference = "Stop"

# Define paths
$scriptDir = $PSScriptRoot
$sourceFile = Join-Path $scriptDir "103_DefaultProfile_02182025.txt"
$destinationDir = "C:\deidentification\inputwatch"
$logFilePath = "C:\Windows\tracing\DeidentifyLog\DeidentifyLog.txt"
$expectedLogEntry = "for jobID"

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

# Function to wait for Job Id in log file
function Wait-ForJobIdInLog {
    param(
        [string]$LogPath,
        [string]$JobId,
        [int]$TimeoutSeconds = 3000,
        [int]$CheckIntervalSeconds = 5
    )
    
    Write-ColoredOutput "Monitoring log file for Job Id $JobId..." "INFO"
    Write-ColoredOutput "Log file path: $LogPath" "INFO"
    Write-ColoredOutput "Timeout: $TimeoutSeconds seconds" "INFO"
    Write-ColoredOutput "Check interval: $CheckIntervalSeconds seconds" "INFO"
    
    $startTime = Get-Date
    
    while ($true) {
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        
        # Check for timeout
        if ($elapsed -ge $TimeoutSeconds) {
            Write-ColoredOutput "Timeout reached after $TimeoutSeconds seconds without finding Job Id $JobId" "ERROR"
            return $false
        }
        
        # Check if log file exists
        if (Test-Path $LogPath) {
            try {
                # Read the log file content
                $logContent = Get-Content -Path $LogPath -Raw
                
                # Check if Job Id appears in the log (case-insensitive)
                if ($logContent -match "(?i)Job Id\s+$JobId\b" -or $logContent -match "(?i)Job ID:\s+$JobId\b" -or $logContent -match "(?i)jobID\s+$JobId\b") {
                    Write-ColoredOutput "Job Id $JobId found in log file!" "SUCCESS"
                    return $true
                }
            }
            catch {
                Write-ColoredOutput "Error reading log file: $_" "WARNING"
            }
        } else {
            Write-ColoredOutput "Log file not found yet at: $LogPath" "WARNING"
        }
        
        # Display progress
        $remaining = $TimeoutSeconds - [int]$elapsed
        Write-ColoredOutput "Waiting for Job Id $JobId... (${remaining}s remaining)" "INFO"
        
        # Wait before next check
        Start-Sleep -Seconds $CheckIntervalSeconds
    }
}

# Function to copy file to inputwatch directory
function Copy-FileToInputWatch {
    param(
        [string]$SourcePath,
        [string]$DestinationDirectory
    )
    
    Write-ColoredOutput "Copying file to inputwatch directory..." "INFO"
    Write-ColoredOutput "Source: $SourcePath" "INFO"
    Write-ColoredOutput "Destination: $DestinationDirectory" "INFO"
    
    # Check if source file exists
    if (-not (Test-Path $SourcePath)) {
        Write-ColoredOutput "Source file not found at: $SourcePath" "ERROR"
        throw "Source file not found"
    }
    
    # Create destination directory if it doesn't exist
    if (-not (Test-Path $DestinationDirectory)) {
        Write-ColoredOutput "Creating destination directory: $DestinationDirectory" "WARNING"
        New-Item -Path $DestinationDirectory -ItemType Directory -Force | Out-Null
    }
    
    # Copy the file
    try {
        $fileName = Split-Path $SourcePath -Leaf
        $destinationPath = Join-Path $DestinationDirectory $fileName
        
        Copy-Item -Path $SourcePath -Destination $destinationPath -Force
        Write-ColoredOutput "File copied successfully to: $destinationPath" "SUCCESS"
        
        # Verify the file was copied
        if (Test-Path $destinationPath) {
            Write-ColoredOutput "File verification: File exists at destination" "SUCCESS"
        } else {
            Write-ColoredOutput "File verification: File not found at destination!" "ERROR"
            throw "File copy verification failed"
        }
    }
    catch {
        Write-ColoredOutput "Error copying file: $_" "ERROR"
        throw
    }
}

# Function to verify log file content
function Test-LogFileContent {
    param(
        [string]$LogPath,
        [string]$ExpectedContent
    )
    
    Write-ColoredOutput "Verifying log file content..." "INFO"
    Write-ColoredOutput "Log file path: $LogPath" "INFO"
    
    # Check if log file exists
    if (-not (Test-Path $LogPath)) {
        Write-ColoredOutput "Log file not found at: $LogPath" "ERROR"
        return $false
    }
    
    try {
        # Read all lines from the log file
        $logLines = Get-Content -Path $LogPath
        
        if ($logLines.Count -lt 1) {
            Write-ColoredOutput "Log file has no lines. Cannot verify last line." "WARNING"
            return $false
        }
        
        # Get the last line (index -1)
        $lastLine = $logLines[-1]
        Write-ColoredOutput "Last line: $lastLine" "INFO"
        Write-ColoredOutput "Expected content: $ExpectedContent" "INFO"
        
        # Check if the last line contains the expected content
        if ($lastLine -like "*$ExpectedContent*") {
            Write-ColoredOutput "Verification PASSED: Log entry found!" "SUCCESS"
            return $true
        } else {
            Write-ColoredOutput "Verification FAILED: Expected content not found in last line" "ERROR"
            return $false
        }
    }
    catch {
        Write-ColoredOutput "Error reading log file: $_" "ERROR"
        return $false
    }
}

# Main execution
try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "MRNBLK Test Script" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    Write-ColoredOutput "Test script started" "INFO"
    
    # Check if running as Administrator
    if (-not (Test-Administrator)) {
        Write-ColoredOutput "This script must be run as Administrator!" "ERROR"
        throw "Administrator privileges required"
    }
    
    Write-ColoredOutput "Administrator privileges verified" "SUCCESS"
    
    # Step 1: Copy file to inputwatch directory
    Write-Host "`n[Step 1/3] Copying file to inputwatch directory..." -ForegroundColor Cyan
    Copy-FileToInputWatch -SourcePath $sourceFile -DestinationDirectory $destinationDir
    
    # Step 2: Monitor log file for Job Id 103
    Write-Host "`n[Step 2/3] Monitoring log file for Job Id 103..." -ForegroundColor Cyan
    $jobIdFound = Wait-ForJobIdInLog -LogPath $logFilePath -JobId "103" -TimeoutSeconds 10000 -CheckIntervalSeconds 5
    
    if (-not $jobIdFound) {
        Write-ColoredOutput "Failed to find Job Id 103 in log file within timeout period" "ERROR"
        throw "Job Id 103 not found in log file"
    }
    
    Write-ColoredOutput "Job Id 103 detected, proceeding to verification" "SUCCESS"
    
    # Step 3: Verify log file content
    Write-Host "`n[Step 3/3] Verifying log file content..." -ForegroundColor Cyan
    $verificationResult = Test-LogFileContent -LogPath $logFilePath -ExpectedContent $expectedLogEntry
    
    # Final summary
    Write-Host "`n========================================" -ForegroundColor Cyan
    if ($verificationResult) {
        Write-Host "Test PASSED: All verifications successful!" -ForegroundColor Green
        Write-Host "========================================`n" -ForegroundColor Green
        Write-ColoredOutput "Test script completed successfully" "SUCCESS"
        exit 0
    } else {
        Write-Host "Test FAILED: Verification failed!" -ForegroundColor Red
        Write-Host "========================================`n" -ForegroundColor Red
        Write-ColoredOutput "Test script failed" "ERROR"
        exit 1
    }
}
catch {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "Test Script Failed!" -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Red
    
    Write-ColoredOutput "Test script failed: $_" "ERROR"
    Write-Host "Error: $_" -ForegroundColor Red
    
    exit 1
}
