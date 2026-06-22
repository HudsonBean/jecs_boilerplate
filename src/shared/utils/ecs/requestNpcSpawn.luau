local c = require("@Shared/components")
local jecs = require("@Packages/jecs")
local world = require("@Shared/world")

local pair = jecs.pair

-- Creates a one-shot ticket entity consumed by spawnSystem (for CLI / scripted spawns).
return function(npcId: string, options: c.SpawnOptionsInterface?): jecs.Entity<any>
	local ticket = world:entity()
	world:set(ticket, c.npc, npcId)

	if options then
		world:set(ticket, c.spawn_options, options)
	end

	world:add(ticket, c.spawn_ticket)
	world:add(ticket, pair(c.spawn_request, ticket))

	return ticket
end
