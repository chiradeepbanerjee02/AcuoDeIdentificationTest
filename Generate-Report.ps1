#Requires -Version 5.1

<#
.SYNOPSIS
    Generate HTML report based on DeIdentification installation and test execution.

.DESCRIPTION
    This script generates a comprehensive HTML report (Reports.html) that includes:
    1. Installation status by checking if the AcuoDeidentification Windows service is running
    2. Test execution results from InputWatchTest.ps1
    3. DeIdentification log analysis

.EXAMPLE
    .\Generate-Report.ps1

.NOTES
    - Run this script after Install-DeIdentification.ps1 and InputWatchTest.ps1
    - The report will be generated in the current directory as Reports.html
    - Log analysis reads entire log files for comprehensive searching. For very large log files, 
      this may consume significant memory. Consider file size limits in production environments.
#>

[CmdletBinding()]
param()

# Set error action preference
$ErrorActionPreference = "Continue"

# Load required assemblies
Add-Type -AssemblyName System.Web

# Define paths
$scriptDir = $PSScriptRoot
$reportPath = Join-Path $scriptDir "Reports.html"
$deidentifyLogPath = "C:\Windows\tracing\DeidentifyLog\DeidentifyLog.txt"
$outputDirPath = "C:\deidentification\output\DIR_OPTION"

# Define validation patterns
$successPattern = "Job ID: 100.*successful 1.*failed 0.*completionPercentage: 100%"
$failurePattern = "failed [1-9]\d*"
$restApiSuccessPattern = "Job ID: 101.*successful 1.*failed 0.*completionPercentage: 100%"
$accblkSuccessPattern = "for jobID 102 took"
$mrnblkSuccessPattern = "for jobID 103 took"

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

# Function to get the installation status by checking Windows service
function Get-InstallationLog {
    Write-ColoredOutput "Checking AcuoDeidentification Windows service status..." "INFO"
    
    try {
        $service = Get-Service -Name "AcuoDeidentification" -ErrorAction SilentlyContinue
        
        if ($null -eq $service) {
            Write-ColoredOutput "AcuoDeidentification service not found" "WARNING"
            return @{
                Found = $false
                Status = "Not Found"
                Details = "AcuoDeidentification Windows service is not installed"
            }
        }
        
        Write-ColoredOutput "Found AcuoDeidentification service" "SUCCESS"
        Write-ColoredOutput "Service Status: $($service.Status)" "INFO"
        Write-ColoredOutput "Service StartType: $($service.StartType)" "INFO"
        
        # Determine installation status based on service status
        $status = "Unknown"
        $details = ""
        
        if ($service.Status -eq 'Running') {
            $status = "Success"
            $details = "AcuoDeidentification service is running"
        }
        elseif ($service.Status -eq 'Stopped') {
            $status = "Failed"
            $details = "AcuoDeidentification service is installed but not running"
        }
        elseif ($service.Status -eq 'StartPending') {
            $status = "Warning"
            $details = "AcuoDeidentification service is starting"
        }
        elseif ($service.Status -eq 'StopPending') {
            $status = "Warning"
            $details = "AcuoDeidentification service is stopping"
        }
        elseif ($service.Status -eq 'Paused') {
            $status = "Warning"
            $details = "AcuoDeidentification service is paused"
        }
        elseif ($service.Status -eq 'PausePending') {
            $status = "Warning"
            $details = "AcuoDeidentification service is pausing"
        }
        elseif ($service.Status -eq 'ContinuePending') {
            $status = "Warning"
            $details = "AcuoDeidentification service is resuming"
        }
        else {
            $status = "Unknown"
            $details = "AcuoDeidentification service is in $($service.Status) state"
        }
        
        return @{
            Found = $true
            Status = $status
            Details = $details
            ServiceName = $service.Name
            ServiceStatus = $service.Status
            ServiceStartType = $service.StartType
            ServiceDisplayName = $service.DisplayName
        }
    }
    catch {
        Write-ColoredOutput "Error checking Windows service: $_" "ERROR"
        return @{
            Found = $false
            Status = "Error"
            Details = "Failed to check Windows service: $_"
        }
    }
}

