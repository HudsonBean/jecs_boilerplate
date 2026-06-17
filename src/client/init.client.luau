-- Client
local jecs = require("@Packages/jecs")
local createScheduler = require("@Shared/createScheduler")
local replecs = require("@Packages/replecs")

local world = jecs.world()
local state = {}
local scheduler = createScheduler(world, state) -- Already has plugins injected

local systemsOrder = {}
-- scheduler:addSystems(systemsOrder) Disable for now because no systems

print("Hello From client!")
