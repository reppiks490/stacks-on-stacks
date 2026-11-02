<#
Install official Godot 4.7.2 standard editor for the current Windows user.
No admin access, PATH changes, third-party installers, Codex, or paid services.
Verifies the downloaded official GitHub release ZIP against SHA-256.
#>
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Sablestar\Godot\4.7.2'),
    [switch]$Launch
)
$ErrorActionPreference = 'Stop'
$version = '4.7.2'
$fileName = "Godot_v$version-stable_win64.exe.zip"
$url = "https://github.com/godotengine/godot/releases/download/$version-stable/$fileName"
$expectedSha256 = '731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953'
$tempZip = Join-Path ([System.IO.Path]::GetTempPath()) $fileName
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
try {
    Write-Host "Downloading official Godot $version ..."
    Invoke-WebRequest -Uri $url -OutFile $tempZip -MaximumRedirection 10
    $got = (Get-FileHash -LiteralPath $tempZip -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($got -ne $expectedSha256) {
        throw "Godot archive SHA-256 mismatch: expected $expectedSha256, got $got. Refusing to install."
    }
    Expand-Archive -LiteralPath $tempZip -DestinationPath $InstallDir -Force
    $exe = Get-ChildItem -LiteralPath $InstallDir -Filter 'Godot_v4.7.2-stable_win64.exe' -File -Recurse | Select-Object -First 1
    if (-not $exe) { throw 'Expected official Godot executable was not found in archive.' }
    Write-Host "Verified Godot executable: $($exe.FullName)"
    & $exe.FullName --headless --version
    if ($LASTEXITCODE -ne 0) { throw "Godot version check failed with code $LASTEXITCODE" }
    Write-Host "Success. Open this project's project.godot with $($exe.FullName)"
    if ($Launch) { Start-Process -FilePath $exe.FullName }
} finally {
    Remove-Item -LiteralPath $tempZip -ErrorAction SilentlyContinue
}
