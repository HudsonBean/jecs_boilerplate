local replicator = require("@Shared/replicator").server
local interval = require("@Shared/utils/interval")
local net = require("@Server/Networking/server")
local planckRunService = require("@Packages/planck-runservice")

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
