--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

type Cost = GameConfig.Cost

type PublicState = {
	gold: number,
	shards: number,
	xp: number,
	level: number,
	highestFloor: number,
	equippedSword: string,
	ownedSwords: { string },
	upgrades: { [string]: number },
	equippedBase: string,
	ownedBases: { string },
	power: number,
	maxHealth: number,
	attackCooldown: number,
}

type RuntimeState = {
	gold: number,
	shards: number,
	xp: number,
	highestFloor: number,
	equippedSword: string,
	ownedSwords: { [string]: boolean },
	upgrades: { [string]: number },
	equippedBase: string,
	ownedBases: { [string]: boolean },
	lastCommands: { [string]: number },
	dirty: boolean,
}

type SaveData = {
	version: number,
	gold: number,
	shards: number,
	xp: number,
	highestFloor: number,
	equippedSword: string,
	ownedSwords: { string },
	upgrades: { [string]: number },
	equippedBase: string,
	ownedBases: { string },
}

local PlayerDataService = {}

local states: { [Player]: RuntimeState } = {}
local changedCallbacks: { (Player, string) -> () } = {}
local loadedCallbacks: { (Player) -> () } = {}

local dataStore: any = nil
local started = false

local function makeDefaultState(): RuntimeState
	local upgrades = {}
	for upgradeId in GameConfig.Upgrades do
		upgrades[upgradeId] = 0
	end

	return {
		gold = GameConfig.Economy.StartingGold,
		shards = GameConfig.Economy.StartingShards,
		xp = GameConfig.Economy.StartingXp,
		highestFloor = 0,
		equippedSword = "rustbite",
		ownedSwords = {
			rustbite = true,
		},
		upgrades = upgrades,
		equippedBase = "camp",
		ownedBases = {
			camp = true,
		},
		lastCommands = {},
		dirty = true,
	}
end

local function copyBooleanKeys(dictionary: { [string]: boolean }): { string }
	local keys = {}

	for key, value in dictionary do
		if value then
			table.insert(keys, key)
		end
	end

	table.sort(keys)
	return keys
end

local function normalizeNumber(value: any, fallback: number): number
	if typeof(value) == "number" and value == value and value >= 0 then
		return math.floor(value)
	end

	return fallback
end

local function applySaveData(state: RuntimeState, saveData: any)
	if typeof(saveData) ~= "table" then
		return
	end

	state.gold = normalizeNumber(saveData.gold, state.gold)
	state.shards = normalizeNumber(saveData.shards, state.shards)
	state.xp = normalizeNumber(saveData.xp, state.xp)
	state.highestFloor = math.clamp(
		normalizeNumber(saveData.highestFloor, state.highestFloor),
		0,
		#GameConfig.FloorOrder
	)

	if typeof(saveData.ownedSwords) == "table" then
		for _, swordId in saveData.ownedSwords do
			if typeof(swordId) == "string" and GameConfig.Swords[swordId] ~= nil then
				state.ownedSwords[swordId] = true
			end
		end
	end

	if typeof(saveData.equippedSword) == "string" and state.ownedSwords[saveData.equippedSword] then
		state.equippedSword = saveData.equippedSword
	end

	if typeof(saveData.upgrades) == "table" then
		for upgradeId, upgradeConfig in GameConfig.Upgrades do
			local savedLevel = saveData.upgrades[upgradeId]
			state.upgrades[upgradeId] =
				math.clamp(normalizeNumber(savedLevel, 0), 0, upgradeConfig.maxLevel)
		end
	end

	if typeof(saveData.ownedBases) == "table" then
		for _, baseId in saveData.ownedBases do
			if typeof(baseId) == "string" and GameConfig.Bases[baseId] ~= nil then
				state.ownedBases[baseId] = true
			end
		end
	end

	if typeof(saveData.equippedBase) == "string" and state.ownedBases[saveData.equippedBase] then
		state.equippedBase = saveData.equippedBase
	end

	state.dirty = false
