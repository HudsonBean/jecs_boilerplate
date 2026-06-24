local DamageTypes = require("@Shared/types/damage")
local HealthTypes = require("@Shared/types/health")
local QuestTypes = require("@Shared/types/quest")
local SpawnOptionsTypes = require("@Shared/types/spawn_options")
local TimerTypes = require("@Shared/types/timer")
local add_names = require("@Shared/utils/ecs/add_names")
local add_shared = require("@Shared/utils/ecs/add_shared")
local jecs = require("@Packages/jecs")
local ref = require("@Shared/utils/ecs/ref")
local replecs = require("@Packages/replecs")
local world = require("@Shared/world")

-- Re-export shared types for `c.HealthInterface`-style access from systems.
export type HealthInterface = HealthTypes.HealthInterface
export type DamageInterface = DamageTypes.DamageInterface
export type DamageSourceInterface = DamageTypes.DamageSourceInterface
export type TimerInterface = TimerTypes.TimerInterface
export type SpawnOptionsInterface = SpawnOptionsTypes.SpawnOptions
export type QuestState = QuestTypes.QuestState
export type QuestProgress = QuestTypes.QuestProgress
export type QuestStateInterface = QuestTypes.QuestStateInterface
export type QuestObjectiveReportInterface = QuestTypes.QuestObjectiveReport

local components = {
	player = world:component() :: jecs.Entity<Player>,
	player_setup = world:component() :: jecs.Entity<(Player, jecs.Entity<any>) -> ()>,
	cleanup = world:component() :: jecs.Entity<(jecs.Entity<any>) -> ()>,

	character = world:component() :: jecs.Entity<Model>,
	health = world:component() :: jecs.Entity<HealthInterface>,
	damage = world:component() :: jecs.Entity<DamageInterface>,
	damage_source = world:component() :: jecs.Entity<DamageSourceInterface>,
	dead = world:entity(),

	npc = world:component() :: jecs.Entity<string>,
	hostile = world:entity(),

	spawn_options = world:component() :: jecs.Entity<SpawnOptionsInterface>,
	spawn_ticket = world:entity(),

	damage_cooldown = world:component() :: jecs.Entity<number>,

	-- pair(c.spawn_request, entity): consumed by spawnSystem (players, NPC tickets, NPC respawn).
	spawn_request = world:component(),

	timer = world:component() :: jecs.Entity<TimerInterface>,
	-- Per-character session time; reset when character config / permadeath is implemented.
	unix = world:component() :: jecs.Entity<number>,

	quest_state = world:component() :: jecs.Entity<QuestStateInterface>,
	-- One-shot intents consumed by questSystem.
	quest_start = world:component() :: jecs.Entity<string>,
	quest_complete = world:component() :: jecs.Entity<string>,
	quest_objective = world:component() :: jecs.Entity<QuestObjectiveReportInterface>,

	interactable = world:entity(),
	-- Client-local: ProximityPrompt visible / within interact distance.
	interactable_in_range = world:entity(),
	-- pair(c.interact_request, target) on player: one-shot client intent; server validates range.
	interact_request = world:entity(),
}

world:set(components.player, replecs.custom_handler, function(player: Player)
	local entity = ref(player)
	return entity
end)

world:removed(components.cleanup, function(entity: jecs.Entity<any>)
	local callback = world:get(entity, components.cleanup)

	if callback then
		callback(entity)
	end
end)

add_names(components)
add_shared(components, {
	-- Client-local interaction discovery; server validates PromptTriggered separately.
	interactable = true,
	interactable_in_range = true,
	-- Server-only intent: interactionSystemServer writes; dialogueSystem consumes.
	interact_request = true,
})

return components
