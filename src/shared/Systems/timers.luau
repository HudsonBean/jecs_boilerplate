local c = require("@Shared/components")
local planckRunService = require("@Packages/planck-runservice")
local world = require("@Shared/world")

local q_timers = world:query(c.timer):cached()

function timers()
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

		local elapsed = now - timer.start

		if elapsed < timer.wait then
			continue
		end
		timer.callback(entity)
		if timer.repeats then
			timer.start = now
			world:set(entity, c.timer, timer)
		else
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
