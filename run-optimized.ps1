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
    # Kept for old callers: ignored. Warm-up is always performed now.
    [switch]$SkipPrewarm,
    # Seconds the texture pass may spend above its normal budget catching up
    # a long queue. The old fork had no gate and kept uploading until OOM.
    [int]$TextureGateSeconds = 60,
    # Push every known 8 GB / NVIDIA speed switch and cut pixel work.
    [switch]$Turbo,
    # Display mode used when -Turbo is not set.
    [string]$Resolution = "1920x1080",
    # Experimental: also move title windows to card memory and cut pipeline
    # waits. Needs a restart to apply; use run-extreme.ps1.
    [switch]$Extreme,
    # Speed switches without the aggressive texture staging (the 42 ms heap pass).
    [switch]$Fast,
    # A/B: max fill workers and skip the post-upload texture recheck.
    [switch]$Lean,
    # Alternate binary (e.g. the diagnostics build that honours the loop limit).
    [string]$VictoryBinary = ""
)

if ($Extreme -or $Fast -or $Lean) { $Turbo = $true }

# The fork otherwise reports a 3840x2160 TV to the title, which makes it
# allocate 4x the render-target bytes and do 4x the pixel work. -Turbo uses
# 720p because pixel work is the largest remaining cost on this card.
$DisplayMode = if ($PSBoundParameters.ContainsKey('Resolution')) { $Resolution } elseif ($Extreme) { "960x540" } elseif ($Turbo) { "1280x720" } else { $Resolution }
$TextureStageMs = if ($Extreme) { 500 } elseif ($Turbo -and -not $Fast) { 400 } else { 250 }
$EarlyTexturesMs = if ($Extreme) { 250 } elseif ($Turbo -and -not $Fast) { 200 } else { 50 }

