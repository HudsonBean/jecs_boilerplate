-- healthSystem
local jecs = require("@Packages/jecs")
local planck = require("@Packages/planck")
local planckRunService = require("@Packages/planck-runservice")

local function healthSystem(world: jecs.World, state: any) -- Don't know what state is quite yet
	print("Hello World!")
end

return {
	name = "healthSystem",
	system = healthSystem,
	phase = planckRunService.Phases.Update,
	runConditions = {},
} :: planck.SystemTable<jecs.World, any>
