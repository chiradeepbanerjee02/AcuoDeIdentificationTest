#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Job 104 DeIdentification Test Script

.DESCRIPTION
    This script performs the following test operations:
    1. Copies "104_DefaultProfile_02192026.txt" to "C:\deidentification\inputwatch"
    2. Waits for processing to complete for Job ID 104
    3. Verifies the deidentification log for successful completion
    4. Counts new files and folders created in C:\deidentification\output
    5. Calculates total size of new files
    6. Saves results to Job104TestResults.json for HTML report generation

.EXAMPLE
    .\Job104Test.ps1

.NOTES
    - This script requires Administrator privileges
    - Run this script from the repository directory where 104_DefaultProfile_02192026.txt is located
    - Results are saved to Job104TestResults.json in the same directory
#>

[CmdletBinding()]
param()

# Set error action preference
$ErrorActionPreference = "Stop"

# Define paths
$scriptDir = $PSScriptRoot
$sourceFile = Join-Path $scriptDir "104_DefaultProfile_02192026.txt"
$destinationDir = "C:\deidentification\inputwatch"
$logFilePath = "C:\Windows\tracing\DeidentifyLog\DeidentifyLog.txt"
$outputDir = "C:\deidentification\output"
$resultsFile = Join-Path $scriptDir "Job104TestResults.json"
$expectedLogEntry = "Job ID: 104, Status callback: , successful 1, failed 0, completionPercentage: 100%"

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

# Function to count files and directories
function Get-DirectoryStats {
    param(
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        return @{
            Directories = 0
            Files = 0
            TotalSize = 0
        }
    }
    
    try {
        $items = Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
        $directories = ($items | Where-Object { $_.PSIsContainer }).Count
        $files = ($items | Where-Object { -not $_.PSIsContainer })
        $fileCount = $files.Count
        $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
        
        return @{
            Directories = $directories
            Files = $fileCount
            TotalSize = if ($totalSize) { $totalSize } else { 0 }
        }
    }
    catch {
        Write-ColoredOutput "Error getting directory stats: $_" "WARNING"
        return @{
            Directories = 0
            Files = 0
            TotalSize = 0
        }
    }
}

