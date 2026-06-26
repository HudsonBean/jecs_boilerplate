--[[
	Interaction authority: validates PromptTriggered with a server-side distance check,
	then writes pair(c.interact_request, target) on the player entity.

	dialogueSystem (future) consumes interact_request; never trust client interactable_in_range.
]]

local ProximityPromptService = game:GetService("ProximityPromptService")
local c = require("@Shared/components")
local interactable = require("@Shared/interactable")
local jecs = require("@Packages/jecs")
local planckRunService = require("@Packages/planck-runservice")
local world = require("@Shared/world")

local pair = jecs.pair
local ref = c.ref

type InteractTrigger = {
	player: Player,
	prompt: ProximityPrompt,
	root: Instance,
}

local interactRequestQueue: { InteractTrigger } = {}

local function clearRelation(entity: jecs.Entity<any>, relation: jecs.Entity<any>)
	local index = 0
	while true do
		local target = world:target(entity, relation, index)
		if not target then
			break
		end
		world:remove(entity, pair(relation, target))
	end
end

local function resolveTargetEntity(root: Instance): jecs.Entity<any>?
	local entity = ref.search(root)
	if entity then
		return entity
	end

	local model = if root:IsA("Model") then root else root:FindFirstAncestorWhichIsA("Model")
	if model then
		return ref.search(model)
	end

	return nil
end

local function isInteractableTarget(entity: jecs.Entity<any>): boolean
	return world:has(entity, c.npc) or world:has(entity, c.interactable)
end

local function interactionSystemServer()
	for _, trigger in interactRequestQueue do
		local playerEntity = ref.search(trigger.player)
		if not playerEntity then
			continue
		end

		if not interactable.isWithinPromptRange(trigger.player, trigger.prompt, trigger.root) then
			continue
		end

		local targetEntity = resolveTargetEntity(trigger.root)
		if not targetEntity or not isInteractableTarget(targetEntity) then
			continue
		end

		clearRelation(playerEntity, c.interact_request)
		world:add(playerEntity, pair(c.interact_request, targetEntity))
	end

	table.clear(interactRequestQueue)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
	local root = if prompt.Parent then interactable.resolveRoot(prompt.Parent) else nil
	if not root then
		return
	end

	table.insert(interactRequestQueue, {
		player = player,
		prompt = prompt,
		root = root,
	})
end)

return {
	name = "interactionSystemServer",
	system = interactionSystemServer,
	phase = planckRunService.Phases.Update,
	runConditions = {},
}
