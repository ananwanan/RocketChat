[CmdletBinding()]
param(
    [ValidateSet('win-x64', 'win-arm64')]
    [string]$Runtime = 'win-x64',

    [ValidateSet('Release', 'Debug')]
    [string]$Configuration = 'Release',

    [switch]$SelfContained,

    [switch]$NoSingleFile,

    [ValidatePattern('^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$')]
    [string]$Version = '1.0.0',

    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$projectPath = Join-Path $repositoryRoot 'RocketChat.Client\RocketChat.Client.csproj'

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repositoryRoot 'artifacts'
} elseif (-not [System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory = Join-Path $repositoryRoot $OutputDirectory
}

$packageName = "RocketChat.Client-$Version-$Runtime"
$stagingDirectory = Join-Path $OutputDirectory $packageName
$archivePath = Join-Path $OutputDirectory "$packageName.zip"
$checksumPath = "$archivePath.sha256"

Write-Host "Packaging Rocket.Chat C# Client" -ForegroundColor Cyan
Write-Host "  Configuration: $Configuration"
Write-Host "  Runtime: $Runtime"
Write-Host "  Self-contained: $($SelfContained.IsPresent)"
Write-Host "  Single file: $(-not $NoSingleFile.IsPresent)"

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

foreach ($target in @($stagingDirectory, $archivePath, $checksumPath)) {
    $resolvedOutput = [System.IO.Path]::GetFullPath($OutputDirectory)
    $resolvedTarget = [System.IO.Path]::GetFullPath($target)
    if (-not $resolvedTarget.StartsWith($resolvedOutput + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean a path outside the output directory: $resolvedTarget"
    }
    if (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Recurse -Force
    }
}

$publishArguments = @(
    'publish', $projectPath,
    '--configuration', $Configuration,
    '--runtime', $Runtime,
    '--self-contained', $SelfContained.IsPresent.ToString().ToLowerInvariant(),
    ('-p:PublishSingleFile=' + (-not $NoSingleFile.IsPresent).ToString().ToLowerInvariant()),
    ('-p:Version=' + $Version),
    '--output', $stagingDirectory
)

& dotnet @publishArguments
if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish failed with exit code $LASTEXITCODE"
}

$readmePath = Join-Path $repositoryRoot 'README.md'
$licensePath = Join-Path $repositoryRoot 'LICENSE'
Copy-Item -LiteralPath $readmePath -Destination $stagingDirectory
Copy-Item -LiteralPath $licensePath -Destination $stagingDirectory

$manifest = [ordered]@{
    name = 'RocketChat.Client'
    version = $Version
    runtime = $Runtime
    configuration = $Configuration
    selfContained = $SelfContained.IsPresent
    singleFile = -not $NoSingleFile.IsPresent
    createdAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stagingDirectory 'package.json') -Encoding utf8

Compress-Archive -Path (Join-Path $stagingDirectory '*') -DestinationPath $archivePath -CompressionLevel Optimal
$hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([System.IO.Path]::GetFileName($archivePath))" | Set-Content -LiteralPath $checksumPath -Encoding ascii

$archive = Get-Item -LiteralPath $archivePath
Write-Host "Package created" -ForegroundColor Green
Write-Host "  ZIP: $($archive.FullName)"
Write-Host "  Size: $([Math]::Round($archive.Length / 1MB, 2)) MB"
Write-Host "  SHA-256: $hash"

[pscustomobject]@{
    PackageDirectory = $stagingDirectory
    Archive = $archive.FullName
    Checksum = $checksumPath
    Sha256 = $hash
}
