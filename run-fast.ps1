# Speed switches with stock texture budgets: targets the 42 ms heap/texture pass.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $here "run-optimized.ps1") -Fast @args
