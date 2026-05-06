# Roblox Best Practices

This guide is intentionally practical. Use it when adding gameplay, remotes, UI, map objects, or persistence.

## Core Rule

The server owns truth. The client can request, display, predict, and animate, but the server decides.

Server-owned examples:

- Currency and inventory.
- Damage and healing.
- Purchases and rewards.
- Match state and progression.
- Checkpoints, unlocks, cooldowns, and permissions.

Client-owned examples:

- Input collection.
- Camera and UI state.
- Animation, sound, particles, and presentation.
- Temporary prediction that the server can correct.

## Remotes

Create remotes under `ReplicatedStorage.Remotes`.

Every server remote handler should answer these questions:

- Who may call this?
- What exact argument types and ranges are accepted?
- What server state must be true before accepting it?
- How often may this player call it?
- What happens if it is spammed, malformed, late, or duplicated?

Prefer `RemoteEvent` for one-way messages. Use `RemoteFunction` only when the caller must synchronously receive a value. Avoid server `InvokeClient`.

## Workspace Objects

Use clear names, tags, attributes, and coordinates:

- Names identify intent, such as `Door_Lobby`, `Button_LobbyDoor`, `Checkpoint_03`.
- Tags identify groups, such as `Door`, `Pickup`, `Checkpoint`, `DamageZone`.
- Attributes configure behavior, such as `CooldownSeconds`, `RewardAmount`, `DoorId`.
- Coordinates and pivots describe placement.

With `StreamingEnabled`, client scripts must tolerate missing Workspace instances. Use timeouts and server-owned validation.

## Persistence

Keep DataStore code server-only.

Use `pcall` around DataStore operations. Prefer `UpdateAsync` when writing player data that might have changed elsewhere. Cache session state in memory and avoid saving every tiny change immediately.

Plan for:

- Player leaving.
- Server shutdown.
- Failed saves.
- Retry/backoff.
- Schema migration.
- User data deletion/export needs.

## Performance

Avoid hot-path broad scans like repeated `workspace:GetDescendants()` calls. Build indexes once and update them with signals or CollectionService tags.

Use events instead of per-frame loops when possible. When per-frame work is necessary, keep it client-side unless it affects authority.

Watch for:

- Too many unanchored parts.
- Heavy physics and constraints.
- NPC humanoid cost.
- High remote traffic.
- Expensive UI updates.
- Memory leaks from unclosed connections.

Use MicroProfiler and Developer Console when performance feels suspicious.

## Lifecycle Cleanup

Clean up:

- RBXScriptConnections.
- Loops/tasks.
- Temporary Instances.
- Per-player tables.
- Character-bound state on respawn.
- UI connections when screens close.

If a module creates resources, it should also expose or own the cleanup path.

## Rojo Source Control

Rojo is one-way from files to Studio for normal work. If a change must persist, put it in the filesystem.

Use:

- `.luau` for scripts/modules.
- `.client.luau` for LocalScripts.
- `.server.luau` for Scripts.
- `.model.json` for simple Roblox Instances.
- `.meta.json` for class/properties on the containing directory or file.

Generated files like `build/` and `sourcemap.json` should stay out of git.

## Definition Of Done

A production-facing gameplay change is done when:

- Source files are updated.
- Rojo sync/build succeeds.
- `stylua --check src` passes.
- `selene src` passes.
- Studio playtest has no relevant output errors.
- Remotes are validated server-side.
- Player lifecycle cleanup is handled.
