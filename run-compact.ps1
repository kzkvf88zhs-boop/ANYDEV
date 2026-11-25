# No-visual-loss VRAM profile: on-demand mips + smaller texture/card caches.
# Does not change resolution or DROP_MIPS. Not launched yet.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $here "run-optimized.ps1") -Compact @args
