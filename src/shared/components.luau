local add_names = require("@Shared/utils/ecs/add_names")
local add_shared = require("@Shared/utils/ecs/add_shared")
local jecs = require("@Packages/jecs")
local ref = require("@Shared/utils/ecs/ref")
local replecs = require("@Packages/replecs")
local world = require("@Shared/world")

export type TimerInterface = {
	start: number,
	wait: number,
	repeats: boolean?,
	callback: (jecs.Entity<any>) -> (),
}

local components = {
	player = world:component() :: jecs.Entity<Player>,
	client = world:entity(),
	player_setup = world:component() :: jecs.Entity<(Player, jecs.Entity<any>) -> ()>,
	cleanup = world:component() :: jecs.Entity<(jecs.Entity<any>) -> ()>,

	health = world:component() :: jecs.Entity<number>,

	timer = world:component() :: jecs.Entity<TimerInterface>,
	unix = world:component() :: jecs.Entity<number>,
}

-- Consistent player mapping
world:set(components.player, replecs.custom_handler, function(player: Player)
	local entity = ref(player)
	return entity
end)

-- Setup cleanup callback
world:removed(components.cleanup, function(entity: jecs.Entity<any>)
	local callback = world:get(entity, components.cleanup)

	if callback then
		callback(entity)
	end
end)

add_names(components)
add_shared(components)

return components
