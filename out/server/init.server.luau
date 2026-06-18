local replecs
local scheduler = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('scheduler'))
local replicator = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('replicator')).server

local systemsOrder = {
	require(script:FindFirstChild('Systems'):FindFirstChild('healthSystem')),
}

scheduler:addSystems(systemsOrder)
