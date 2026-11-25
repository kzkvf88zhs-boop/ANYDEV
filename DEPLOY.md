# Deploying anydev

## 1. What to upload

Upload the **source tree only**. Do not upload game files, built binaries, caches, logs, or local config.

Include:

- `README.md` — this build's description and credits
- `README.upstream.md` — preserved upstream README
- `DEPLOY.md` — this checklist
- `LICENSE`
- `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`, `rustfmt.toml`, `.gitignore`, `.victory-root`
- `.cargo/`, `.githooks/`, `.github/`
- `apps/`, `crates/`, `docs/`, `scripts/`, `tests/`, `xtask/`
- `run-optimized.ps1`, `run-game.ps1`, `run-menu.ps1`, `run-turbo.ps1`, `run-extreme.ps1`, `victory.example.toml`
- `crates/victory-formats/src/bcpack-tables.bin` (the one allowed binary data file)

Never upload:

- anything from the game (`*.rpf`, `*.xvd`, `game_scarlett_master.exe`, DLLs, saves)
- `target/`, `target-diag/`
- `%LOCALAPPDATA%\victory\cache` or `data`
- `victory.toml`, `*.log`, `*.transcript.txt`
- any game executable or extracted archive

`.gitignore` and `cargo xtask policy` enforce this.

## 2. Create the GitHub repository

Create an **empty** repo named `anydev` on GitHub (no README, no license, no `.gitignore` — the local files already exist).

## 3. Push the local fork

From `C:\Users\vedan\anydev`:

```powershell
git remote set-url origin https://github.com/<YOUR-GITHUB-USER>/anydev.git
git push -u origin anydev:main
```

If Git asks for credentials, use a Personal Access Token with `repo` scope, or configure a credential helper:

```powershell
git config --global credential.helper manager
```

## 4. Optional: publish a release with binaries

Build locally, then attach these files to a GitHub Release manually:

- `target\release\victory.exe`
- `run-turbo.ps1`, `run-optimized.ps1`, `run-game.ps1`, `run-menu.ps1`
- `README.md`, `LICENSE`

Do **not** attach game files or shader caches to the release.

## 5. Verify

After pushing, open `https://github.com/<YOUR-GITHUB-USER>/anydev` and confirm that `README.md`, `run-turbo.ps1`, and the `crates/` folder are present, and that no `target/` or game data appears.
