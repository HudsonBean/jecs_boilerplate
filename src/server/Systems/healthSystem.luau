local planckRunService = require("@Packages/planck-runservice")

local function healthSystem()
	-- print("Hello World!")
end

return {
	name = "healthSystem",
	system = healthSystem,
	phase = planckRunService.Phases.Update,
	runConditions = {},
}
