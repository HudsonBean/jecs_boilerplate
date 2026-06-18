local net = require(script:FindFirstChild('Networking'):FindFirstChild('server'))
local scheduler = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('scheduler'))
local replicator = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('replicator')).server
local players = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('players'))
local world = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('world'))
local jabby = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('jabby'))
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
	require(script:FindFirstChild('Systems'):FindFirstChild('replecsServer')),
	require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('Systems'):FindFirstChild('timers')), -- Starts the player unix timer
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
