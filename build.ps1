<#
.SYNOPSIS
  Builds a Docker image, exports its filesystem for WSL import, and optionally uploads as a GitHub Release asset via REST API.
#>

[CmdletBinding()]
param(
    [switch]$Upload  # Pass -Upload to enable GitHub upload; otherwise, only generate the tar file
)

$ErrorActionPreference = 'Stop'

# 1) Setup
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Paths and names
$composeFile = Join-Path $scriptDir 'compose.yml'
$serviceName = 'xve-distro'
$imageName   = 'xve-distro'
$container   = 'xve-builder'
$outputTar   = Join-Path $scriptDir '..\xve-distro.tar'

# GitHub repo settings (owner/repo)
$ghRepo     = 'your-org/xve-artifacts'  # replace with your own
$versionTag = "export-$(Get-Date -Format 'yyyy-MM-dd_HH-mm')"

# Retrieve GitHub PAT if upload requested
if ($Upload) {
    $pat = $Env:GITHUB_TOKEN
    if (-not $pat) {
        $pat = [Environment]::GetEnvironmentVariable('GITHUB_TOKEN','User')
    }
    if (-not $pat) {
        Write-Error 'GITHUB_TOKEN not found; cannot upload without a PAT. Omit -Upload to skip.'
        exit 1
    }
}

# Function to create or fetch a release and upload asset
function Upload-ReleaseAsset {
    param(
        [string]$repo,
        [string]$tag,
        [string]$filePath
    )
    $apiBaseUrl = 'https://api.github.com'
    $headers = @{ Authorization = "token $pat"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'XVE-Export-Script' }

    # Create or get release
    $createUrl = "$apiBaseUrl/repos/$repo/releases"
    $body = @{ tag_name = $tag; name = "XVE Distro $tag"; prerelease = $true } | ConvertTo-Json
    try {
        $release = Invoke-RestMethod -Method Post -Uri $createUrl -Headers $headers -Body $body -ErrorAction Stop
    } catch {
        $existingUrl = "$apiBaseUrl/repos/$repo/releases/tags/$tag"
        $release = Invoke-RestMethod -Method Get -Uri $existingUrl -Headers $headers -ErrorAction Stop
    }

    # Upload asset
    $assetName = [System.Uri]::EscapeDataString((Split-Path $filePath -Leaf))
    $uploadUrl = "https://uploads.github.com/repos/$repo/releases/$($release.id)/assets?name=$assetName"
    Write-Host "Uploading asset to $uploadUrl"
    Invoke-RestMethod -Method Post -Uri $uploadUrl -Headers @{ Authorization = "token $pat"; 'Content-Type' = 'application/octet-stream'; 'User-Agent' = 'XVE-Export-Script' } -InFile $filePath -ErrorAction Stop
    Write-Host 'Upload complete.'
}

# 2) Main steps
try {
    Write-Host "Building image '$imageName'..."
    Push-Location $scriptDir
    $env:COMPOSE_BAKE = 'true'
    $env:BUILDX_BAKE_ENTITLEMENTS_FS = '0'
    docker buildx bake -f $composeFile $serviceName
    Pop-Location

    Write-Host "Creating container '$container'..."
    docker create --name $container $imageName | Out-Null

    Write-Host "Exporting to '$outputTar'..."
    docker export --output $outputTar $container
    Write-Host "Export complete; tar saved to $outputTar"

    if ($Upload) {
        Write-Host "Uploading release asset..."
        Upload-ReleaseAsset -repo $ghRepo -tag $versionTag -filePath $outputTar
    } else {
        Write-Host "Skipping upload; run with -Upload to enable GitHub release." -ForegroundColor Yellow
    }
} catch {
    Write-Error "ERROR: $_"
    exit 1
} finally {
    if (docker ps -a --format '{{.Names}}' | Select-String -Pattern "^$container$") {
        Write-Host "Removing container '$container'..."
        docker rm $container | Out-Null
    }
    Write-Host "Done!" -ForegroundColor Green
}
