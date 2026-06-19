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

export type HealthInterface = {
	health: number,
	max_health: number,
	regen: number,
	regen_multiplier: number,
	regen_delay: number,
	regenerating: boolean,
}

export type DamageSourceInterface = {
	damage: number,
	delay: number, -- Delay in seconds before hitting the same target
	instance: BasePart,
}

-- on victim consumed in healthSystem
export type DamageInterface = {
	damage: number,
	source: jecs.Entity<any>,
}

local components = {
	player = world:component() :: jecs.Entity<Player>,
	player_setup = world:component() :: jecs.Entity<(Player, jecs.Entity<any>) -> ()>,
	cleanup = world:component() :: jecs.Entity<(jecs.Entity<any>) -> ()>,

	character = world:component() :: jecs.Entity<Model>,
	health = world:component() :: jecs.Entity<HealthInterface>,
	damage = world:component() :: jecs.Entity<DamageInterface>,
	damage_source = world:component() :: jecs.Entity<DamageSourceInterface>,
	dead = world:entity(),

	-- Relation: pair(damage_cooldown, sourceEntity) on victims; value = os.clock() expiry time.
	-- Hazard-only today. Use a separate relation (e.g. ability_cooldown) for player attacks.
	damage_cooldown = world:component() :: jecs.Entity<number>,

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