# Function to analyze DeIdentification log
function Get-DeIdentificationLog {
    Write-ColoredOutput "Analyzing DeIdentification log..." "INFO"
    
    if (-not (Test-Path $deidentifyLogPath)) {
        Write-ColoredOutput "DeIdentification log not found: $deidentifyLogPath" "WARNING"
        return @{
            Found = $false
            Status = "Not Found"
            Details = "DeIdentification log file does not exist"
        }
    }
    
    try {
        $logLines = @(Get-Content -Path $deidentifyLogPath)
        
        if ($logLines.Count -lt 2) {
            return @{
                Found = $true
                Status = "Incomplete"
                Details = "Log file has insufficient entries"
                LogPath = $deidentifyLogPath
                RecentEntries = $logLines
            }
        }
        
        $lastLine = $logLines[-1]
        
        $status = "Unknown"
        $details = ""
        $successLineFound = $null
        
        # Check for successful completion in the entire log file
        foreach ($line in $logLines) {
            if ($line -match $successPattern) {
                $successLineFound = $line
                break
            }
        }
        
        # Check for folders inside C:\deidentification\output\DIR_OPTION
        $foldersExist = $false
        $folderDetails = ""
        
        if (Test-Path $outputDirPath) {
            $folders = @(Get-ChildItem -Path $outputDirPath -Directory -ErrorAction SilentlyContinue)
            if ($folders.Count -gt 0) {
                $foldersExist = $true
                $folderDetails = "Found $($folders.Count) folder(s) in DIR_OPTION"
                Write-ColoredOutput $folderDetails "SUCCESS"
            } else {
                $folderDetails = "No folders found in DIR_OPTION"
                Write-ColoredOutput $folderDetails "WARNING"
            }
        } else {
            $folderDetails = "DIR_OPTION path does not exist"
            Write-ColoredOutput $folderDetails "WARNING"
        }
        
        # Determine status based on both log and folder checks
        if ($successLineFound -and $foldersExist) {
            $status = "Success"
            $details = "DeIdentification processing completed successfully by placing the text file into inputwatch directory configured in the self hosted runner. $folderDetails"
        }
        elseif ($successLineFound -and -not $foldersExist) {
            $status = "Warning"
            $details = "Success log entry found but $folderDetails"
        }
        elseif (-not $successLineFound -and $foldersExist) {
            $status = "Warning"
            $details = "Folders found in output but success log entry not found in entire log file. $folderDetails"
        }
        else {
            # Check for failures in the entire log file
            $failureFound = $false
            foreach ($line in $logLines) {
                if ($line -match $failurePattern) {
                    $failureFound = $true
                    break
                }
            }
            
            if ($failureFound) {
                $status = "Failed"
                $details = "DeIdentification processing had failures"
            } else {
                $status = "In Progress"
                $details = "Processing status unclear or still in progress. $folderDetails"
            }
        }
        
        return @{
            Found = $true
            Status = $status
            Details = $details
            LogPath = $deidentifyLogPath
            SuccessLine = $successLineFound
            LastLine = $lastLine
            TotalLines = $logLines.Count
            FoldersExist = $foldersExist
            FolderDetails = $folderDetails
        }
    }
    catch {
        Write-ColoredOutput "Error reading DeIdentification log: $_" "ERROR"
        return @{
            Found = $false
            Status = "Error"
            Details = "Failed to read DeIdentification log: $_"
        }
    }
}

# Function to analyze REST API test log
function Get-RestApiTestLog {
    Write-ColoredOutput "Analyzing REST API test log..." "INFO"
    
    if (-not (Test-Path $deidentifyLogPath)) {
        Write-ColoredOutput "DeIdentification log not found: $deidentifyLogPath" "WARNING"
        return @{
            Found = $false
            Status = "Not Found"
            Details = "DeIdentification log file does not exist"
        }
    }
    
    try {
        $logLines = @(Get-Content -Path $deidentifyLogPath)
        
        if ($logLines.Count -lt 2) {
            return @{
                Found = $true
                Status = "Incomplete"
                Details = "Log file has insufficient entries"
                LogPath = $deidentifyLogPath
                RecentEntries = $logLines
            }
        }
        
        $lastLine = $logLines[-1]
        
        $status = "Unknown"
        $details = ""
        $successLineFound = $null
        
        # Check for successful completion in the entire log file
        foreach ($line in $logLines) {
            if ($line -match $restApiSuccessPattern) {
                $successLineFound = $line
                break
            }
        }
        
        # Determine status based on log check
        if ($successLineFound) {
            $status = "Success"
            $details = "REST API call completed successfully with Job ID 101"
        }
        else {
            # Check for failures in the entire log file
            $failureFound = $false
            foreach ($line in $logLines) {
                if ($line -match $failurePattern) {
                    $failureFound = $true
                    break
                }
            }
            
            if ($failureFound) {
                $status = "Failed"
                $details = "REST API call had failures"
            } else {
                $status = "In Progress"
                $details = "REST API call status unclear or still in progress"
            }
        }
        
        return @{
            Found = $true
            Status = $status
            Details = $details
            LogPath = $deidentifyLogPath
            SuccessLine = $successLineFound
            LastLine = $lastLine
            TotalLines = $logLines.Count
        }
    }
    catch {
        Write-ColoredOutput "Error reading REST API test log: $_" "ERROR"
        return @{
            Found = $false
            Status = "Error"
            Details = "Failed to read REST API test log: $_"
        }
    }
}

