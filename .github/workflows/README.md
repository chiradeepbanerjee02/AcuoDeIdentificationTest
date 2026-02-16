# GitHub Actions Test Report Workflow

This workflow generates a sample HTML test report on a self-hosted GitHub Actions runner.

## Overview

The workflow is defined in `.github/workflows/test-report.yml` and provides automated test reporting for the Acuo DeIdentification project.

## Features

- **Self-Hosted Runner**: Runs on your self-hosted GitHub Actions runner
- **HTML Test Report**: Generates a professional-looking HTML report with:
  - Test summary with passed/failed counts
  - Detailed test results table
  - Metadata including timestamp, branch, and commit information
  - Responsive design with modern styling
- **Artifact Upload**: Automatically uploads the HTML report as a workflow artifact
- **Manual Trigger**: Supports manual workflow execution via `workflow_dispatch`

## Triggering the Workflow

The workflow can be triggered in three ways:

1. **Push to main/master branch**: Automatically runs when code is pushed
2. **Pull Request**: Runs when a PR is opened against main/master
3. **Manual Trigger**: Go to Actions → Test Report Generation → Run workflow

## Workflow Steps

1. **Checkout code**: Checks out the repository code
2. **Create test report directory**: Creates the `test-reports/` directory
3. **Run sample tests**: Executes sample tests and generates results
4. **Generate HTML report**: Creates a styled HTML test report
5. **Display results**: Shows test summary in the workflow logs
6. **Upload artifacts**: Uploads the HTML report and full test reports as artifacts

## Viewing the Report

After the workflow completes:

1. Go to the Actions tab in your repository
2. Click on the completed workflow run
3. Scroll down to the "Artifacts" section
4. Download `test-report` to get the HTML file
5. Open `test-report.html` in your web browser

## Sample Report Contents

The generated report includes:

- **Summary Cards**: Total, Passed, and Failed test counts
- **Test Results Table**: 
  - Test number
  - Test name
  - Description
  - Status (Pass/Fail)
  - Duration
- **Metadata Section**:
  - Execution date and time
  - Environment (Self-Hosted Runner)
  - Repository information
  - Branch and commit SHA

## Customization

To customize the workflow:

1. Edit `.github/workflows/test-report.yml`
2. Modify the test scenarios in the "Run sample tests" step
3. Update the HTML template in the "Generate HTML report" step
4. Add additional test steps as needed

## Requirements

- A configured self-hosted GitHub Actions runner
- Repository permissions to run GitHub Actions
- Write access to upload artifacts

## Report Retention

Test reports are retained for **30 days** by default. This can be changed by modifying the `retention-days` parameter in the workflow file.
