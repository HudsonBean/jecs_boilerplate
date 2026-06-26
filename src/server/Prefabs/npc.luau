local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

--[[
	NPC world instances. Two entry points:
	- CollectionService tags at boot (attachComponents)
	- spawnNpc via spawnSystem (CLI tickets or future respawn on existing entity)
]]

local c = require("@Shared/components")
local jecs = require("@Packages/jecs")
local SpawnOptionsTypes = require("@Shared/types/spawn_options")
local npc_configs = require("@Server/Configs/npc_configs")
local replicator = require("@Shared/replicator").server
local world = require("@Shared/world")

local ref = c.ref

local TAG = "npc"
local NPCS_FOLDER_NAME = "Npcs"

export type SpawnNpcOptions = SpawnOptionsTypes.SpawnOptions

export type SpawnNpcFn = (
	npcId: string,
	options: SpawnNpcOptions | Vector3 | nil,
	existingEntity: jecs.Entity<any>?
) -> jecs.Entity<any>?

local function getModelFolder(): Folder?
	return ServerStorage:FindFirstChild("NpcModels") :: Folder?
end

local function getNpcsFolder(): Folder
	local folder = workspace:FindFirstChild(NPCS_FOLDER_NAME)
	if folder and folder:IsA("Folder") then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = NPCS_FOLDER_NAME
	folder.Parent = workspace

	return folder
end

local function resolveTargetCFrame(options: SpawnNpcOptions?): CFrame
	if options and options.cframe then
		return options.cframe
	end

	local position = (options and options.position) or Vector3.zero
	return CFrame.new(position)
end

local function resolveNpcId(instance: Instance): string?
	local npcId = instance:GetAttribute("npc_id")
	if typeof(npcId) == "string" and npcId ~= "" then
		return npcId
	end

	if instance.Name ~= "" then
		return instance.Name
	end

	return nil
end

local function buildHealth(config: npc_configs.NpcConfig): c.HealthInterface
	local healthConfig = config.health

	return {
		health = healthConfig.health,
		max_health = healthConfig.max_health or healthConfig.health,
		regen = healthConfig.regen or 0,
		regen_multiplier = healthConfig.regen_multiplier or 1,
		regen_delay = healthConfig.regen_delay or 5,
		regenerating = false,
	}
end

local function loadCharacterModel(config: npc_configs.NpcConfig, targetCFrame: CFrame): Model?
	local modelFolder = getModelFolder()
	if not modelFolder then
		warn("[npc prefab] NpcModels folder missing under ServerStorage")
		return nil
	end

	local template = modelFolder:FindFirstChild(config.model)
	if not template or not template:IsA("Model") then
		warn("[npc prefab] model not found:", config.model)
		return nil
	end

	local character = template:Clone()
	character:PivotTo(targetCFrame)
	character.Parent = getNpcsFolder()

	return character
end

local function attachComponentsToCharacter(character: Model, npcId: string): jecs.Entity<any>?
	local config = npc_configs.get(npcId)
	if not config then
		warn("[npc prefab] unknown npc_id:", npcId)
		return nil
	end

	return ref(character, function(entity)
		world:set(entity, c.npc, npcId)
		world:set(entity, c.character, character)
		replicator:set_reliable(entity, c.health)
		world:set(entity, c.health, buildHealth(config))

		if config.hostile then
			world:add(entity, c.hostile)
		end

		world:set(entity, c.cleanup, function()
			ref.unlist(character)
			if character.Parent then
				character:Destroy()
			end
		end)
	end)
end

-- Reuses a persistent NPC entity (spawnSystem respawn). Character ref maps to the same entity.
local function attachComponentsToExistingEntity(
	existingEntity: jecs.Entity<any>,
	character: Model,
	npcId: string
): jecs.Entity<any>?
	local config = npc_configs.get(npcId)
	if not config then
		warn("[npc prefab] unknown npc_id:", npcId)
		return nil
	end

	ref.set(character, existingEntity)
	world:set(existingEntity, c.npc, npcId)
	world:set(existingEntity, c.character, character)

	if not world:has(existingEntity, c.health) then
		replicator:set_reliable(existingEntity, c.health)
	end

	world:set(existingEntity, c.health, buildHealth(config))

	if config.hostile then
		world:add(existingEntity, c.hostile)
	else
		world:remove(existingEntity, c.hostile)
	end

	world:set(existingEntity, c.cleanup, function()
		ref.unlist(character)
		if character.Parent then
			character:Destroy()
		end
	end)

	return existingEntity
end

local function attachComponents(instance: Instance): jecs.Entity<any>?
	local npcId = resolveNpcId(instance)
	if not npcId then
		warn("[npc prefab] tagged instance missing npc_id attribute:", instance:GetFullName())
		return nil
	end

	local config = npc_configs.get(npcId)
	if not config then
		warn("[npc prefab] unknown npc_id:", npcId)
		return nil
	end

	if instance:IsA("Model") and instance:FindFirstChildOfClass("Humanoid") then
		return attachComponentsToCharacter(instance, npcId)
	end

	local targetCFrame = if instance:IsA("BasePart")
		then instance.CFrame
		elseif instance:IsA("Model") then instance:GetPivot()
		else CFrame.new()

	local character = loadCharacterModel(config, targetCFrame)
	if not character then
		return nil
	end

	local entity = attachComponentsToCharacter(character, npcId)
	if entity and instance ~= character then
		instance:Destroy()
	end

	return entity
end

local function spawnNpc(
	npcId: string,
	options: SpawnNpcOptions | Vector3 | nil,
	existingEntity: jecs.Entity<any>?
): jecs.Entity<any>?
	local config = npc_configs.get(npcId)
	if not config then
		warn("[npc prefab] unknown npc_id:", npcId)
		return nil
	end

	local resolvedOptions: SpawnNpcOptions = if typeof(options) == "Vector3"
		then { position = options }
		else (options or {})
	local targetCFrame = resolveTargetCFrame(resolvedOptions)

	local character = loadCharacterModel(config, targetCFrame)
	if not character then
		return nil
	end

	if existingEntity then
		return attachComponentsToExistingEntity(existingEntity, character, npcId)
	end

	return attachComponentsToCharacter(character, npcId)
end

for _, instance in CollectionService:GetTagged(TAG) do
	attachComponents(instance)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(attachComponents)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance: Instance)
	local entity = ref.search(instance)
	if not entity then
		return
	end

	-- delete triggers the c.cleanup hook, which unlists the instance from ref.
	world:delete(entity)
end)

return spawnNpc :: SpawnNpcFn
