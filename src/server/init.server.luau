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

-- Bootstrap server prefabs only (damage sources, etc.)
bootstrapPrefabs(ServerScriptService:WaitForChild("Server"))

-- Replecs: start replication and answer full-state requests
replicator:init()

net.ReceiveFull.On(function(player)
	if replicator:is_player_ready(player) then
		return nil, nil
	end

	replicator:mark_player_ready(player)
	return replicator:get_full(player)
end)

-- Planck: schedule systems
local systemsOrder = {
	require("@Server/Systems/replecsServer"),
	require("@Shared/Systems/timers"), -- Starts the player unix timer
	require("@Server/Systems/damageSystem"),
	require("@Server/Systems/healthSystem"),
	require("@Server/Systems/deathSystem"),
}

scheduler:addSystems(systemsOrder)

-- Jabby: expose the server world to the debugger
jabby.register({
	name = "Server",
	applet = jabby.applets.world,
	configuration = { world = world :: any },
})

-- Initial player setup on join
local characterSetup = world:entity()
world:set(characterSetup, c.player_setup, function(player: Player, _entity)
	spawnCharacter(player)
end)

-- Bootstrap players (after everything else is ready)
players.start_current_players()
players.listen_for_players()
