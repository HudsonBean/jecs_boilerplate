local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local c = require("@Shared/components")
local ref = require("@Shared/utils/ecs/ref")
local replecs = require("@Packages/replecs")
local replicator = require("@Shared/replicator")
local world = require("@Shared/world")

local players = {}

function setup(player: Player)
	local entity = ref(player)
	world:set(entity, c.player, player)

	if RunService:IsServer() then
		world:add(entity, replecs.networked)
		replicator.server:set_custom(entity, c.player)
		replicator.server:set_reliable(entity, c.player)
		replicator.server:set_reliable(entity, c.unix)
		replicator.server:set_reliable(entity, c.quest_state)
		world:set(entity, c.unix, 0)
		world:set(entity, c.quest_state, { quests = {} })

		-- Repeating timer lives on the player entity; one-shot delays use scheduleDelay instead.
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
	if not entity then
		return
	end

	-- Deletes the entity and every component on it (health, dead, damage_cooldown pairs, timer, etc.).
	world:delete(entity)
	ref.unlist(player)
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