end

local function serializeState(state: RuntimeState): SaveData
	return {
		version = 1,
		gold = state.gold,
		shards = state.shards,
		xp = state.xp,
		highestFloor = state.highestFloor,
		equippedSword = state.equippedSword,
		ownedSwords = copyBooleanKeys(state.ownedSwords),
		upgrades = table.clone(state.upgrades),
		equippedBase = state.equippedBase,
		ownedBases = copyBooleanKeys(state.ownedBases),
	}
end

local function getSaveKey(player: Player): string
	return `player_{player.UserId}`
end

local function emitLoaded(player: Player)
	for _, callback in loadedCallbacks do
		local ok, err = pcall(callback, player)
		if not ok then
			warn(`[PlayerDataService] Loaded callback failed: {err}`)
		end
	end
end

local function syncLeaderstats(player: Player, state: RuntimeState)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats == nil then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local function setIntValue(name: string, value: number)
		local existing = leaderstats:FindFirstChild(name)
		local intValue: IntValue

		if existing ~= nil and existing:IsA("IntValue") then
			intValue = existing
		else
			if existing ~= nil then
				existing:Destroy()
			end

			intValue = Instance.new("IntValue")
			intValue.Name = name
			intValue.Parent = leaderstats
		end

		intValue.Value = math.floor(value)
	end

	setIntValue("Gold", state.gold)
	setIntValue("Shards", state.shards)
	setIntValue("Floor", state.highestFloor)
end

local function emitChanged(player: Player, reason: string)
	local state = states[player]
	if state ~= nil then
		state.dirty = true
		syncLeaderstats(player, state)
	end

	for _, callback in changedCallbacks do
		local ok, err = pcall(callback, player, reason)
		if not ok then
			warn(`[PlayerDataService] Changed callback failed: {err}`)
		end
	end
end

local function loadFromDataStore(player: Player): any
	if dataStore == nil then
		return nil
	end

	local ok, result = pcall(function()
		return dataStore:GetAsync(getSaveKey(player))
	end)

	if not ok then
		warn(`[PlayerDataService] Failed to load {player.Name}: {result}`)
		return nil
	end

	return result
end

local function savePlayer(player: Player, removing: boolean)
	local state = states[player]
	if state == nil then
		return
	end

	if dataStore == nil then
		if removing then
			states[player] = nil
		end

		return
	end

	if not state.dirty and not removing then
		return
	end

	local payload = serializeState(state)
	local ok, err = pcall(function()
		dataStore:UpdateAsync(getSaveKey(player), function()
			return payload
		end)
	end)

	if ok then
		state.dirty = false
	else
		warn(`[PlayerDataService] Failed to save {player.Name}: {err}`)
	end

	if removing then
		states[player] = nil
	end
end

local function loadPlayer(player: Player)
	local state = makeDefaultState()
	applySaveData(state, loadFromDataStore(player))
	states[player] = state
	syncLeaderstats(player, state)
	emitLoaded(player)
	emitChanged(player, "Loaded")
end

local function spendCost(state: RuntimeState, cost: Cost): boolean
	local goldCost = cost.gold or 0
	local shardCost = cost.shards or 0

	if state.gold < goldCost or state.shards < shardCost then
		return false
	end

	state.gold -= goldCost
	state.shards -= shardCost
	return true
end

local function roundCost(value: number): number
	return math.max(1, math.floor(value + 0.5))
end

function PlayerDataService.onLoaded(callback: (Player) -> ())
	table.insert(loadedCallbacks, callback)
end

function PlayerDataService.onChanged(callback: (Player, string) -> ())
	table.insert(changedCallbacks, callback)
end

