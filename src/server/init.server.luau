-- Server
local jecs = require("@Packages/jecs")
local createScheduler = require("@Shared/createScheduler")

local world = jecs.world()
local state = {}
local scheduler = createScheduler(world, state) -- Already has plugins injected

local systemsOrder = {
	require("@Shared/Systems/HealthSystem"), -- healthSystem
}
scheduler:addSystems(systemsOrder)
