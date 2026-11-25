param(
    [string]$Exe = "C:\Users\vedan\Downloads\GTA6.v1.0.2.1-\game_scarlett_master.exe",
    # Each level left out divides a title-filled texture's bytes by ~4.
    # In-game default is 2: the fork's evidence-backed 8 GB value.
    # Menus/intro credits use 1 via -Menu, because they are far lighter than gameplay.
    # Never use 3 for this machine: it is the blurry profile.
    [int]$DropMips = 2,
    # Hard ceiling on indexed texture copies. 4096 MB still leaves room for
    # 1080p render targets; -LowVram falls back to the old conservative 3072 MB.
    [int]$TextureBudgetMb = 4096,
    # Bytes of texture data staged per frame. The fork triples this while a
    # large backlog is due, so 192 MB becomes up to 576 MB during streaming.
    [int]$TextureStageMb = 192,
    # Launch for menus/intro credits only: sharper textures, lighter scene.
    [switch]$Menu,
    # Correctness-first profile: drops the non-exact speed shortcuts.
    [switch]$Safe,
    # Use 3072 MB texture cap if the desktop/browser is eating card memory.
    [switch]$LowVram,
    # Prewarm the shader cache before starting the title. The binary has a
    # built-in timer: it stops taking new shaders after this many seconds and
    # keeps everything already translated for the next launch.
    [int]$PrewarmSeconds = 300,
    # Worker threads for the offline warm-up.
    [int]$WarmJobs = 8,
    # Skip the warm-up (useful while iterating quickly).
    [switch]$SkipPrewarm,
    # Seconds the texture pass may spend above its normal budget catching up
    # a long queue. The old fork had no gate and kept uploading until OOM.
    [int]$TextureGateSeconds = 60
)

# 1080p only. The fork otherwise reports a 3840x2160 TV to the title, which
# makes it allocate 4x the render-target bytes and do 4x the pixel work.
$DisplayMode = "1920x1080"

