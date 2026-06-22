export type QuestState = "inactive" | "active" | "completed"

export type QuestProgress = {
	state: QuestState,
	objectives: { [string]: number },
}

export type QuestStateInterface = {
	quests: { [string]: QuestProgress },
}

-- kind matches quest_configs QuestObjectiveKind; string keeps shared code off server configs.
export type QuestObjectiveReport = {
	kind: string,
	target: string?,
	amount: number?,
}

return nil