# Function to analyze ACCBLK test log
function Get-AccblkTestLog {
    Write-ColoredOutput "Analyzing ACCBLK test log..." "INFO"
    
    if (-not (Test-Path $deidentifyLogPath)) {
        Write-ColoredOutput "DeIdentification log not found: $deidentifyLogPath" "WARNING"
        return @{
            Found = $false
            Status = "Not Found"
            Details = "DeIdentification log file does not exist"
        }
    }
    
    try {
        $logLines = @(Get-Content -Path $deidentifyLogPath)
        
        if ($logLines.Count -lt 2) {
            return @{
                Found = $true
                Status = "Incomplete"
                Details = "Log file has insufficient entries"
                LogPath = $deidentifyLogPath
                RecentEntries = $logLines
            }
        }
        
        $lastLine = $logLines[-1]
        
        $status = "Unknown"
        $details = ""
        $successLineFound = $null
        
        # Check for successful completion in the entire log file
        foreach ($line in $logLines) {
            if ($line -match $accblkSuccessPattern) {
                $successLineFound = $line
                break
            }
        }
        
        # Determine status based on log check
        if ($successLineFound) {
            $status = "Success"
            $details = "ACCBLK test completed successfully with Job ID 102"
        }
        else {
            # Check for failures in the entire log file
            $failureFound = $false
            foreach ($line in $logLines) {
                if ($line -match $failurePattern) {
                    $failureFound = $true
                    break
                }
            }
            
            if ($failureFound) {
                $status = "Failed"
                $details = "ACCBLK test had failures"
            } else {
                $status = "In Progress"
                $details = "ACCBLK test status unclear or still in progress"
            }
        }
        
        return @{
            Found = $true
            Status = $status
            Details = $details
            LogPath = $deidentifyLogPath
            SuccessLine = $successLineFound
            LastLine = $lastLine
            TotalLines = $logLines.Count
        }
    }
    catch {
        Write-ColoredOutput "Error reading ACCBLK test log: $_" "ERROR"
        return @{
            Found = $false
            Status = "Error"
            Details = "Failed to read ACCBLK test log: $_"
        }
    }
}

# Function to analyze MRNBLK test log
function Get-MrnblkTestLog {
    Write-ColoredOutput "Analyzing MRNBLK test log..." "INFO"
    
    if (-not (Test-Path $deidentifyLogPath)) {
        Write-ColoredOutput "DeIdentification log not found: $deidentifyLogPath" "WARNING"
        return @{
            Found = $false
            Status = "Not Found"
            Details = "DeIdentification log file does not exist"
        }
    }
    
    try {
        $logLines = @(Get-Content -Path $deidentifyLogPath)
        
        if ($logLines.Count -lt 1) {
            return @{
                Found = $true
                Status = "Incomplete"
                Details = "Log file has insufficient entries"
                LogPath = $deidentifyLogPath
                RecentEntries = $logLines
            }
        }
        
        $lastLine = $logLines[-1]
        
        $status = "Unknown"
        $details = ""
        $successLineFound = $null
        
        # Check for successful completion in the entire log file
        foreach ($line in $logLines) {
            if ($line -match $mrnblkSuccessPattern) {
                $successLineFound = $line
                break
            }
        }
        
        # Determine status based on log check
        if ($successLineFound) {
            $status = "Success"
            $details = "MRNBLK test completed successfully with Job ID 103"
        }
        else {
            # Check for failures in the entire log file
            $failureFound = $false
            foreach ($line in $logLines) {
                if ($line -match $failurePattern) {
                    $failureFound = $true
                    break
                }
            }
            
            if ($failureFound) {
                $status = "Failed"
                $details = "MRNBLK test had failures"
            } else {
                $status = "In Progress"
                $details = "MRNBLK test status unclear or still in progress"
            }
        }
        
        return @{
            Found = $true
            Status = $status
            Details = $details
            LogPath = $deidentifyLogPath
            SuccessLine = $successLineFound
            LastLine = $lastLine
            TotalLines = $logLines.Count
        }
    }
    catch {
        Write-ColoredOutput "Error reading MRNBLK test log: $_" "ERROR"
        return @{
            Found = $false
            Status = "Error"
            Details = "Failed to read MRNBLK test log: $_"
        }
    }
}

