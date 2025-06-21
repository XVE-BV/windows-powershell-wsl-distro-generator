<#
.SYNOPSIS
  Builds a Docker image, exports its filesystem for WSL import, and uploads as a GitHub Release asset via REST API.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# 1) Setup
# Resolve script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Paths and names
$composeFile = Join-Path $scriptDir 'compose.yml'
$serviceName = 'xve-distro'
$imageName   = 'xve-distro'
$container   = 'xve-builder'
$outputTar   = Join-Path $scriptDir '..\xve-distro.tar'

# GitHub repo settings (owner/repo)
$ghRepo     = 'jonasvanderhaegen-xve/xve-artifacts'  # replace
$versionTag = "export-$(Get-Date -Format 'yyyy-MM-dd_HH-mm')"

# Retrieve GitHub PAT: first check environment, then Windows user vars
$pat = $Env:GITHUB_TOKEN
if (-not $pat) {
    $pat = [Environment]::GetEnvironmentVariable('GITHUB_TOKEN','User')
}

# Function to create or fetch a release and upload asset
function Upload-ReleaseAsset {
    param(
        [string]$repo,
        [string]$tag,
        [string]$filePath
    )
    # Headers for GitHub API
    $apiBaseUrl = "https://api.github.com"
    $headers = @{ Authorization = "token $pat"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'XVE-Export-Script' }

    # 1) Create release
    $createUrl = "$apiBaseUrl/repos/$repo/releases"
    $body = @{ tag_name = $tag; name = "XVE Distro $tag"; prerelease = $true } | ConvertTo-Json
    try {
        $release = Invoke-RestMethod -Method Post -Uri $createUrl -Headers $headers -Body $body -ErrorAction Stop
    } catch {
        # If release exists or repo empty, fetch existing
        $existingUrl = "$apiBaseUrl/repos/$repo/releases/tags/$tag"
        $release = Invoke-RestMethod -Method Get -Uri $existingUrl -Headers $headers -ErrorAction Stop
    }

        # 2) Upload asset using uploads.github.com domain
    # Use release ID to construct asset upload URL
    $uploadDomain = "https://uploads.github.com"
    $assetName = [System.Uri]::EscapeDataString((Split-Path $filePath -Leaf))
    $uploadUrl = "$uploadDomain/repos/$repo/releases/$($release.id)/assets?name=$assetName"
    # Perform upload
    Invoke-RestMethod -Method Post -Uri $uploadUrl -Headers @{ Authorization = "token $pat"; 'Content-Type'='application/octet-stream'; 'User-Agent'='XVE-Export-Script' } -InFile $filePath -ErrorAction Stop -Method Post -Uri $uploadUri -Headers @{ Authorization = "token $pat"; 'Content-Type'='application/octet-stream'; 'User-Agent'='XVE-Export-Script' } -InFile $filePath -ErrorAction Stop
}

# 2) Main steps
try {
    # Build image
    Write-Host "Building image '$imageName'..."
    Push-Location $scriptDir
    $env:COMPOSE_BAKE = 'true'
    $env:BUILDX_BAKE_ENTITLEMENTS_FS = '0'
    docker buildx bake -f $composeFile $serviceName
    Pop-Location

    # Create temporary container
    Write-Host "Creating temporary container '$container'..."
    docker create --name $container $imageName | Out-Null

    # Export filesystem
    Write-Host "Exporting filesystem to '$outputTar'..."
    docker export --output $outputTar $container

    # Upload if PAT present
    if ($pat) {
        Write-Host "Uploading '$outputTar' to GitHub release '$versionTag'..."

        Invoke-RestMethod `
          -Method Post `
          -Uri $uploadUrl `
          -Headers @{ Authorization = "token $pat" } `
          -InFile $filePath `
          -ContentType 'application/octet-stream' `
          -ErrorAction Stop

    } else {
        Write-Warning "GITHUB_TOKEN not set; skipping upload."
    }
} catch {
    Write-Error "ERROR during build or upload: $_"
    exit 1
} finally {
    # Cleanup container
    if (docker ps -a --format '{{.Names}}' | Select-String -Pattern "^$container$") {
        Write-Host "Removing container '$container'..."
        docker rm $container | Out-Null
    }
    Write-Host "Done!" -ForegroundColor Green
}
