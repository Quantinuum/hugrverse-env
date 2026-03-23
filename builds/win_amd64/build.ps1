# Parent build script for win_amd64.
# Invokes sub-component builds then bundles all outputs into a zip archive.
#
# Usage: .\build.ps1 -OutputPath <output_path>
#   OutputPath - Absolute path for the resulting .zip archive,
#                e.g. C:\output\hugrverse_env_win_amd64.zip
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== hugrverse-env build: win_amd64 ==="

# ── Component builds ──────────────────────────────────────────────────────────
Write-Host "--- Building LLVM ---"
& "$ScriptDir\llvm\build.ps1"
if ($LASTEXITCODE -ne 0) { throw "LLVM build failed" }

# ── Bundle outputs ────────────────────────────────────────────────────────────
Write-Host "=== Bundling outputs to $OutputPath ==="
$InstallRoots = @("C:\hugrverse")
Compress-Archive -Path $InstallRoots -DestinationPath $OutputPath -Force

Write-Host "=== Build complete: $OutputPath ==="
