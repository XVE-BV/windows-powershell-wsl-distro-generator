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
# Set this to the owner/repo of your artifacts repository (e.g. 'myuser/my-artifacts-repo')
$ghRepo     = 'your-org/xve-artifacts'
$versionTag = "export-$(Get-Date -Format 'yyyy-MM-dd_HH-mm')"
# Retrieve a GitHub Personal Access Token (PAT). It can be set as a Windows user env var or in this session.
$pat = if ($Env:GITHUB_TOKEN) { $Env:GITHUB_TOKEN } else { [Environment]::GetEnvironmentVariable('GITHUB_TOKEN','User') }


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
        # Prepare GitHub API headers including User-Agent
        $apiUrl = "https://api.github.com/repos/$ghRepo/releases"
        $headers = @{ Authorization = "token $pat"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'XVE-Export-Script' }
        # Create or get existing release by tag
        try {
            $release = Invoke-RestMethod -Method Post -Uri $apiUrl -Headers $headers -Body (@{ tag_name = $versionTag; name = "XVE Distro $versionTag"; prerelease = $true } | ConvertTo-Json)
        } catch {
            # Handle empty repository error
            $errorContent = $_.Exception.Response.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($errorContent.message -eq 'Repository is empty.') {
                Write-Error "Cannot create release in an empty repository '$ghRepo'. Please push an initial commit (e.g., a README.md) and try again."
                return
            }
            # If release already exists (HTTP 422 or other), fetch it
            $release = Invoke-RestMethod -Method Get -Uri "$apiUrl/tags/$versionTag" -Headers $headers
        }
        # Determine upload URL template and strip placeholders
$uploadUrl = ($release.upload_url -split '\{')[0]
# Validate URL
if (-not [Uri]::IsWellFormedUriString($uploadUrl, [UriKind]::Absolute)) {
    Write-Error "Invalid upload URL: $uploadUrl"
    return
}
# Escape file name for query parameter
$fileName = [Uri]::EscapeDataString((Split-Path $outputTar -Leaf))
$uploadUri = "$uploadUrl?name=$fileName"
# Upload the tarball as a release asset
Invoke-RestMethod -Method Post -Uri $uploadUri -Headers $headers -InFile $outputTar
        } # end REST API fallback
    } # end upload decision (gh vs PAT)
} finally {
    # 5) Cleanup temporary container
    if (docker ps -a --format '{{.Names}}' | Select-String -Pattern "^$container$") {
        Write-Host "Removing container '$container'..."
        docker rm $container | Out-Null
    }
    Write-Host "`nDone!" -ForegroundColor Green
}
