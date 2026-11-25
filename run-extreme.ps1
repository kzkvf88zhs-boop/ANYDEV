# Experimental maximum-throughput profile. Restart required to take effect.
# 960x540, card-side windows, 24 ms pipeline wait, 8 s texture bake.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $here "run-optimized.ps1") -Extreme @args
