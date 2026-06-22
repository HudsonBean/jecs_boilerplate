--[[
	Quest authority: reads one-shot intent components, writes c.quest_state.

	Writers (dialogue, proximity, combat, etc.) set intent; this system consumes it:
	- c.quest_start    → accept a quest
	- c.quest_complete → dialogue turn-in (manual objectives)
	- c.quest_objective → world progress (kill, collect, talk_to_npc, …)

	Intent is always removed when seen, even if validation fails (avoids infinite retries).
]]

local c = require("@Shared/components")
local jecs = require("@Packages/jecs")
local planckRunService = require("@Packages/planck-runservice")
local quest_configs = require("@Server/Configs/quest_configs")
local world = require("@Shared/world")

local q_quest_start = world:query(c.player, c.quest_state, c.quest_start):cached()
local q_quest_complete = world:query(c.player, c.quest_state, c.quest_complete):cached()
local q_quest_objective = world:query(c.player, c.quest_state, c.quest_objective):cached()

local function getQuestState(entity: jecs.Entity<any>): c.QuestStateInterface
	return world:get(entity, c.quest_state) :: c.QuestStateInterface
end

local function writeQuestState(entity: jecs.Entity<any>, questState: c.QuestStateInterface)
	world:set(entity, c.quest_state, questState)
end

local function getQuestProgressState(questState: c.QuestStateInterface, questId: string): c.QuestState
	local progress = questState.quests[questId]
	return if progress then progress.state else "inactive"
end

local function objectiveRequiredCount(objective: quest_configs.QuestObjective): number
	return objective.count or 1
end

local function objectiveProgress(progress: c.QuestProgress, objective: quest_configs.QuestObjective): number
	return progress.objectives[objective.id] or 0
end

local function isObjectiveComplete(progress: c.QuestProgress, objective: quest_configs.QuestObjective): boolean
	return objectiveProgress(progress, objective) >= objectiveRequiredCount(objective)
end

local function isSequential(config: quest_configs.QuestConfig): boolean
	return if config.sequential == nil then true else config.sequential
end

-- When sequential, only objectives up to the first incomplete step accept progress.
local function getUnlockedObjectives(
	config: quest_configs.QuestConfig,
	progress: c.QuestProgress
): { quest_configs.QuestObjective }
	if not isSequential(config) then
		return config.objectives
	end

	local unlocked: { quest_configs.QuestObjective } = {}

	for _, objective in config.objectives do
		table.insert(unlocked, objective)

		if not isObjectiveComplete(progress, objective) then
			break
		end
	end

	return unlocked
end

local function areAllObjectivesComplete(config: quest_configs.QuestConfig, progress: c.QuestProgress): boolean
	for _, objective in config.objectives do
		if not isObjectiveComplete(progress, objective) then
			return false
		end
	end

	return true
end

local function initObjectiveProgress(config: quest_configs.QuestConfig): { [string]: number }
	local objectives: { [string]: number } = {}

	for _, objective in config.objectives do
		objectives[objective.id] = 0
	end

	return objectives
end

local function meetsPrerequisites(questState: c.QuestStateInterface, config: quest_configs.QuestConfig): boolean
	local prerequisites = config.requires
	if prerequisites then
		for _, prerequisite in prerequisites do
			if getQuestProgressState(questState, prerequisite.quest) ~= prerequisite.state then
				return false
			end
		end
	end

	return true
end

local function canStart(questState: c.QuestStateInterface, questId: string, config: quest_configs.QuestConfig): boolean
	local state = getQuestProgressState(questState, questId)
	if state == "active" then
		return false
	end

	if state == "completed" and not config.repeatable then
		return false
	end

	return meetsPrerequisites(questState, config)
end

local function applyRewards(rewards: { quest_configs.QuestReward }?)
	if rewards then
		for _, reward in rewards do
			if reward.kind == "currency" then
				-- TODO: currencySystem via c.currency_grant intent
				warn("[questSystem] currency reward not implemented:", reward.currencyId, reward.amount)
			elseif reward.kind == "item" then
				-- TODO: itemSystem via c.item_grant intent
				warn("[questSystem] item reward not implemented:", reward.itemId, reward.amount)
			elseif reward.kind == "xp" then
				-- TODO: xpSystem via c.xp_grant intent
				warn("[questSystem] xp reward not implemented:", reward.amount)
			end
		end
	end
end

local function finishQuest(
	entity: jecs.Entity<any>,
	questState: c.QuestStateInterface,
	questId: string,
	config: quest_configs.QuestConfig,
	progress: c.QuestProgress
)
	progress.state = "completed"
	questState.quests[questId] = progress
	writeQuestState(entity, questState)
	applyRewards(config.rewards)
end

local function processStart(entity: jecs.Entity<any>, questId: string)
	world:remove(entity, c.quest_start)

	local config = quest_configs.get(questId)
	if not config then
		warn("[questSystem] unknown quest id:", questId)
		return
	end

	local questState = getQuestState(entity)
	if not canStart(questState, questId, config) then
		return
	end

	questState.quests[questId] = {
		state = "active",
		objectives = initObjectiveProgress(config),
	}
	writeQuestState(entity, questState)
end

-- Dialogue turn-in: completes unlocked manual objectives (e.g. "I did the do").
local function processComplete(entity: jecs.Entity<any>, questId: string)
	world:remove(entity, c.quest_complete)

	local config = quest_configs.get(questId)
	if not config then
		warn("[questSystem] unknown quest id:", questId)
		return
	end

	local questState = getQuestState(entity)
	local progress = questState.quests[questId]
	if not progress or progress.state ~= "active" then
		return
	end

	local changed = false

	for _, objective in getUnlockedObjectives(config, progress) do
		if objective.kind ~= "manual" or isObjectiveComplete(progress, objective) then
			continue
		end

		progress.objectives[objective.id] = objectiveRequiredCount(objective)
		changed = true
	end

	if not changed then
		return
	end

	if areAllObjectivesComplete(config, progress) then
		finishQuest(entity, questState, questId, config, progress)
	else
		questState.quests[questId] = progress
		writeQuestState(entity, questState)
	end
end

local function processObjective(entity: jecs.Entity<any>, report: c.QuestObjectiveReportInterface)
	world:remove(entity, c.quest_objective)

	local increment = report.amount or 1
	local questState = getQuestState(entity)
	local changed = false

	for questId, progress in questState.quests do
		if progress.state ~= "active" then
			continue
		end

		local config = quest_configs.get(questId)
		if not config then
			continue
		end

		for _, objective in getUnlockedObjectives(config, progress) do
			if objective.kind ~= report.kind then
				continue
			end

			if report.target and objective.target ~= report.target then
				continue
			end

			if isObjectiveComplete(progress, objective) then
				continue
			end

			local current = objectiveProgress(progress, objective)
			progress.objectives[objective.id] = math.min(current + increment, objectiveRequiredCount(objective))
			changed = true

			if areAllObjectivesComplete(config, progress) then
				finishQuest(entity, questState, questId, config, progress)
				return
			end
		end
	end

	if changed then
		writeQuestState(entity, questState)
	end
end

local function questSystem()
	for entity, questId in q_quest_start:iter() do
		processStart(entity, questId)
	end

	for entity, questId in q_quest_complete:iter() do
		processComplete(entity, questId)
	end

	for entity, report in q_quest_objective:iter() do
		processObjective(entity, report)
	end
end

return {
	name = "questSystem",
	system = questSystem,
	phase = planckRunService.Phases.Update,
	runConditions = {},
}
