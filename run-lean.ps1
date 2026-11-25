# A/B profile: max fill workers + no post-upload texture recheck.
# Risk: textures changed without a descriptor write may stay stale.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $here "run-optimized.ps1") -Lean @args
