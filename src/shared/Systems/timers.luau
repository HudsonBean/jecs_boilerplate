local c = require("@Shared/components")
local scheduler = require("@Shared/scheduler")
local world = require("@Shared/world")

local q_timers = world:query(c.timer):cached()

function TIMERS()
	local now = os.clock()

	for entity, timer in q_timers:iter() do
		local elapsed = now - timer.start

		if elapsed < timer.wait then
			continue
		end
		timer.callback(entity)
		if timer.repeats then
			timer.start = now
		else
			world:delete(entity)
		end
	end
end

scheduler.System(TIMERS)
return TIMERS
