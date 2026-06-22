--[[
	Watches c.dead and, after a delay, clears dead + queues pair(c.spawn_request, entity).

	Does not spawn directly — spawnSystem picks up the relation on the next PostUpdate.
]]

local c = require("@Shared/components")
local jecs = require("@Packages/jecs")
local planckRunService = require("@Packages/planck-runservice")
local scheduleDelay = require("@Shared/utils/scheduleDelay")
local world = require("@Shared/world")

local pair = jecs.pair

local RESPAWN_DELAY = 5 -- TODO: Per-game-mode or per-spawn-point config

local q_dead = world:query(c.dead):cached()
-- Maps dead entity → one-shot timer entity (see scheduleDelay).
local respawnTimers: { [jecs.Entity<any>]: jecs.Entity<any> } = {}

local function cancelRespawnTimer(entity: jecs.Entity<any>)
	local existing = respawnTimers[entity]
	if existing and world:contains(existing) then
		world:delete(existing)
	end
	respawnTimers[entity] = nil
end

local function cleanupStaleRespawnTimers()
	for entity in respawnTimers do
		if not world:contains(entity) or not world:has(entity, c.dead) then
			cancelRespawnTimer(entity)
		end
	end
end

local function respawnSystem()
	cleanupStaleRespawnTimers()

	for entity in q_dead:iter() do
		if respawnTimers[entity] then
			continue
		end

		respawnTimers[entity] = scheduleDelay(RESPAWN_DELAY, function()
			respawnTimers[entity] = nil

			if not world:contains(entity) or not world:has(entity, c.dead) then
				return
			end

			world:remove(entity, c.dead)
			world:add(entity, pair(c.spawn_request, entity))
		end)
	end
end

return {
	name = "respawnSystem",
	system = respawnSystem,
	phase = planckRunService.Phases.PostUpdate,
	runConditions = {},
}
