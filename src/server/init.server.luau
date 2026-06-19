local ServerScriptService = game:GetService("ServerScriptService")

local net = require("@Server/Networking/server")
local scheduler = require("@Shared/scheduler")
local replicator = require("@Shared/replicator").server
local bootstrapPrefabs = require("@Shared/utils/bootstrapPrefabs")
local c = require("@Shared/components")
local jabby = require("@Packages/jabby")
local players = require("@Shared/players")
local spawnCharacter = require("@Server/Prefabs/character")
local world = require("@Shared/world")

bootstrapPrefabs(ServerScriptService:WaitForChild("Server"))

replicator:init()

net.ReceiveFull.On(function(player)
	if replicator:is_player_ready(player) then
		return nil, nil
	end

	replicator:mark_player_ready(player)
	return replicator:get_full(player)
end)

-- Update:    damage → write c.damage events
-- PostUpdate: health → apply damage, death → strip body + schedule respawn, replecs → replicate
local systemsOrder = {
	require("@Shared/Systems/timers"),
	require("@Server/Systems/damageSystem"),
	require("@Server/Systems/healthSystem"),
	require("@Server/Systems/deathSystem"),
	require("@Server/Systems/replecsServer"),
}

scheduler:addSystems(systemsOrder)

jabby.register({
	name = "Server",
	applet = jabby.applets.world,
	configuration = { world = world :: any },
})

local characterSetup = world:entity()
world:set(characterSetup, c.player_setup, function(player: Player, _entity)
	spawnCharacter(player)
end)

players.start_current_players()
players.listen_for_players()
