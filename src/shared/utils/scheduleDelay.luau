local c = require("@Shared/components")
local jecs = require("@Packages/jecs")
local world = require("@Shared/world")

-- One-shot delay on a throwaway timer entity.
-- Use this instead of putting c.timer on entities that already have one (e.g. players).
-- Callbacks are deferred so yielding work (e.g. LoadCharacterAsync) never runs inside the timers system.
return function(wait: number, onComplete: () -> ()): jecs.Entity<any>
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