if ($Menu -and -not $PSBoundParameters.ContainsKey('DropMips')) {
    $DropMips = 1
}
if ($LowVram) {
    $TextureBudgetMb = 3072
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$victory = Join-Path $repoRoot "target\release\victory.exe"

if (-not (Test-Path -LiteralPath $victory)) {
    Write-Error "Release binary not found at $victory. Build it first with: cargo build --release -p victory --bin victory"
    exit 1
}
if (-not (Test-Path -LiteralPath $Exe)) {
    Write-Error "Game executable not found: $Exe"
    exit 1
}

# Offline shader warm-up: CPU only, no device, no game window. Anything
# translated here is already in the run's cache, so the title does not have
# to translate shaders the first time a scene uses them.
if (-not $SkipPrewarm -and $PrewarmSeconds -gt 0) {
    $shaderRoot = Split-Path -Parent $Exe
    Write-Host "Prewarming shaders for up to ${PrewarmSeconds}s with $WarmJobs workers..."
    $env:VICTORY_WARM_SECONDS = "$PrewarmSeconds"
    $env:VICTORY_HOST_WAVE = "32"
    try {
        & $victory translate $shaderRoot --warm all --jobs $WarmJobs
    } catch {
        Write-Warning "Shader warm-up failed; continuing with the launch anyway: $_"
    } finally {
        Remove-Item -Path Env:VICTORY_WARM_SECONDS -ErrorAction SilentlyContinue
        Remove-Item -Path Env:VICTORY_HOST_WAVE -ErrorAction SilentlyContinue
    }
}

# Clear switches from earlier experiments so each launch starts from the same state.
# Removing VICTORY_BAKE_TEXTURES_MS restores its safe 1500 ms pre-bake window.
$remove = @(
    'VICTORY_SKIP_PIPELINES', 'VICTORY_BAKE_TEXTURES_MS',
    'VICTORY_CARD_FETCH_INFLIGHT', 'VICTORY_LEVELS_ON_DEMAND',
    'VICTORY_REFRESH_ONCE', 'VICTORY_AMBIENT', 'VICTORY_INPLACE',
    'VICTORY_EFFICIENCY_MODE', 'VICTORY_DISK_CORES', 'VICTORY_FAST_CORES'
)
if ($Safe) {
    # Non-exact / experimental shortcuts used by the fast profile.
    $remove += @('VICTORY_SKIP_WC_COMPARE', 'VICTORY_MERGE_GAP', 'VICTORY_MERGE_RUNS', 'VICTORY_ASYNC_PRESENT')
}
foreach ($name in $remove) {
    Remove-Item -Path "Env:$name" -ErrorAction SilentlyContinue
}

# Fork's tuned settings for NVIDIA 8 GB / Wave32 GPUs.
$env:VICTORY_ASYNC_SUBMIT = "1"
$env:VICTORY_QUEUE2 = "1"
$env:VICTORY_INDIRECT_WINDOW = "1"
$env:VICTORY_TEXTURE_NO_WAIT = "1"
$env:VICTORY_COPY_PLAIN = "1"
$env:VICTORY_WIDE_TEXTURES = "1"
$env:VICTORY_RELAY = "2"
$env:VICTORY_LATE_WAIT = "3"
$env:VICTORY_WIDE_MERGE = "1"
$env:VICTORY_STAGING_POOL = "1"
$env:VICTORY_DRIVER_WATCH = "1"
# DexNom's CPU submission workers. Ignored by the old binary, active after the port.
$env:VICTORY_FILL_WORKERS = "4"
$env:VICTORY_PARALLEL_PRELUDES = "1"

if (-not $Safe) {
    # Fast profile. These are shortcuts: SKIP_WC_COMPARE can send stale bytes,
    # MERGE_GAP can overwrite a shader store within 64 bytes, and ASYNC_PRESENT
    # assumes memory stays stable. They are what produced the old 6.6 fps.
    $env:VICTORY_SKIP_WC_COMPARE = "1"
    $env:VICTORY_MERGE_GAP = "64"
    $env:VICTORY_MERGE_RUNS = "4096"
    $env:VICTORY_ASYNC_PRESENT = "1"
}

# Display and texture memory/speed.
$env:VICTORY_DISPLAY_MODE = $DisplayMode
$env:VICTORY_TEXTURE_DROP_MIPS = "$DropMips"
# Hard ceiling on indexed texture copies so the 8 GB card never starts paging.
# This bypasses the 90%-of-budget rule, so target-room/percent knobs are inert.
$env:VICTORY_TEXTURE_BUDGET_MB = "$TextureBudgetMb"
$env:VICTORY_TEXTURE_STAGE_MB = "$TextureStageMb"
$env:VICTORY_TEXTURE_STAGE_MS = "250"
$env:VICTORY_TEXTURE_CATCHUP = "1"
$env:VICTORY_TEXTURE_GATE_S = "$TextureGateSeconds"
# Spend a little more time uploading before the first indexed draw, and keep
# the decoration bake's texture window enabled (default 1500 ms).
$env:VICTORY_EARLY_TEXTURES_MS = "50"
$env:VICTORY_LAZY_TEXTURES = "1"
$env:VICTORY_TEXTURE_SWEEP = "1"
$env:VICTORY_FULL_CARD_PASS = "1"
$env:VICTORY_CARD_ROOM_FOR_BUFFERS = "1"
# Diagnostics ring buffer is not needed for play.
$env:VICTORY_TRAIL = "0"

# CPU/GPU work reduction.
# Join touching hash pieces into one pass instead of one pass per sent range.
$env:VICTORY_CARD_REHASH_RUNS = "1"
# Merge consecutive title buffer copies into one kernel call.
$env:VICTORY_JOIN_COPIES = "1"

$profile = if ($Menu) { "MENU" } elseif ($Safe) { "SAFE" } else { "GAME" }
Write-Host "Launching [$profile] at $DisplayMode, dropMips=$DropMips, textureStage=${TextureStageMb}MB, textureBudget=${TextureBudgetMb}MB"
& $victory run $Exe --execute
