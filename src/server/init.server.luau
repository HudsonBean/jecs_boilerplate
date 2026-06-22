local ServerScriptService = game:GetService("ServerScriptService")

local net = require("@Server/Networking/server")
local scheduler = require("@Shared/scheduler")
local replicator = require("@Shared/replicator").server
local bootstrapPrefabs = require("@Shared/utils/bootstrapPrefabs")
local c = require("@Shared/components")
local jabby = require("@Packages/jabby")
local jecs = require("@Packages/jecs")
local players = require("@Shared/players")
local world = require("@Shared/world")

local pair = jecs.pair

bootstrapPrefabs(ServerScriptService:WaitForChild("Server"))

replicator:init()

net.ReceiveFull.On(function(player)
	if replicator:is_player_ready(player) then
		return nil, nil
	end

	replicator:mark_player_ready(player)
	return replicator:get_full(player)
end)

-- Update:    timers → damage → quest intents
-- PostUpdate: health → death → respawn (queues spawn_request) → spawn → replicate
local systemsOrder = {
	require("@Shared/Systems/timers"),
	require("@Server/Systems/damageSystem"),
	require("@Server/Systems/questSystem"),
	require("@Server/Systems/healthSystem"),
	require("@Server/Systems/deathSystem"),
	require("@Server/Systems/respawnSystem"),
	require("@Server/Systems/spawnSystem"),
	require("@Server/Systems/replecsServer"),
}

scheduler:addSystems(systemsOrder)

jabby.register({
	name = "Server",
	applet = jabby.applets.world,
	configuration = { world = world :: any },
})

local playerSetup = world:entity()
world:set(playerSetup, c.player_setup, function(_player: Player, entity)
	-- Same path as respawn: spawnSystem runs spawnPlayer when it sees the pair.
	world:add(entity, pair(c.spawn_request, entity))
end)

players.start_current_players()
players.listen_for_players()
