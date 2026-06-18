local net = require("@Client/Networking/client")
local scheduler = require("@Shared/scheduler")
local replicator = require("@Shared/replicator").client
local players = require("@Shared/players")

replicator:init()

local buf, variants = net.ReceiveFull.Invoke(nil)

local systemsOrder = {
	require("@Client/Systems/replecsClient"),
	require("@Client/Systems/testingSystem"),
}

scheduler:addSystems(systemsOrder)

players.start_current_players()
players.listen_for_players()

if buf then
	replicator:apply_full(buf, variants)
end
