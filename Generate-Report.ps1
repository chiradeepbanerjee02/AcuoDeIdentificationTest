#Requires -Version 5.1

<#
.SYNOPSIS
    Generate HTML report based on DeIdentification installation and test execution.

.DESCRIPTION
    This script generates a comprehensive HTML report (Reports.html) that includes:
    1. Installation status from Install-DeIdentification.ps1 execution
    2. Test execution results from RestDeIdTests.ps1
    3. DeIdentification log analysis

.EXAMPLE
    .\Generate-Report.ps1

.NOTES
    - Run this script after Install-DeIdentification.ps1 and RestDeIdTests.ps1
    - The report will be generated in the current directory as Reports.html
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
$installLogDir = Join-Path $env:TEMP "AcuoDeIdentificationInstall"
$deidentifyLogPath = "C:\Windows\tracing\DeidentifyLog\DeidentifyLog.txt"

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

# Function to get the most recent installation log
function Get-InstallationLog {
    Write-ColoredOutput "Searching for installation logs..." "INFO"
    
    if (-not (Test-Path $installLogDir)) {
        Write-ColoredOutput "Installation log directory not found: $installLogDir" "WARNING"
        return @{
            Found = $false
            Status = "Not Found"
            Details = "Installation log directory does not exist"
        }
    }
    
    $logFiles = Get-ChildItem -Path $installLogDir -Filter "Install-AcuoDeIdentification-*.log" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
    
    if ($null -eq $logFiles) {
        Write-ColoredOutput "No installation log files found" "WARNING"
        return @{
            Found = $false
            Status = "Not Found"
            Details = "No installation log files found in directory"
        }
    }
    
    Write-ColoredOutput "Found installation log: $($logFiles.FullName)" "SUCCESS"
    
    try {
        $logContent = Get-Content -Path $logFiles.FullName -Raw
        
        # Determine installation status from log
        $status = "Unknown"
        $details = ""
        
        if ($logContent -match "Installation script completed successfully") {
            $status = "Success"
            $details = "Installation completed successfully"
        }
        elseif ($logContent -match "Installation script failed") {
            $status = "Failed"
            $details = "Installation failed - check log for details"
        }
        elseif ($logContent -match "Installation completed with exit code: 0") {
            $status = "Success"
            $details = "Installation completed with exit code 0"
        }
        else {
            $status = "Unknown"
            $details = "Could not determine installation status from log"
        }
        
        return @{
            Found = $true
            Status = $status
            Details = $details
            LogPath = $logFiles.FullName
            LogContent = $logContent
            Timestamp = $logFiles.LastWriteTime
        }
    }
    catch {
        Write-ColoredOutput "Error reading installation log: $_" "ERROR"
        return @{
            Found = $false
            Status = "Error"
            Details = "Failed to read installation log: $_"
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
        $logLines = @(Get-Content -Path $deidentifyLogPath -Tail 50)
        
        if ($logLines.Count -lt 2) {
            return @{
                Found = $true
                Status = "Incomplete"
                Details = "Log file has insufficient entries"
                LogPath = $deidentifyLogPath
                RecentEntries = $logLines
            }
        }
        
        # Get the second last line (most recent completion status)
        $secondLastLine = $logLines[-2]
        $lastLine = $logLines[-1]
        
        $status = "Unknown"
        $details = ""
        
        # Check for successful completion
        if ($secondLastLine -match "Job ID: 100.*successful 1.*failed 0.*completionPercentage: 100%") {
            $status = "Success"
            $details = "DeIdentification processing completed successfully"
        }
        elseif ($secondLastLine -match "failed [1-9]") {
            $status = "Failed"
            $details = "DeIdentification processing had failures"
        }
        else {
            $status = "In Progress"
            $details = "Processing status unclear or still in progress"
        }
        
        return @{
            Found = $true
            Status = $status
            Details = $details
            LogPath = $deidentifyLogPath
            SecondLastLine = $secondLastLine
            LastLine = $lastLine
            TotalLines = $logLines.Count
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

# Function to generate HTML report
function New-HtmlReport {
    param(
        [hashtable]$InstallLog,
        [hashtable]$DeIdentLog
    )
    
    Write-ColoredOutput "Generating HTML report..." "INFO"
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $overallStatus = "Unknown"
    
    # Determine overall status
    if ($InstallLog.Status -eq "Success" -and $DeIdentLog.Status -eq "Success") {
        $overallStatus = "PASSED"
        $statusColor = "#28a745"
        $statusIcon = "✓"
    }
    elseif ($InstallLog.Status -eq "Failed" -or $DeIdentLog.Status -eq "Failed") {
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
                            <span class="status-badge status-$(($InstallLog.Status).ToLower())">$($InstallLog.Status)</span>
                        </div>
                        
                        <div class="info-label">Details:</div>
                        <div class="info-value">$($InstallLog.Details)</div>
                        
$(if ($InstallLog.Found) {
"                        <div class='info-label'>Log File:</div>
                        <div class='info-value'>$($InstallLog.LogPath)</div>
                        
                        <div class='info-label'>Timestamp:</div>
                        <div class='info-value'>$($InstallLog.Timestamp)</div>"
})
                    </div>
$(if ($InstallLog.Found -and $InstallLog.LogContent) {
"                    <div style='margin-top: 15px;'>
                        <strong>Installation Log Preview:</strong>
                        <div class='log-preview'>$([System.Web.HttpUtility]::HtmlEncode($InstallLog.LogContent.Substring(0, [Math]::Min(2000, $InstallLog.LogContent.Length))))</div>
                    </div>"
})
                </div>
            </div>
            
            <!-- DeIdentification Test Section -->
            <div class="section">
                <div class="section-header">
                    DeIdentification Test Results
                </div>
                <div class="section-body">
                    <div class="info-grid">
                        <div class="info-label">Status:</div>
                        <div class="info-value">
                            <span class="status-badge status-$(($DeIdentLog.Status).ToLower())">$($DeIdentLog.Status)</span>
                        </div>
                        
                        <div class="info-label">Details:</div>
                        <div class="info-value">$($DeIdentLog.Details)</div>
                        
$(if ($DeIdentLog.Found) {
"                        <div class='info-label'>Log File:</div>
                        <div class='info-value'>$($DeIdentLog.LogPath)</div>
                        
                        <div class='info-label'>Total Log Lines:</div>
                        <div class='info-value'>$($DeIdentLog.TotalLines)</div>"
})
                    </div>
$(if ($DeIdentLog.Found -and $DeIdentLog.SecondLastLine) {
"                    <div style='margin-top: 15px;'>
                        <strong>Recent Log Entries:</strong>
                        <div class='log-preview'>Second Last Line: $([System.Web.HttpUtility]::HtmlEncode($DeIdentLog.SecondLastLine))

Last Line: $([System.Web.HttpUtility]::HtmlEncode($DeIdentLog.LastLine))</div>
                    </div>"
})
                </div>
            </div>
            
            <!-- Summary Statistics -->
            <div class="summary-stats">
                <div class="stat-item">
                    <div class="stat-value">2</div>
                    <div class="stat-label">Test Phases</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value">$(if ($InstallLog.Status -eq 'Success' -and $DeIdentLog.Status -eq 'Success') { '100%' } elseif ($InstallLog.Status -eq 'Success' -or $DeIdentLog.Status -eq 'Success') { '50%' } else { '0%' })</div>
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
    Write-Host "`n[Step 1/3] Analyzing installation logs..." -ForegroundColor Cyan
    $installLog = Get-InstallationLog
    
    # Step 2: Get DeIdentification log
    Write-Host "`n[Step 2/3] Analyzing DeIdentification logs..." -ForegroundColor Cyan
    $deidentLog = Get-DeIdentificationLog
    
    # Step 3: Generate HTML report
    Write-Host "`n[Step 3/3] Generating HTML report..." -ForegroundColor Cyan
    $success = New-HtmlReport -InstallLog $installLog -DeIdentLog $deidentLog
    
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
