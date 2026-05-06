--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)
local WorldBuilder = require(script.Parent.WorldBuilder)

type EnemyRuntime = {
	configId: string,
	name: string,
	health: number,
	maxHealth: number,
	attack: number,
	rewardGold: number,
	rewardShards: number,
	rewardXp: number,
	model: Model,
	root: BasePart,
	alive: boolean,
}

type RunState = {
	player: Player,
	floorId: number,
	roomIndex: number,
	arena: WorldBuilder.RunArena,
	enemies: { EnemyRuntime },
	chestReady: boolean,
	chestClaimed: boolean,
	health: number,
	maxHealth: number,
	lastAttackAt: number,
	slot: number,
}

local DungeonService = {}

local runs: { [Player]: RunState } = {}
local runSlots: { [Player]: number } = {}
local freeRunSlots: { number } = {}
local nextRunSlot = 0

local stateUpdateRemote: RemoteEvent? = nil
local toastRemote: RemoteEvent? = nil

local function toast(player: Player, message: string)
	local remote = toastRemote
	if remote ~= nil then
		remote:FireClient(player, message)
	end
end

local function sendRunState(player: Player)
	local remote = stateUpdateRemote
	if remote == nil then
		return
	end

	local run = runs[player]
	if run == nil then
		remote:FireClient(player, {
			kind = "Run",
			run = {
				active = false,
			},
		})
		return
	end

	local enemiesLeft = 0
	local enemyHealth = 0
	local enemyMaxHealth = 0

	for _, enemy in run.enemies do
		if enemy.alive then
			enemiesLeft += 1
			enemyHealth += enemy.health
			enemyMaxHealth += enemy.maxHealth
		end
	end

	local floor = GameConfig.Floors[run.floorId]

	remote:FireClient(player, {
		kind = "Run",
		run = {
			active = true,
			floor = run.floorId,
			floorName = if floor ~= nil then floor.name else "Unknown Depth",
			room = run.roomIndex,
			rooms = if floor ~= nil then floor.rooms else 1,
			health = run.health,
			maxHealth = run.maxHealth,
			enemiesLeft = enemiesLeft,
			enemyHealth = enemyHealth,
			enemyMaxHealth = enemyMaxHealth,
			chestReady = run.chestReady,
		},
	})
end

local function acquireRunSlot(player: Player): number
	local existing = runSlots[player]
	if existing ~= nil then
		return existing
	end

	local slot = table.remove(freeRunSlots)
	if slot == nil then
		nextRunSlot += 1
		slot = nextRunSlot
	end

	runSlots[player] = slot
	return slot
end

local function releaseRunSlot(player: Player)
	local slot = runSlots[player]
	if slot ~= nil then
		table.insert(freeRunSlots, slot)
	end

	runSlots[player] = nil
end

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function countAliveEnemies(enemies: { EnemyRuntime }): number
	local count = 0
	for _, enemy in enemies do
		if enemy.alive then
			count += 1
		end
	end

	return count
end

local function endRun(player: Player, message: string?)
	local run = runs[player]
	if run == nil then
		sendRunState(player)
		return
	end

	WorldBuilder.destroyRunArena(run.arena)
	runs[player] = nil
	releaseRunSlot(player)
	WorldBuilder.teleportToLobby(player)
	sendRunState(player)

	if message ~= nil then
		toast(player, message)
	end
end

