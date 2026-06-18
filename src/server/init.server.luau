local net = require("@Server/Networking/server")
local scheduler = require("@Shared/scheduler")
local replicator = require("@Shared/replicator").server
local players = require("@Shared/players")

replicator:init()

local systemsOrder = {
	require("@Server/Systems/replecsServer"),
	require("@Server/Systems/healthSystem"),
}

scheduler:addSystems(systemsOrder)

players.start_current_players()
players.listen_for_players()

net.ReceiveFull.On(function(player)
	if replicator:is_player_ready(player) then
		return nil, nil
	end

	replicator:mark_player_ready(player)
	return replicator:get_full(player)
end)
