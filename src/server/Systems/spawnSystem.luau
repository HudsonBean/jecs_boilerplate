--[[
	Consumes pair(c.spawn_request, entity) and runs the matching prefab.

	Prefabs may yield (e.g. LoadCharacterAsync). Planck systems must not yield, so spawn
	work runs in task.defer after this tick collects and clears requests.
]]

local c = require("@Shared/components")
local jecs = require("@Packages/jecs")
local planckRunService = require("@Packages/planck-runservice")
local clearRelation = require("@Shared/utils/ecs/clearRelation")
local spawnNpc = require("@Server/Prefabs/npc")
local spawnPlayer = require("@Server/Prefabs/player")
local world = require("@Shared/world")

local pair = jecs.pair
local Wildcard = jecs.Wildcard

type SpawnJob =
	{ kind: "player", entity: jecs.Entity<any>, player: Player }
	| { kind: "npc_ticket", entity: jecs.Entity<any>, npcId: string, options: c.SpawnOptionsInterface? }
	| { kind: "npc_respawn", entity: jecs.Entity<any>, npcId: string, options: c.SpawnOptionsInterface? }

local q_spawn_requests = world:query(pair(c.spawn_request, Wildcard)):cached()

local function getSpawnOptions(entity: jecs.Entity<any>): c.SpawnOptionsInterface?
	if world:has(entity, c.spawn_options) then
		return world:get(entity, c.spawn_options) :: c.SpawnOptionsInterface
	end

	return nil
end

local function runSpawnJob(job: SpawnJob)
	if job.kind == "player" then
		if not world:contains(job.entity) then
			return
		end

		spawnPlayer(job.player)
		return
	end

	if job.kind == "npc_ticket" then
		spawnNpc(job.npcId, job.options)

		if world:contains(job.entity) then
			world:delete(job.entity)
		end

		return
	end

	if world:contains(job.entity) then
		spawnNpc(job.npcId, job.options, job.entity)
	end
end

local function spawnSystem()
	local jobs: { SpawnJob } = {}

	for entity in q_spawn_requests:iter() do
		clearRelation(entity, c.spawn_request)

		if world:has(entity, c.player) then
			table.insert(jobs, {
				kind = "player",
				entity = entity,
				player = world:get(entity, c.player) :: Player,
			})
			continue
		end

		if world:has(entity, c.npc) then
			local npcId = world:get(entity, c.npc) :: string
			local options = getSpawnOptions(entity)

			if world:has(entity, c.spawn_ticket) then
				table.insert(jobs, {
					kind = "npc_ticket",
					entity = entity,
					npcId = npcId,
					options = options,
				})
			else
				table.insert(jobs, {
					kind = "npc_respawn",
					entity = entity,
					npcId = npcId,
					options = options,
				})
			end

			continue
		end

		warn("[spawnSystem] spawn_request with no handler:", entity)
	end

	for _, job in jobs do
		task.defer(runSpawnJob, job)
	end
end

return {
	name = "spawnSystem",
	system = spawnSystem,
	phase = planckRunService.Phases.PostUpdate,
	runConditions = {},
}
