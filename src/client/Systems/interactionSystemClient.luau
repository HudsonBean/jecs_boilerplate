--[[
	Client interaction discovery only. ProximityPrompt visibility drives c.interactable_in_range
	for local UX; the server validates PromptTriggered and writes c.interact_request.
]]

local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local c = require("@Shared/components")
local interactable = require("@Shared/interactable")
local planckRunService = require("@Packages/planck-runservice")
local world = require("@Shared/world")

local ref = c.ref
local TAG = interactable.TAG

local inRangeQueue: { Instance } = {}
local outOfRangeQueue: { Instance } = {}

local function resolveInteractableEntity(from: Instance)
	local root = interactable.resolveRoot(from)
	if not root then
		return nil
	end

	return ref.search(root)
end

local function attachComponents(instance: Instance)
	ref(instance, function(entity)
		world:add(entity, c.interactable)

		world:set(entity, c.cleanup, function()
			ref.unlist(instance)
		end)
	end)
end

local function ensureProximityPrompt(instance: Instance)
	if instance:FindFirstChildOfClass("ProximityPrompt") then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Parent = instance
end

local function enqueueUnique(queue: { Instance }, instance: Instance)
	if table.find(queue, instance) then
		return
	end

	table.insert(queue, instance)
end

local function interactionSystemClient()
	for _, instance in inRangeQueue do
		local entity = resolveInteractableEntity(instance)
		if not entity then
			continue
		end

		if not world:has(entity, c.interactable) then
			world:delete(entity)
			continue
		end

		world:add(entity, c.interactable_in_range)
	end

	for _, instance in outOfRangeQueue do
		local entity = resolveInteractableEntity(instance)
		if not entity then
			continue
		end

		if not world:has(entity, c.interactable) then
			world:delete(entity)
			continue
		end

		if world:has(entity, c.interactable_in_range) then
			world:remove(entity, c.interactable_in_range)
		end
	end

	table.clear(inRangeQueue)
	table.clear(outOfRangeQueue)
end

for _, instance in CollectionService:GetTagged(TAG) do
	ensureProximityPrompt(instance)
	attachComponents(instance)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance: Instance)
	ensureProximityPrompt(instance)
	attachComponents(instance)
end)

CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance: Instance)
	local entity = ref.search(instance)
	if not entity then
		return
	end

	world:delete(entity)
end)

ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
	local root = if prompt.Parent then interactable.resolveRoot(prompt.Parent) else nil
	if root then
		enqueueUnique(inRangeQueue, root)
	end
end)

ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
	local root = if prompt.Parent then interactable.resolveRoot(prompt.Parent) else nil
	if not root then
		return
	end

	local index = table.find(inRangeQueue, root)
	if index then
		table.remove(inRangeQueue, index)
	end

	enqueueUnique(outOfRangeQueue, root)
end)

return {
	name = "interactionSystemClient",
	system = interactionSystemClient,
	phase = planckRunService.Phases.PostUpdate,
	runConditions = {},
}
