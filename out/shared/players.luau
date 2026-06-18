local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local c = require(script.Parent:FindFirstChild('components'))
local ref = require(script.Parent:FindFirstChild('utils'):FindFirstChild('ecs'):FindFirstChild('ref'))
local replecs = require(script.Parent.Parent:FindFirstChild('Packages'):FindFirstChild('replecs'))
local replicator = require(script.Parent:FindFirstChild('replicator'))
local world = require(script.Parent:FindFirstChild('world'))

local players = {}

function setup(player: Player)
	local entity = ref(player)
	world:set(entity, c.player, player)

	if RunService:IsServer() then
		world:add(entity, replecs.networked)
		replicator.server:set_custom(entity, c.player)
		replicator.server:set_reliable(entity, c.player)
		replicator.server:set_reliable(entity, c.unix)
		world:set(entity, c.unix, 0)

		world:set(entity, c.timer, {
			start = os.clock(),
			wait = 1,
			repeats = true,
			callback = function()
				world:set(entity, c.unix, world:get(entity, c.unix) :: number + 1)
			end,
		})
	end

	for _, callback in world:query(c.player_setup):iter() do
		callback(player, entity)
	end
end

function players.cleanup(player: Player)
	local entity = ref.search(player)
	if entity then
		world:delete(entity)
	end
end

function players.start_current_players()
	for _, player in Players:GetPlayers() do
		setup(player)
	end
end

function players.listen_for_players()
	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(players.cleanup)
end

return players
