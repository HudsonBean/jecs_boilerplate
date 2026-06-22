--[[
	HP reached 0: tag c.dead and strip the living character bundle.

	healthSystem stops querying dead entities once c.health is removed.
	respawnSystem picks up c.dead later.
]]

local c = require("@Shared/components")
local clearRelation = require("@Shared/utils/ecs/clearRelation")
local planckRunService = require("@Packages/planck-runservice")
local world = require("@Shared/world")

local q_health = world:query(c.health):cached()

local function cleanupCharacter(entity)
	if world:has(entity, c.character) then
		local character = world:get(entity, c.character) :: Model
		character:Destroy()
		world:remove(entity, c.character)
	end

	if world:has(entity, c.health) then
		world:remove(entity, c.health)
	end

	-- Drop hazard hit cooldowns so respawn does not inherit stale timestamps.
	clearRelation(entity, c.damage_cooldown)
end

local function deathSystem()
	for entity, health: c.HealthInterface in q_health:iter() do
		if health.health > 0 or world:has(entity, c.dead) then
			continue
		end

		world:add(entity, c.dead)
		cleanupCharacter(entity)
	end
end

return {
	name = "deathSystem",
	system = deathSystem,
	phase = planckRunService.Phases.PostUpdate,
	runConditions = {},
}