function PlayerDataService.start()
	if started then
		return
	end

	started = true

	if not RunService:IsStudio() or GameConfig.Player.StudioDataStoresEnabled then
		dataStore = DataStoreService:GetDataStore(GameConfig.DataStoreName)
	end

	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(function(player)
		savePlayer(player, true)
	end)

	for _, player in Players:GetPlayers() do
		task.defer(loadPlayer, player)
	end

	task.spawn(function()
		while started do
			task.wait(60)

			for _, player in Players:GetPlayers() do
				savePlayer(player, false)
			end
		end
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			savePlayer(player, true)
		end
	end)
end

function PlayerDataService.getPublicState(player: Player): PublicState?
	local state = states[player]
	if state == nil then
		return nil
	end

	local xpLevel = math.max(1, math.floor(state.xp / 350) + 1)

	return {
		gold = state.gold,
		shards = state.shards,
		xp = state.xp,
		level = xpLevel,
		highestFloor = state.highestFloor,
		equippedSword = state.equippedSword,
		ownedSwords = copyBooleanKeys(state.ownedSwords),
		upgrades = table.clone(state.upgrades),
		equippedBase = state.equippedBase,
		ownedBases = copyBooleanKeys(state.ownedBases),
		power = PlayerDataService.getDamage(player),
		maxHealth = PlayerDataService.getMaxHealth(player),
		attackCooldown = PlayerDataService.getAttackCooldown(player),
	}
end

function PlayerDataService.getEquippedSword(player: Player): string
	local state = states[player]
	return if state ~= nil then state.equippedSword else "rustbite"
end

function PlayerDataService.getEquippedBase(player: Player): string
	local state = states[player]
	return if state ~= nil then state.equippedBase else "camp"
end

function PlayerDataService.getDamage(player: Player): number
	local state = states[player]
	if state == nil then
		return GameConfig.Swords.rustbite.damage
	end

	local sword = GameConfig.Swords[state.equippedSword] or GameConfig.Swords.rustbite
	local powerLevel = state.upgrades.power or 0

	return sword.damage + (powerLevel * GameConfig.Upgrades.power.effectPerLevel)
end

function PlayerDataService.getMaxHealth(player: Player): number
	local state = states[player]
	if state == nil then
		return GameConfig.Player.BaseHealth
	end

	local vitalityLevel = state.upgrades.vitality or 0
	return GameConfig.Player.BaseHealth
		+ (vitalityLevel * GameConfig.Upgrades.vitality.effectPerLevel)
end

function PlayerDataService.getAttackCooldown(player: Player): number
	local state = states[player]
	if state == nil then
		return GameConfig.Swords.rustbite.cooldown
	end

	local sword = GameConfig.Swords[state.equippedSword] or GameConfig.Swords.rustbite
	local hasteLevel = state.upgrades.haste or 0
	local reduction = hasteLevel * GameConfig.Upgrades.haste.effectPerLevel

	return math.max(0.28, sword.cooldown - reduction)
end

function PlayerDataService.getUpgradeCost(upgradeId: string, nextLevel: number): Cost?
	local upgrade = GameConfig.Upgrades[upgradeId]
	if upgrade == nil then
		return nil
	end

	local growthPower = math.max(0, nextLevel - 1)
	local multiplier = upgrade.costGrowth ^ growthPower

	return {
		gold = if upgrade.baseCost.gold ~= nil
			then roundCost(upgrade.baseCost.gold * multiplier)
			else nil,
		shards = if upgrade.baseCost.shards ~= nil
			then roundCost(upgrade.baseCost.shards * multiplier)
			else nil,
	}
end

function PlayerDataService.addRewards(
	player: Player,
	rewards: { gold: number, shards: number, xp: number },
	reason: string
)
	local state = states[player]
	if state == nil then
		return
	end

	local fortuneLevel = state.upgrades.fortune or 0
	local base = GameConfig.Bases[state.equippedBase] or GameConfig.Bases.camp
	local goldMultiplier = 1
		+ (fortuneLevel * GameConfig.Upgrades.fortune.effectPerLevel)
		+ base.goldBonusPercent
	local earnedGold = math.floor((rewards.gold * goldMultiplier) + 0.5)

	state.gold += math.max(0, earnedGold)
	state.shards += math.max(0, rewards.shards)
	state.xp += math.max(0, rewards.xp)

	emitChanged(player, reason)
