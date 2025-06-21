<#
.SYNOPSIS
  Builds a Docker image, exports its filesystem for WSL import, and optionally uploads to GitHub.
#>

[CmdletBinding()]
param(
    [switch]$Upload  # Pass -Upload to enable GitHub release upload
)

$ErrorActionPreference = 'Stop'

# Setup
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$composeFile = Join-Path $scriptDir 'compose.yml'
$serviceName = 'xve-distro'
$imageName   = 'xve-distro'
$container   = 'xve-builder'
$outputTar   = Join-Path $scriptDir '..\xve-distro.tar'

# GitHub settings
$ghRepo     = 'jonasvanderhaegen-xve/xve-artifacts'  # replace
$versionTag = "export-$(Get-Date -Format 'yyyy-MM-dd_HH-mm')"

# Retrieve PAT if Upload
if ($Upload) {
    $pat = $Env:GITHUB_TOKEN
    if (-not $pat) { $pat = [Environment]::GetEnvironmentVariable('GITHUB_TOKEN','User') }
    if (-not $pat) { Write-Error 'GITHUB_TOKEN not found; cannot upload.'; exit 1 }
}

function Upload-ReleaseAsset {
    param($repo, $tag, $filePath)
    $api = 'https://api.github.com'
    $headers = @{ Authorization = "token $pat"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'XVE-Export-Script' }

    # Check or create release
    $tagUrl = "$api/repos/$repo/releases/tags/$tag"
    try {
        $rel = Invoke-RestMethod -Method Get -Uri $tagUrl -Headers $headers -ErrorAction Stop
    } catch {
        $body = @{ tag_name = $tag; name = "XVE Distro $tag"; prerelease = $true } | ConvertTo-Json
        $rel = Invoke-RestMethod -Method Post -Uri "$api/repos/$repo/releases" -Headers $headers -Body $body -ErrorAction Stop
    }

     # Upload asset with progress bar via WebClient
     $assetName = [Uri]::EscapeDataString((Split-Path $filePath -Leaf))
     $uploadUrl = "https://uploads.github.com/repos/$repo/releases/$($rel.id)/assets?name=$assetName"
     Write-Host "Uploading asset to $uploadUrl with progress..."
     # Create WebClient and hook progress events
     $wc = New-Object System.Net.WebClient
     $wc.Headers.Add('Authorization',"token $pat")
     $wc.Headers.Add('User-Agent','XVE-Export-Script')
     $progressDone = $false

     $wc.add_UploadProgressChanged({
         param($sender, $e)
         Write-Progress `
       -Activity "Uploading $assetName" `
       -Status ("{0:N0} / {1:N0} bytes" -f $e.BytesSent, $e.TotalBytesToSend) `
       -PercentComplete $e.ProgressPercentage
     })
     $wc.add_UploadFileCompleted({
         $script:progressDone = $true
     })

     # Start async upload
     $uri = [Uri] $uploadUrl
     $wc.UploadFileAsync($uri, 'POST', $filePath)

     # Wait for it to finish
     while (-not $progressDone) { Start-Sleep -Milliseconds 100 }
    
     $wc.Dispose()
     Write-Host 'Upload complete.'
}

# Main
try {
    Write-Host "Building image..."
    Push-Location $scriptDir
    $env:COMPOSE_BAKE = 'true'; $env:BUILDX_BAKE_ENTITLEMENTS_FS = '0'
    docker buildx bake -f $composeFile $serviceName
    Pop-Location

    Write-Host "Creating temp container..."
    docker create --name $container $imageName | Out-Null

    Write-Host "Exporting to tar..."
    docker export --output $outputTar $container
    Write-Host "Export saved: $outputTar"

    if ($Upload) {
        Write-Host "Uploading to GitHub..."
        Upload-ReleaseAsset -repo $ghRepo -tag $versionTag -filePath $outputTar
    } else {
        Write-Host "Skip upload. Use -Upload to enable." -ForegroundColor Yellow
    }
} catch {
    Write-Error "ERROR: $_"; exit 1
} finally {
    if (docker ps -a --format '{{.Names}}' | Select-String "^$container$") { docker rm $container | Out-Null }
    Write-Host "Done!" -ForegroundColor Green
}
