# AcuoDeIdentificationTest

Automated test suite for Acuo DeIdentification Service installation, configuration, and functional testing.

## Overview

This repository contains PowerShell scripts for installing, configuring, and testing the Acuo DeIdentification service. It includes automated test scripts that verify various deidentification scenarios and generates comprehensive HTML reports of test execution results.

## Contents

### Installation & Setup
- **`AcuoDeidentificationSetup.msi`** - MSI installer for the Acuo DeIdentification service
- **`AcuoDeidentificationService.exe.config`** - Configuration file for the DeIdentification service
- **`Install-DeIdentification.ps1`** - Script to uninstall existing installation and install the service with custom configuration

### Test Scripts
- **`PreRequisites.ps1`** - Pre-test cleanup script that:
  - Cleans output directories (`C:\deidentification\output\DIR_OPTION`)
  - Cleans input watch directories (`C:\deidentification\inputwatch`)
  - Restarts the AcuoDeidentification service
  - Backs up and clears log files
  
- **`InputWatchTest.ps1`** - Tests the input watch functionality by:
  - Copying test profile to input watch directory
  - Waiting for processing completion
  - Verifying successful deidentification in logs (Job ID: 100)

- **`RestApiTest.ps1`** - Tests the REST API endpoint by:
  - Making API calls to the deidentification service
  - Waiting for processing completion
  - Verifying successful completion in logs (Job ID: 101)

- **`Test-Part10RestApi.ps1`** - Tests Part10 REST API functionality by:
  - Force deletes all subdirectories and files under `C:\Acuo\part10` before testing
  - Reads REST API URLs from `AcuoAccessP10Calls.txt`
  - For each URL, triggers the REST API call
  - Scans `C:\Acuo\part10` directory before and after each call
  - Counts directories and files created as a result of each call
  - Archives the part10 directory with timestamp after testing
  - Cleans up part10 directory contents after archiving
  - Saves results to `Part10TestResults.json` for HTML report generation

- **`Job104Test.ps1`** - Tests Job 104 DeIdentification functionality:
  - Copies test profile (Job ID: 104) to input watch directory
  - Waits for processing to complete
  - Verifies successful deidentification in logs
  - Counts new files and folders created in output directory
  - Calculates total size of new files
  - Saves results to `Job104TestResults.json` for HTML report generation

- **`ACCBLKTest.ps1`** - Tests ACCBLK (Accession Number Block) functionality:
  - Processes ACCBLK test profile (Job ID: 102)
  - Verifies block list processing

- **`MRNBLKTest.ps1`** - Tests MRNBLK (Medical Record Number Block) functionality:
  - Processes MRNBLK test profile (Job ID: 103)
  - Verifies block list processing

- **`Generate-Report.ps1`** - Generates comprehensive HTML test report including:
  - Installation status verification
  - Test execution results
  - Log analysis and validation

### Test Data Files
- **`100_DefaultProfile_02142026.txt`** - Default profile for input watch testing (Job ID: 100)
- **`102_DefaultProfile_02182025.txt`** - ACCBLK test profile (Job ID: 102)
- **`103_DefaultProfile_02182025.txt`** - MRNBLK test profile (Job ID: 103)
- **`104_DefaultProfile_02192026.txt`** - Test profile for Job 104 deidentification testing
- **`AcuoAccessP10Calls.txt`** - Contains REST API URLs for Part10 testing
- **`requestbody.txt`** - JSON request body for REST API testing

### GitHub Actions
- **`.github/workflows/test-report.yml`** - Automated CI/CD workflow that:
  - Runs on self-hosted Windows runner
  - Installs the DeIdentification service
  - Executes all test scripts
  - Generates and uploads HTML test reports as artifacts

## Prerequisites

- **Operating System**: Windows (tested on Windows Server/Windows 10+)
- **PowerShell**: Version 5.1 or higher
- **Administrator Privileges**: Required for all operations
- **Self-Hosted GitHub Runner**: Required for CI/CD workflow execution (Windows, X64)

## Installation

1. Clone this repository
2. Run the installation script with administrator privileges:
   ```powershell
   .\Install-DeIdentification.ps1
   ```

This will:
- Uninstall any existing AcuoDeIdentification installation
- Install the service from the MSI package
- Apply the custom configuration
- Start the service

## Usage

### Running Tests Manually

1. **Install the service**:
   ```powershell
   .\Install-DeIdentification.ps1
   ```

2. **Run pre-requisites** (cleans up test environment):
   ```powershell
   .\PreRequisites.ps1
   ```

3. **Run individual tests**:
   ```powershell
   .\InputWatchTest.ps1
   .\RestApiTest.ps1
   .\ACCBLKTest.ps1
   .\MRNBLKTest.ps1
   .\Job104Test.ps1
   .\Test-Part10RestApi.ps1
   ```

4. **Generate HTML report**:
   ```powershell
   .\Generate-Report.ps1
   ```

### Running Tests via GitHub Actions

The tests can be triggered automatically via GitHub Actions:
- Push to `main` or `master` branch
- Create a pull request
- Manual workflow dispatch from the Actions tab

After workflow completion, download the `rest-api-test-report` artifact to view the HTML test report.

## Configuration

The service configuration is controlled by `AcuoDeidentificationService.exe.config`. Key settings include:
- Database connections
- Input/output directories
- REST API endpoints
- Logging configuration

## Test Results

Test results are logged to:
- **Service Log**: `C:\Windows\tracing\DeidentifyLog\DeidentifyLog.txt`
- **HTML Report**: `Reports.html` (generated by `Generate-Report.ps1`)

The HTML report includes:
- Installation status
- Test execution summary
- Detailed test results with pass/fail status
- Log excerpts showing verification points
- Timestamp and environment information

## Directory Structure

```
AcuoDeIdentificationTest/
├── .github/
│   └── workflows/
│       ├── test-report.yml          # CI/CD workflow definition
│       └── README.md                # Workflow documentation
├── AcuoDeidentificationSetup.msi    # Service installer
├── AcuoDeidentificationService.exe.config  # Service configuration
├── Install-DeIdentification.ps1     # Installation script
├── PreRequisites.ps1                # Pre-test cleanup script
├── InputWatchTest.ps1               # Input watch test
├── RestApiTest.ps1                  # REST API test
├── Test-Part10RestApi.ps1           # Part10 REST API test
├── Job104Test.ps1                   # Job 104 deidentification test
├── ACCBLKTest.ps1                   # Accession number block test
├── MRNBLKTest.ps1                   # Medical record number block test
├── Generate-Report.ps1              # Report generation script
├── 100_DefaultProfile_02142026.txt  # Test profile (default)
├── 102_DefaultProfile_02182025.txt  # Test profile (ACCBLK)
├── 103_DefaultProfile_02182025.txt  # Test profile (MRNBLK)
├── 104_DefaultProfile_02192026.txt  # Test profile (Job 104)
├── AcuoAccessP10Calls.txt           # Part10 REST API URLs
├── requestbody.txt                  # REST API request body
└── README.md                        # This file
```

## Notes

- All test scripts require administrator privileges
- Scripts should be run from the repository directory
- The service must be installed before running tests
- Log files can grow large; the `PreRequisites.ps1` script backs up and clears logs before each test run
- Test artifacts are retained for 30 days in GitHub Actions

## License

This is a test automation suite for the Acuo DeIdentification service.
