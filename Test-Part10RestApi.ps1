#Requires -Version 5.1

<#
.SYNOPSIS
    Part10 REST API Test Script for DeIdentification Service

.DESCRIPTION
    This script performs the following test operations:
    1. Reads REST API URLs from AcuoAccessP10Calls.txt
    2. For each URL, triggers the REST API call
    3. Scans C:/Acuo/part10 directory before and after each call
    4. Counts directories and files created as a result of each call
    5. Saves results to Part10TestResults.json for HTML report generation

.EXAMPLE
    .\Test-Part10RestApi.ps1

.NOTES
    - Run this script from the repository directory where AcuoAccessP10Calls.txt is located
    - Results are saved to Part10TestResults.json in the same directory
#>

[CmdletBinding()]
param()

# Set error action preference
$ErrorActionPreference = "Continue"

# Define paths
$scriptDir = $PSScriptRoot
$apiCallsFile = Join-Path $scriptDir "AcuoAccessP10Calls.txt"
$resultsFile = Join-Path $scriptDir "Part10TestResults.json"
$part10Dir = "C:\Acuo\part10"

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

# Function to invoke REST API call
function Invoke-Part10RestApi {
    param(
        [string]$Url
    )
    
    Write-ColoredOutput "Invoking REST API: $Url" "INFO"
    
    try {
        $response = Invoke-RestMethod `
            -Uri $Url `
            -Method Get `
            -UseBasicParsing `
            -TimeoutSec 30
        
        Write-ColoredOutput "REST API call completed successfully" "SUCCESS"
        return @{
            Success = $true
            Message = "API call successful"
            StatusCode = 200
        }
    }
    catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "N/A" }
        Write-ColoredOutput "Error invoking REST API: $_ (Status: $statusCode)" "WARNING"
        return @{
            Success = $false
            Message = $_.Exception.Message
            StatusCode = $statusCode
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

# Main execution
try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Part10 REST API Test Script" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    Write-ColoredOutput "Test script started" "INFO"
    
    # Check if API calls file exists
    if (-not (Test-Path $apiCallsFile)) {
        Write-ColoredOutput "API calls file not found: $apiCallsFile" "ERROR"
        throw "API calls file not found"
    }
    
    # Read API calls from file
    Write-ColoredOutput "Reading API calls from file..." "INFO"
    $apiCalls = Get-Content -Path $apiCallsFile | Where-Object { $_ -and $_.Trim() -ne "" }
    Write-ColoredOutput "Found $($apiCalls.Count) API calls to execute" "SUCCESS"
    
    # Initialize results array
    $results = @()
    
    # Get initial state of part10 directory
    Write-ColoredOutput "Getting initial state of $part10Dir..." "INFO"
    $initialStats = Get-DirectoryStats -Path $part10Dir
    Write-ColoredOutput "Initial state: $($initialStats.Directories) directories, $($initialStats.Files) files, $(Format-Size $initialStats.TotalSize)" "INFO"
    
    # Process each API call
    $callNumber = 1
    foreach ($apiUrl in $apiCalls) {
        $apiUrl = $apiUrl.Trim()
        if ([string]::IsNullOrWhiteSpace($apiUrl)) {
            continue
        }
        
        Write-Host "`n----------------------------------------" -ForegroundColor Yellow
        Write-Host "Processing API Call $callNumber of $($apiCalls.Count)" -ForegroundColor Yellow
        Write-Host "----------------------------------------" -ForegroundColor Yellow
        
        # Get before state
        $beforeStats = Get-DirectoryStats -Path $part10Dir
        Write-ColoredOutput "Before call: $($beforeStats.Directories) directories, $($beforeStats.Files) files" "INFO"
        
        # Invoke API call
        $apiResult = Invoke-Part10RestApi -Url $apiUrl
        
        # Wait for processing (5 seconds)
        Write-ColoredOutput "Waiting 5 seconds for processing..." "INFO"
        Start-Sleep -Seconds 5
        
        # Get after state
        $afterStats = Get-DirectoryStats -Path $part10Dir
        Write-ColoredOutput "After call: $($afterStats.Directories) directories, $($afterStats.Files) files" "INFO"
        
        # Calculate differences
        $directoriesCreated = $afterStats.Directories - $beforeStats.Directories
        $filesCreated = $afterStats.Files - $beforeStats.Files
        $sizeIncrease = $afterStats.TotalSize - $beforeStats.TotalSize
        
        Write-ColoredOutput "Changes: +$directoriesCreated directories, +$filesCreated files, +$(Format-Size $sizeIncrease)" "SUCCESS"
        
        # Store result
        $result = @{
            CallNumber = $callNumber
            Url = $apiUrl
            Success = $apiResult.Success
            Message = $apiResult.Message
            StatusCode = $apiResult.StatusCode
            DirectoriesBefore = $beforeStats.Directories
            DirectoriesAfter = $afterStats.Directories
            DirectoriesCreated = $directoriesCreated
            FilesBefore = $beforeStats.Files
            FilesAfter = $afterStats.Files
            FilesCreated = $filesCreated
            SizeBefore = $beforeStats.TotalSize
            SizeAfter = $afterStats.TotalSize
            SizeIncrease = $sizeIncrease
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        }
        
        $results += $result
        $callNumber++
    }
    
    # Get final state
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-ColoredOutput "Getting final state of $part10Dir..." "INFO"
    $finalStats = Get-DirectoryStats -Path $part10Dir
    Write-ColoredOutput "Final state: $($finalStats.Directories) directories, $($finalStats.Files) files, $(Format-Size $finalStats.TotalSize)" "INFO"
    
    $totalDirChange = $finalStats.Directories - $initialStats.Directories
    $totalFileChange = $finalStats.Files - $initialStats.Files
    $totalSizeChange = $finalStats.TotalSize - $initialStats.TotalSize
    
    Write-ColoredOutput "Overall changes: +$totalDirChange directories, +$totalFileChange files, +$(Format-Size $totalSizeChange)" "SUCCESS"
    
    # Create summary
    $summary = @{
        TestName = "Part10 REST API Test"
        ExecutionTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        TotalApiCalls = $apiCalls.Count
        SuccessfulCalls = ($results | Where-Object { $_.Success }).Count
        FailedCalls = ($results | Where-Object { -not $_.Success }).Count
        InitialDirectories = $initialStats.Directories
        InitialFiles = $initialStats.Files
        InitialSize = $initialStats.TotalSize
        FinalDirectories = $finalStats.Directories
        FinalFiles = $finalStats.Files
        FinalSize = $finalStats.TotalSize
        TotalDirectoriesCreated = $totalDirChange
        TotalFilesCreated = $totalFileChange
        TotalSizeIncrease = $totalSizeChange
        Results = $results
    }
    
    # Save results to JSON file
    Write-ColoredOutput "Saving results to $resultsFile..." "INFO"
    $summary | ConvertTo-Json -Depth 10 | Out-File -FilePath $resultsFile -Encoding UTF8 -Force
    Write-ColoredOutput "Results saved successfully" "SUCCESS"
    
    # Final summary
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "Part10 REST API Test Completed!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Total API Calls: $($apiCalls.Count)" -ForegroundColor Cyan
    Write-Host "Successful: $($summary.SuccessfulCalls)" -ForegroundColor Green
    Write-Host "Failed: $($summary.FailedCalls)" -ForegroundColor $(if ($summary.FailedCalls -gt 0) { 'Red' } else { 'Gray' })
    Write-Host "Directories Created: +$totalDirChange" -ForegroundColor Cyan
    Write-Host "Files Created: +$totalFileChange" -ForegroundColor Cyan
    Write-Host "Size Increase: +$(Format-Size $totalSizeChange)" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Green
    
    Write-ColoredOutput "Part10 REST API test completed successfully" "SUCCESS"
    exit 0
}
catch {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "Part10 REST API Test Script Failed!" -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Red
    
    Write-ColoredOutput "Part10 REST API test script failed: $_" "ERROR"
    Write-Host "Error: $_" -ForegroundColor Red
    
    # Save error to results file
    $errorSummary = @{
        TestName = "Part10 REST API Test"
        ExecutionTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Success = $false
        Error = $_.Exception.Message
        Results = @()
    }
    
    $errorSummary | ConvertTo-Json -Depth 10 | Out-File -FilePath $resultsFile -Encoding UTF8 -Force
    
    exit 1
}
