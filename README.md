# testrblx

A production-oriented Roblox game project using [Rojo](https://github.com/rojo-rbx/rojo), Selene, StyLua, and Wally.

## Start Here

1. Install tools:

```bash
make install
```

2. Confirm the toolchain:

```bash
make doctor
```

3. Start Rojo:

```bash
make serve
```

4. In Roblox Studio, connect the Rojo plugin to `localhost:34872`.

5. Before handoff or committing, run:

```bash
make check
```

## Getting Started

Install the pinned local toolchain:

```bash
aftman install --no-trust-check
```

To build the place from scratch, use:

```bash
make build
```

Next, open `build/testrblx.rbxlx` in Roblox Studio and start the Rojo server:

```bash
rojo serve
```

## Daily Workflow

```bash
stylua src
selene src
rojo sourcemap default.project.json -o sourcemap.json
```

You can run the full local check with:

```bash
make check
```

## Project Layout

- `src/shared` -> `ReplicatedStorage.Shared`
- `src/remotes` -> `ReplicatedStorage.Remotes`
- `src/server` -> `ServerScriptService.Server`
- `src/client` -> `StarterPlayer.StarterPlayerScripts.Client`

See `AGENTS.md` for Codex-specific editing rules and production guardrails for Roblox code.

More project guidance lives in:

- `docs/START_HERE.md`
- `docs/ROBLOX_BEST_PRACTICES.md`
