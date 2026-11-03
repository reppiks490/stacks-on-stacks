#requires -Version 5.1
<#
.SYNOPSIS
  Launch EVERBLOOM using installed Godot without guessing a Windows path.
.DESCRIPTION
  Default opens the Godot editor. -RunGame starts the game directly.
  -ResetSaves makes a timestamped backup then requires typing RESET.
  Uses PowerShell syntax (not Git Bash). Never installs software or changes Git.
#>
[CmdletBinding()]
param(
    [switch]$RunGame,
    [switch]$ResetSaves
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$projectFile = Join-Path $projectRoot 'project.godot'
if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
    throw "Project missing at $projectFile. Fetch and switch to the expansion branch first."
}

function Find-GodotExecutable {
    $cmd = Get-Command -Name 'godot', 'godot.exe' -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandType -eq 'Application' } |
        Select-Object -First 1
    if ($cmd) { return [string]$cmd.Source }
    $roots = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'),
        'C:\Program Files\WinGet\Packages',
        (Join-Path $env:LOCALAPPDATA 'Programs'),
        $env:ProgramFiles,
        (Join-Path $env:USERPROFILE 'Downloads'),
        (Join-Path $env:USERPROFILE 'Desktop')
    )
    $matches = @()
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        $matches += @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*Godot*.exe' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch 'console|manager|headless' })
    }
    $preferred = @($matches | Where-Object { $_.Name -match '4[._]7[._]2' } |
        Sort-Object FullName | Select-Object -First 1)
    if ($preferred.Count -gt 0) { return [string]$preferred[0].FullName }
    if ($matches.Count -gt 0) { return [string]$matches[0].FullName }
    throw "Godot executable not found. WinGet shows package installation, but no executable was located. Try: Get-Command godot* -All"
}

if ($ResetSaves) {
    $godotDataRoot = Join-Path $env:APPDATA 'Godot\app_userdata'
    if (-not (Test-Path -LiteralPath $godotDataRoot)) {
        throw "Godot user-data root not found: $godotDataRoot (no save has been touched)"
    }
    $candidate = @(Get-ChildItem -LiteralPath $godotDataRoot -Directory |
        Where-Object { $_.Name -match 'EVERBLOOM' })
    if ($candidate.Count -ne 1) {
        throw "Expected exactly one EVERBLOOM save folder, found $($candidate.Count). Nothing was deleted."
    }
    $source = $candidate[0].FullName
    Write-Host "Selected save folder: $source" -ForegroundColor Yellow
    Write-Host "ResetSaves removes progression and wardrobe/companion state. Normal game launch does not."
    $ack = Read-Host "Type RESET to create a backup and reset the game, or anything else to cancel"
    if ($ack -cne 'RESET') {
        Write-Host "Save reset cancelled. Nothing deleted."
        exit 0
    }
    $backupRoot = Join-Path $env:USERPROFILE 'Documents\EVERBLOOM-save-backups'
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = Join-Path $backupRoot "backup-$stamp"
    Copy-Item -LiteralPath $source -Destination $backup -Recurse -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $backup)) { throw "Backup failed, save files preserved." }
    Write-Host "Backup created: $backup" -ForegroundColor Green
    $files = @(Get-ChildItem -LiteralPath $source -File |
        Where-Object {
            $_.Name -like 'everbloom_save_v1.json*' -or
            $_.Name -like 'everbloom_avatar.cfg*' -or
            $_.Name -like 'everbloom_frontier_social.cfg*' -or
            $_.Name -like 'everbloom_companions.cfg*'
        })
    foreach ($file in $files) {
        Remove-Item -LiteralPath $file.FullName -Force
    }
    Write-Host "EVERBLOOM progression reset ($($files.Count) files). Backup retained."
}

$godot = Find-GodotExecutable
Write-Host "Godot executable: $godot" -ForegroundColor Green
Write-Host "EVERBLOOM folder: $projectRoot"
if ($RunGame) {
    & $godot --path $projectRoot
} else {
    & $godot --editor --path $projectRoot
}