# Function to read Part10 test results
function Get-Part10TestResults {
    Write-ColoredOutput "Reading Part10 test results..." "INFO"
    
    $resultsFilePath = Join-Path $scriptDir "Part10TestResults.json"
    
    if (-not (Test-Path $resultsFilePath)) {
        Write-ColoredOutput "Part10 test results file not found: $resultsFilePath" "WARNING"
        return @{
            Found = $false
            Status = "Not Found"
            Details = "Part10 test results file does not exist. Test may not have been run."
        }
    }
    
    try {
        $resultsJson = Get-Content -Path $resultsFilePath -Raw | ConvertFrom-Json
        
        if (-not $resultsJson) {
            return @{
                Found = $true
                Status = "Error"
                Details = "Part10 test results file is empty or invalid"
            }
        }
        
        # Determine overall status
        $status = "Unknown"
        $details = ""
        
        if ($resultsJson.PSObject.Properties['Success'] -and -not $resultsJson.Success) {
            $status = "Failed"
            $details = "Part10 test execution failed: $($resultsJson.Error)"
        }
        elseif ($resultsJson.TotalApiCalls -gt 0) {
            if ($resultsJson.FailedCalls -eq 0) {
                $status = "Success"
                $details = "All $($resultsJson.TotalApiCalls) API calls completed successfully"
            }
            elseif ($resultsJson.SuccessfulCalls -gt 0) {
                $status = "Partial"
                $details = "$($resultsJson.SuccessfulCalls) of $($resultsJson.TotalApiCalls) API calls succeeded"
            }
            else {
                $status = "Failed"
                $details = "All $($resultsJson.TotalApiCalls) API calls failed"
            }
        }
        else {
            $status = "No Data"
            $details = "No API calls were processed"
        }
        
        Write-ColoredOutput "Part10 test results loaded successfully" "SUCCESS"
        Write-ColoredOutput "Status: $status - $details" "INFO"
        
        return @{
            Found = $true
            Status = $status
            Details = $details
            TestData = $resultsJson
            ResultsFile = $resultsFilePath
        }
    }
    catch {
        Write-ColoredOutput "Error reading Part10 test results: $_" "ERROR"
        return @{
            Found = $false
            Status = "Error"
            Details = "Failed to read Part10 test results: $_"
        }
    }
}

