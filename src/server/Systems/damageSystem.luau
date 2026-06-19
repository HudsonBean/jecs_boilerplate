local Players = game:GetService("Players")

local c = require("@Shared/components")
local jecs = require("@Packages/jecs")
local planckRunService = require("@Packages/planck-runservice")
local ref = require("@Shared/utils/ecs/ref")
local world = require("@Shared/world")

local pair = jecs.pair

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

local function getPlayerEntityFromPart(part: BasePart): jecs.Entity<any>?
	local model = part:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end

	if not model:FindFirstChildOfClass("Humanoid") then
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

-- Victim is on cooldown for this specific damage source until expiresAt
local function isOnCooldown(victimEntity: jecs.Entity<any>, sourceEntity: jecs.Entity<any>, now: number): boolean
	local expiresAt = world:get(victimEntity, pair(c.cooldown, sourceEntity))
	return expiresAt ~= nil and now < expiresAt
end

local function damageSystem()
	local now = os.clock()

	for sourceEntity, source: c.DamageSourceInterface in world:query(c.damage_source) do
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
			if isOnCooldown(victimEntity, sourceEntity, now) then
				continue
			end

			world:set(victimEntity, pair(c.cooldown, sourceEntity), now + source.delay)
			world:set(victimEntity, c.damage, {
				damage = source.damage,
				source = sourceEntity,
			})
		end
	end
end

return {
	name = "damageSystem",
	system = damageSystem,
	phase = planckRunService.Phases.Update,
	runConditions = {},
}