if ($Menu -and -not $PSBoundParameters.ContainsKey('DropMips')) {
    $DropMips = 1
}
if ($LowVram) {
    $TextureBudgetMb = 3072
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$victory = if ($VictoryBinary) { $VictoryBinary } else { Join-Path $repoRoot "target\release\victory.exe" }

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
# to translate shaders the first time a scene uses them. This is mandatory:
# the emitter changed, so a cold cache costs minutes in the first world.
if ($PrewarmSeconds -lt 1) { $PrewarmSeconds = 300 }
if ($SkipPrewarm) { Write-Host "-SkipPrewarm ignored: shader warm-up is mandatory." }
$shaderRoot = Split-Path -Parent $Exe
$warmLog = Join-Path $env:TEMP 'victory-prewarm.out.log'
Write-Host "Prewarming shaders for up to ${PrewarmSeconds}s with $WarmJobs workers (live countdown below)..."

# Run the CPU-only translate in a job so the parent can draw a live countdown.
$warmJob = Start-Job -ScriptBlock {
    param($victoryExe, $shaderDir, $seconds, $workers)
    $env:VICTORY_WARM_SECONDS = "$seconds"
    $env:VICTORY_HOST_WAVE = "32"
    & $victoryExe translate $shaderDir --warm all --jobs $workers 2>&1
} -ArgumentList $victory, $shaderRoot, $PrewarmSeconds, $WarmJobs

$warmStart = Get-Date
while ($warmJob.State -in @('NotStarted', 'Running')) {
    $elapsed = [int]((Get-Date) - $warmStart).TotalSeconds
    $remaining = [math]::Max(0, $PrewarmSeconds - $elapsed)
    $pct = [math]::Min(100, [int](100 * $elapsed / $PrewarmSeconds))
    $filled = [int](20 * $pct / 100)
    $bar = '[' + ('#' * $filled) + ('.' * (20 - $filled)) + ']'
    Write-Host -NoNewline ("`r  prewarm {0} {1,3}%  {2:00}:{3:00} remaining" -f $bar, $pct, [math]::Floor($remaining / 60), ($remaining % 60))
    Start-Sleep -Seconds 1
}
Write-Host ""
$warmOutput = Receive-Job -Job $warmJob
Remove-Job -Job $warmJob -Force
if ($warmOutput) {
    $warmOutput | Out-File -FilePath $warmLog -Encoding utf8
    $warmOutput | Select-Object -Last 5 | ForEach-Object { Write-Host "  $_" }
}
Write-Host ("Prewarm finished after {0}s; log: {1}" -f [int]((Get-Date) - $warmStart).TotalSeconds, $warmLog)
Write-Host "Starting the title..."

# Clear switches from earlier experiments so each launch starts from the same state.
# Removing VICTORY_BAKE_TEXTURES_MS restores its safe 1500 ms pre-bake window.
$remove = @(
    'VICTORY_SKIP_PIPELINES', 'VICTORY_BAKE_TEXTURES_MS',
    'VICTORY_CARD_FETCH_INFLIGHT', 'VICTORY_LEVELS_ON_DEMAND',
    'VICTORY_REFRESH_ONCE', 'VICTORY_AMBIENT', 'VICTORY_INPLACE',
    'VICTORY_EFFICIENCY_MODE', 'VICTORY_DISK_CORES', 'VICTORY_FAST_CORES',
    # Extreme-only switches must never leak into a normal run.
    'VICTORY_CARD_WINDOWS_MB', 'VICTORY_PIPELINE_WAIT_MS',
    'VICTORY_QUEUE2_LANDING_MB', 'VICTORY_CARD_ROOM_FOR_TARGETS_MB',
    'VICTORY_SHADER_LOOP_LIMIT', 'VICTORY_FRAME_LOG'
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
if ($Fast -or $Lean) { $env:VICTORY_FILL_WORKERS = "6" }
if ($Lean) { $env:VICTORY_HEAP_RECHECK = "0" }

if ($Turbo) {
    # Switches from the fork's own play script and README that this launcher
    # was not setting. Together they keep the card fed instead of stalling the
    # submit thread, and let indirect draws use the cheaper window path.
    $env:VICTORY_WIDE_BACK = "1"
    $env:VICTORY_CARD_BUFFERS_MIN_MB = "1"
    $env:VICTORY_INDIRECT_WINDOW_DRAWS = "1"
    $env:VICTORY_INDIRECT_GATHER = "1"
    $env:VICTORY_JOIN_PARTS = "1"
    $env:VICTORY_GUARD_HOLES_FRAME = "1"
    $env:VICTORY_HEAP_WORKER = "1"
    $env:VICTORY_ALIAS_ONCE = "1"
    $env:VICTORY_XMEM_PERSISTENT_VIEW = "1"
    $env:VICTORY_CLAMP_WAITS = "0"
    # Stream textures harder, still bounded by the card budget. -Fast keeps
    # the fork defaults instead: the aggressive values cost 42 ms a frame.
    if (-not $Fast -and $TextureStageMb -lt 320) { $TextureStageMb = 320 }
    if (-not $Fast -and $TextureGateSeconds -lt 90) { $TextureGateSeconds = 90 }
    # Up to 6 s of uploads before the title's decoration bake, instead of the
    # safe 1.5 s: textures picked by index are ready before gameplay starts.
    $env:VICTORY_BAKE_TEXTURES_MS = if ($Fast) { "1500" } else { "3000" }

    if ($Extreme) {
        # Normally the title's vertex/index/constant windows are read over
        # the bus. Put up to 256 MB of them on the card.
        $env:VICTORY_CARD_WINDOWS_MB = "256"
        # Waiting up to 500 ms a frame for background pipelines is often
        # longer than a frame itself.
        $env:VICTORY_PIPELINE_WAIT_MS = "24"
        $env:VICTORY_QUEUE2_LANDING_MB = "128"
        $env:VICTORY_CARD_ROOM_FOR_TARGETS_MB = "3072"
        # Only honoured by a diagnostics build; harmless in release.
        $env:VICTORY_SHADER_LOOP_LIMIT = "256"
        if ($TextureStageMb -lt 384) { $TextureStageMb = 384 }
        if ($TextureGateSeconds -lt 120) { $TextureGateSeconds = 120 }
        $env:VICTORY_BAKE_TEXTURES_MS = "8000"
    }
}

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
$env:VICTORY_TEXTURE_STAGE_MS = "$TextureStageMs"
$env:VICTORY_TEXTURE_CATCHUP = "1"
$env:VICTORY_TEXTURE_GATE_S = "$TextureGateSeconds"
# Spend a little more time uploading before the first indexed draw, and keep
# the decoration bake's texture window enabled (default 1500 ms).
$env:VICTORY_EARLY_TEXTURES_MS = "$EarlyTexturesMs"
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

$profile = if ($Extreme) { "EXTREME" } elseif ($Lean) { "LEAN" } elseif ($Fast) { "FAST" } elseif ($Turbo) { "TURBO" } elseif ($Menu) { "MENU" } elseif ($Safe) { "SAFE" } else { "GAME" }
Write-Host "Launching [$profile] at $DisplayMode, dropMips=$DropMips, textureStage=${TextureStageMb}MB, textureBudget=${TextureBudgetMb}MB"
& $victory run $Exe --execute
