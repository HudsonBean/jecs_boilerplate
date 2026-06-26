--[[
	Reads c.damage (written by damageSystem), applies it to c.health, runs regen.

	Regen uses scheduleDelay + local maps because regen timing is per-entity state
	that does not need to replicate or appear in queries.
]]

local c = require("@Shared/components")
local jecs = require("@Packages/jecs")
local planckRunService = require("@Packages/planck-runservice")
local world = require("@Shared/world")

local REGEN_TICK_INTERVAL = 1

local function scheduleDelay(wait: number, onComplete: () -> ()): jecs.Entity<any>
	local timerEntity = world:entity()
	world:set(timerEntity, c.timer, {
		start = os.clock(),
		wait = wait,
		repeats = false,
		callback = function(_entity: jecs.Entity<any>)
			task.defer(onComplete)
		end,
	})
	return timerEntity
end

local q_health = world:query(c.health):cached()
local regenTimers: { [jecs.Entity<any>]: jecs.Entity<any> } = {}
local regenNextTick: { [jecs.Entity<any>]: number } = {}

local function cancelRegen(entity: jecs.Entity<any>)
	local existing = regenTimers[entity]
	if existing and world:contains(existing) then
		world:delete(existing)
	end
	regenTimers[entity] = nil
	regenNextTick[entity] = nil

	if world:has(entity, c.health) then
		local health = world:get(entity, c.health) :: c.HealthInterface
		if health.regenerating then
			health.regenerating = false
			world:set(entity, c.health, health)
		end
	end
end

local function cleanupStaleRegenTimers()
	for entity in regenTimers do
		if not world:contains(entity) or world:has(entity, c.dead) or not world:has(entity, c.health) then
			cancelRegen(entity)
		end
	end
end

local function tickRegen(entity: jecs.Entity<any>, health: c.HealthInterface): boolean
	local now = os.clock()
	local nextTick = regenNextTick[entity]

	if nextTick and now < nextTick then
		return false
	end

	health.health = math.min(health.health + health.regen * health.regen_multiplier, health.max_health)

	if health.health >= health.max_health then
		health.regenerating = false
		regenNextTick[entity] = nil
	else
		regenNextTick[entity] = now + REGEN_TICK_INTERVAL
	end

	return true
end

local function healthSystem()
	cleanupStaleRegenTimers()

	for entity, health: c.HealthInterface in q_health:iter() do
		if world:has(entity, c.dead) then
			continue
		end

		local health_changed = false

		if world:has(entity, c.damage) then
			cancelRegen(entity)
			health = world:get(entity, c.health) :: c.HealthInterface

			local damage = world:get(entity, c.damage) :: c.DamageInterface
			health.health = math.max(0, health.health - damage.damage)
			world:remove(entity, c.damage)
			health_changed = true

			regenTimers[entity] = scheduleDelay(health.regen_delay, function()
				regenTimers[entity] = nil

				if not world:contains(entity) or not world:has(entity, c.health) then
					return
				end

				local current = world:get(entity, c.health) :: c.HealthInterface
				if current.regenerating then
					return
				end

				current.regenerating = true
				regenNextTick[entity] = os.clock()
				world:set(entity, c.health, current)
			end)
		end

		if health.regenerating then
			if tickRegen(entity, health) then
				health_changed = true
			end
		end

		if health.health > health.max_health then -- TODO: Maybe add an overheal feature
			health.health = health.max_health
			health.regenerating = false
			regenNextTick[entity] = nil
			health_changed = true
		end

		if health_changed then
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