local function spawnRoomEnemies(run: RunState)
	local floor = GameConfig.Floors[run.floorId]
	if floor == nil then
		return
	end

	run.enemies = {}

	local pack = floor.enemyPacks[run.roomIndex]
	if pack == nil then
		pack = { "boneCrawler" }
	end

	local roomCenter = run.arena.roomCenters[run.roomIndex]
	local spread = 8

	for index, enemyId in pack do
		local enemyConfig = GameConfig.Enemies[enemyId] or GameConfig.Enemies.boneCrawler
		local offset =
			Vector3.new(((index - 1) - (#pack - 1) / 2) * spread, 0, -4 - ((index % 2) * 7))
		local health = math.floor(enemyConfig.health * (1 + ((run.floorId - 1) * 0.18)))
		local model, root =
			WorldBuilder.createEnemyModel(run.arena.folder, enemyConfig, roomCenter + offset, index)

		table.insert(run.enemies, {
			configId = enemyId,
			name = enemyConfig.name,
			health = health,
			maxHealth = health,
			attack = math.floor(enemyConfig.attack * (1 + ((run.floorId - 1) * 0.14))),
			rewardGold = enemyConfig.rewardGold,
			rewardShards = enemyConfig.rewardShards,
			rewardXp = enemyConfig.rewardXp,
			model = model,
			root = root,
			alive = true,
		})
	end

	sendRunState(run.player)
end

local function completeRoom(run: RunState)
	local floor = GameConfig.Floors[run.floorId]
	if floor == nil then
		return
	end

	if run.roomIndex < floor.rooms then
		WorldBuilder.setGateOpen(run.arena, run.roomIndex)
		run.roomIndex += 1
		spawnRoomEnemies(run)
		toast(run.player, `Room {run.roomIndex - 1} cleared. Gate opened.`)
	else
		run.chestReady = true
		WorldBuilder.setChestReady(run.arena, true)
		toast(run.player, "Floor cleared. Claim the chest.")
		sendRunState(run.player)
	end
end

local function findNearestAliveEnemy(run: RunState, root: BasePart): EnemyRuntime?
	local nearest: EnemyRuntime? = nil
	local nearestDistance = math.huge

	for _, enemy in run.enemies do
		if enemy.alive and enemy.root.Parent ~= nil then
			local distance = (enemy.root.Position - root.Position).Magnitude
			if distance < nearestDistance then
				nearest = enemy
				nearestDistance = distance
			end
		end
	end

	if nearestDistance > GameConfig.Player.AttackRange then
		return nil
	end

	return nearest
end

local function startFloor(player: Player, floorId: number)
	if runs[player] ~= nil then
		toast(player, "Finish or return from your current run first.")
		return
	end

	local floor = GameConfig.Floors[floorId]
	local profile = PlayerDataService.getPublicState(player)
	if floor == nil or profile == nil then
		toast(player, "That floor is not available.")
		return
	end

	if floorId > profile.highestFloor + 1 then
		toast(player, "Clear the previous floor first.")
		return
	end

	local slot = acquireRunSlot(player)
	local arena = WorldBuilder.createRunArena(player, floor, slot)
	local maxHealth = PlayerDataService.getMaxHealth(player)

	local run = {
		player = player,
		floorId = floorId,
		roomIndex = 1,
		arena = arena,
		enemies = {},
		chestReady = false,
		chestClaimed = false,
		health = maxHealth,
		maxHealth = maxHealth,
		lastAttackAt = 0,
		slot = slot,
	}

	runs[player] = run
	local character = player.Character
	if character ~= nil then
		character:PivotTo(arena.spawnCFrame)
	end

	spawnRoomEnemies(run)
	toast(player, `Entered {floor.name}.`)
end

local function attackNearest(player: Player)
	local run = runs[player]
	if run == nil then
		toast(player, "Start a dungeon run first.")
		return
	end

	if run.chestReady then
		toast(player, "The floor is clear. Claim the chest.")
		return
	end

	local now = os.clock()
	local cooldown = PlayerDataService.getAttackCooldown(player)
	if now - run.lastAttackAt < cooldown then
		return
	end

	local root = getCharacterRoot(player)
	if root == nil then
		return
	end

	local enemy = findNearestAliveEnemy(run, root)
	if enemy == nil then
		toast(player, "Move closer to an enemy.")
		return
	end

	run.lastAttackAt = now
	local damage = PlayerDataService.getDamage(player)
	enemy.health = math.max(0, enemy.health - damage)

	if enemy.health <= 0 then
		enemy.alive = false
		enemy.model:Destroy()
		PlayerDataService.addRewards(player, {
			gold = enemy.rewardGold,
			shards = enemy.rewardShards,
			xp = enemy.rewardXp,
		}, "EnemyDefeated")

		if countAliveEnemies(run.enemies) == 0 then
			completeRoom(run)
		else
			sendRunState(player)
		end
	else
		run.health = math.max(0, run.health - enemy.attack)
		if run.health <= 0 then
			endRun(player, "You were defeated and returned to the lobby.")
			return
		end

		sendRunState(player)
	end
end

local function claimChest(player: Player)
	local run = runs[player]
	if run == nil then
		return
	end

	if not run.chestReady or run.chestClaimed then
		toast(player, "No chest is ready yet.")
		return
	end

	local floor = GameConfig.Floors[run.floorId]
	if floor == nil then
		return
	end

	run.chestClaimed = true
	PlayerDataService.recordFloorCleared(player, run.floorId)
	PlayerDataService.addRewards(player, {
		gold = floor.completionGold,
		shards = floor.completionShards,
		xp = floor.completionXp,
	}, "FloorChestClaimed")

	endRun(player, `{floor.name} cleared. Rewards claimed.`)
end

local function readString(payload: any, key: string): string?
	if typeof(payload) ~= "table" then
		return nil
	end

	local value = payload[key]
	return if typeof(value) == "string" then value else nil
end

local function readNumber(payload: any, key: string): number?
	if typeof(payload) ~= "table" then
		return nil
	end

	local value = payload[key]
	return if typeof(value) == "number" then value else nil
end

local function handleShopResult(player: Player, ok: boolean, message: string)
	toast(player, message)

	if not ok then
		return
	end

	sendRunState(player)
end

function DungeonService.endRunForPlayer(player: Player, message: string?)
	endRun(player, message)
end

function DungeonService.start(
	commandRemote: RemoteEvent,
	stateRemote: RemoteEvent,
	toastEvent: RemoteEvent
)
	stateUpdateRemote = stateRemote
	toastRemote = toastEvent

	commandRemote.OnServerEvent:Connect(function(player: Player, action: any, payload: any)
		if typeof(action) ~= "string" then
			return
		end

		if not PlayerDataService.consumeActionCooldown(player, `cmd_{action}`, 0.08) then
			return
		end

		if action == "RequestState" then
			sendRunState(player)
		elseif action == "StartFloor" then
			local requestedFloor = readNumber(payload, "floor") or 1
			startFloor(player, math.floor(requestedFloor))
		elseif action == "AttackNearest" then
			attackNearest(player)
		elseif action == "ClaimChest" then
			claimChest(player)
		elseif action == "ReturnLobby" then
			endRun(player, "Returned to the lobby.")
		elseif action == "BuySword" then
			local swordId = readString(payload, "id")
			if swordId ~= nil then
				handleShopResult(player, PlayerDataService.buySword(player, swordId))
			end
		elseif action == "EquipSword" then
			local swordId = readString(payload, "id")
			if swordId ~= nil then
				handleShopResult(player, PlayerDataService.equipSword(player, swordId))
			end
		elseif action == "BuyUpgrade" then
			local upgradeId = readString(payload, "id")
			if upgradeId ~= nil then
				handleShopResult(player, PlayerDataService.buyUpgrade(player, upgradeId))
			end
		elseif action == "BuyBase" then
			local baseId = readString(payload, "id")
			if baseId ~= nil then
				handleShopResult(player, PlayerDataService.buyBase(player, baseId))
			end
		elseif action == "EquipBase" then
			local baseId = readString(payload, "id")
			if baseId ~= nil then
				handleShopResult(player, PlayerDataService.equipBase(player, baseId))
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		endRun(player, nil)
	end)
end

return DungeonService
