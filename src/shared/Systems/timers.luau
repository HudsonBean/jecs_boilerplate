local c = require("@Shared/components")
local planckRunService = require("@Packages/planck-runservice")
local world = require("@Shared/world")

local q_timers = world:query(c.timer):cached()

local function timers()
	local now = os.clock()

	for entity, timer in q_timers:iter() do
		if type(timer) ~= "table" then
			warn(
				"BAD TIMER:",
				entity,
				type(timer),
				debug.info(timer, "sln"),
				"| get:",
				type(world:get(entity, c.timer))
			)
			continue
		end

		if now - timer.start < timer.wait then
			continue
		end

		timer.callback(entity)

		if timer.repeats then
			timer.start = now
			world:set(entity, c.timer, timer)
		else
			-- One-shot timer entities (e.g. from scheduleDelay) are deleted after firing.
			world:delete(entity)
		end
	end
end

return {
	name = "timers",
	system = timers,
	phase = planckRunService.Phases.Update,
	runConditions = {},
}
