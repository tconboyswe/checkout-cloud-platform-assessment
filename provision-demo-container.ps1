$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ResourceGroup = "rg-checkout-assessment-dev"
$Location = "uksouth"
$VirtualNetworkName = "checkout-assessment-dev-vnet"
$SubnetName = "checkout-assessment-dev-snet-mtls-test"
$ContainerName = "checkout-assessment-dev-mtls-test"
$ContainerImage = "nicolaka/netshoot:latest"
$CertificateDirectory = "C:\Users\tomco\Documents\Repositories\checkout-cloud-platform-secondary-folder\certs"
$FileShareName = "mtls-demo"
$MountPath = "/mnt/mtls"

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
        [string]$Operation
    )

    # Capture all output and never echo arguments. Some calls contain the
    # storage account key, which must not be written to the terminal.
    $output = @(& az @Arguments 2>&1)
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
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

function Test-AzureResources {
    Write-Step "Checking resource group, virtual network and subnet"

    $resourceGroupExists = Invoke-AzureCli `
        -Arguments @("group", "exists", "--name", $ResourceGroup, "--output", "tsv") `
        -Operation "Resource group check"

    if ($resourceGroupExists -ne "true") {
        throw "Resource group '$ResourceGroup' does not exist."
    }

    $vnet = Invoke-AzureCli `
        -Arguments @(
            "network", "vnet", "list",
            "--resource-group", $ResourceGroup,
            "--query", "[?name=='$VirtualNetworkName'].name | [0]",
            "--output", "tsv"
        ) `
        -Operation "Virtual network check"

    if ([string]::IsNullOrWhiteSpace($vnet)) {
        throw "Virtual network '$VirtualNetworkName' does not exist in '$ResourceGroup'."
    }

    $subnet = Invoke-AzureCli `
        -Arguments @(
            "network", "vnet", "subnet", "list",
            "--resource-group", $ResourceGroup,
            "--vnet-name", $VirtualNetworkName,
            "--query", "[?name=='$SubnetName'].name | [0]",
            "--output", "tsv"
        ) `
        -Operation "Subnet check"

    if ([string]::IsNullOrWhiteSpace($subnet)) {
        throw "Subnet '$SubnetName' does not exist in virtual network '$VirtualNetworkName'."
    }

    Write-Host "Required Azure resources exist." -ForegroundColor Green
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

function New-RandomStorageAccountName {
    $characters = "abcdefghijklmnopqrstuvwxyz0123456789"

    for ($attempt = 1; $attempt -le 10; $attempt++) {
        $suffix = -join (1..8 | ForEach-Object {
                $characters[(Get-Random -Minimum 0 -Maximum $characters.Length)]
            })
        $candidate = "checkoutmtls$suffix"

        $isAvailable = Invoke-AzureCli `
            -Arguments @(
                "storage", "account", "check-name",
                "--name", $candidate,
                "--query", "nameAvailable",
                "--output", "tsv"
            ) `
            -Operation "Storage account name availability check"

        if ($isAvailable -eq "true") {
            return $candidate
        }
    }

    throw "Unable to find an available storage account name after 10 attempts."
}

function Find-StorageAccountWithDemoShare {
    Write-Step "Looking for an existing demo file share"

    $accountOutput = Invoke-AzureCli `
        -Arguments @(
            "storage", "account", "list",
            "--resource-group", $ResourceGroup,
            "--query", "[].name",
            "--output", "tsv"
        ) `
        -Operation "Storage account listing"

    $accountNames = @(
        $accountOutput -split "\r?\n" |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    foreach ($accountName in $accountNames) {
        $share = Invoke-AzureCli `
            -Arguments @(
                "storage", "share-rm", "list",
                "--resource-group", $ResourceGroup,
                "--storage-account", $accountName,
                "--query", "[?name=='$FileShareName'].name | [0]",
                "--output", "tsv"
            ) `
            -Operation "File share check for storage account '$accountName'"

        if ($share -eq $FileShareName) {
            Write-Host "Reusing storage account '$accountName'." -ForegroundColor Green
            return $accountName
        }
    }

    Write-Host "No existing storage account contains '$FileShareName'." -ForegroundColor Yellow
    return $null
}

function New-DemoStorageAccount {
    Write-Step "Creating storage account"

    $accountName = New-RandomStorageAccountName

    $null = Invoke-AzureCli `
        -Arguments @(
            "storage", "account", "create",
            "--name", $accountName,
            "--resource-group", $ResourceGroup,
            "--location", $Location,
            "--kind", "StorageV2",
            "--sku", "Standard_LRS",
            "--https-only", "true",
            "--output", "none"
        ) `
        -Operation "Storage account creation"

    Write-Host "Created storage account '$accountName'." -ForegroundColor Green
    return $accountName
}

function Get-StorageAccountKey {
    param(
        [Parameter(Mandatory)]
        [string]$AccountName
    )

    # Keep the key in memory and never display it.
    $accountKey = Invoke-AzureCli `
        -Arguments @(
            "storage", "account", "keys", "list",
            "--resource-group", $ResourceGroup,
            "--account-name", $AccountName,
            "--query", "[0].value",
            "--output", "tsv"
        ) `
        -Operation "Storage account key retrieval"

    if ([string]::IsNullOrWhiteSpace($accountKey)) {
        throw "Azure CLI did not return a key for storage account '$AccountName'."
    }

    return $accountKey
}

function Initialize-DemoFileShare {
    param(
        [Parameter(Mandatory)]
        [string]$AccountName,

        [Parameter(Mandatory)]
        [string]$AccountKey
    )

    Write-Step "Checking Azure Files share"

    $shareExists = Invoke-AzureCli `
        -Arguments @(
            "storage", "share", "exists",
            "--name", $FileShareName,
            "--account-name", $AccountName,
            "--account-key", $AccountKey,
            "--query", "exists",
            "--output", "tsv"
        ) `
        -Operation "File share existence check"

    if ($shareExists -ne "true") {
        $null = Invoke-AzureCli `
            -Arguments @(
                "storage", "share", "create",
                "--name", $FileShareName,
                "--account-name", $AccountName,
                "--account-key", $AccountKey,
                "--output", "none"
            ) `
            -Operation "File share creation"

        Write-Host "Created file share '$FileShareName'." -ForegroundColor Green
        return
    }

    Write-Host "File share '$FileShareName' already exists." -ForegroundColor Green
}

function Send-CertificateFiles {
    param(
        [Parameter(Mandatory)]
        [string]$AccountName,

        [Parameter(Mandatory)]
        [string]$AccountKey
    )

    Write-Step "Uploading certificate files to Azure Files"

    foreach ($fileName in $CertificateFiles) {
        $sourcePath = Join-Path -Path $CertificateDirectory -ChildPath $fileName

        # Azure Files replaces the destination file when the same path is uploaded.
        $null = Invoke-AzureCli `
            -Arguments @(
                "storage", "file", "upload",
                "--account-name", $AccountName,
                "--account-key", $AccountKey,
                "--share-name", $FileShareName,
                "--source", $sourcePath,
                "--path", $fileName,
                "--no-progress",
                "--output", "none"
            ) `
            -Operation "Upload of '$fileName'"

        Write-Host "Uploaded '$fileName'." -ForegroundColor Green
    }
}

function Test-DemoContainerExists {
    $container = Invoke-AzureCli `
        -Arguments @(
            "container", "list",
            "--resource-group", $ResourceGroup,
            "--query", "[?name=='$ContainerName'].name | [0]",
            "--output", "tsv"
        ) `
        -Operation "Container existence check"

    return -not [string]::IsNullOrWhiteSpace($container)
}

function Confirm-ContainerRecreation {
    param(
        [Parameter(Mandatory)]
        [bool]$ContainerExists
    )

    Write-Step "Confirming container recreation"

    if ($ContainerExists) {
        Write-Host `
            "The existing container must be deleted and recreated to add the Azure Files mount." `
            -ForegroundColor Yellow
    }
    else {
        Write-Host "The demo container does not currently exist and will be created." -ForegroundColor Yellow
    }

    Write-Host -NoNewline "Recreate the demo container with the certificate volume mounted? (y/N)"
    $response = Read-Host

    if ($response -cnotmatch "^[yY]$") {
        Write-Host "Container recreation cancelled. No container changes were made." -ForegroundColor Yellow
        return $false
    }

    return $true
}

function Remove-DemoContainer {
    Write-Step "Deleting existing demo container"

    $null = Invoke-AzureCli `
        -Arguments @(
            "container", "delete",
            "--resource-group", $ResourceGroup,
            "--name", $ContainerName,
            "--yes",
            "--output", "none"
        ) `
        -Operation "Container deletion"

    for ($attempt = 1; $attempt -le 60; $attempt++) {
        if (-not (Test-DemoContainerExists)) {
            Write-Host "Existing container was deleted." -ForegroundColor Green
            return
        }

        Start-Sleep -Seconds 5
    }

    throw "Timed out waiting for container '$ContainerName' to be deleted."
}

function Get-SubnetResourceId {
    Write-Step "Retrieving subnet resource ID"

    $subnetId = Invoke-AzureCli `
        -Arguments @(
            "network", "vnet", "subnet", "show",
            "--resource-group", $ResourceGroup,
            "--vnet-name", $VirtualNetworkName,
            "--name", $SubnetName,
            "--query", "id",
            "--output", "tsv"
        ) `
        -Operation "Subnet resource ID retrieval"

    if ([string]::IsNullOrWhiteSpace($subnetId)) {
        throw "Azure CLI did not return the subnet resource ID."
    }

    Write-Host "Subnet resource ID retrieved." -ForegroundColor Green
    return $subnetId
}

function New-DemoContainer {
    param(
        [Parameter(Mandatory)]
        [string]$SubnetId,

        [Parameter(Mandatory)]
        [string]$AccountName,

        [Parameter(Mandatory)]
        [string]$AccountKey
    )

    Write-Step "Creating demo container with Azure Files mounted at $MountPath"

    $null = Invoke-AzureCli `
        -Arguments @(
            "container", "create",
            "--resource-group", $ResourceGroup,
            "--name", $ContainerName,
            "--location", $Location,
            "--image", $ContainerImage,
            "--subnet", $SubnetId,
            "--ip-address", "Private",
            "--os-type", "Linux",
            "--cpu", "1",
            "--memory", "1.5",
            "--restart-policy", "Never",
            "--command-line", "sleep 7d",
            "--azure-file-volume-account-name", $AccountName,
            "--azure-file-volume-account-key", $AccountKey,
            "--azure-file-volume-share-name", $FileShareName,
            "--azure-file-volume-mount-path", $MountPath,
            "--output", "none"
        ) `
        -Operation "Container creation"

    Write-Host "Container creation request completed." -ForegroundColor Green
}

function Wait-DemoContainerReady {
    Write-Step "Waiting for the demo container to become ready"

    for ($attempt = 1; $attempt -le 90; $attempt++) {
        $status = Invoke-AzureCli `
            -Arguments @(
                "container", "show",
                "--resource-group", $ResourceGroup,
                "--name", $ContainerName,
                "--query", "[provisioningState, instanceView.state]",
                "--output", "tsv"
            ) `
            -Operation "Container readiness check"

        $values = @($status -split "\s+" | Where-Object { $_ })
        $provisioningState = if ($values.Count -ge 1) { $values[0] } else { "" }
        $runtimeState = if ($values.Count -ge 2) { $values[1] } else { "" }

        if ($provisioningState -eq "Failed") {
            throw "Container provisioning failed."
        }

        if ($provisioningState -eq "Succeeded" -and $runtimeState -eq "Running") {
            Write-Host "Container provisioning succeeded and the container is running." -ForegroundColor Green
            return
        }

        Write-Host `
            "Provisioning state: $provisioningState; runtime state: $runtimeState" `
            -ForegroundColor DarkGray
        Start-Sleep -Seconds 10
    }

    throw "Timed out waiting for container '$ContainerName' to become ready."
}

function Get-DemoContainerPrivateIp {
    $privateIp = Invoke-AzureCli `
        -Arguments @(
            "container", "show",
            "--resource-group", $ResourceGroup,
            "--name", $ContainerName,
            "--query", "ipAddress.ip",
            "--output", "tsv"
        ) `
        -Operation "Container private IP retrieval"

    if ([string]::IsNullOrWhiteSpace($privateIp)) {
        throw "Azure CLI did not return the container private IP address."
    }

    return $privateIp
}

function Show-NextCommands {
    param(
        [Parameter(Mandatory)]
        [string]$PrivateIp
    )

    Write-Host "`nDemo container private IP: $PrivateIp" -ForegroundColor Green
    Write-Host "`nOpen the container shell with:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host 'az container exec `'
    Write-Host '    --resource-group rg-checkout-assessment-dev `'
    Write-Host '    --name checkout-assessment-dev-mtls-test `'
    Write-Host '    --exec-command "/bin/sh"'

    Write-Host "`nThen run these verification commands inside the container:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "ls -l /mnt/mtls"
    Write-Host ""
    Write-Host "openssl x509 -in /mnt/mtls/trusted-client-cert.pem -noout -subject -fingerprint -sha1"

    Write-Host `
        "`nPersistent demo certificate storage is ready. You should not need to upload the certificates again when the container is recreated using this Azure Files share." `
        -ForegroundColor Green
}

function Start-DemoContainerProvisioning {
    Test-AzureCliInstalled
    Test-AzureLogin
    Test-AzureResources
    Test-LocalCertificateFiles

    $storageAccountName = Find-StorageAccountWithDemoShare
    if ([string]::IsNullOrWhiteSpace($storageAccountName)) {
        $storageAccountName = New-DemoStorageAccount
    }

    $storageAccountKey = Get-StorageAccountKey -AccountName $storageAccountName
    Initialize-DemoFileShare -AccountName $storageAccountName -AccountKey $storageAccountKey
    Send-CertificateFiles -AccountName $storageAccountName -AccountKey $storageAccountKey

    $containerExists = Test-DemoContainerExists
    if (-not (Confirm-ContainerRecreation -ContainerExists $containerExists)) {
        return
    }

    if ($containerExists) {
        Remove-DemoContainer
    }

    $subnetId = Get-SubnetResourceId
    New-DemoContainer `
        -SubnetId $subnetId `
        -AccountName $storageAccountName `
        -AccountKey $storageAccountKey

    Wait-DemoContainerReady
    $privateIp = Get-DemoContainerPrivateIp
    Show-NextCommands -PrivateIp $privateIp
}

try {
    Start-DemoContainerProvisioning
}
catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
