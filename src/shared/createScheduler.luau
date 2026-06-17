-- createScheduler
local jecs = require("@Packages/jecs")
local planck = require("@Packages/planck")
local planckJabby = require("@Packages/planck-jabby")
local planckRunServicePlugin = require("@Packages/planck-runservice")

local function createScheduler(world: jecs.World, state: any): planck.Scheduler<jecs.World, any>
	return planck.Scheduler
		.new(world, state)
		:addPlugin(planckRunServicePlugin.Plugin.new())
		:addPlugin(planckJabby.new())
end

return createScheduler
