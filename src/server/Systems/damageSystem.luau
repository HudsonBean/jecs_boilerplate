--[[
	Hazard overlap → c.damage on victims. Runs in Update before healthSystem (PostUpdate).

	Each source queries its hitbox once per frame; per-victim cooldown is pair(c.damage_cooldown, source).
]]

-- TODO: Implement optimizations!
--[[
Right now we do "GetPartsInPart" which if we have an open-world and many damageSources we will
definitely encounter some lag.
]]

local Players = game:GetService("Players")

local c = require("@Shared/components")
local jecs = require("@Packages/jecs")
local planckRunService = require("@Packages/planck-runservice")
local ref = require("@Shared/utils/ecs/ref")
local world = require("@Shared/world")

local pair = jecs.pair

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

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
	Cooldown is stored on the victim as pair(c.damage_cooldown, sourceEntity) → expiry time.
	source.delay is seconds between ticks for that hazard.
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
			return false
		end
		world:remove(victimEntity, hitCooldown)
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
