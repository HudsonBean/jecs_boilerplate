local Players = game:GetService("Players")

local c = require("@Shared/components")
local jecs = require("@Packages/jecs")
local SpawnOptionsTypes = require("@Shared/types/spawn_options")
local ref = require("@Shared/utils/ecs/ref")
local replicator = require("@Shared/replicator").server
local world = require("@Shared/world")

Players.CharacterAutoLoads = false

export type SpawnPlayerOptions = SpawnOptionsTypes.SpawnOptions

-- TODO: Replace with per-player config lookup
local DEFAULT_HEALTH: c.HealthInterface = {
	health = 100,
	max_health = 100,
	regen = 1,
	regen_multiplier = 1,
	regen_delay = 5,
	regenerating = false,
}

local function getDefaultSpawn(): Vector3 -- TODO: Get spawn location from config
	local spawnLocation = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawnLocation then
		return spawnLocation.Position + Vector3.new(0, 3, 0)
	end
	return Vector3.new(0, 5, 0)
end

local function resolveTargetCFrame(options: SpawnPlayerOptions?): CFrame
	if options and options.cframe then
		return options.cframe
	end

	local position = (options and options.position) or getDefaultSpawn()
	return CFrame.new(position)
end

local function resolveEntity(player: Player): jecs.Entity<any>
	local entity = ref.search(player)
	if not entity then
		warn("[player prefab] spawn called before player entity exists:", player.Name)
		entity = ref(player)
	end

	return entity
end

local function isPlayerAlive(entity: jecs.Entity<any>): boolean
	return world:contains(entity)
		and not world:has(entity, c.dead)
		and world:has(entity, c.health)
end

local function attachComponents(entity: jecs.Entity<any>, character: Model)
	world:set(entity, c.character, character)

	-- Register replication once; death removes health, respawn writes fresh stats here.
	if not world:has(entity, c.health) then
		replicator:set_reliable(entity, c.health)
	end

	world:set(entity, c.health, table.clone(DEFAULT_HEALTH))
end

local function loadCharacter(player: Player, targetCFrame: CFrame): Model?
	player:LoadCharacterAsync()

	local character = player.Character
	if character then
		character:PivotTo(targetCFrame)
	end

	return character
end

local function teleportPlayer(entity: jecs.Entity<any>, targetCFrame: CFrame): boolean
	if not world:has(entity, c.character) then
		return false
	end

	local character = world:get(entity, c.character) :: Model
	if not character.Parent then
		return false
	end

	-- TODO: Notify anti-cheat that this is an authorized server-side teleport so movement
	-- validation does not flag it as an exploit when CLI/admin tools move players.
	character:PivotTo(targetCFrame)
	return true
end

local function spawnPlayer(player: Player, options: SpawnPlayerOptions | Vector3 | nil): jecs.Entity<any>
	local entity = resolveEntity(player)
	local targetCFrame = resolveTargetCFrame(if typeof(options) == "Vector3" then { position = options } else options)

	if isPlayerAlive(entity) then
		if teleportPlayer(entity, targetCFrame) then
			return entity
		end
	end

	if world:has(entity, c.dead) then
		world:remove(entity, c.dead)
	end

	local character = loadCharacter(player, targetCFrame)
	if character then
		attachComponents(entity, character)
	end

	return entity
end

return spawnPlayer
