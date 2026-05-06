--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local ClientMain = {}

type ProfileState = {
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

type RunState = {
	active: boolean,
	floor: number?,
	floorName: string?,
	room: number?,
	rooms: number?,
	health: number?,
	maxHealth: number?,
	enemiesLeft: number?,
	enemyHealth: number?,
	enemyMaxHealth: number?,
	chestReady: boolean?,
}

local profile: ProfileState? = nil
local runState: RunState = {
	active = false,
}

local commandRemote: RemoteEvent
local stateUpdateRemote: RemoteEvent
local toastRemote: RemoteEvent

local screenGui: ScreenGui
local hudLabel: TextLabel
local runLabel: TextLabel
local toastLabel: TextLabel
local startButton: TextButton
local attackButton: TextButton
local chestButton: TextButton
local returnButton: TextButton
local shopTabs: Frame
local shopList: ScrollingFrame
local activeShopTab = "Swords"
local toastSerial = 0

local function formatCost(cost: GameConfig.Cost): string
	local pieces = {}
	if cost.gold ~= nil and cost.gold > 0 then
		table.insert(pieces, `{cost.gold}g`)
	end

	if cost.shards ~= nil and cost.shards > 0 then
		table.insert(pieces, `{cost.shards}s`)
	end

	if #pieces == 0 then
		return "Free"
	end

	return table.concat(pieces, " / ")
end

local function getUpgradeCost(upgradeId: string, nextLevel: number): GameConfig.Cost
	local upgrade = GameConfig.Upgrades[upgradeId]
	if upgrade == nil then
		return { gold = 0 }
	end

	local growthPower = math.max(0, nextLevel - 1)
	local multiplier = upgrade.costGrowth ^ growthPower

	return {
		gold = if upgrade.baseCost.gold ~= nil
			then math.max(1, math.floor((upgrade.baseCost.gold * multiplier) + 0.5))
			else nil,
		shards = if upgrade.baseCost.shards ~= nil
			then math.max(1, math.floor((upgrade.baseCost.shards * multiplier) + 0.5))
			else nil,
	}
end

local function hasId(list: { string }, id: string): boolean
	for _, value in list do
		if value == id then
			return true
		end
	end

	return false
end

local function getNextFloor(): number
	local currentProfile = profile
	if currentProfile == nil then
		return 1
	end

	return math.clamp(currentProfile.highestFloor + 1, 1, #GameConfig.FloorOrder)
end

local function fireCommand(action: string, payload: any?)
	commandRemote:FireServer(action, payload or {})
end

local function makeLabel(
	parent: Instance,
	name: string,
	text: string,
	size: UDim2,
	position: UDim2
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextColor3 = Color3.fromRGB(241, 238, 228)
	label.TextSize = 16
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function makeButton(
	parent: Instance,
	name: string,
	text: string,
	size: UDim2,
	position: UDim2
): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = true
	button.BackgroundColor3 = Color3.fromRGB(42, 48, 56)
	button.BorderColor3 = Color3.fromRGB(99, 111, 126)
	button.Font = Enum.Font.GothamBold
	button.Position = position
	button.Size = size
	button.Text = text
	button.TextColor3 = Color3.fromRGB(246, 243, 233)
	button.TextSize = 15
	button.TextWrapped = true
	button.Parent = parent
	return button
end

local function clearShopList()
	for _, child in shopList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function createShopRow(title: string, body: string, actionText: string, callback: () -> ())
	local row = Instance.new("Frame")
	row.Name = "ShopRow"
	row.BackgroundColor3 = Color3.fromRGB(30, 35, 42)
	row.BorderColor3 = Color3.fromRGB(74, 84, 98)
	row.Size = UDim2.new(1, -10, 0, 86)
	row.Parent = shopList

	local titleLabel =
		makeLabel(row, "Title", title, UDim2.new(1, -138, 0, 26), UDim2.fromOffset(10, 6))
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.fromRGB(255, 240, 196)
	titleLabel.TextSize = 15

	local bodyLabel =
		makeLabel(row, "Body", body, UDim2.new(1, -138, 0, 44), UDim2.fromOffset(10, 34))
	bodyLabel.TextColor3 = Color3.fromRGB(204, 211, 215)
	bodyLabel.TextSize = 13

	local button =
		makeButton(row, "Action", actionText, UDim2.fromOffset(112, 50), UDim2.new(1, -122, 0, 18))
	button.Activated:Connect(callback)
end

local function renderShop()
	clearShopList()

	local currentProfile = profile
	if currentProfile == nil then
		return
	end

	if activeShopTab == "Swords" then
		for _, swordId in GameConfig.SwordOrder do
			local sword = GameConfig.Swords[swordId]
			local owned = hasId(currentProfile.ownedSwords, swordId)
			local equipped = currentProfile.equippedSword == swordId
			local actionText = if equipped then "Equipped" elseif owned then "Equip" else "Forge"
			local body =
				`Power {sword.damage} | Speed {string.format("%.2fs", sword.cooldown)} | {formatCost(
					sword.price
				)} | Floor {sword.requiredFloor}`

			createShopRow(sword.name, body, actionText, function()
				if equipped then
					return
				end

				fireCommand(if owned then "EquipSword" else "BuySword", {
					id = swordId,
				})
			end)
		end
	elseif activeShopTab == "Upgrades" then
		for _, upgradeId in GameConfig.UpgradeOrder do
			local upgrade = GameConfig.Upgrades[upgradeId]
			local level = currentProfile.upgrades[upgradeId] or 0
			local actionText = if level >= upgrade.maxLevel then "Maxed" else "Upgrade"
			local cost = if level >= upgrade.maxLevel
				then { gold = 0 }
				else getUpgradeCost(upgradeId, level + 1)
			local body =
				`Level {level}/{upgrade.maxLevel} | +{upgrade.effectPerLevel} each | From {formatCost(
					cost
				)}`

			createShopRow(upgrade.name, body, actionText, function()
				if level < upgrade.maxLevel then
					fireCommand("BuyUpgrade", {
						id = upgradeId,
					})
				end
			end)
		end
	else
		for _, baseId in GameConfig.BaseOrder do
			local base = GameConfig.Bases[baseId]
			local owned = hasId(currentProfile.ownedBases, baseId)
			local equipped = currentProfile.equippedBase == baseId
			local actionText = if equipped then "Active" elseif owned then "Use" else "Build"
			local bonus = math.floor(base.goldBonusPercent * 100)
			local body = `{formatCost(base.price)} | Floor {base.requiredFloor} | +{bonus}% gold`

			createShopRow(base.name, body, actionText, function()
				if equipped then
					return
				end

				fireCommand(if owned then "EquipBase" else "BuyBase", {
					id = baseId,
				})
			end)
		end
	end
end

local function render()
	local currentProfile = profile
	if currentProfile ~= nil then
		local sword = GameConfig.Swords[currentProfile.equippedSword] or GameConfig.Swords.rustbite
		local base = GameConfig.Bases[currentProfile.equippedBase] or GameConfig.Bases.camp
		hudLabel.Text =
			`{Constants.GAME_NAME}  |  Gold {currentProfile.gold}  Shards {currentProfile.shards}  Floor {currentProfile.highestFloor}  Power {currentProfile.power}  Sword {sword.name}  Base {base.name}`

		local nextFloor = getNextFloor()
		local nextFloorConfig = GameConfig.Floors[nextFloor]
		startButton.Text = `Start {nextFloorConfig.name}`
	else
		hudLabel.Text = `{Constants.GAME_NAME} loading...`
		startButton.Text = "Start"
	end

	if runState.active then
		local health = runState.health or 0
		local maxHealth = runState.maxHealth or 0
		local enemiesLeft = runState.enemiesLeft or 0
		local enemyHealth = runState.enemyHealth or 0
		local enemyMaxHealth = runState.enemyMaxHealth or 0
		runLabel.Text =
			`{runState.floorName or "Dungeon"} | Room {runState.room or 1}/{runState.rooms or 1} | HP {health}/{maxHealth} | Enemies {enemiesLeft} ({enemyHealth}/{enemyMaxHealth})`
	else
		runLabel.Text = "Lobby"
	end

	attackButton.Visible = runState.active
	chestButton.Visible = runState.active
	returnButton.Visible = runState.active
	chestButton.BackgroundColor3 = if runState.chestReady
		then Color3.fromRGB(81, 117, 75)
		else Color3.fromRGB(42, 48, 56)

	renderShop()
end

local function showToast(message: string)
	toastSerial += 1
	local serial = toastSerial

	toastLabel.Text = message
	toastLabel.Visible = true

	task.delay(3, function()
		if toastSerial == serial then
			toastLabel.Visible = false
		end
	end)
end

local function buildGui(player: Player)
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DungeonGameGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local hud = Instance.new("Frame")
	hud.Name = "Hud"
	hud.BackgroundColor3 = Color3.fromRGB(18, 21, 26)
	hud.BorderColor3 = Color3.fromRGB(73, 83, 96)
	hud.Position = UDim2.fromOffset(16, 16)
	hud.Size = UDim2.new(1, -32, 0, 64)
	hud.Parent = screenGui

	hudLabel =
		makeLabel(hud, "HudLabel", "Loading...", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 8))
	runLabel =
		makeLabel(hud, "RunLabel", "Lobby", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 36))
	runLabel.TextColor3 = Color3.fromRGB(161, 221, 211)
	runLabel.TextSize = 14

	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.BackgroundColor3 = Color3.fromRGB(21, 24, 30)
	actions.BorderColor3 = Color3.fromRGB(73, 83, 96)
	actions.Position = UDim2.new(0, 16, 1, -182)
	actions.Size = UDim2.fromOffset(360, 166)
	actions.Parent = screenGui

	startButton =
		makeButton(actions, "Start", "Start", UDim2.fromOffset(328, 34), UDim2.fromOffset(16, 14))
	startButton.Activated:Connect(function()
		fireCommand("StartFloor", {
			floor = getNextFloor(),
		})
	end)

	attackButton = makeButton(
		actions,
		"Attack",
		"Attack Nearest",
		UDim2.fromOffset(154, 34),
		UDim2.fromOffset(16, 58)
	)
	attackButton.Activated:Connect(function()
		fireCommand("AttackNearest")
	end)

	chestButton = makeButton(
		actions,
		"Chest",
		"Claim Chest",
		UDim2.fromOffset(154, 34),
		UDim2.fromOffset(190, 58)
	)
	chestButton.Activated:Connect(function()
		fireCommand("ClaimChest")
	end)

	returnButton = makeButton(
		actions,
		"Return",
		"Return Lobby",
		UDim2.fromOffset(328, 34),
		UDim2.fromOffset(16, 104)
	)
	returnButton.Activated:Connect(function()
		fireCommand("ReturnLobby")
	end)

	local shop = Instance.new("Frame")
	shop.Name = "Shop"
	shop.BackgroundColor3 = Color3.fromRGB(18, 21, 26)
	shop.BorderColor3 = Color3.fromRGB(73, 83, 96)
	shop.Position = UDim2.new(1, -402, 0, 96)
	shop.Size = UDim2.new(0, 386, 1, -112)
	shop.Parent = screenGui

	shopTabs = Instance.new("Frame")
	shopTabs.Name = "Tabs"
	shopTabs.BackgroundTransparency = 1
	shopTabs.Position = UDim2.fromOffset(10, 10)
	shopTabs.Size = UDim2.new(1, -20, 0, 36)
	shopTabs.Parent = shop

	local tabs = { "Swords", "Upgrades", "Bases" }
	for index, tabName in tabs do
		local tab = makeButton(
			shopTabs,
			tabName,
			tabName,
			UDim2.new(1 / #tabs, -6, 1, 0),
			UDim2.new((index - 1) / #tabs, 3, 0, 0)
		)
		tab.Activated:Connect(function()
			activeShopTab = tabName
			render()
		end)
	end

	shopList = Instance.new("ScrollingFrame")
	shopList.Name = "List"
	shopList.BackgroundTransparency = 1
	shopList.BorderSizePixel = 0
	shopList.CanvasSize = UDim2.fromOffset(0, 0)
	shopList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	shopList.Position = UDim2.fromOffset(10, 56)
	shopList.ScrollBarThickness = 8
	shopList.Size = UDim2.new(1, -20, 1, -66)
	shopList.Parent = shop

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = shopList

	toastLabel =
		makeLabel(screenGui, "Toast", "", UDim2.fromOffset(520, 44), UDim2.new(0.5, -260, 0, 92))
	toastLabel.BackgroundColor3 = Color3.fromRGB(18, 21, 26)
	toastLabel.BackgroundTransparency = 0.08
	toastLabel.BorderColor3 = Color3.fromRGB(92, 201, 174)
	toastLabel.Font = Enum.Font.GothamBold
	toastLabel.TextXAlignment = Enum.TextXAlignment.Center
	toastLabel.Visible = false
end

function ClientMain.start(): ()
	local player = Players.LocalPlayer
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

	commandRemote = remotesFolder:WaitForChild(GameConfig.Remotes.DungeonCommand) :: RemoteEvent
	stateUpdateRemote = remotesFolder:WaitForChild(GameConfig.Remotes.StateUpdate) :: RemoteEvent
	toastRemote = remotesFolder:WaitForChild(GameConfig.Remotes.Toast) :: RemoteEvent

	buildGui(player)

	stateUpdateRemote.OnClientEvent:Connect(function(message: any)
		if typeof(message) ~= "table" then
			return
		end

		if message.kind == "Profile" and typeof(message.profile) == "table" then
			profile = message.profile
		elseif message.kind == "Run" and typeof(message.run) == "table" then
			runState = message.run
		end

		render()
	end)

	toastRemote.OnClientEvent:Connect(function(message: any)
		if typeof(message) == "string" then
			showToast(message)
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.E then
			fireCommand("AttackNearest")
		end
	end)

	fireCommand("RequestState")

	print(`[Client] {Constants.GAME_NAME} {Constants.VERSION} ready for {player.Name}`)
end

return ClientMain
