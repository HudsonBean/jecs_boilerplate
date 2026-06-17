local planck = require("@Packages/planck")
local planckRunServicePlugin = require("@Packages/planck-runservice")

local function createScheduler(world, state): planck.Scheduler
	return planck.Scheduler.new(world, state):addPlugin(planckRunServicePlugin.Plugin.new()) -- Inject the plugin
end

return createScheduler
