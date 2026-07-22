$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ResourceGroup = "rg-checkout-assessment-dev"
$ContainerName = "checkout-assessment-dev-mtls-test"
$CertificateDirectory = "C:\Users\tomco\Documents\Repositories\checkout-cloud-platform-secondary-folder\certs"
$RemoteCertificateDirectory = "/mnt/mtls"

$CertificateFiles = @(
    "trusted-client-cert.pem",
    "trusted-client-key.pem",
    "wrong-client-cert.pem",
    "wrong-client-key.pem"
)

function Write-Step {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Invoke-AzureCli {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [Parameter(Mandatory)]
        [string]$Operation,

        [switch]$AllowFailure
    )

    # Capture output so Azure CLI errors can be handled consistently.
    $output = @(& az @Arguments 2>&1)
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        if ($AllowFailure) {
            return $null
        }

        throw "$Operation failed. Azure CLI returned exit code $exitCode."
    }

    return (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
}

function Test-AzureCliInstalled {
    Write-Step "Checking Azure CLI"

    if (-not (Get-Command "az" -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or is not available on PATH."
    }

    Write-Host "Azure CLI is installed." -ForegroundColor Green
}

function Test-AzureLogin {
    Write-Step "Checking Azure login"

    $null = Invoke-AzureCli `
        -Arguments @("account", "show", "--output", "none") `
        -Operation "Azure login check"

    Write-Host "Azure login is valid." -ForegroundColor Green
}

function Test-DemoContainerExists {
    Write-Step "Checking demo container"

    $name = Invoke-AzureCli `
        -Arguments @(
            "container", "show",
            "--resource-group", $ResourceGroup,
            "--name", $ContainerName,
            "--query", "name",
            "--output", "tsv"
        ) `
        -Operation "Container lookup" `
        -AllowFailure

    return -not [string]::IsNullOrWhiteSpace($name)
}

function Get-DemoContainerState {
    $state = Invoke-AzureCli `
        -Arguments @(
            "container", "show",
            "--resource-group", $ResourceGroup,
            "--name", $ContainerName,
            "--query", "instanceView.state",
            "--output", "tsv"
        ) `
        -Operation "Container state check"

    if ([string]::IsNullOrWhiteSpace($state)) {
        throw "Azure CLI did not return the container state."
    }

    return $state.Trim()
}

function Test-LocalCertificateFiles {
    Write-Step "Checking local certificate files"

    $missingFiles = [System.Collections.Generic.List[string]]::new()

    foreach ($fileName in $CertificateFiles) {
        $path = Join-Path -Path $CertificateDirectory -ChildPath $fileName

        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $missingFiles.Add($path)
        }
    }

    if ($missingFiles.Count -gt 0) {
        $formattedPaths = ($missingFiles | ForEach-Object { " - $_" }) -join [Environment]::NewLine
        throw "The following certificate files are missing:$([Environment]::NewLine)$formattedPaths"
    }

    Write-Host "All certificate files are present." -ForegroundColor Green
}

function Show-CertificateProvisioningRequirement {
    Write-Step "Checking certificate provisioning requirements"

    Write-Host `
        "Certificates must be mounted into the container when it is created. This script cannot upload them through az container exec because ACI exec does not support command arguments." `
        -ForegroundColor Yellow

    Write-Host "`nAn Azure Files volume should be mounted at $RemoteCertificateDirectory." -ForegroundColor Yellow
    Write-Host "The demo expects these remote paths:" -ForegroundColor Yellow

    foreach ($fileName in $CertificateFiles) {
        Write-Host " - $RemoteCertificateDirectory/$fileName"
    }

    Write-Host "`nRemote files are not checked by this script." -ForegroundColor Yellow
}

function Show-NextCommands {
    Write-Host "`nContainer and local certificate checks passed." -ForegroundColor Green
    Write-Host "`nRun this command next:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host 'az container exec `'
    Write-Host '    --resource-group rg-checkout-assessment-dev `'
    Write-Host '    --name checkout-assessment-dev-mtls-test `'
    Write-Host '    --exec-command "/bin/sh"'

    Write-Host "`nThen run these commands inside the container:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host 'export CERT_DIR="/mnt/mtls"'
    Write-Host ""
    Write-Host 'export TRUSTED_CLIENT_CERT="${CERT_DIR}/trusted-client-cert.pem"'
    Write-Host ""
    Write-Host 'export TRUSTED_CLIENT_KEY="${CERT_DIR}/trusted-client-key.pem"'
    Write-Host ""
    Write-Host 'export WRONG_CLIENT_CERT="${CERT_DIR}/wrong-client-cert.pem"'
    Write-Host ""
    Write-Host 'export WRONG_CLIENT_KEY="${CERT_DIR}/wrong-client-key.pem"'
    Write-Host ""
    Write-Host 'export APIM_HOST="checkout-assessment-dev-apim.azure-api.net"'
    Write-Host ""
    Write-Host 'export API_URL="https://${APIM_HOST}/process-message"'
    Write-Host ""
    Write-Host 'export FUNCTION_URL="https://checkout-assessment-dev-func.azurewebsites.net/api/process-message"'
    Write-Host ""
    Write-Host "export BODY='{`"message`":`"live interview demo`"}'"
}

function Start-DemoPreparation {
    Test-AzureCliInstalled
    Test-AzureLogin

    if (-not (Test-DemoContainerExists)) {
        Write-Host "`nThe demo container does not exist. Recreate it before running this script." -ForegroundColor Red
        exit 1
    }

    $containerState = Get-DemoContainerState
    if ($containerState -ne "Running") {
        Write-Host "`nThe demo container is not running. Current state: $containerState" -ForegroundColor Red
        exit 1
    }

    Write-Host "Demo container is running." -ForegroundColor Green

    Test-LocalCertificateFiles
    Show-CertificateProvisioningRequirement
    Show-NextCommands
}

try {
    Start-DemoPreparation
}
catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
