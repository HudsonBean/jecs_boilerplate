local c = require("@Shared/components")
local planckRunService = require("@Packages/planck-runservice")
local respawnSystem = require("@Server/Systems/respawnSystem")
local world = require("@Shared/world")

local function cleanupCharacter(entity)
	if world:has(entity, c.character) then
		local character = world:get(entity, c.character) :: Model
		character:Destroy()
		world:remove(entity, c.character)
	end

	if world:has(entity, c.health) then
		world:remove(entity, c.health)
	end
end

local function deathSystem()
	for entity, health: c.HealthInterface in world:query(c.health) do
		if health.health <= 0 and not world:has(entity, c.dead) then
			world:add(entity, c.dead)
			cleanupCharacter(entity)
			respawnSystem.scheduleRespawn(entity)
		end
	end
end

return {
	name = "deathSystem",
	system = deathSystem,
	phase = planckRunService.Phases.PostUpdate,
	runConditions = {},
}
