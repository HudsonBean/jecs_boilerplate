--!nonstrict

local replicator = require("@Shared/replicator").client
local net = require("@Client/Networking/client")
local planckRunService = require("@Packages/planck-runservice")

type Signal<T...> = { [any]: any }
type Cleanup = () -> ()

local function collect<T...>(event: (listener: (T...) -> ()) -> Cleanup | Signal<T...>)
	local storage = {}
	local mt = {}
	local iter = function()
		local n = #storage
		return function()
			if n <= 0 then
				mt.__iter = nil
				return nil
			end

			n -= 1
			return n + 1, unpack(table.remove(storage, 1) :: any)
		end
	end

	local disconnect
	if type(event) == "function" then
		disconnect = event(function(...)
			table.insert(storage, { ... })
			mt.__iter = iter
		end)
	else
		disconnect = event:Connect(function(...)
			table.insert(storage, { ... })
			mt.__iter = iter
		end)
	end

	setmetatable(storage, mt)
	return (storage :: any) :: () -> (number, T...), function()
		disconnect()
	end
end

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
