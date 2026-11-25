# Progress checkpoint — 2026-11-25

Branch: `quality-port` (repo `C:\Users\vedan\victory-nvidia-8gb`).

User is increasing the Windows page file and restarting the PC. Work is paused until they confirm the restart is done.

## Current run at checkpoint

- Launcher: `run-menu.ps1 -SkipPrewarm` (fast profile, **not** `-Safe`), 1080p.
- Menu profile: `VICTORY_TEXTURE_DROP_MIPS=1` (sharp menu), `TextureBudgetMb=4096`, `TextureStageMb=192`.
- Shader cache: prewarmed with the modified translator; the prewarm pass reached 12k shaders and exited with code 1 before printing its summary. The cached shaders are still usable.
- Observed menu FPS in logs: ~30 fps. User reports the visual result was good but gameplay FPS was ~4.
- The previous `-Safe` launch and a game-profile (`DropMips=2`) menu launch caused the big slowdown/pixelation; both were corrected before this checkpoint.

## Source state (uncommitted work being saved now)

- `crates/victory-formats/src/texture.rs`: added `Layout::bytes_from`.
- `crates/victory-gpu/src/resource.rs`: added `placed_bytes_from` and `first_mip`.
- `crates/victory-gpu/src/draw.rs`: texture pass uses mip-aware byte length; added gated catch-up (`VICTORY_TEXTURE_GATE_S`, default 60 s).
- `crates/victory-gpu/src/descriptor/host.rs`: remap coalescing and full-rescan fallback instead of dropping notifications.
- `crates/victory-shader/src/emit/lower.rs`: DexNom pixel-quad sampling, DPP handling, memory count guard, and cube LOD fix.
- `crates/victory-gpu/src/host.rs`: partial port of DexNom `VICTORY_FILL_WORKERS` / grouped upload fills. **Not yet compiled.**
- Launcher scripts: `run-optimized.ps1`, `run-menu.ps1`, `run-game.ps1`, `prewarm-shaders.ps1`.

## Important: binary vs source

- `target\release\victory.exe` was last built **before** the `host.rs` fill-worker port. It contains all other edits.
- A low-priority `cargo check` into a separate target dir was started to validate the fill-worker port, then stopped for the restart. Its result is unknown.

## Next steps after restart

1. Run `cargo check --release -p victory --bin victory` (or `cargo build --release -p victory --bin victory`) and fix any errors in the fill-worker port.
2. Rebuild `target\release\victory.exe` while no game is running.
3. Re-run prewarm (shader emitter changed, so the cache may need a second pass).
4. Launch with `run-menu.ps1 -SkipPrewarm` for sharp menus, then `run-game.ps1 -SkipPrewarm` for gameplay (`DropMips=2`).
5. Compare FPS after the larger page file. If gameplay is still ~4 fps, reduce streaming pressure next: try `-TextureGateSeconds 0` or `-TextureStageMb 96`, and consider `-LowVram` only if card memory pressure is visible.
6. Keep `DropMips=2` in gameplay and `DropMips=1` in menus. Do not use `DropMips=3` (blurry) or raise `VICTORY_TEXTURE_BUDGET_MB` above 4096 on this 8 GB card.

## Logs

- `C:\Users\vedan\AppData\Local\Temp\opencode\victory-menu-sharp.err.log` — latest sharp menu run.
- `C:\Users\vedan\AppData\Local\Temp\opencode\victory-game-fast.err.log` — earlier fast run that later dropped to ~8 fps during a texture burst.
- `C:\Users\vedan\AppData\Local\Temp\opencode\victory-prewarm-fast.err.log` — prewarm progress.
