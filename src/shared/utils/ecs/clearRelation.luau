local jecs = require("@Packages/jecs")
local world = require("@Shared/world")

local pair = jecs.pair

-- Removes every target of a relation on an entity (e.g. all pair(c.damage_cooldown, *) entries).
return function(entity: jecs.Entity<any>, relation: jecs.Entity<any>)
	local index = 0
	while true do
		local target = world:target(entity, relation, index)
		if not target then
			break
		end
		world:remove(entity, pair(relation, target))
	end
end
