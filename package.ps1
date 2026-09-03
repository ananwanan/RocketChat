param(
    [ValidateSet('installer', 'windows', 'web', 'android', 'all')]
    [string]$Target = 'installer'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$artifactRoot = Join-Path $projectRoot 'artifacts'
$toolRoot = Join-Path $projectRoot '.tools\inno-setup'

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Command,
        [Parameter(Mandatory)]
        [string]$ErrorMessage
    )

    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw $ErrorMessage
    }
}

function Get-AppVersion {
    $pubspec = Get-Content -LiteralPath (Join-Path $projectRoot 'pubspec.yaml') -Raw
    $match = [regex]::Match($pubspec, '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)')
    if (-not $match.Success) {
        throw 'Unable to read the application version from pubspec.yaml.'
    }
    return $match.Groups[1].Value
}

function Get-InnoSetupCompiler {
    $command = Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue
    $candidates = @(
        $(if ($command) { $command.Source }),
        (Join-Path $toolRoot 'ISCC.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
        'C:\Program Files\Inno Setup 6\ISCC.exe'
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    if ($candidates.Count -gt 0) {
        return ($candidates | Select-Object -First 1)
    }

    Write-Host 'Inno Setup was not found. Downloading the official portable compiler...'
    New-Item -ItemType Directory -Force -Path $toolRoot | Out-Null
    $downloadPath = Join-Path ([IO.Path]::GetTempPath()) "innosetup-$([guid]::NewGuid()).exe"

    try {
        $innoSetupUri = 'https://github.com/jrsoftware/issrc/releases/download/is-6_7_3/innosetup-6.7.3.exe'
        Invoke-WebRequest -Uri $innoSetupUri -OutFile $downloadPath
        $securityModule = Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1'
        Import-Module -Name $securityModule -Force
        $signature = Get-AuthenticodeSignature -LiteralPath $downloadPath
        if ($signature.Status -ne 'Valid') {
            $signer = if ($signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { 'none' }
            throw "The Inno Setup download signature could not be validated. Status: $($signature.Status); signer: $signer; details: $($signature.StatusMessage)"
        }
        if ($signature.SignerCertificate.Subject -notmatch 'Pyrsys B\.V\.') {
            throw "The Inno Setup download was signed by an unexpected publisher: $($signature.SignerCertificate.Subject)"
        }

        $arguments = @(
            '/VERYSILENT',
            '/SUPPRESSMSGBOXES',
            '/NORESTART',
            '/PORTABLE=1',
            "/DIR=$toolRoot"
        )
        $process = Start-Process -FilePath $downloadPath -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
        if ($process.ExitCode -ne 0) {
            throw "Inno Setup bootstrap failed with exit code $($process.ExitCode)."
        }
    }
    finally {
        if (Test-Path -LiteralPath $downloadPath) {
            Remove-Item -LiteralPath $downloadPath -Force
        }
    }

    $compiler = Join-Path $toolRoot 'ISCC.exe'
    if (-not (Test-Path -LiteralPath $compiler)) {
        throw "Inno Setup finished but ISCC.exe was not found at $compiler."
    }
    return $compiler
}

function Copy-BuildOutput {
    param(
        [Parameter(Mandatory)]
        [string]$Source,
        [Parameter(Mandatory)]
        [string]$Destination,
        [switch]$SourceIsDirectory
    )

    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }
    $destinationParent = if ($SourceIsDirectory) { $artifactRoot } else { Split-Path -Parent $Destination }
    New-Item -ItemType Directory -Force -Path $destinationParent | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
    Write-Host "Packaged output to $Destination"
}

function Invoke-FlutterBuild {
    param([string]$Platform)

    switch ($Platform) {
        'windows' {
            Invoke-CheckedCommand { flutter build windows --release } 'Flutter Windows build failed.'
            Copy-BuildOutput `
                -Source (Join-Path $projectRoot 'build\windows\x64\runner\Release') `
                -Destination (Join-Path $artifactRoot 'windows') `
                -SourceIsDirectory
        }
        'web' {
            Invoke-CheckedCommand { flutter build web --release } 'Flutter Web build failed.'
            Copy-BuildOutput `
                -Source (Join-Path $projectRoot 'build\web') `
                -Destination (Join-Path $artifactRoot 'web') `
                -SourceIsDirectory
        }
        'android' {
            Invoke-CheckedCommand { flutter build apk --release } 'Flutter Android build failed.'
            Copy-BuildOutput `
                -Source (Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk') `
                -Destination (Join-Path $artifactRoot 'android\app-release.apk')
        }
    }
}

function Invoke-WindowsInstallerBuild {
    Invoke-CheckedCommand { flutter build windows --release } 'Flutter Windows build failed.'

    $compiler = Get-InnoSetupCompiler
    $version = Get-AppVersion
    $sourceDirectory = Join-Path $projectRoot 'build\windows\x64\runner\Release'
    $outputDirectory = Join-Path $artifactRoot 'installer'
    $installerScript = Join-Path $projectRoot 'installer\RocketChat.iss'

    if (Test-Path -LiteralPath $outputDirectory) {
        Remove-Item -LiteralPath $outputDirectory -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

    $compilerArguments = @(
        "/DAppVersion=$version",
        "/DSourceDir=$sourceDirectory",
        "/DOutputDir=$outputDirectory",
        "/DProjectRoot=$projectRoot",
        $installerScript
    )
    & $compiler @compilerArguments
    if ($LASTEXITCODE -ne 0) {
        throw 'Windows installer compilation failed.'
    }

    $installer = Get-ChildItem -LiteralPath $outputDirectory -Filter '*.exe' | Select-Object -First 1
    if (-not $installer) {
        throw 'Installer compilation completed without producing an executable.'
    }
    $stream = [IO.File]::OpenRead($installer.FullName)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha256.ComputeHash($stream)
    }
    finally {
        $sha256.Dispose()
        $stream.Dispose()
    }
    $hash = ([BitConverter]::ToString($hashBytes)).Replace('-', '').ToLowerInvariant()
    $checksumPath = "$($installer.FullName).sha256"
    "$hash *$($installer.Name)" | Set-Content -LiteralPath $checksumPath -Encoding Ascii
    Write-Host "Installer created: $($installer.FullName)"
    Write-Host "SHA-256 checksum: $checksumPath"
}

Push-Location $projectRoot
try {
    Invoke-CheckedCommand { flutter pub get } 'flutter pub get failed.'

    $targets = if ($Target -eq 'all') { @('installer', 'web', 'android') } else { @($Target) }
    foreach ($platform in $targets) {
        if ($platform -eq 'installer') {
            Invoke-WindowsInstallerBuild
        }
        else {
            Invoke-FlutterBuild -Platform $platform
        }
    }
}
finally {
    Pop-Location
}
