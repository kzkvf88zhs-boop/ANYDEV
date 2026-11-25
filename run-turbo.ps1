# Maximum-effort profile: 720p + every known 8 GB / NVIDIA speed switch.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $here "run-optimized.ps1") -Turbo @args
