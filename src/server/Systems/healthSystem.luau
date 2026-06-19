local c = require("@Shared/components")
local planckRunService = require("@Packages/planck-runservice")
local world = require("@Shared/world")

local q_health = world:query(c.health):cached()

local function healthSystem()
	for entity, health: c.HealthInterface in q_health:iter() do
		if world:has(entity, c.dead) then
			continue
		end

		local dirty = false

		if world:has(entity, c.damage) then
			local damage = world:get(entity, c.damage) :: c.DamageInterface
			health.health = math.max(0, health.health - damage.damage)
			world:remove(entity, c.damage)
			dirty = true
		end

		if health.health > health.max_health then -- TODO: Maybe add an overheal feature
			health.health = health.max_health
			dirty = true
		end

		if dirty then
			world:set(entity, c.health, health)
		end
	end
end

return {
	name = "healthSystem",
	system = healthSystem,
	phase = planckRunService.Phases.PostUpdate,
	runConditions = {},
}
