local net = require(script:FindFirstChild('Networking'):FindFirstChild('client'))
local scheduler = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('scheduler'))
local replicator = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('replicator')).client
local players = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('players'))

replicator:init()

local buf, variants = net.ReceiveFull.Invoke(nil)

local systemsOrder = {
	require(script:FindFirstChild('Systems'):FindFirstChild('replecsClient')),
	require(script:FindFirstChild('Systems'):FindFirstChild('testingSystem')),
}

scheduler:addSystems(systemsOrder)

players.start_current_players()
players.listen_for_players()

if buf then
	replicator:apply_full(buf, variants)
end
