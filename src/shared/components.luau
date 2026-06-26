local DamageTypes = require("@Shared/types/damage")
local HealthTypes = require("@Shared/types/health")
local QuestTypes = require("@Shared/types/quest")
local SpawnOptionsTypes = require("@Shared/types/spawn_options")
local TimerTypes = require("@Shared/types/timer")
local jecs = require("@Packages/jecs")
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

local refs: { [any]: any } = {}

local function ref(key: any, initer: ((entity: jecs.Entity<any>) -> ())?): jecs.Entity<any>
	if not key then
		return world:entity()
	end

	local entity = refs[key]
	if not entity then
		entity = world:entity()

		if initer then
			initer(entity)
		end

		refs[key] = entity
	end

	return entity
end

local function __call(_, key: any, initer: (entity: jecs.Entity<any>) -> ())
	return ref(key, initer)
end

local function search(key: any)
	if not key then
		return nil
	end

	return refs[key]
end

local function set(key: any, entity: jecs.Entity<any>)
	refs[key] = entity
end

local function unlist(key: any)
	if not key then
		return
	end

	refs[key] = nil
end

local REF = (setmetatable({
	set = set,
	search = search,
	unlist = unlist,
}, {
	__call = __call,
}) :: any) :: typeof(ref) & { set: typeof(set), search: typeof(search), unlist: typeof(unlist) }

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
	-- pair(c.interact_request, target) on player: server validates PromptTriggered, then writes intent.
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

for name, entity in pairs(components :: any) do
	world:set(entity, jecs.Name, name)
end

for _, entity in pairs(components :: any) do
	world:add(entity, replecs.shared)
end

components.ref = REF

return components
