--[[
	Interaction authority: owns ProximityPrompts for interactable-tagged instances,
	validates PromptTriggered on the server, then writes pair(c.interact_request, target)
	on the player entity.

	interact_request is a short-lived intent (0.5s TTL): dialogueSystem (future) should
	consume it by clearing the relation; otherwise this system auto-expires it via c.timer.
	Never trust client interactable_in_range.
]]

local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local c = require("@Shared/components")
local interactable = require("@Shared/interactable")
local jecs = require("@Packages/jecs")
local planckRunService = require("@Packages/planck-runservice")
local world = require("@Shared/world")

local pair = jecs.pair
local ref = c.ref

local INTERACT_REQUEST_TIMEOUT = 0.5

type InteractTrigger = {
	player: Player,
	prompt: ProximityPrompt,
	root: Instance,
}

local interactRequestQueue: { InteractTrigger } = {}
-- Maps player entity → one-shot timer entity (see scheduleDelay).
local interactRequestTimers: { [jecs.Entity<any>]: jecs.Entity<any> } = {}

local function scheduleDelay(wait: number, onComplete: () -> ()): jecs.Entity<any>
	local timerEntity = world:entity()
	world:set(timerEntity, c.timer, {
		start = os.clock(),
		wait = wait,
		repeats = false,
		callback = function(_entity: jecs.Entity<any>)
			task.defer(onComplete)
		end,
	})
	return timerEntity
end

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

local function cancelInteractRequestTimer(playerEntity: jecs.Entity<any>)
	local existing = interactRequestTimers[playerEntity]
	if existing and world:contains(existing) then
		world:delete(existing)
	end
	interactRequestTimers[playerEntity] = nil
end

local function cleanupStaleInteractRequestTimers()
	for playerEntity in interactRequestTimers do
		if not world:contains(playerEntity) or not world:target(playerEntity, c.interact_request, 0) then
			cancelInteractRequestTimer(playerEntity)
		end
	end
end

local function bindInteractable(instance: Instance)
	local existingEntity = ref.search(instance)
	if existingEntity then
		world:add(existingEntity, c.interactable)
		return
	end

	ref(instance, function(entity)
		world:add(entity, c.interactable)

		world:set(entity, c.cleanup, function()
			ref.unlist(instance)
		end)
	end)
end

local function unbindInteractable(instance: Instance)
	interactable.removeProximityPrompt(instance)

	local entity = ref.search(instance)
	if not entity then
		return
	end

	world:remove(entity, c.interactable)

	if world:has(entity, c.npc) or world:has(entity, c.player) then
		return
	end

	world:delete(entity)
end

local function registerInteractable(instance: Instance)
	interactable.ensureProximityPrompt(instance)
	bindInteractable(instance)
end

local function interactionSystemServer()
	cleanupStaleInteractRequestTimers()

	for _, trigger in interactRequestQueue do
		local playerEntity = ref.search(trigger.player)
		if not playerEntity then
			continue
		end

		if not CollectionService:HasTag(trigger.root, interactable.TAG) then
			continue
		end

		if not interactable.isWithinPromptRange(trigger.player, trigger.prompt, trigger.root) then
			continue
		end

		local targetEntity = resolveTargetEntity(trigger.root)
		if not targetEntity or not world:has(targetEntity, c.interactable) then
			continue
		end

		clearRelation(playerEntity, c.interact_request)
		world:add(playerEntity, pair(c.interact_request, targetEntity))

		cancelInteractRequestTimer(playerEntity)
		interactRequestTimers[playerEntity] = scheduleDelay(INTERACT_REQUEST_TIMEOUT, function()
			interactRequestTimers[playerEntity] = nil

			if not world:contains(playerEntity) then
				return
			end

			clearRelation(playerEntity, c.interact_request)
		end)
	end

	table.clear(interactRequestQueue)
end

for _, instance in CollectionService:GetTagged(interactable.TAG) do
	registerInteractable(instance)
end

CollectionService:GetInstanceAddedSignal(interactable.TAG):Connect(registerInteractable)
CollectionService:GetInstanceRemovedSignal(interactable.TAG):Connect(unbindInteractable)

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
	local root = if prompt.Parent then interactable.resolveRoot(prompt.Parent) else nil
	if not root or not CollectionService:HasTag(root, interactable.TAG) then
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
