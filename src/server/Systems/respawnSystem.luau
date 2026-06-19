local c = require("@Shared/components")
local jecs = require("@Packages/jecs")
local scheduleDelay = require("@Shared/utils/scheduleDelay")
local spawnCharacter = require("@Server/Prefabs/character")
local world = require("@Shared/world")

local RESPAWN_DELAY = 5 -- TODO: Temporary respawn delay

local function respawn(entity: jecs.Entity<any>)
	if not world:has(entity, c.dead) then
		return
	end

	world:remove(entity, c.dead)

	local player = world:get(entity, c.player)
	if player then
		spawnCharacter(player) -- prefab re-attaches character + health
	end
	-- TODO: NPC respawn via a dedicated NPC prefab when added
end

local function scheduleRespawn(entity: jecs.Entity<any>)
	scheduleDelay(RESPAWN_DELAY, function()
		respawn(entity)
	end)
end

return {
	respawn = respawn,
	scheduleRespawn = scheduleRespawn,
}
