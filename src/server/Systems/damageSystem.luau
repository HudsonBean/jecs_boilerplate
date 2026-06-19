local Players = game:GetService("Players")

local c = require("@Shared/components")
local jecs = require("@Packages/jecs")
local planckRunService = require("@Packages/planck-runservice")
local ref = require("@Shared/utils/ecs/ref")
local world = require("@Shared/world")

local pair = jecs.pair

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

-- Reuse query matching across frames instead of rebuilding it every tick.
local q_damage_sources = world:query(c.damage_source):cached()

local function getPlayerEntityFromPart(part: BasePart): jecs.Entity<any>?
	local model = part:FindFirstAncestorOfClass("Model")
	if not model or not model:FindFirstChildOfClass("Humanoid") then
		return nil
	end

	local player = Players:GetPlayerFromCharacter(model)
	if not player then
		return nil
	end

	return ref.search(player)
end

local function canTakeDamage(entity: jecs.Entity<any>): boolean
	return world:has(entity, c.health) and not world:has(entity, c.dead)
end

--[[
	Hazard hit cooldown lives on the VICTIM, not the hazard.

	Each successful hit writes pair(c.damage_cooldown, sourceEntity) on the victim with an
	expiry timestamp (os.clock). Until that time passes, the same hazard cannot
	apply another c.damage event to that victim.

	source.delay (on the hazard) is the config: "wait this many seconds between ticks."
]]
local function tryApplyHit(
	victimEntity: jecs.Entity<any>,
	sourceEntity: jecs.Entity<any>,
	source: c.DamageSourceInterface,
	now: number
): boolean
	local hitCooldown = pair(c.damage_cooldown, sourceEntity)
	local expiresAt = world:get(victimEntity, hitCooldown)

	if expiresAt then
		if now < expiresAt then
			return false -- still on cooldown for this hazard
		end
		world:remove(victimEntity, hitCooldown) -- expired; drop the stale pair
	end

	world:set(victimEntity, hitCooldown, now + source.delay)
	world:set(victimEntity, c.damage, {
		damage = source.damage,
		source = sourceEntity,
	})
	return true
end

local function damageSystem()
	local now = os.clock()

	for sourceEntity, source: c.DamageSourceInterface in q_damage_sources:iter() do
		local hitbox = source.instance
		if not hitbox or not hitbox.Parent then
			continue
		end

		overlapParams.FilterDescendantsInstances = { hitbox }

		for _, part in workspace:GetPartsInPart(hitbox, overlapParams) do
			local victimEntity = getPlayerEntityFromPart(part)
			if not victimEntity or not canTakeDamage(victimEntity) then
				continue
			end

			tryApplyHit(victimEntity, sourceEntity, source, now)
		end
	end
end

return {
	name = "damageSystem",
	system = damageSystem,
	phase = planckRunService.Phases.Update,
	runConditions = {},
}
