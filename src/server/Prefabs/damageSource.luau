local CollectionService = game:GetService("CollectionService")

--[[
	World hazards: attach c.damage_source to tagged Parts (Studio or spawnDamageSource CLI).

	Not routed through spawn_request — the Part already exists; we only ECS-bind it.
]]

local c = require("@Shared/components")
local jecs = require("@Packages/jecs")
local world = require("@Shared/world")

local ref = c.ref

local TAG = "damage_source"

local function attachComponents(instance: BasePart, damage: number?, delay: number?)
	local resolvedDamage = tonumber(damage or instance:GetAttribute("damage"))
	local resolvedDelay = tonumber(delay or instance:GetAttribute("delay"))
	if resolvedDamage == nil or resolvedDelay == nil then
		warn("[damageSource prefab] damage or delay not set for instance:", instance.Name)
		return nil
	end

	instance.CanQuery = true

	return ref(instance, function(entity)
		world:set(entity, c.damage_source, {
			damage = resolvedDamage,
			delay = resolvedDelay,
			instance = instance,
		})
		-- ref maps this BasePart -> entity so tag add/remove can find the same entity.
		world:set(entity, c.cleanup, function()
			ref.unlist(instance)
		end)
	end)
end

local function spawnDamageSource(position: Vector3, damage: number, delay: number): jecs.Entity<any>
	local damageSource = Instance.new("Part")
	damageSource:AddTag(TAG)
	damageSource:SetAttribute("delay", delay)
	damageSource:SetAttribute("damage", damage)
	damageSource.Name = "damage_source"
	damageSource.Anchored = true
	damageSource.Size = Vector3.new(5, 1, 5)
	damageSource.TopSurface = Enum.SurfaceType.Smooth
	damageSource.BottomSurface = Enum.SurfaceType.Smooth
	damageSource.Color = Color3.fromRGB(196, 40, 28)
	damageSource.CFrame = CFrame.new(position)

	local particleEmitter = Instance.new("ParticleEmitter")
	particleEmitter.LightInfluence = 1
	particleEmitter.Rate = 14
	particleEmitter.SpreadAngle = Vector2.one * 500
	particleEmitter.Size = NumberSequence.new(0.25)
	particleEmitter.Transparency = NumberSequence.new(0.1)
	particleEmitter.Speed = NumberRange.new(1)
	particleEmitter.Lifetime = NumberRange.new(2.5)
	particleEmitter.Color =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 255), NumberSequenceKeypoint.new(1, 255) })
	particleEmitter.Parent = damageSource

	return attachComponents(damageSource, damage, delay)
end

for _, instance in CollectionService:GetTagged(TAG) do
	attachComponents(instance)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(attachComponents)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance: BasePart)
	local entity = ref.search(instance)
	if not entity then
		return
	end

	-- delete triggers the c.cleanup hook, which unlists the instance from ref.
	world:delete(entity)
end)

return spawnDamageSource
