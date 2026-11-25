# Menus, intro credits and logos: sharper textures, lighter scene.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $here "run-optimized.ps1") -Menu @args
