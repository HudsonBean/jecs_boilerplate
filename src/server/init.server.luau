local net = require("@Server/Networking/server")
local scheduler = require("@Shared/scheduler")
local replicator = require("@Shared/replicator").server
local players = require("@Shared/players")
local world = require("@Shared/world")
local jabby = require("@Packages/jabby")

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
}

scheduler:addSystems(systemsOrder)

-- Jabby: expose the server world to the debugger
jabby.register({
	name = "Server",
	applet = jabby.applets.world,
	configuration = { world = world :: any },
})

-- Bootstrap players (after everything else is ready)
players.start_current_players()
players.listen_for_players()
