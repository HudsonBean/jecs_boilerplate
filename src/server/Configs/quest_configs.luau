local QuestTypes = require("@Shared/types/quest")

export type QuestState = QuestTypes.QuestState

export type QuestObjectiveKind = "manual" | "talk_to_npc" | "kill" | "collect" | "reach_zone"

export type QuestObjective = {
	id: string,
	kind: QuestObjectiveKind,
	target: string?, -- npc_id, enemy id, item id, zone id, etc.
	count: number?,
	description: string?, -- optional quest-log override; falls back to system-generated text
}

-- One entry = one reward. Quests grant multiple rewards via rewards: { QuestReward }.
-- kind tells questSystem how to apply the entry; ids point into future item/currency configs.
export type QuestReward =
	| { kind: "currency", currencyId: string, amount: number }
	| { kind: "item", itemId: string, amount: number }
	| { kind: "xp", amount: number }

export type QuestPrerequisite = {
	quest: string,
	state: QuestState,
}

-- Static quest definitions. Player progress lives on ECS entities, not in this module.
export type QuestConfig = {
	title: string,
	description: string,
	-- When sequential is true (default), objectives unlock in array order.
	-- Example: collect item -> return to npc is two entries in this array.
	objectives: { QuestObjective },
	sequential: boolean?,
	rewards: { QuestReward }?,
	requires: { QuestPrerequisite }?,
	repeatable: boolean?,

	--[[ Deferred fields — add when a system needs them:
	turn_in_npc: string?
		-- npc_id that accepts final turn-in when the last objective is not talk_to_npc/manual.
		-- Often redundant with the last objective's target; skip until duplication hurts.

	hidden: boolean?
		-- Quest exists in data but is omitted from the quest log until activated.

	optional_objectives: { string }?
		-- Objective ids that do not block quest completion (bonus steps / exploration).

	fail_conditions: { ... }?
		-- e.g. escort npc dies, timer expires. Shape TBD when escort/timed quests exist.

	time_limit_seconds: number?
		-- Soft or hard deadline from quest accept; pairs with fail_conditions in questSystem.
	]]
}

local configs: { [string]: QuestConfig } = {
	do_the_do = {
		title = "Do the Do",
		description = "Go do the do. Don't ask what the do is.",
		objectives = {
			{
				id = "turn_in",
				kind = "manual",
				count = 1,
				description = "Do the do",
			},
		},
		rewards = {
			{ kind = "currency", currencyId = "gold", amount = 10 },
		},
	},

	--[[ Example multi-step quest shape for later:
	fetch_the_thing = {
		title = "Fetch the Thing",
		description = "Get the thing. Bring it back.",
		sequential = true,
		objectives = {
			{
				id = "collect_thing",
				kind = "collect",
				target = "mysterious_artifact",
				count = 1,
				description = "Find the mysterious artifact",
			},
			{
				id = "return_to_developer",
				kind = "talk_to_npc",
				target = "ZombieKicker7",
				description = "Return to ZombieKicker7",
			},
		},
		rewards = {
			{ kind = "xp", amount = 50 },
			{ kind = "currency", currencyId = "gold", amount = 25 },
			{ kind = "item", itemId = "developer_sword", amount = 1 },
		},
	},
	]]
}

local function get(questId: string): QuestConfig?
	return configs[questId]
end

return {
	get = get,
}
