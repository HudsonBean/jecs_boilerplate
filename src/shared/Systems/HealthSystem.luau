local planckRunService = require("@Packages/planck-runservice")

local function healthSystem(world, state) -- Don't know what state is quite yet
	print("Hello World!")
end

return {
	name = "healthSystem",
	system = healthSystem,
	phase = planckRunService.Phases.Update,
	-- runConditions = {},
}
