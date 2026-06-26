local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local net = require("@Client/Networking/client")
local scheduler = require("@Shared/scheduler")
local replicator = require("@Shared/replicator").client
local c = require("@Shared/components")
local jabby = require("@Packages/jabby")
local world = require("@Shared/world")

local ref = c.ref

replicator:init()
local buf, variants = net.ReceiveFull.Invoke(nil)

local systemsOrder = {
	require("@Client/Systems/interactionSystemClient"),
	require("@Client/Systems/replecsClient"),
}

scheduler:addSystems(systemsOrder)

local client = jabby.obtain_client()

jabby.register({
	name = "Client",
	applet = jabby.applets.world,
	configuration = { world = world :: any },
})

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F4 then
		client.spawn_app(client.apps.home)
	end
end)

local function setupPlayer(player: Player)
	local entity = ref(player)
	world:set(entity, c.player, player)

	for _, callback in world:query(c.player_setup):iter() do
		callback(player, entity)
	end
end

local function cleanupPlayer(player: Player)
	local entity = ref.search(player)
	if not entity then
		return
	end

	world:delete(entity)
	ref.unlist(player)
end

for _, player in Players:GetPlayers() do
	setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(cleanupPlayer)

if buf then
	replicator:apply_full(buf, variants)
end
