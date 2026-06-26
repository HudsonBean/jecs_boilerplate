--[[
	Flushes replecs deltas to clients at fixed rates. No game logic; safe to remove in a headless test.
]]

local replicator = require("@Shared/replicator").server
local net = require("@Server/Networking/server")
local planckRunService = require("@Packages/planck-runservice")

local function interval(seconds: number)
	local pin: number? = nil

	return function()
		if not pin then
			pin = os.clock()
		end

		local elapsed = os.clock() - pin > seconds
		if elapsed then
			pin = os.clock()
		end

		return elapsed
	end
end

local updates_interval = interval(1 / 20)
local unreliable_interval = interval(1 / 30)

local function replecsServer()
	if updates_interval() then
		for player, buf, variants in replicator:collect_updates() do
			net.SendUpdates.Fire(player, buf, variants)
		end
	end

	if unreliable_interval() then
		for player, buf, variants in replicator:collect_unreliable() do
			net.SendUnreliables.Fire(player, buf, variants)
		end
	end
end

return {
	name = "replecsServer",
	system = replecsServer,
	phase = planckRunService.Phases.PostUpdate,
	runConditions = {},
}
