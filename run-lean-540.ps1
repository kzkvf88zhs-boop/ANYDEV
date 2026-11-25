# Lean A/B at 960x540: 44% fewer pixels than 720p for a GPU-bound run.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $here "run-optimized.ps1") -Lean -Resolution "960x540" @args