# Function to format size
function Format-Size {
    param([long]$Size)
    
    if ($Size -eq 0) { return "0 B" }
    if ($Size -lt 1KB) { return "$Size B" }
    if ($Size -lt 1MB) { return "{0:N2} KB" -f ($Size / 1KB) }
    if ($Size -lt 1GB) { return "{0:N2} MB" -f ($Size / 1MB) }
    return "{0:N2} GB" -f ($Size / 1GB)
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
        
        if ($logLines.Count -eq 0) {
            Write-ColoredOutput "Log file is empty." "WARNING"
            return $false
        }
        
        Write-ColoredOutput "Searching entire log file with $($logLines.Count) lines..." "INFO"
        Write-ColoredOutput "Expected content: $ExpectedContent" "INFO"
        
        # Search through the entire log file for the expected content
        $foundMatch = $false
        foreach ($line in $logLines) {
            if ($line -like "*$ExpectedContent*") {
                Write-ColoredOutput "Match found: $line" "INFO"
                $foundMatch = $true
                break
            }
        }
        
        if ($foundMatch) {
            Write-ColoredOutput "Verification PASSED: Log entry found!" "SUCCESS"
            return $true
        } else {
            Write-ColoredOutput "Verification FAILED: Expected content not found in entire log file" "ERROR"
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
    Write-Host "Job 104 DeIdentification Test Script" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    Write-ColoredOutput "Test script started" "INFO"
    
    # Check if running as Administrator
    if (-not (Test-Administrator)) {
        Write-ColoredOutput "This script must be run as Administrator!" "ERROR"
        throw "Administrator privileges required"
    }
    
    Write-ColoredOutput "Administrator privileges verified" "SUCCESS"
    
    # Step 1: Get initial state of output directory
    Write-Host "`n[Step 1/5] Getting initial state of output directory..." -ForegroundColor Cyan
    $initialStats = Get-DirectoryStats -Path $outputDir
    Write-ColoredOutput "Initial state: $($initialStats.Directories) directories, $($initialStats.Files) files, $(Format-Size $initialStats.TotalSize)" "INFO"
    
    # Step 2: Copy file to inputwatch directory
    Write-Host "`n[Step 2/5] Copying file to inputwatch directory..." -ForegroundColor Cyan
    Copy-FileToInputWatch -SourcePath $sourceFile -DestinationDirectory $destinationDir
    
    # Step 3: Wait for 45 seconds
    Write-Host "`n[Step 3/5] Waiting for 45 seconds for processing..." -ForegroundColor Cyan
    $waitSeconds = 45
    Write-ColoredOutput "Waiting for $waitSeconds seconds..." "INFO"
    
    for ($i = 0; $i -lt $waitSeconds; $i += 9) {
        $remaining = $waitSeconds - $i
        Write-ColoredOutput "Time remaining: $remaining seconds..." "INFO"
        Start-Sleep -Seconds 9
    }
    
    Write-ColoredOutput "Wait period completed" "SUCCESS"
    
    # Step 4: Verify log file content
    Write-Host "`n[Step 4/5] Verifying log file content..." -ForegroundColor Cyan
    $verificationResult = Test-LogFileContent -LogPath $logFilePath -ExpectedContent $expectedLogEntry
    
    # Step 5: Get final state and calculate changes
    Write-Host "`n[Step 5/5] Calculating file and folder changes..." -ForegroundColor Cyan
    $finalStats = Get-DirectoryStats -Path $outputDir
    Write-ColoredOutput "Final state: $($finalStats.Directories) directories, $($finalStats.Files) files, $(Format-Size $finalStats.TotalSize)" "INFO"
    
    $directoriesCreated = $finalStats.Directories - $initialStats.Directories
    $filesCreated = $finalStats.Files - $initialStats.Files
    $sizeIncrease = $finalStats.TotalSize - $initialStats.TotalSize
    
    Write-ColoredOutput "Changes: +$directoriesCreated directories, +$filesCreated files, +$(Format-Size $sizeIncrease)" "SUCCESS"
    
    # Create summary
    $summary = @{
        TestName = "Job 104 DeIdentification Test"
        ExecutionTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        JobId = 104
        VerificationPassed = $verificationResult
        InitialDirectories = $initialStats.Directories
        InitialFiles = $initialStats.Files
        InitialSize = $initialStats.TotalSize
        FinalDirectories = $finalStats.Directories
        FinalFiles = $finalStats.Files
        FinalSize = $finalStats.TotalSize
        TotalDirectoriesCreated = $directoriesCreated
        TotalFilesCreated = $filesCreated
        TotalSizeIncrease = $sizeIncrease
        OutputDirectory = $outputDir
        Success = $verificationResult
    }
    
    # Save results to JSON file
    Write-ColoredOutput "Saving results to JSON file: $resultsFile" "INFO"
    $summary | ConvertTo-Json -Depth 10 | Set-Content -Path $resultsFile -Encoding UTF8
    Write-ColoredOutput "Results saved successfully" "SUCCESS"
    
    # Final summary
    Write-Host "`n========================================" -ForegroundColor Cyan
    if ($verificationResult) {
        Write-Host "Test PASSED: All verifications successful!" -ForegroundColor Green
        Write-Host "Files created: $filesCreated" -ForegroundColor Green
        Write-Host "Directories created: $directoriesCreated" -ForegroundColor Green
        Write-Host "Size increase: $(Format-Size $sizeIncrease)" -ForegroundColor Green
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
    
    # Save error to JSON
    $errorSummary = @{
        TestName = "Job 104 DeIdentification Test"
        ExecutionTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        JobId = 104
        Success = $false
        Error = $_.Exception.Message
    }
    
    $errorSummary | ConvertTo-Json -Depth 10 | Set-Content -Path $resultsFile -Encoding UTF8
    
    exit 1
}
