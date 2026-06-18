local Players = game:GetService("Players")
local c = require("@Shared/components")
local planckRunService = require("@Packages/planck-runservice")
local ref = require("@Shared/utils/ecs/ref")
local world = require("@Shared/world")

local function testingSystem()
	local player = Players.LocalPlayer
	local entity = ref.serach(player)
	if entity and world:has(entity, c.unix) then
		print("[client unix]", world:get(entity, c.unix))
	end
end

return {
	name = "testingSystem",
	system = testingSystem,
	phase = planckRunService.Phases.Update,
	runConditions = {},
}
