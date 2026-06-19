local Players = game:GetService("Players")

local c = require("@Shared/components")
local jecs = require("@Packages/jecs")
local ref = require("@Shared/utils/ecs/ref")
local replicator = require("@Shared/replicator").server
local world = require("@Shared/world")

Players.CharacterAutoLoads = false

-- TODO: Replace with per-character/NPC config lookup
local DEFAULT_HEALTH: c.HealthInterface = {
	health = 100,
	max_health = 100,
	regen = 1,
	regen_multiplier = 1,
	regen_delay = 5,
}

local function getDefaultSpawn(): Vector3 -- TODO: Get spawn location from config
	local spawnLocation = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawnLocation then
		return spawnLocation.Position + Vector3.new(0, 3, 0)
	end
	return Vector3.new(0, 5, 0)
end

-- Attach baseline components shared by players and NPCs.
local function attachComponents(entity: jecs.Entity<any>, character: Model)
	world:set(entity, c.character, character)

	-- Health is removed on death; assign fresh stats whenever a body is spawned in.
	if not world:has(entity, c.health) then
		replicator:set_reliable(entity, c.health)
	end

	world:set(entity, c.health, table.clone(DEFAULT_HEALTH))
end

local function loadCharacter(player: Player, position: Vector3): Model?
	player:LoadCharacterAsync()

	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(position))
	end

	return character
end

local function spawnCharacter(player: Player, position: Vector3?): jecs.Entity<any>
	local spawnPosition = position or getDefaultSpawn()

	local entity = ref.search(player)
	if not entity then
		warn("[character prefab] spawn called before player entity exists:", player.Name)
		entity = ref(player)
	end

	local character = loadCharacter(player, spawnPosition)
	if character then
		attachComponents(entity, character)
	end

	return entity
end

return spawnCharacter
