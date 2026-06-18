local net = require(script:FindFirstChild('Networking'):FindFirstChild('server'))
local scheduler = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('scheduler'))
local replicator = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('replicator')).server
local players = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('players'))

replicator:init()

local systemsOrder = {
	require(script:FindFirstChild('Systems'):FindFirstChild('replecsServer')),
	require(script:FindFirstChild('Systems'):FindFirstChild('healthSystem')),
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
