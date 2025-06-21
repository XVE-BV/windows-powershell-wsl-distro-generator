<#
.SYNOPSIS
  Builds a Docker image and exports its filesystem for WSL import.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Config
$composeFile = 'compose.yml'
$serviceName = 'xve-distro'
$imageName = 'xve-distro'
$container = 'xve-builder'
$outputTar = '../xve-distro.tar'


try {
    # 1) Build
    Write-Host "1/4 Building image '$imageName' using buildx bake..."
    $env:COMPOSE_BAKE = "true"
    $env:BUILDX_BAKE_ENTITLEMENTS_FS = "0"
    docker buildx bake -f $composeFile $serviceName

    # 2) Create container (no entrypoint run)
    Write-Host "2/4: Creating temporary container '$container'..."
    docker create --name $container $imageName | Out-Null

    # 3) Export FS to tar
    Write-Host "3/4: Exporting filesystem to '$outputTar'..."
    docker export --output $outputTar $container
} finally {
    # Ensure container cleanup
    if (docker ps -a --format "{{.Names}}" | Select-String -Pattern "^$container$") {
        Write-Host "4/4: Removing container '$container'..."
        docker rm $container | Out-Null
    }

    Write-Host "`n Done! Generated '$outputTar' in $(Get-Location)." -ForegroundColor Green
}