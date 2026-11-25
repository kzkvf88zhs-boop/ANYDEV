param(
    [int]$Seconds = 300,
    [int]$Jobs = 8,
    [string]$Exe = "C:\Users\vedan\Downloads\GTA6.v1.0.2.1-\game_scarlett_master.exe"
)

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$victory = Join-Path $repoRoot "target\release\victory.exe"
if (-not (Test-Path -LiteralPath $victory)) {
    Write-Error "Release binary not found: $victory"
    exit 1
}
if (-not (Test-Path -LiteralPath $Exe)) {
    Write-Error "Game executable not found: $Exe"
    exit 1
}

$shaderRoot = Split-Path -Parent $Exe
$env:VICTORY_WARM_SECONDS = "$Seconds"
$env:VICTORY_HOST_WAVE = "32"
try {
    Write-Host "Prewarming shaders for up to ${Seconds}s with $Jobs workers..."
    & $victory translate $shaderRoot --warm all --jobs $Jobs
} finally {
    Remove-Item -Path Env:VICTORY_WARM_SECONDS -ErrorAction SilentlyContinue
    Remove-Item -Path Env:VICTORY_HOST_WAVE -ErrorAction SilentlyContinue
}
