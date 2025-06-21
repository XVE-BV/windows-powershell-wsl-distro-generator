<#
.SYNOPSIS
  Builds a Docker image, exports its filesystem for WSL import, and uploads as a GitHub Release asset.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Resolve script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Config
$composeFile = Join-Path $scriptDir 'compose.yml'
$serviceName = 'xve-distro'
$imageName   = 'xve-distro'
$container   = 'xve-builder'
$outputTar   = Join-Path $scriptDir '..\xve-distro.tar'

# GitHub settings
# GitHub settings
# A GitHub Personal Access Token (PAT) with 'repo' scope is required if the 'gh' CLI is unavailable.
# To create one:
# 1. On GitHub, go to https://github.com/settings/tokens and generate a new classic token with 'repo' scope.
# 2. On Windows (PowerShell), set it as a user environment variable:
#      [Environment]::SetEnvironmentVariable('GITHUB_TOKEN','<your_token_here>','User')
#    Restart your PowerShell session so that $Env:GITHUB_TOKEN is available to this script.
$ghRepo     = 'your-org/xve-artifacts'
$versionTag = "export-$(Get-Date -Format 'yyyy-MM-dd_HH-mm')"
# Expect a Personal Access Token in env var GITHUB_TOKEN
$pat        = $Env:GITHUB_TOKEN

try {
    # 1) Build the image via Buildx Bake
    Write-Host "1/4: Building image '$imageName'..."
    Push-Location $scriptDir
    $env:COMPOSE_BAKE = 'true'
    $env:BUILDX_BAKE_ENTITLEMENTS_FS = '0'
    docker buildx bake -f $composeFile $serviceName
    Pop-Location

    # 2) Create a temporary container
    Write-Host "2/4: Creating temporary container '$container'..."
    docker create --name $container $imageName | Out-Null

    # 3) Export the filesystem to a tarball
    Write-Host "3/4: Exporting filesystem to '$outputTar'..."
    docker export --output $outputTar $container

    # 4) Upload to GitHub
    Write-Host "4/4: Uploading '$outputTar' to GitHub release '$versionTag'..."
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        # Use GitHub CLI if available
        gh auth status | Out-Null
        gh release create $versionTag $outputTar `
            --repo $ghRepo `
            --title "XVE Distro $versionTag" `
            --notes "Automated export on $(Get-Date -Format o)" `
            --prerelease 2>&1
    } elseif ($pat) {
        # Fallback to REST API using Personal Access Token
        Write-Host "Using REST API with PAT to upload asset..."
        # Create release
        $apiUrl = "https://api.github.com/repos/$ghRepo/releases"
        $releaseData = @{ tag_name = $versionTag; name = "XVE Distro $versionTag"; prerelease = $true } | ConvertTo-Json
        $release = Invoke-RestMethod -Method Post -Uri $apiUrl -Headers @{ Authorization = "token $pat"; Accept = 'application/vnd.github.v3+json' } -Body $releaseData
        # Upload asset
        $uploadUrl = $release.upload_url -replace '\{.*\}$',''
        Invoke-RestMethod -Method Post -Uri "$uploadUrl?name=$(Split-Path $outputTar -Leaf)" -Headers @{ Authorization = "token $pat"; "Content-Type" = 'application/octet-stream' } -InFile $outputTar
    } else {
        Write-Warning "Neither 'gh' CLI found nor GITHUB_TOKEN set. Skipping upload."
    }
} finally {
    # Cleanup temporary container
    if (docker ps -a --format '{{.Names}}' | Select-String -Pattern "^$container$") {
        Write-Host "Removing container '$container'..."
        docker rm $container | Out-Null
    }
    Write-Host "`nDone!" -ForegroundColor Green
}
