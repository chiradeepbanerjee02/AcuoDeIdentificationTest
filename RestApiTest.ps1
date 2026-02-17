#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    REST API Test Script for DeIdentification Service

.DESCRIPTION
    This script performs the following test operations:
    1. Reads the request body from requestbody.txt
    2. Makes a REST API call to the DeIdentification service endpoint
    3. Waits for processing to complete
    4. Verifies the deidentification log for successful completion with Job ID 101

.EXAMPLE
    .\RestApiTest.ps1

.NOTES
    - This script requires Administrator privileges
    - Run this script from the repository directory where requestbody.txt is located
#>

[CmdletBinding()]
param()

# Set error action preference
$ErrorActionPreference = "Stop"

# Define paths and endpoints
$scriptDir = $PSScriptRoot
$requestBodyPath = Join-Path $scriptDir "requestbody.txt"
$deidRestEndpoint = "http://us14-acuo125:8099/AcuoDeidentification/deidentifysync"
$logFilePath = "C:\Windows\tracing\DeidentifyLog\DeidentifyLog.txt"
$expectedLogEntry = "Job ID: 101, Status callback: , successful 1, failed 0, completionPercentage: 100%"

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

# Function to read request body from file
function Get-RequestBody {
    param(
        [string]$FilePath
    )
    
    Write-ColoredOutput "Reading request body from file..." "INFO"
    Write-ColoredOutput "File path: $FilePath" "INFO"
    
    # Check if file exists
    if (-not (Test-Path $FilePath)) {
        Write-ColoredOutput "Request body file not found at: $FilePath" "ERROR"
        throw "Request body file not found"
    }
    
    try {
        $body = Get-Content -Path $FilePath -Raw
        Write-ColoredOutput "Request body loaded successfully" "SUCCESS"
        return $body
    }
    catch {
        Write-ColoredOutput "Error reading request body file: $_" "ERROR"
        throw
    }
}

# Function to invoke REST API
function Invoke-DeidentificationRestApi {
    param(
        [string]$Endpoint,
        [string]$Body
    )
    
    Write-ColoredOutput "Invoking REST API..." "INFO"
    Write-ColoredOutput "Endpoint: $Endpoint" "INFO"
    
    try {
        $response = Invoke-RestMethod `
            -Uri $Endpoint `
            -Headers (@{SOAPAction='Read'}) `
            -Method Post `
            -Body $Body `
            -ContentType 'application/soap+xml' `
            -UseBasicParsing
        
        Write-ColoredOutput "REST API call completed successfully" "SUCCESS"
        Write-ColoredOutput "Response received" "INFO"
        return $response
    }
    catch {
        Write-ColoredOutput "Error invoking REST API: $_" "ERROR"
        Write-ColoredOutput "Exception details: $($_.Exception.Message)" "ERROR"
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
        
        Write-ColoredOutput "Searching entire log file for expected content..." "INFO"
        Write-ColoredOutput "Expected content: $ExpectedContent" "INFO"
        
        # Search through all lines for the expected content
        $found = $false
        foreach ($line in $logLines) {
            if ($line -like "*$ExpectedContent*") {
                Write-ColoredOutput "Verification PASSED: Log entry found!" "SUCCESS"
                Write-ColoredOutput "Matching line: $line" "INFO"
                $found = $true
                break
            }
        }
        
        if (-not $found) {
            Write-ColoredOutput "Verification FAILED: Expected content not found in entire log file" "ERROR"
        }
        
        return $found
    }
    catch {
        Write-ColoredOutput "Error reading log file: $_" "ERROR"
        return $false
    }
}

# Main execution
try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "REST API Test Script" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    Write-ColoredOutput "Test script started" "INFO"
    
    # Check if running as Administrator
    if (-not (Test-Administrator)) {
        Write-ColoredOutput "This script must be run as Administrator!" "ERROR"
        throw "Administrator privileges required"
    }
    
    Write-ColoredOutput "Administrator privileges verified" "SUCCESS"
    
    # Step 1: Read request body
    Write-Host "`n[Step 1/4] Reading request body from file..." -ForegroundColor Cyan
    $body = Get-RequestBody -FilePath $requestBodyPath
    
    # Step 2: Invoke REST API
    Write-Host "`n[Step 2/4] Invoking REST API..." -ForegroundColor Cyan
    $response = Invoke-DeidentificationRestApi -Endpoint $deidRestEndpoint -Body $body
    
    # Step 3: Wait for processing (45 seconds)
    Write-Host "`n[Step 3/4] Waiting for 45 seconds for processing..." -ForegroundColor Cyan
    $waitSeconds = 45
    Write-ColoredOutput "Waiting for $waitSeconds seconds..." "INFO"
    
    for ($i = 0; $i -lt $waitSeconds; $i += 10) {
        $remaining = $waitSeconds - $i
        Write-ColoredOutput "Time remaining: $remaining seconds..." "INFO"
        Start-Sleep -Seconds 10
    }
    
    Write-ColoredOutput "Wait period completed" "SUCCESS"
    
    # Step 4: Verify log file content
    Write-Host "`n[Step 4/4] Verifying log file content..." -ForegroundColor Cyan
    $verificationResult = Test-LogFileContent -LogPath $logFilePath -ExpectedContent $expectedLogEntry
    
    # Final summary
    Write-Host "`n========================================" -ForegroundColor Cyan
    if ($verificationResult) {
        Write-Host "Test PASSED: All verifications successful!" -ForegroundColor Green
        Write-Host "========================================`n" -ForegroundColor Green
        Write-ColoredOutput "REST API test completed successfully" "SUCCESS"
        exit 0
    } else {
        Write-Host "Test FAILED: Verification failed!" -ForegroundColor Red
        Write-Host "========================================`n" -ForegroundColor Red
        Write-ColoredOutput "REST API test failed" "ERROR"
        exit 1
    }
}
catch {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "REST API Test Script Failed!" -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Red
    
    Write-ColoredOutput "REST API test script failed: $_" "ERROR"
    Write-Host "Error: $_" -ForegroundColor Red
    
    exit 1
}
