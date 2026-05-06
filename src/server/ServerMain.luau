--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local DungeonService = require(script.Parent.DungeonService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local ServerMain = {}

local characterConnections: { [Player]: RBXScriptConnection } = {}

local function getRemoteEvent(name: string): RemoteEvent
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotesFolder:WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), `{name} must be a RemoteEvent`)
	return remote
end

local function sendProfile(player: Player, stateUpdateRemote: RemoteEvent)
	local profile = PlayerDataService.getPublicState(player)
	if profile == nil then
		return
	end

	stateUpdateRemote:FireClient(player, {
		kind = "Profile",
		profile = profile,
	})
end

function ServerMain.start(): ()
	local commandRemote = getRemoteEvent(GameConfig.Remotes.DungeonCommand)
	local stateUpdateRemote = getRemoteEvent(GameConfig.Remotes.StateUpdate)
	local toastRemote = getRemoteEvent(GameConfig.Remotes.Toast)

	WorldBuilder.start()

	PlayerDataService.onLoaded(function(player: Player)
		WorldBuilder.updatePlayerBase(player, PlayerDataService.getEquippedBase(player))
		WorldBuilder.giveSwordTool(player, PlayerDataService.getEquippedSword(player))
		WorldBuilder.teleportToLobby(player)
		sendProfile(player, stateUpdateRemote)

		local existingConnection = characterConnections[player]
		if existingConnection ~= nil then
			existingConnection:Disconnect()
		end

		characterConnections[player] = player.CharacterAdded:Connect(function()
			task.defer(function()
				WorldBuilder.giveSwordTool(player, PlayerDataService.getEquippedSword(player))
				WorldBuilder.teleportToLobby(player)
			end)
		end)
	end)

	PlayerDataService.onChanged(function(player: Player, reason: string)
		sendProfile(player, stateUpdateRemote)

		if string.find(reason, "Sword") ~= nil then
			WorldBuilder.giveSwordTool(player, PlayerDataService.getEquippedSword(player))
		elseif string.find(reason, "Base") ~= nil then
			WorldBuilder.updatePlayerBase(player, PlayerDataService.getEquippedBase(player))
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		local connection = characterConnections[player]
		if connection ~= nil then
			connection:Disconnect()
		end

		characterConnections[player] = nil
		WorldBuilder.clearPlayerBase(player)
		DungeonService.endRunForPlayer(player, nil)
	end)

	DungeonService.start(commandRemote, stateUpdateRemote, toastRemote)
	PlayerDataService.start()

	print(`[Server] {Constants.GAME_NAME} {Constants.VERSION} ready`)
end

return ServerMain
