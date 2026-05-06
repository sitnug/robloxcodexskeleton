# Codex Instructions for testrblx

These instructions are for Codex and any future AI/code agent working in this repository.
Follow them before making Roblox Studio, Rojo, or Luau changes.

## Mission

- This is a Rojo-managed Roblox game. Treat the filesystem as the source of truth.
- Build features so they can survive production: secure server authority, clear module boundaries, typed Luau, repeatable local checks, and no hidden Studio-only state.
- Prefer small, shippable changes that can be tested in Studio through Rojo.

## Start Every Task

- Read `README.md`, this file, and any relevant docs in `docs/`.
- Check `git status --short` before editing. Do not overwrite or revert user work.
- Inspect the current Rojo map in `default.project.json` before adding files.
- If Roblox Studio tools are needed, call `list_roblox_studios`, then `set_active_studio` for the intended Studio instance before reading or mutating the game.
- Prefer filesystem edits under `src/`, `default.project.json`, and config files. Direct Studio edits are allowed for inspection/prototyping, but persistent code or model changes must be mirrored into Rojo files.
- Run `make check` before final handoff unless the task is purely documentation.

## Rojo Map

- `src/shared` syncs to `ReplicatedStorage.Shared`.
- `src/remotes` syncs to `ReplicatedStorage.Remotes`.
- `src/server` syncs to `ServerScriptService.Server`.
- `src/client` syncs to `StarterPlayer.StarterPlayerScripts.Client`.
- Files ending in `.spec.luau` or `.test.luau` are ignored by Rojo and should stay out of live game runtime.
- Use `.model.json` files for simple Instances like `RemoteEvent`, `RemoteFunction`, folders, values, and simple parts.
- Use `.meta.json` only when changing the class/properties of the containing filesystem object is clearer than creating a model file.
- Do not assume all Studio properties live-sync through Rojo. For terrain, CSG, MeshPart asset data, and other non-script-heavy assets, verify with a Rojo build/open flow.

## Luau Style

- Add `--!strict` to new Luau files.
- Keep bootstrap scripts tiny. Put feature logic in ModuleScripts with typed public functions.
- Use `game:GetService()` at the top of each file for services.
- Avoid `_G`, `shared`, mutable globals, and hidden cross-script state.
- Prefer clear data tables and explicit return values over Instance lookups scattered through gameplay code.
- Use `task.wait`, `task.defer`, and event-driven code; avoid busy loops and unbounded spawned threads.
- Keep modules focused. A module should have one clear reason to change.
- Add explicit Luau types at public module boundaries and for non-trivial tables.
- Return frozen constant/config tables when they are not meant to mutate.
- Avoid comments that repeat the code. Add comments only to explain non-obvious Roblox behavior, lifecycle, replication, or security assumptions.

## Client And Server

- The server owns gameplay truth: economy, inventory, progression, damage, cooldowns, purchases, match state, and rewards.
- Clients handle input, UI, camera, animation presentation, audio/visual effects, and prediction only when the server can verify the result.
- Never trust client-provided currency, inventory, position, hit results, cooldown state, or permissions.
- Keep sensitive modules and data in server-only containers; do not place secrets or authority logic in replicated locations.
- Put shared pure data/helpers in `ReplicatedStorage.Shared`. Do not put server-only logic there.
- Design gameplay state so a late-joining or respawned client can reconstruct the current view from server-owned state.
- Do not store long-lived per-player state only in UI or client scripts.

## Remotes

- Put shared remotes under `ReplicatedStorage.Remotes`, preferably as `.model.json` files.
- Prefer `RemoteEvent` for one-way messages. Use `RemoteFunction` only when a response is genuinely required.
- Avoid server `InvokeClient`; a client error, disconnect, or missing return can stall server code.
- Validate every server remote by type, shape, range, state, ownership, distance, permission, and cooldown.
- Rate-limit client-to-server remotes and design every handler as if it can be called thousands of times per second.
- Use `UnreliableRemoteEvent` only for continuous, non-critical data where loss or reordering is acceptable.
- Keep remote names boring but not security-sensitive. Security must come from server validation, not obscurity.
- Do not create a remote before defining who may call it, when they may call it, and what server state it can change.
- Never let a client request directly set final state. Treat client messages as intents.

