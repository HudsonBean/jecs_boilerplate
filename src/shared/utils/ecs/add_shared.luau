local replecs = require("@Packages/replecs")
local world = require("@Shared/world")

function add_shared<T>(entities: T): T
	for name, entity in pairs(entities :: any) do
		world:add(entity, replecs.shared)
	end
	return entities
end

return add_shared
