local c = require("@Shared/components")
local jecs = require("@Packages/jecs")
local scheduleDelay = require("@Shared/utils/scheduleDelay")
local spawnCharacter = require("@Server/Prefabs/character")
local world = require("@Shared/world")

local RESPAWN_DELAY = 5 -- TODO: Per-game-mode or per-spawn-point config

local function respawn(entity: jecs.Entity<any>)
	-- PlayerRemoving deletes the entity (all components) and unlists ref; see players.cleanup.
	-- Guard remains in case a deferred respawn timer fires in the same frame as leave.
	if not world:contains(entity) or not world:has(entity, c.dead) then
		return
	end

	world:remove(entity, c.dead)

	local player = world:get(entity, c.player)
	if player then
		spawnCharacter(player) -- prefab re-attaches character + health
	end
	-- TODO: NPC respawn via a dedicated NPC prefab when added
end

-- Uses a throwaway timer entity because player entities already own a repeating c.timer (unix demo).
local function scheduleRespawn(entity: jecs.Entity<any>)
	scheduleDelay(RESPAWN_DELAY, function()
		respawn(entity)
	end)
end

return {
	respawn = respawn,
	scheduleRespawn = scheduleRespawn,
}
