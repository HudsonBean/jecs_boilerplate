local collect = require("@Shared/utils/collect")
local replicator = require("@Shared/replicator").client
local net = require("@Client/Networking/client")
local planckRunService = require("@Packages/planck-runservice")

-- Batch network events per frame so replication applies once in PreUpdate.
local reliable_updates = collect(function(listener)
	net.SendUpdates.On(listener)
end)
local unreliable_updates = collect(function(listener)
	net.SendUnreliables.On(listener)
end)

local function replecsClient()
	for _, buf, variants in reliable_updates do
		replicator:apply_updates(buf, variants)
	end

	for _, buf, variants in unreliable_updates do
		replicator:apply_unreliable(buf, variants)
	end
end

return {
	name = "replecsClient",
	system = replecsClient,
	phase = planckRunService.Phases.PreUpdate,
	runConditions = {},
}
