param(
    [ValidateSet('windows', 'web', 'android', 'all')]
    [string]$Target = 'windows'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$artifactRoot = Join-Path $projectRoot 'artifacts'

function Invoke-FlutterBuild {
    param([string]$Platform)

    switch ($Platform) {
        'windows' {
            flutter build windows --release
            $source = Join-Path $projectRoot 'build\windows\x64\runner\Release'
            $destination = Join-Path $artifactRoot 'windows'
            $isDirectory = $true
        }
        'web' {
            flutter build web --release
            $source = Join-Path $projectRoot 'build\web'
            $destination = Join-Path $artifactRoot 'web'
            $isDirectory = $true
        }
        'android' {
            flutter build apk --release
            $source = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
            $destination = Join-Path $artifactRoot 'android\app-release.apk'
            $isDirectory = $false
        }
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Flutter $Platform build failed."
    }

    if (Test-Path -LiteralPath $destination) {
        Remove-Item -LiteralPath $destination -Recurse -Force
    }
    $destinationParent = if ($isDirectory) { $artifactRoot } else { Split-Path -Parent $destination }
    New-Item -ItemType Directory -Force -Path $destinationParent | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
    Write-Host "Packaged $Platform to $destination"
}

Push-Location $projectRoot
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw 'flutter pub get failed.'
    }

    $targets = if ($Target -eq 'all') { @('windows', 'web', 'android') } else { @($Target) }
    foreach ($platform in $targets) {
        Invoke-FlutterBuild -Platform $platform
    }
}
finally {
    Pop-Location
}
