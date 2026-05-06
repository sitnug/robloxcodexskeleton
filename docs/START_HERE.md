# Start Here

This folder is ready to use as the base for a new Roblox game built with Rojo.

## First Run

```bash
make install
make doctor
make serve
```

Open Roblox Studio, open or create the place for this game, and connect the Rojo plugin to:

```text
localhost:34872
```

## Daily Loop

1. Edit source files in `src/`.
2. Keep Rojo running with `make serve`.
3. Test in Roblox Studio.
4. Run `make check`.
5. Mirror any important Studio-created scripts/models back into Rojo source.

## Source Layout

- `src/shared` becomes `ReplicatedStorage.Shared`.
- `src/remotes` becomes `ReplicatedStorage.Remotes`.
- `src/server` becomes `ServerScriptService.Server`.
- `src/client` becomes `StarterPlayer.StarterPlayerScripts.Client`.

## What Belongs In Each Place

- Shared pure modules, constants, config, and type helpers: `src/shared`.
- RemoteEvent and RemoteFunction definitions: `src/remotes`.
- Authoritative gameplay, saves, economy, purchases, NPC ownership, rewards, and anti-exploit validation: `src/server`.
- UI, camera, input, local effects, animations, and presentation: `src/client`.

## Working With Codex

Ask Codex for concrete changes and give object names or coordinates when map context matters.

Good examples:

- "Inspect Workspace and summarize all parts named Door, Button, Spawn, or Checkpoint with coordinates."
- "Create a server-authoritative coin pickup system using CollectionService tags."
- "Add a RemoteEvent for opening a door, but validate distance and cooldown on the server."
- "Move this Studio prototype into Rojo source and run make check."

Codex should always prefer durable source changes over Studio-only edits.

## Before You Build Real Gameplay

- Name important map objects clearly.
- Add tags/attributes for gameplay objects that scripts need to find.
- Decide which state is server-owned before adding remotes.
- Keep client code able to handle streamed-out Workspace instances.
- Add cleanup paths for players leaving, characters respawning, UI closing, and rounds ending.

## Ready Check

Run:

```bash
make check
```

This verifies formatting, linting, sourcemap generation, and Rojo build output.
