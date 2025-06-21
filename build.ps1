<#
.SYNOPSIS
  Builds a Docker image and exports its filesystem for WSL import.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
# Resolve script location and paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Config: locate compose.yml one level up if not in build/
$composeFile = Join-Path $scriptDir 'compose.yml'

$serviceName = 'xve-distro'
$imageName   = 'xve-distro'
$container   = 'xve-builder'
$outputTar   = Join-Path $scriptDir '..\xve-distro.tar'

# GitHub settings
$ghRepo     = 'jonasvanderhaegen-xve/xve-artifacts'
$versionTag = "export-$(Get-Date -Format 'yyyy-MM-dd_HH-mm')"

try {
    # 1) Build the image via Docker Buildx Bake
    Write-Host "1/4: Building image '$imageName' using buildx bake..."
    Push-Location $scriptDir
    $env:COMPOSE_BAKE = 'true'
    $env:BUILDX_BAKE_ENTITLEMENTS_FS = '0'
    docker buildx bake -f $composeFile $serviceName
    Pop-Location

    # 2) Create a temporary container (no entrypoint run)
    Write-Host "2/4: Creating temporary container '$container'..."
    docker create --name $container $imageName | Out-Null

    # 3) Export the filesystem to a tarball
    Write-Host "3/4: Exporting filesystem to '$outputTar'..."
    docker export --output $outputTar $container

    Write-Host "4/4: Uploading '$outputTar' to GitHub release '$versionTag'..."
        gh release create $versionTag $outputTar `
            --repo $ghRepo `
            --title "XVE Distro $versionTag" `
            --notes "Automated export on $(Get-Date -Format o)" \
            --prerelease


} finally {
    # 4) Cleanup the temporary container
    if (docker ps -a --format '{{.Names}}' | Select-String -Pattern "^$container$") {
        Write-Host "4/4: Removing container '$container'..."
        docker rm $container | Out-Null
    }

    Write-Host "`nDone! Generated '$outputTar'" -ForegroundColor Green
}