## Data Persistence

- Wrap DataStore calls in `pcall` and handle unknown write outcomes.
- Prefer `UpdateAsync` for player data mutations that must not overwrite newer state.
- Check request budgets before bursts and cache session data in memory instead of reading/writing every small change.
- Do not enable Studio access to live production DataStores or touch live player data unless the user explicitly asks.
- Keep persistence code server-only.
- Separate runtime state from serialized save data. Save only the durable data needed to restore a player.
- Plan for retries, shutdown saves, partial failures, schema migration, and player data erasure/export requests.

## Performance And Lifecycle

- Clean up connections, tasks, instances, and per-player state on removal.
- Use CollectionService tags or explicit registries for many world objects instead of repeated broad tree scans.
- Profile suspicious work with MicroProfiler and `debug.profilebegin` / `debug.profileend`.
- Keep remotes small and purposeful; batch only when it makes the state model simpler.
- With `Workspace.StreamingEnabled`, client code must tolerate streamed-out world instances and use defensive waits/timeouts.
- Avoid `GetDescendants()` loops in hot paths. Build indexes once or update them from add/remove signals.
- Avoid per-frame work unless it is truly frame-dependent. Prefer events, timers, and dirty flags.
- Be careful with NPCs, physics, constraints, particles, and unanchored parts; they can dominate server/client cost.
- Always disconnect event connections and cancel loops when a player, character, tool, UI, or round ends.

## Workspace And Map Objects

- Use object names, tags, attributes, pivots, `CFrame`, `Position`, and `Size` as the reliable map language.
- For map interaction work, inspect `Workspace` structurally first, then modify scripts or Rojo model files.
- If creating gameplay objects in Studio, add stable names/tags and mirror important objects into Rojo-compatible files or documented Studio asset workflow.
- Do not assume a client can always see a Workspace object when StreamingEnabled is on.
- Prefer server-side hit/zone checks for rewards, damage, doors, purchases, and progression.

## UI

- Keep UI code client-side, but keep purchase/economy/reward decisions server-side.
- UI should observe replicated state or server responses; it should not be the source of gameplay truth.
- Clean up UI connections on close/destroy and when the local player respawns.

## Tooling

- Install pinned tools with `aftman install --no-trust-check`.
- Format with `stylua src`.
- Lint with `selene src`.
- Generate editor sourcemaps with `rojo sourcemap default.project.json -o sourcemap.json`.
- Build a place artifact with `rojo build default.project.json -o build/testrblx.rbxlx`.
- Start Rojo with `rojo serve default.project.json` or `make serve`.
- Run `make check` before handing off production-facing changes.
- If adding Wally packages, update `wally.toml`, run `wally install`, commit `wally.lock`, and wire `Packages` into Rojo only when packages exist.
- Generated artifacts such as `build/` and `sourcemap.json` are ignored by git.

## Definition Of Done

- The change is mirrored in source files and survives a Rojo rebuild.
- `stylua --check src`, `selene src`, `rojo sourcemap`, and `rojo build` pass, or any skipped check is explained.
- Studio runtime behavior has been checked when the change touches gameplay, remotes, UI, Workspace, or player lifecycle.
- New remotes have validation and rate/cooldown thinking.
- New player state has cleanup on player removal and does not leak connections.
- The final response lists changed files, checks run, and any remaining risk.

## Good Codex Requests For This Project

- "Inspect Workspace and summarize named gameplay objects with coordinates."
- "Add a server-authoritative door interaction for this button and door."
- "Create a RemoteEvent under ReplicatedStorage.Remotes and add safe server validation."
- "Move this prototype Studio script into Rojo source."
- "Run make check and inspect Studio output for errors."

## References

- Roblox security guidance: https://create.roblox.com/docs/scripting/security/security-tactics
- Roblox remote events/callbacks: https://create.roblox.com/docs/scripting/events/remote
- Roblox DataStore limits/errors: https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits
- Roblox MicroProfiler: https://create.roblox.com/docs/performance-optimization/microprofiler
- Roblox Open Cloud API keys: https://create.roblox.com/docs/cloud/auth/api-keys
- Rojo sync details: https://rojo.space/docs/v7/sync-details/