# Function to generate HTML report
function New-HtmlReport {
    param(
        [hashtable]$InstallLog,
        [hashtable]$DeIdentLog,
        [hashtable]$RestApiLog,
        [hashtable]$AccblkLog,
        [hashtable]$MrnblkLog,
        [hashtable]$Part10Log
    )
    
    Write-ColoredOutput "Generating HTML report..." "INFO"
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $overallStatus = "Unknown"
    
    # Determine overall status
    if ($InstallLog.Status -eq "Success" -and $DeIdentLog.Status -eq "Success" -and $RestApiLog.Status -eq "Success" -and $AccblkLog.Status -eq "Success" -and $MrnblkLog.Status -eq "Success" -and $Part10Log.Status -eq "Success") {
        $overallStatus = "PASSED"
        $statusColor = "#28a745"
        $statusIcon = "✓"
    }
    elseif ($InstallLog.Status -eq "Failed" -or $DeIdentLog.Status -eq "Failed" -or $RestApiLog.Status -eq "Failed" -or $AccblkLog.Status -eq "Failed" -or $MrnblkLog.Status -eq "Failed" -or $Part10Log.Status -eq "Failed") {
        $overallStatus = "FAILED"
        $statusColor = "#dc3545"
        $statusIcon = "✗"
    }
    else {
        $overallStatus = "WARNING"
        $statusColor = "#ffc107"
        $statusIcon = "⚠"
    }
    
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AcuoDeIdentification Test Report</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: #f5f5f5;
            padding: 20px;
            line-height: 1.6;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 28px;
            margin-bottom: 10px;
        }
        
        .header p {
            opacity: 0.9;
            font-size: 14px;
        }
        
        .status-banner {
            padding: 20px 30px;
            text-align: center;
            font-size: 24px;
            font-weight: bold;
            background: $statusColor;
            color: white;
        }
        
        .content {
            padding: 30px;
        }
        
        .section {
            margin-bottom: 30px;
            border: 1px solid #e0e0e0;
            border-radius: 6px;
            overflow: hidden;
        }
        
        .section-header {
            background: #f8f9fa;
            padding: 15px 20px;
            border-bottom: 1px solid #e0e0e0;
            font-weight: 600;
            font-size: 18px;
            color: #333;
        }
        
        .section-body {
            padding: 20px;
        }
        
        .info-grid {
            display: grid;
            grid-template-columns: 200px 1fr;
            gap: 15px;
            margin-bottom: 15px;
        }
        
        .info-label {
            font-weight: 600;
            color: #666;
        }
        
        .info-value {
            color: #333;
        }
        
        .status-badge {
            display: inline-block;
            padding: 5px 12px;
            border-radius: 4px;
            font-size: 14px;
            font-weight: 600;
        }
        
        .status-success {
            background: #d4edda;
            color: #155724;
        }
        
        .status-failed {
            background: #f8d7da;
            color: #721c24;
        }
        
        .status-warning {
            background: #fff3cd;
            color: #856404;
        }
        
        .status-unknown {
            background: #e2e3e5;
            color: #383d41;
        }
        
        .status-error {
            background: #f8d7da;
            color: #721c24;
        }
        
        .status-notfound {
            background: #e2e3e5;
            color: #383d41;
        }
        
        .status-incomplete {
            background: #fff3cd;
            color: #856404;
        }
        
        .status-inprogress {
            background: #cfe2ff;
            color: #084298;
        }
        
        .log-preview {
            background: #f8f9fa;
            border: 1px solid #dee2e6;
            border-radius: 4px;
            padding: 15px;
            font-family: 'Courier New', Courier, monospace;
            font-size: 13px;
            color: #333;
            overflow-x: auto;
            white-space: pre-wrap;
            max-height: 200px;
            overflow-y: auto;
        }
        
        .footer {
            background: #f8f9fa;
            padding: 20px 30px;
            text-align: center;
            color: #666;
            font-size: 14px;
            border-top: 1px solid #e0e0e0;
        }
        
        .summary-stats {
            display: flex;
            justify-content: space-around;
            margin: 20px 0;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 6px;
        }
        
        .stat-item {
            text-align: center;
        }
        
        .stat-value {
            font-size: 32px;
            font-weight: bold;
            color: #667eea;
        }
        
        .stat-label {
            font-size: 14px;
            color: #666;
            margin-top: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>AcuoDeIdentification Test Report</h1>
            <p>Generated on: $timestamp</p>
        </div>
        
        <div class="status-banner">
            $statusIcon Overall Status: $overallStatus
        </div>
        
        <div class="content">
            <!-- Installation Section -->
            <div class="section">
                <div class="section-header">
                    Installation Status
                </div>
                <div class="section-body">
                    <div class="info-grid">
                        <div class="info-label">Status:</div>
                        <div class="info-value">
                            <span class="status-badge status-$(($InstallLog.Status -replace ' ', '').ToLower())">$($InstallLog.Status)</span>
                        </div>
                        
                        <div class="info-label">Details:</div>
                        <div class="info-value">$($InstallLog.Details)</div>
                        
$(if ($InstallLog.Found) {
"                        <div class='info-label'>Service Name:</div>
                        <div class='info-value'>$($InstallLog.ServiceName)</div>
                        
                        <div class='info-label'>Service Status:</div>
                        <div class='info-value'>$($InstallLog.ServiceStatus)</div>
                        
                        <div class='info-label'>Service Start Type:</div>
                        <div class='info-value'>$($InstallLog.ServiceStartType)</div>
                        
                        <div class='info-label'>Display Name:</div>
                        <div class='info-value'>$($InstallLog.ServiceDisplayName)</div>"
})
                    </div>
                </div>
            </div>
            
            <!-- DeIdentification Test Section -->
            <div class="section">
                <div class="section-header">
                    Inputwatch Test Results
                </div>
                <div class="section-body">
                    <div class="info-grid">
                        <div class="info-label">Status:</div>
                        <div class="info-value">
                            <span class="status-badge status-$(($DeIdentLog.Status -replace ' ', '').ToLower())">$($DeIdentLog.Status)</span>
                        </div>
                        
                        <div class="info-label">Details:</div>
                        <div class="info-value">$($DeIdentLog.Details)</div>
                        
$(if ($DeIdentLog.Found) {
"                        <div class='info-label'>Log File:</div>
                        <div class='info-value'>$($DeIdentLog.LogPath)</div>
                        
                        <div class='info-label'>Total Log Lines:</div>
                        <div class='info-value'>$($DeIdentLog.TotalLines)</div>
                        
                        <div class='info-label'>Folders in DIR_OPTION:</div>
                        <div class='info-value'>$($DeIdentLog.FolderDetails)</div>"
})
                    </div>
$(if ($DeIdentLog.Found -and $DeIdentLog.SuccessLine) {
"                    <div style='margin-top: 15px;'>
                        <strong>Success Log Entry Found:</strong>
                        <div class='log-preview'>$([System.Web.HttpUtility]::HtmlEncode($DeIdentLog.SuccessLine))</div>
                    </div>"
})
$(if ($DeIdentLog.Found -and $DeIdentLog.LastLine) {
"                    <div style='margin-top: 15px;'>
                        <strong>Last Log Entry:</strong>
                        <div class='log-preview'>$([System.Web.HttpUtility]::HtmlEncode($DeIdentLog.LastLine))</div>
                    </div>"
})
                </div>
            </div>
            
            <!-- Rest API call test Section -->
            <div class="section">
                <div class="section-header">
                    Rest API call test
                </div>
                <div class="section-body">
                    <div class="info-grid">
                        <div class="info-label">Status:</div>
                        <div class="info-value">
                            <span class="status-badge status-$(($RestApiLog.Status -replace ' ', '').ToLower())">$($RestApiLog.Status)</span>
                        </div>
                        
                        <div class="info-label">Details:</div>
                        <div class="info-value">$($RestApiLog.Details)</div>
                        
$(if ($RestApiLog.Found) {
"                        <div class='info-label'>Log File:</div>
                        <div class='info-value'>$($RestApiLog.LogPath)</div>
                        
                        <div class='info-label'>Total Log Lines:</div>
                        <div class='info-value'>$($RestApiLog.TotalLines)</div>"
})
                    </div>
$(if ($RestApiLog.Found -and $RestApiLog.SuccessLine) {
"                    <div style='margin-top: 15px;'>
                        <strong>Success Log Entry Found:</strong>
                        <div class='log-preview'>$([System.Web.HttpUtility]::HtmlEncode($RestApiLog.SuccessLine))</div>
                    </div>"
})
$(if ($RestApiLog.Found -and $RestApiLog.LastLine) {
"                    <div style='margin-top: 15px;'>
                        <strong>Last Log Entry:</strong>
                        <div class='log-preview'>$([System.Web.HttpUtility]::HtmlEncode($RestApiLog.LastLine))</div>
                    </div>"
})
                </div>
            </div>
            
            <!-- ACCBLK Test Section -->
            <div class="section">
                <div class="section-header">
                    ACCBLK Test Results
                </div>
                <div class="section-body">
                    <div class="info-grid">
                        <div class="info-label">Status:</div>
                        <div class="info-value">
                            <span class="status-badge status-$(($AccblkLog.Status -replace ' ', '').ToLower())">$($AccblkLog.Status)</span>
                        </div>
                        
                        <div class="info-label">Details:</div>
                        <div class="info-value">$($AccblkLog.Details)</div>
                        
$(if ($AccblkLog.Found) {
"                        <div class='info-label'>Log File:</div>
                        <div class='info-value'>$($AccblkLog.LogPath)</div>
                        
                        <div class='info-label'>Total Log Lines:</div>
                        <div class='info-value'>$($AccblkLog.TotalLines)</div>"
})
                    </div>
$(if ($AccblkLog.Found -and $AccblkLog.SuccessLine) {
"                    <div style='margin-top: 15px;'>
                        <strong>Success Log Entry Found:</strong>
                        <div class='log-preview'>$([System.Web.HttpUtility]::HtmlEncode($AccblkLog.SuccessLine))</div>
                    </div>"
})
$(if ($AccblkLog.Found -and $AccblkLog.LastLine) {
"                    <div style='margin-top: 15px;'>
                        <strong>Last Log Entry:</strong>
                        <div class='log-preview'>$([System.Web.HttpUtility]::HtmlEncode($AccblkLog.LastLine))</div>
                    </div>"
})
                </div>
            </div>
            
            <!-- MRNBLK Test Section -->
            <div class="section">
                <div class="section-header">
                    MRNBLK Test Results
                </div>
                <div class="section-body">
                    <div class="info-grid">
                        <div class="info-label">Status:</div>
                        <div class="info-value">
                            <span class="status-badge status-$(($MrnblkLog.Status -replace ' ', '').ToLower())">$($MrnblkLog.Status)</span>
                        </div>
                        
                        <div class="info-label">Details:</div>
                        <div class="info-value">$($MrnblkLog.Details)</div>
                        
$(if ($MrnblkLog.Found) {
"                        <div class='info-label'>Log File:</div>
                        <div class='info-value'>$($MrnblkLog.LogPath)</div>
                        
                        <div class='info-label'>Total Log Lines:</div>
                        <div class='info-value'>$($MrnblkLog.TotalLines)</div>"
})
                    </div>
$(if ($MrnblkLog.Found -and $MrnblkLog.SuccessLine) {
"                    <div style='margin-top: 15px;'>
                        <strong>Success Log Entry Found:</strong>
                        <div class='log-preview'>$([System.Web.HttpUtility]::HtmlEncode($MrnblkLog.SuccessLine))</div>
                    </div>"
})
$(if ($MrnblkLog.Found -and $MrnblkLog.LastLine) {
"                    <div style='margin-top: 15px;'>
                        <strong>Last Log Entry:</strong>
                        <div class='log-preview'>$([System.Web.HttpUtility]::HtmlEncode($MrnblkLog.LastLine))</div>
                    </div>"
})
                </div>
            </div>
            
            <!-- Part10 REST API Test Section -->
            <div class="section">
                <div class="section-header">
                    Part10 REST API Test Results
                </div>
                <div class="section-body">
                    <div class="info-grid">
                        <div class="info-label">Status:</div>
                        <div class="info-value">
                            <span class="status-badge status-$(($Part10Log.Status -replace ' ', '').ToLower())">$($Part10Log.Status)</span>
                        </div>
                        
                        <div class="info-label">Details:</div>
                        <div class="info-value">$($Part10Log.Details)</div>
                        
$(if ($Part10Log.Found -and $Part10Log.TestData) {
    $testData = $Part10Log.TestData
"                        <div class='info-label'>Total API Calls:</div>
                        <div class='info-value'>$($testData.TotalApiCalls)</div>
                        
                        <div class='info-label'>Successful Calls:</div>
                        <div class='info-value' style='color: #28a745; font-weight: bold;'>$($testData.SuccessfulCalls)</div>
                        
                        <div class='info-label'>Failed Calls:</div>
                        <div class='info-value' style='color: $(if ($testData.FailedCalls -gt 0) { '#dc3545' } else { '#6c757d' }); font-weight: bold;'>$($testData.FailedCalls)</div>
                        
                        <div class='info-label'>Total Directories Created:</div>
                        <div class='info-value' style='color: #007bff; font-weight: bold;'>$($testData.TotalDirectoriesCreated)</div>
                        
                        <div class='info-label'>Total Files Created:</div>
                        <div class='info-value' style='color: #007bff; font-weight: bold;'>$($testData.TotalFilesCreated)</div>
                        
                        <div class='info-label'>Total Size Increase:</div>
                        <div class='info-value' style='color: #007bff; font-weight: bold;'>$(
                            if ($testData.TotalSizeIncrease -eq 0) { '0 B' }
                            elseif ($testData.TotalSizeIncrease -lt 1KB) { '{0} B' -f $testData.TotalSizeIncrease }
                            elseif ($testData.TotalSizeIncrease -lt 1MB) { '{0:N2} KB' -f ($testData.TotalSizeIncrease / 1KB) }
                            elseif ($testData.TotalSizeIncrease -lt 1GB) { '{0:N2} MB' -f ($testData.TotalSizeIncrease / 1MB) }
                            else { '{0:N2} GB' -f ($testData.TotalSizeIncrease / 1GB) }
                        )</div>"
})
                    </div>
$(if ($Part10Log.Found -and $Part10Log.TestData -and $Part10Log.TestData.Results) {
"                    <div style='margin-top: 20px;'>
                        <strong>API Call Details:</strong>
                        <table style='width: 100%; margin-top: 10px; border-collapse: collapse;'>
                            <thead>
                                <tr style='background: #f8f9fa; border-bottom: 2px solid #dee2e6;'>
                                    <th style='padding: 10px; text-align: left; border: 1px solid #dee2e6;'>#</th>
                                    <th style='padding: 10px; text-align: left; border: 1px solid #dee2e6;'>URL</th>
                                    <th style='padding: 10px; text-align: center; border: 1px solid #dee2e6;'>Status</th>
                                    <th style='padding: 10px; text-align: center; border: 1px solid #dee2e6;'>Dirs +</th>
                                    <th style='padding: 10px; text-align: center; border: 1px solid #dee2e6;'>Files +</th>
                                </tr>
                            </thead>
                            <tbody>"
    foreach ($result in $Part10Log.TestData.Results) {
        $statusColor = if ($result.Success) { '#28a745' } else { '#dc3545' }
        $statusText = if ($result.Success) { '✓ Success' } else { '✗ Failed' }
        $truncatedUrl = if ($result.Url.Length -gt 60) { $result.Url.Substring(0, 57) + '...' } else { $result.Url }
"                                <tr style='border-bottom: 1px solid #dee2e6;'>
                                    <td style='padding: 8px; border: 1px solid #dee2e6;'>$($result.CallNumber)</td>
                                    <td style='padding: 8px; border: 1px solid #dee2e6; font-size: 0.9em;' title='$([System.Web.HttpUtility]::HtmlEncode($result.Url))'>$([System.Web.HttpUtility]::HtmlEncode($truncatedUrl))</td>
                                    <td style='padding: 8px; text-align: center; border: 1px solid #dee2e6; color: $statusColor; font-weight: bold;'>$statusText</td>
                                    <td style='padding: 8px; text-align: center; border: 1px solid #dee2e6; font-weight: bold;'>$($result.DirectoriesCreated)</td>
                                    <td style='padding: 8px; text-align: center; border: 1px solid #dee2e6; font-weight: bold;'>$($result.FilesCreated)</td>
                                </tr>"
    }
"                            </tbody>
                        </table>
                    </div>"
})
                </div>
            </div>
            
            <!-- Summary Statistics -->
            <div class="summary-stats">
                <div class="stat-item">
                    <div class="stat-value">6</div>
                    <div class="stat-label">Test Phases</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value">$(
                        $successCount = 0
                        if ($InstallLog.Status -eq 'Success') { $successCount++ }
                        if ($DeIdentLog.Status -eq 'Success') { $successCount++ }
                        if ($RestApiLog.Status -eq 'Success') { $successCount++ }
                        if ($AccblkLog.Status -eq 'Success') { $successCount++ }
                        if ($MrnblkLog.Status -eq 'Success') { $successCount++ }
                        if ($Part10Log.Status -eq 'Success') { $successCount++ }
                        [math]::Round(($successCount / 6) * 100, 0).ToString() + '%'
                    )</div>
                    <div class="stat-label">Success Rate</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value">$overallStatus</div>
                    <div class="stat-label">Final Result</div>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p>AcuoDeIdentification Automated Test Suite</p>
            <p>Report generated by Generate-Report.ps1</p>
        </div>
    </div>
