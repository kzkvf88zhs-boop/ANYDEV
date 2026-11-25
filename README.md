# anydev — 8 GB NVIDIA build

A personal build of **soldsawn/victory-nvidia-8gb**, tuned for an **RTX 4060 Laptop 8 GB (Wave32)** on Windows 11. This is the build that held roughly **8 fps consistently** in prior runs on this machine. It is not a general VIctory release and it ships no game files.

## Credits

This build would not exist without:

- **[soldsawn/victory-nvidia-8gb](https://github.com/soldsawn/victory-nvidia-8gb)** — the direct base. Its README documents the 8 GB texture-drop finding and the RTX 4060 Laptop measurements.
- **[fxceless/victory-fork](https://github.com/fxceless/victory-fork)** — parent fork with the rendering, shader and relay work.
- **[Marvisak/VIctory](https://github.com/Marvisak/VIctory)** — the original compatibility layer: loader, runtime services, D3D12 backend and shader recompiler. Licensed GPL-3.0-or-later.
- **[ivall/xcl](https://github.com/ivall/xcl)** — independent reference layer that informed fixes (GPL-2.0-only).
- All upstream contributors and integrated PR authors listed in `README.upstream.md`.

Licensed **GPL-3.0-or-later**. See `LICENSE`.

## What is different in anydev

- `crates/victory-gpu/src/host.rs`: fixed the fill-worker match arm that prevented the current source from compiling.
- `run-optimized.ps1`: shader prewarm is mandatory and shows a **live countdown**; the `-SkipPrewarm` switch is accepted but ignored. Added a **Turbo** profile (720p) and an experimental **Extreme** profile (960×540, card-side windows, 24 ms pipeline wait).
- `run-turbo.ps1`: one-command stable gameplay profile (1080p-ready fallback, 720p by default in Turbo).
- `run-extreme.ps1`: experimental maximum-throughput profile. It produced a black display in testing — use only for A/B experiments.
- Texture streaming: longer decoration-bake window, larger staging budget and catch-up gate; all bounded by the card budget.

The upstream README is preserved as `README.upstream.md`.

## Requirements

- Windows 10/11 x64, AVX2 CPU, Rust from `rust-toolchain.toml`.
- Direct3D 12 GPU with Shader Model 6.6 and mesh shaders. Tested on RTX 4060 Laptop 8 GB.
- A large Windows paging file (48 GB was used during testing).
- Your own copy of the Xbox Series title. **No game files are included.**

## Build

```powershell
cargo build --release -p victory
```

The binary is `target\release\victory.exe`.

## Run

```powershell
powershell -ExecutionPolicy Bypass -File .\run-turbo.ps1
```

`run-turbo.ps1` always prewarms shaders first (with a live countdown), then launches at 1280×720 with `VICTORY_TEXTURE_DROP_MIPS=2` and the tuned 8 GB switches. For a menu-only run use `run-menu.ps1`; for the experimental profile use `run-extreme.ps1`.

Input: XInput pads, or keyboard pad when the game window has focus (WASD/IJKL, arrows, Enter/Backspace/X/Y, Q/E, Z/C, Esc/Tab).

## Data locations

- Saves and `crashes.log`: `%LOCALAPPDATA%\victory\data`
- Shader/pipeline cache: `%LOCALAPPDATA%\victory\cache`
- Local config: `victory.toml` (git-ignored; keep paths outside the repo)

## Performance notes

- The base fork measured 153–172 ms/frame (~6 fps) at 1080p with full scene on this GPU.
- This build was observed at about **8 fps consistently** with the Turbo switches.
- It is **not** a 15 fps/playable build: indirect-draw clamping, copies and translated shaders remain the bottleneck.

See `DEPLOY.md` for what to upload and how to publish this fork.