end

function PlayerDataService.recordFloorCleared(player: Player, floorId: number)
	local state = states[player]
	if state == nil then
		return
	end

	if floorId > state.highestFloor then
		state.highestFloor = floorId
		emitChanged(player, "FloorCleared")
	end
end

function PlayerDataService.consumeActionCooldown(
	player: Player,
	key: string,
	seconds: number
): boolean
	local state = states[player]
	if state == nil then
		return false
	end

	local now = os.clock()
	local last = state.lastCommands[key]
	if last ~= nil and now - last < seconds then
		return false
	end

	state.lastCommands[key] = now
	return true
end

function PlayerDataService.buySword(player: Player, swordId: string): (boolean, string)
	local state = states[player]
	local sword = GameConfig.Swords[swordId]
	if state == nil or sword == nil then
		return false, "That sword is not available."
	end

	if state.ownedSwords[swordId] then
		state.equippedSword = swordId
		emitChanged(player, "SwordEquipped")
		return true, `{sword.name} equipped.`
	end

	if state.highestFloor < sword.requiredFloor then
		return false, `Clear floor {sword.requiredFloor} first.`
	end

	if not spendCost(state, sword.price) then
		return false, "Not enough gold or shards."
	end

	state.ownedSwords[swordId] = true
	state.equippedSword = swordId
	emitChanged(player, "SwordPurchased")
	return true, `{sword.name} forged and equipped.`
end

function PlayerDataService.equipSword(player: Player, swordId: string): (boolean, string)
	local state = states[player]
	local sword = GameConfig.Swords[swordId]
	if state == nil or sword == nil or not state.ownedSwords[swordId] then
		return false, "You do not own that sword."
	end

	state.equippedSword = swordId
	emitChanged(player, "SwordEquipped")
	return true, `{sword.name} equipped.`
end

function PlayerDataService.buyUpgrade(player: Player, upgradeId: string): (boolean, string)
	local state = states[player]
	local upgrade = GameConfig.Upgrades[upgradeId]
	if state == nil or upgrade == nil then
		return false, "That upgrade is not available."
	end

	local currentLevel = state.upgrades[upgradeId] or 0
	if currentLevel >= upgrade.maxLevel then
		return false, `{upgrade.name} is maxed.`
	end

	local cost = PlayerDataService.getUpgradeCost(upgradeId, currentLevel + 1)
	if cost == nil or not spendCost(state, cost) then
		return false, "Not enough gold or shards."
	end

	state.upgrades[upgradeId] = currentLevel + 1
	emitChanged(player, "UpgradePurchased")
	return true, `{upgrade.name} upgraded to {currentLevel + 1}.`
end

function PlayerDataService.buyBase(player: Player, baseId: string): (boolean, string)
	local state = states[player]
	local base = GameConfig.Bases[baseId]
	if state == nil or base == nil then
		return false, "That base is not available."
	end

	if state.ownedBases[baseId] then
		state.equippedBase = baseId
		emitChanged(player, "BaseEquipped")
		return true, `{base.name} equipped.`
	end

	if state.highestFloor < base.requiredFloor then
		return false, `Clear floor {base.requiredFloor} first.`
	end

	if not spendCost(state, base.price) then
		return false, "Not enough gold or shards."
	end

	state.ownedBases[baseId] = true
	state.equippedBase = baseId
	emitChanged(player, "BasePurchased")
	return true, `{base.name} built.`
end

function PlayerDataService.equipBase(player: Player, baseId: string): (boolean, string)
	local state = states[player]
	local base = GameConfig.Bases[baseId]
	if state == nil or base == nil or not state.ownedBases[baseId] then
		return false, "You do not own that base."
	end

	state.equippedBase = baseId
	emitChanged(player, "BaseEquipped")
	return true, `{base.name} equipped.`
end

return PlayerDataService