</body>
</html>
"@
    
    try {
        # Write HTML to file
        $html | Out-File -FilePath $reportPath -Encoding UTF8 -Force
        Write-ColoredOutput "Report generated successfully: $reportPath" "SUCCESS"
        return $true
    }
    catch {
        Write-ColoredOutput "Error generating report: $_" "ERROR"
        return $false
    }
}

# Main execution
try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Generate HTML Report Script" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    Write-ColoredOutput "Report generation started" "INFO"
    
    # Step 1: Get installation log
    Write-Host "`n[Step 1/7] Analyzing installation logs..." -ForegroundColor Cyan
    $installLog = Get-InstallationLog
    
    # Step 2: Get DeIdentification log
    Write-Host "`n[Step 2/7] Analyzing DeIdentification logs..." -ForegroundColor Cyan
    $deidentLog = Get-DeIdentificationLog
    
    # Step 3: Get REST API test log
    Write-Host "`n[Step 3/7] Analyzing REST API test logs..." -ForegroundColor Cyan
    $restApiLog = Get-RestApiTestLog
    
    # Step 4: Get ACCBLK test log
    Write-Host "`n[Step 4/7] Analyzing ACCBLK test logs..." -ForegroundColor Cyan
    $accblkLog = Get-AccblkTestLog
    
    # Step 5: Get MRNBLK test log
    Write-Host "`n[Step 5/7] Analyzing MRNBLK test logs..." -ForegroundColor Cyan
    $mrnblkLog = Get-MrnblkTestLog
    
    # Step 6: Get Part10 test results
    Write-Host "`n[Step 6/7] Reading Part10 test results..." -ForegroundColor Cyan
    $part10Log = Get-Part10TestResults
    
    # Step 7: Generate HTML report
    Write-Host "`n[Step 7/7] Generating HTML report..." -ForegroundColor Cyan
    $success = New-HtmlReport -InstallLog $installLog -DeIdentLog $deidentLog -RestApiLog $restApiLog -AccblkLog $accblkLog -MrnblkLog $mrnblkLog -Part10Log $part10Log
    
    if ($success) {
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host "Report Generated Successfully!" -ForegroundColor Green
        Write-Host "========================================`n" -ForegroundColor Green
        Write-ColoredOutput "Report saved to: $reportPath" "SUCCESS"
        Write-ColoredOutput "Report generation script completed successfully" "SUCCESS"
        exit 0
    }
    else {
        Write-Host "`n========================================" -ForegroundColor Red
        Write-Host "Report Generation Failed!" -ForegroundColor Red
        Write-Host "========================================`n" -ForegroundColor Red
        Write-ColoredOutput "Failed to generate report" "ERROR"
        exit 1
    }
}
catch {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "Report Generation Script Failed!" -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Red
    
    Write-ColoredOutput "Report generation script failed: $_" "ERROR"
    Write-Host "Error: $_" -ForegroundColor Red
    
    exit 1
}
