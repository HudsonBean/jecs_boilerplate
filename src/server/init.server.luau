local Players = game:GetService("Players")

local net = require("@Server/Networking/server")
local scheduler = require("@Shared/scheduler")
local replicator = require("@Shared/replicator").server
local c = require("@Shared/components")
local jabby = require("@Packages/jabby")
local jecs = require("@Packages/jecs")
local replecs = require("@Packages/replecs")
local world = require("@Shared/world")

local pair = jecs.pair
local ref = c.ref

replicator:init()

net.ReceiveFull.On(function(player)
	if replicator:is_player_ready(player) then
		return nil, nil
	end

	replicator:mark_player_ready(player)
	return replicator:get_full(player)
end)

local function setupPlayer(player: Player)
	local entity = ref(player)
	world:set(entity, c.player, player)

	world:add(entity, replecs.networked)
	replicator:set_custom(entity, c.player)
	replicator:set_reliable(entity, c.player)
	replicator:set_reliable(entity, c.unix)
	replicator:set_reliable(entity, c.quest_state)
	world:set(entity, c.unix, 0)
	world:set(entity, c.quest_state, { quests = {} })

	world:set(entity, c.timer, {
		start = os.clock(),
		wait = 1,
		repeats = true,
		callback = function()
			world:set(entity, c.unix, world:get(entity, c.unix) :: number + 1)
		end,
	})

	for _, callback in world:query(c.player_setup):iter() do
		callback(player, entity)
	end
end

local function cleanupPlayer(player: Player)
	local entity = ref.search(player)
	if not entity then
		return
	end

	world:delete(entity)
	ref.unlist(player)
end

-- Update:    timers → damage → quest intents
-- PostUpdate: health → death → respawn (queues spawn_request) → spawn → replicate
local systemsOrder = {
	require("@Shared/Systems/timers"),
	require("@Server/Systems/damageSystem"),
	require("@Server/Systems/questSystem"),
	require("@Server/Systems/healthSystem"),
	require("@Server/Systems/deathSystem"),
	require("@Server/Systems/respawnSystem"),
	require("@Server/Systems/spawnSystem"),
	require("@Server/Systems/interactionSystemServer"),
	require("@Server/Systems/replecsServer"),
}

scheduler:addSystems(systemsOrder)

jabby.register({
	name = "Server",
	applet = jabby.applets.world,
	configuration = { world = world :: any },
})

local playerSetup = world:entity()
world:set(playerSetup, c.player_setup, function(_player: Player, entity)
	world:add(entity, pair(c.spawn_request, entity))
end)

for _, player in Players:GetPlayers() do
	setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(cleanupPlayer)
