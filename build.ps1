<#
.SYNOPSIS
  Builds a Docker image, exports its filesystem for WSL import, and uploads as a GitHub Release asset.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Resolve script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Config paths
$composeFile = Join-Path $scriptDir 'compose.yml'
$serviceName = 'xve-distro'
$imageName   = 'xve-distro'
$container   = 'xve-builder'
$outputTar   = Join-Path $scriptDir '..\xve-distro.tar'

# GitHub settings
$ghRepo     = 'jonasvanderhaegen-xve/xve-artifacts'           # replace with your owner/repo
$versionTag = "export-$(Get-Date -Format 'yyyy-MM-dd_HH-mm')"
# Retrieve PAT from env or Windows user variable
$pat = if ($Env:GITHUB_TOKEN) { $Env:GITHUB_TOKEN } else { [Environment]::GetEnvironmentVariable('GITHUB_TOKEN','User') }

# Helper: upload via REST API
function Upload-ToGitHubRelease {
    param(
        [Parameter(Mandatory)] [string]$releaseTag,
        [Parameter(Mandatory)] [string]$filePath
    )
    $apiUrl = "https://api.github.com/repos/$ghRepo/releases"
    $headers = @{
        Authorization = "token $pat";
        Accept        = 'application/vnd.github+json';
        'User-Agent'  = 'XVE-Export-Script'
    }
    try {
        # Attempt to create new release
        $body = @{ tag_name = $releaseTag; name = "XVE Distro $releaseTag"; prerelease = $true } | ConvertTo-Json
        $release = Invoke-RestMethod -Method Post -Uri $apiUrl -Headers $headers -Body $body -ErrorAction Stop
    } catch {
        # If repository is empty or release exists, fetch existing
        $msg = ($_ | Select-Object -ExpandProperty Exception).Exception.Response.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($msg.message -eq 'Repository is empty.') {
            Throw "Cannot create release: repository is empty. Push an initial commit first."
        }
        # Fetch existing by tag
        $release = Invoke-RestMethod -Method Get -Uri "$apiUrl/tags/$releaseTag" -Headers $headers -ErrorAction Stop
    }
    # Prepare upload URL
    $uploadUrl = ($release.upload_url -split '\{')[0]
    if (-not [Uri]::IsWellFormedUriString($uploadUrl, [UriKind]::Absolute)) {
        Throw "Invalid upload URL: $uploadUrl"
    }
    $fileName  = [Uri]::EscapeDataString((Split-Path $filePath -Leaf))
    $uploadUri = "$uploadUrl?name=$fileName"
    # Upload asset
    Invoke-RestMethod -Method Post -Uri $uploadUri -Headers $headers -InFile $filePath -ErrorAction Stop
}

# Main logic
try {
    Write-Host "1/4: Building image '$imageName'..."
    Push-Location $scriptDir
    $env:COMPOSE_BAKE = 'true'
    $env:BUILDX_BAKE_ENTITLEMENTS_FS = '0'
    docker buildx bake -f $composeFile $serviceName
    Pop-Location

    Write-Host "2/4: Creating temporary container '$container'..."
    docker create --name $container $imageName | Out-Null

    Write-Host "3/4: Exporting filesystem to '$outputTar'..."
    docker export --output $outputTar $container

    Write-Host "4/4: Uploading to GitHub release '$versionTag'..."
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        gh auth status | Out-Null
        gh release create $versionTag $outputTar --repo $ghRepo --title "XVE Distro $versionTag" --notes "Automated export on $(Get-Date -Format o)" --prerelease
    } elseif ($pat) {
        Upload-ToGitHubRelease -releaseTag $versionTag -filePath $outputTar
    } else {
        Write-Warning "Neither GitHub CLI nor GITHUB_TOKEN found; skipping upload."
    }
} catch {
    Write-Error "ERROR: $_"
    exit 1
} finally {
    # Cleanup
    if (docker ps -a --format '{{.Names}}' | Select-String -Pattern "^$container$") {
        Write-Host "Removing container '$container'..."
        docker rm $container | Out-Null
    }
    Write-Host "`nDone!" -ForegroundColor Green
}
