-- Server
local createScheduler = require("@Shared/createScheduler")
local jecs = require("@Packages/jecs")
local planck = require("@Packages/planck")
local world = require("@Shared/world")

local state = {}
local scheduler = createScheduler(world, state) -- Already has plugins injected

local systemsOrder: { planck.System<jecs.World, any> } = {

	require("@Shared/Systems/healthSystem"), -- healthSystem
}
scheduler:addSystems(systemsOrder)
