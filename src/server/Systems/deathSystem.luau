local c = require("@Shared/components")
local clearRelation = require("@Shared/utils/ecs/clearRelation")
local planckRunService = require("@Packages/planck-runservice")
local respawnSystem = require("@Server/Systems/respawnSystem")
local world = require("@Shared/world")

-- Strip the living character bundle. Health is removed so deathSystem won't re-trigger on HP 0.
local function cleanupCharacter(entity)
	if world:has(entity, c.character) then
		local character = world:get(entity, c.character) :: Model
		character:Destroy()
		world:remove(entity, c.character)
	end

	if world:has(entity, c.health) then
		world:remove(entity, c.health)
	end

	-- Victims accumulate pair(damage_cooldown, hazard) relations while standing in hazards.
	-- Clear them on death so a respawned body doesn't inherit "recently hit" timestamps.
	clearRelation(entity, c.damage_cooldown)
end

local function deathSystem()
	for entity, health: c.HealthInterface in world:query(c.health) do
		if health.health > 0 or world:has(entity, c.dead) then
			continue
		end

		world:add(entity, c.dead)
		cleanupCharacter(entity)
		respawnSystem.scheduleRespawn(entity)
	end
end

return {
	name = "deathSystem",
	system = deathSystem,
	phase = planckRunService.Phases.PostUpdate,
	runConditions = {},
}
