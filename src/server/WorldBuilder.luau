--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

type EnemyConfig = GameConfig.EnemyConfig
type FloorConfig = GameConfig.FloorConfig

export type RunArena = {
	folder: Folder,
	spawnCFrame: CFrame,
	roomCenters: { Vector3 },
	gates: { [number]: BasePart },
	chestModel: Model,
}

local ROOT_NAME = "DungeonGame"

local WorldBuilder = {}

local rootFolder: Folder? = nil
local baseFolder: Folder? = nil
local runFolder: Folder? = nil
local playerBaseSlots: { [Player]: number } = {}
local playerBaseModels: { [Player]: Model } = {}
local availableBaseSlots: { number } = {}
local nextBaseSlot = 0

local function getRoot(): Folder
	if rootFolder ~= nil and rootFolder.Parent ~= nil then
		return rootFolder
	end

	local existing = Workspace:FindFirstChild(ROOT_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = ROOT_NAME
	folder.Parent = Workspace
	rootFolder = folder

	return folder
end

local function createFolder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function createPart(
	parent: Instance,
	name: string,
	cframe: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	transparency: number?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.TopSurface = Enum.SurfaceType.Smooth
	part.CFrame = cframe
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.Parent = parent
	return part
end

local function addSurfaceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "RuneSurface"
	surfaceGui.Face = face
	surfaceGui.LightInfluence = 0.25
	surfaceGui.PixelsPerStud = 26
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 0.35
	label.Parent = surfaceGui
end

local function addTextureSlot(
	part: BasePart,
	slotName: string,
	face: Enum.NormalId,
	studsPerTile: number,
	transparency: number
)
	local assetId = GameConfig.AssetSlots[slotName]
	if typeof(assetId) ~= "string" or assetId == "" then
		return
	end

	local texture = Instance.new("Texture")
	texture.Name = slotName
	texture.Face = face
	texture.Texture = assetId
	texture.StudsPerTileU = studsPerTile
	texture.StudsPerTileV = studsPerTile
	texture.Transparency = transparency
	texture.Parent = part
end

local function addMeshSlot(part: BasePart, slotName: string, scale: Vector3)
	local assetId = GameConfig.AssetSlots[slotName]
	if typeof(assetId) ~= "string" or assetId == "" then
		return
	end

	local mesh = Instance.new("SpecialMesh")
	mesh.Name = slotName
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = assetId
	mesh.Scale = scale
	mesh.Parent = part
end

local function addBillboard(parent: Instance, text: string, offset: Vector3, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Name = "LabelAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = if parent:IsA("Model") and parent.PrimaryPart ~= nil
		then parent.PrimaryPart.CFrame + offset
		else (parent :: BasePart).CFrame + offset
	anchor.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Billboard"
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Size = UDim2.fromOffset(220, 48)
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 0.25
	label.Parent = billboard
end

local function createCrystal(
	parent: Instance,
	name: string,
	position: Vector3,
	color: Color3,
	scale: number
)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	local core = createPart(
		model,
		"Core",
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(45)),
		Vector3.new(2.2, 5.5, 2.2) * scale,
		color,
		Enum.Material.Neon,
		0.1
	)
	core.Shape = Enum.PartType.Cylinder
	model.PrimaryPart = core

	createPart(
		model,
		"Base",
		CFrame.new(position - Vector3.new(0, 2.9 * scale, 0)),
		Vector3.new(3.8, 1, 3.8) * scale,
		Color3.fromRGB(38, 38, 46),
		Enum.Material.Slate,
		0
	)

	return model
end

local function createDecorativeSword(
	parent: Instance,
	name: string,
	cframe: CFrame,
	bladeColor: Color3,
	hiltColor: Color3
)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	local blade = createPart(
		model,
		"Blade",
		cframe * CFrame.new(0, 2.1, 0),
		Vector3.new(0.55, 4.4, 0.22),
		bladeColor,
		Enum.Material.Metal,
		0
	)
	addTextureSlot(blade, "SwordBladeTexture", Enum.NormalId.Front, 3, 0.18)
	addTextureSlot(blade, "SwordBladeTexture", Enum.NormalId.Back, 3, 0.18)
	model.PrimaryPart = blade

	createPart(
		model,
		"Guard",
		cframe,
		Vector3.new(2.4, 0.28, 0.5),
		hiltColor,
		Enum.Material.Metal,
		0
	)
	createPart(
		model,
		"Grip",
		cframe * CFrame.new(0, -1.2, 0),
		Vector3.new(0.36, 2.2, 0.36),
		hiltColor,
		Enum.Material.Wood,
		0
	)

	local gem = createPart(
		model,
		"Gem",
		cframe * CFrame.new(0, 0.38, -0.28),
		Vector3.new(0.42, 0.42, 0.42),
		bladeColor,
		Enum.Material.Neon,
		0
	)
	gem.Shape = Enum.PartType.Ball

	return model
end

local function buildLobby()
	local root = getRoot()
	local lobby = createFolder(root, "Lobby")

	createPart(
		lobby,
		"LobbyFloor",
		CFrame.new(0, 0, 12),
		Vector3.new(150, 2, 120),
		Color3.fromRGB(40, 43, 48),
		Enum.Material.Slate,
		0
	)

	local spawnPad = createPart(
		lobby,
		"SpawnPad",
		CFrame.new(GameConfig.World.LobbySpawn - Vector3.new(0, 3.6, 0)),
		Vector3.new(18, 0.4, 18),
		Color3.fromRGB(92, 201, 174),
		Enum.Material.Neon,
		0.15
	)
	addSurfaceText(spawnPad, Enum.NormalId.Top, "DUNGEON GATE", Color3.fromRGB(10, 36, 34))

	local gateLeft = createPart(
		lobby,
		"DungeonGate_Left",
		CFrame.new(-7, 8, -39),
		Vector3.new(3, 16, 4),
		Color3.fromRGB(58, 62, 70),
		Enum.Material.Basalt,
		0
	)
	local gateRight = createPart(
		lobby,
		"DungeonGate_Right",
		CFrame.new(7, 8, -39),
		Vector3.new(3, 16, 4),
		Color3.fromRGB(58, 62, 70),
		Enum.Material.Basalt,
		0
	)
	createPart(
		lobby,
		"DungeonGate_Crown",
		CFrame.new(0, 16, -39),
		Vector3.new(18, 3, 4),
		Color3.fromRGB(58, 62, 70),
		Enum.Material.Basalt,
		0
	)
	createCrystal(
		lobby,
		"GateCrystal_Left",
		gateLeft.Position + Vector3.new(0, 9, 0),
		Color3.fromRGB(92, 201, 174),
		0.7
	)
	createCrystal(
		lobby,
		"GateCrystal_Right",
		gateRight.Position + Vector3.new(0, 9, 0),
		Color3.fromRGB(202, 176, 255),
		0.7
	)

	local portal = createPart(
		lobby,
		"DungeonPortalVisual",
		CFrame.new(0, 7, -40),
		Vector3.new(9, 12, 0.35),
		Color3.fromRGB(118, 231, 235),
		Enum.Material.Neon,
		0.45
	)
	addSurfaceText(portal, Enum.NormalId.Front, "RUNES OF DESCENT", Color3.fromRGB(242, 255, 253))

	local swordShop = createPart(
		lobby,
		"SwordForgePad",
		CFrame.new(-46, 1.4, 0),
		Vector3.new(22, 0.8, 18),
		Color3.fromRGB(111, 72, 56),
		Enum.Material.Metal,
		0
	)
	addSurfaceText(swordShop, Enum.NormalId.Top, "SWORD FORGE", Color3.fromRGB(255, 205, 132))
	createDecorativeSword(
		lobby,
		"ForgeDisplaySword",
		CFrame.new(-46, 5.4, 0) * CFrame.Angles(0, 0, math.rad(-20)),
		Color3.fromRGB(255, 115, 65),
		Color3.fromRGB(87, 55, 41)
	)

	local upgradeShop = createPart(
		lobby,
		"UpgradeShrinePad",
		CFrame.new(46, 1.4, 0),
		Vector3.new(22, 0.8, 18),
		Color3.fromRGB(55, 82, 95),
		Enum.Material.Metal,
		0
	)
	addSurfaceText(upgradeShop, Enum.NormalId.Top, "UPGRADE SHRINE", Color3.fromRGB(153, 239, 235))
	createCrystal(
		lobby,
		"UpgradeShrineCrystal",
		Vector3.new(46, 6.2, 0),
		Color3.fromRGB(93, 210, 206),
		1
	)

	local baseShop = createPart(
		lobby,
		"BasePlannerPad",
		CFrame.new(0, 1.4, 52),
		Vector3.new(32, 0.8, 16),
		Color3.fromRGB(73, 70, 99),
		Enum.Material.Metal,
		0
	)
	addSurfaceText(baseShop, Enum.NormalId.Top, "BASE PLANNER", Color3.fromRGB(234, 218, 153))

	baseFolder = createFolder(root, "PlayerBases")
	runFolder = createFolder(root, "DungeonRuns")

	addBillboard(
		portal,
		"Clear rooms. Claim the chest. Build your base.",
		Vector3.new(0, 8, 0),
		Color3.fromRGB(238, 255, 250)
	)
end

local function getBaseSlot(player: Player): number
	local existing = playerBaseSlots[player]
	if existing ~= nil then
		return existing
	end

	local slot = table.remove(availableBaseSlots)
	if slot == nil then
		nextBaseSlot += 1
		slot = ((nextBaseSlot - 1) % GameConfig.World.MaxBasePlots) + 1
	end

	playerBaseSlots[player] = slot
	return slot
end

local function getBaseSlotCFrame(slot: number): CFrame
	local row = math.floor((slot - 1) / 3)
	local column = (slot - 1) % 3
	return CFrame.new(-48 + (column * 48), 1.5, 88 + (row * 34))
end

local function buildPlayerBase(player: Player, baseId: string): Model
	local parent = baseFolder or getRoot()
	local baseConfig = GameConfig.Bases[baseId] or GameConfig.Bases.camp
	local slot = getBaseSlot(player)
	local cframe = getBaseSlotCFrame(slot)

	local model = Instance.new("Model")
	model.Name = `{player.Name}_Base`
	model.Parent = parent

	local floor = createPart(
		model,
		"BaseFoundation",
		cframe,
		Vector3.new(36, 1, 24),
		baseConfig.primaryColor,
		Enum.Material.Slate,
		0
	)
	model.PrimaryPart = floor

	createPart(
		model,
		"BackWall",
		cframe * CFrame.new(0, 5, 10.5),
		Vector3.new(34, 9, 2),
		baseConfig.primaryColor:Lerp(Color3.new(0, 0, 0), 0.22),
		Enum.Material.Brick,
		0
	)
	createPart(
		model,
		"LeftTower",
		cframe * CFrame.new(-15, 6, 4),
		Vector3.new(5, 12, 5),
		baseConfig.primaryColor,
		Enum.Material.Brick,
		0
	)
	createPart(
		model,
		"RightTower",
		cframe * CFrame.new(15, 6, 4),
		Vector3.new(5, 12, 5),
		baseConfig.primaryColor,
		Enum.Material.Brick,
		0
	)
	local banner = createPart(
		model,
		"Banner",
		cframe * CFrame.new(0, 7.5, 9.35),
		Vector3.new(9, 7, 0.35),
		baseConfig.accentColor,
		Enum.Material.Fabric,
		0
	)
	addTextureSlot(banner, "BaseBannerTexture", Enum.NormalId.Front, 5, 0.1)
	createCrystal(
		model,
		"BaseCrystal",
		cframe.Position + Vector3.new(0, 6, -4),
		baseConfig.accentColor,
		0.65
	)

	addBillboard(
		model,
		`{player.DisplayName}'s {baseConfig.name}`,
		Vector3.new(0, 12, 0),
		Color3.fromRGB(245, 245, 240)
	)

	return model
end

local function removeDungeonTools(container: Instance?)
	if container == nil then
		return
	end

	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("DungeonSword") == true then
			child:Destroy()
		end
	end
end

local function makeSwordTool(swordId: string): Tool
	local sword = GameConfig.Swords[swordId] or GameConfig.Swords.rustbite

	local tool = Instance.new("Tool")
	tool.Name = sword.name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("DungeonSword", true)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.Size = Vector3.new(0.42, 2.3, 0.42)
	handle.Color = sword.hiltColor
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.BottomSurface = Enum.SurfaceType.Smooth
	blade.TopSurface = Enum.SurfaceType.Smooth
	blade.Size = Vector3.new(0.48, 4.4, 0.22)
	blade.CFrame = handle.CFrame * CFrame.new(0, 3.1, 0)
	blade.Color = sword.bladeColor
	blade.Material = Enum.Material.Metal
	blade.CanCollide = false
	blade.Massless = true
	blade.Parent = tool
	addTextureSlot(blade, "SwordBladeTexture", Enum.NormalId.Front, 3, 0.12)
	addTextureSlot(blade, "SwordBladeTexture", Enum.NormalId.Back, 3, 0.12)

	local bladeWeld = Instance.new("WeldConstraint")
	bladeWeld.Part0 = handle
	bladeWeld.Part1 = blade
	bladeWeld.Parent = blade

	local guard = Instance.new("Part")
	guard.Name = "Guard"
	guard.BottomSurface = Enum.SurfaceType.Smooth
	guard.TopSurface = Enum.SurfaceType.Smooth
	guard.Size = Vector3.new(2.1, 0.28, 0.5)
	guard.CFrame = handle.CFrame * CFrame.new(0, 1.25, 0)
	guard.Color = sword.accentColor
	guard.Material = Enum.Material.Metal
	guard.CanCollide = false
	guard.Massless = true
	guard.Parent = tool

	local guardWeld = Instance.new("WeldConstraint")
	guardWeld.Part0 = handle
	guardWeld.Part1 = guard
	guardWeld.Parent = guard

	tool.Grip = CFrame.new(0, -1.2, 0) * CFrame.Angles(math.rad(90), 0, 0)
	return tool
end

function WorldBuilder.start()
	getRoot()
	buildLobby()
end

function WorldBuilder.clearPlayerBase(player: Player)
	local model = playerBaseModels[player]
	if model ~= nil then
		model:Destroy()
	end

	playerBaseModels[player] = nil

	local slot = playerBaseSlots[player]
	if slot ~= nil then
		table.insert(availableBaseSlots, slot)
	end

	playerBaseSlots[player] = nil
end

function WorldBuilder.updatePlayerBase(player: Player, baseId: string)
	local oldModel = playerBaseModels[player]
	if oldModel ~= nil then
		oldModel:Destroy()
	end

	playerBaseModels[player] = buildPlayerBase(player, baseId)
end

function WorldBuilder.giveSwordTool(player: Player, swordId: string)
	removeDungeonTools(player.Character)
	removeDungeonTools(player:FindFirstChildOfClass("Backpack"))

	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if backpack == nil then
		return
	end

	makeSwordTool(swordId).Parent = backpack
end

function WorldBuilder.teleportToLobby(player: Player)
	local character = player.Character
	if character == nil then
		return
	end

	character:PivotTo(CFrame.new(GameConfig.World.LobbySpawn))
end

function WorldBuilder.createRunArena(player: Player, floor: FloorConfig, slot: number): RunArena
	local parent = runFolder or getRoot()
	local folder = Instance.new("Folder")
	folder.Name = `{player.Name}_Floor_{floor.id}`
	folder.Parent = parent

	local origin = GameConfig.World.DungeonOrigin
		+ Vector3.new((slot - 1) * GameConfig.World.RunSlotSpacing, 0, 0)
	local roomCenters = {}
	local gates = {}
	local roomLength = 48
	local roomWidth = 42
	local wallHeight = 15

	for roomIndex = 1, floor.rooms do
		local center = origin + Vector3.new(0, 0, -((roomIndex - 1) * (roomLength + 10)))
		table.insert(roomCenters, center)

		local floorPart = createPart(
			folder,
			`Room_{roomIndex}_Floor`,
			CFrame.new(center),
			Vector3.new(roomWidth, 1.5, roomLength),
			floor.floorColor,
			Enum.Material.Slate,
			0
		)
		addTextureSlot(floorPart, "DungeonWallTexture", Enum.NormalId.Top, 8, 0.28)

		local leftWall = createPart(
			folder,
			`Room_{roomIndex}_LeftWall`,
			CFrame.new(center + Vector3.new(-roomWidth / 2, wallHeight / 2, 0)),
			Vector3.new(2, wallHeight, roomLength),
			floor.wallColor,
			Enum.Material.Basalt,
			0
		)
		addTextureSlot(leftWall, "DungeonWallTexture", Enum.NormalId.Right, 7, 0.22)

		local rightWall = createPart(
			folder,
			`Room_{roomIndex}_RightWall`,
			CFrame.new(center + Vector3.new(roomWidth / 2, wallHeight / 2, 0)),
			Vector3.new(2, wallHeight, roomLength),
			floor.wallColor,
			Enum.Material.Basalt,
			0
		)
		addTextureSlot(rightWall, "DungeonWallTexture", Enum.NormalId.Left, 7, 0.22)
		createPart(
			folder,
			`Room_{roomIndex}_RuneNorth`,
			CFrame.new(center + Vector3.new(0, 0.9, -roomLength / 4)),
			Vector3.new(roomWidth - 8, 0.15, 1.2),
			floor.accentColor,
			Enum.Material.Neon,
			0.18
		)
		createPart(
			folder,
			`Room_{roomIndex}_RuneSouth`,
			CFrame.new(center + Vector3.new(0, 0.9, roomLength / 4)),
			Vector3.new(roomWidth - 8, 0.15, 1.2),
			floor.accentColor,
			Enum.Material.Neon,
			0.18
		)

		if roomIndex < floor.rooms then
			local gate = createPart(
				folder,
				`Gate_{roomIndex}`,
				CFrame.new(center + Vector3.new(0, 7, -roomLength / 2 - 5)),
				Vector3.new(14, 14, 2),
				floor.accentColor,
				Enum.Material.Neon,
				0.15
			)
			addSurfaceText(gate, Enum.NormalId.Front, "LOCKED", Color3.fromRGB(18, 18, 24))
			gates[roomIndex] = gate
		end
	end

	local finalCenter = roomCenters[#roomCenters]
	local chestModel = Instance.new("Model")
	chestModel.Name = "EndChest"
	chestModel.Parent = folder
	local chestBase = createPart(
		chestModel,
		"ChestBase",
		CFrame.new(finalCenter + Vector3.new(0, 2, -12)),
		Vector3.new(7, 3, 4),
		Color3.fromRGB(104, 66, 42),
		Enum.Material.Wood,
		1
	)
	chestBase.CanCollide = false
	chestModel.PrimaryPart = chestBase
	local chestLid = createPart(
		chestModel,
		"ChestLid",
		CFrame.new(finalCenter + Vector3.new(0, 4, -12)),
		Vector3.new(7.4, 1.6, 4.4),
		floor.accentColor,
		Enum.Material.Metal,
		1
	)
	chestLid.CanCollide = false
	addBillboard(chestModel, "Floor Chest", Vector3.new(0, 5, 0), floor.accentColor)

	return {
		folder = folder,
		spawnCFrame = CFrame.new(origin + Vector3.new(0, 5, roomLength / 2 - 8)),
		roomCenters = roomCenters,
		gates = gates,
		chestModel = chestModel,
	}
end

function WorldBuilder.setGateOpen(arena: RunArena, roomIndex: number)
	local gate = arena.gates[roomIndex]
	if gate == nil then
		return
	end

	gate.CanCollide = false
	gate.Transparency = 0.82
	gate.Color = Color3.fromRGB(154, 255, 223)
end

function WorldBuilder.setChestReady(arena: RunArena, ready: boolean)
	for _, child in arena.chestModel:GetDescendants() do
		if child:IsA("BasePart") then
			child.Transparency = if ready then 0 else 1
			child.CanCollide = ready
		end
	end
end

function WorldBuilder.destroyRunArena(arena: RunArena?)
	if arena ~= nil and arena.folder.Parent ~= nil then
		arena.folder:Destroy()
	end
end

function WorldBuilder.createEnemyModel(
	parent: Instance,
	enemy: EnemyConfig,
	position: Vector3,
	index: number
): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = `{enemy.name}_{index}`
	model.Parent = parent

	local root = createPart(
		model,
		"Root",
		CFrame.new(position + Vector3.new(0, 3.6, 0)),
		Vector3.new(4.2, 5.6, 3.2),
		enemy.color,
		Enum.Material.SmoothPlastic,
		0
	)
	addMeshSlot(
		root,
		if enemy.configId == "runeGolem" then "GolemMesh" else "GoblinMesh",
		Vector3.new(1, 1, 1)
	)
	model.PrimaryPart = root

	local head = createPart(
		model,
		"Head",
		CFrame.new(position + Vector3.new(0, 7.2, 0)),
		Vector3.new(3.2, 3.2, 3.2),
		enemy.color:Lerp(Color3.new(1, 1, 1), 0.08),
		Enum.Material.SmoothPlastic,
		0
	)
	head.Shape = Enum.PartType.Ball

	createPart(
		model,
		"RuneCore",
		CFrame.new(position + Vector3.new(0, 3.7, -1.68)),
		Vector3.new(1.1, 1.1, 0.2),
		enemy.accentColor,
		Enum.Material.Neon,
		0
	)
	createPart(
		model,
		"LeftClaw",
		CFrame.new(position + Vector3.new(-2.8, 3.2, -0.6)),
		Vector3.new(1, 3.5, 1),
		enemy.accentColor,
		Enum.Material.Metal,
		0
	)
	createPart(
		model,
		"RightClaw",
		CFrame.new(position + Vector3.new(2.8, 3.2, -0.6)),
		Vector3.new(1, 3.5, 1),
		enemy.accentColor,
		Enum.Material.Metal,
		0
	)

	addBillboard(model, enemy.name, Vector3.new(0, 6, 0), enemy.accentColor)

	return model, root
end

return WorldBuilder
