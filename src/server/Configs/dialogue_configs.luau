local QuestTypes = require("@Shared/types/quest")

export type QuestState = QuestTypes.QuestState

export type DialogueChoice = {
	label: string,
	next: string,
	starts_quest: string?,
	completes_quest: string?,
}

export type DialogueNode = {
	text: string,
	choices: { DialogueChoice }?,
	requires_quest: string?,
	requires_quest_state: QuestState?,
}

export type DialogueTree = {
	start: string,
	nodes: { [string]: DialogueNode },
}

local trees: { [string]: DialogueTree } = {
	developer_greeting = {
		start = "intro",
		nodes = {
			intro = {
				text = "Oh, you're alive. Rare around here.",
				choices = {
					{ label = "Who are you?", next = "who_are_you" },
					{ label = "Do you have work for me?", next = "quest_offer" },
					{ label = "Goodbye", next = "bye" },
				},
			},

			who_are_you = {
				text = "ZombieKicker7. Developer. Part-time hazard. Full-time disappointment.",
				choices = {
					{ label = "Got any quests?", next = "quest_offer" },
					{ label = "Back", next = "intro" },
				},
			},

			quest_offer = {
				text = "Yeah. It's called \"do the do.\" Very technical. Don't ask what the do is.",
				requires_quest = "do_the_do",
				requires_quest_state = "inactive",
				choices = {
					{ label = "I'll do the do", next = "quest_accepted", starts_quest = "do_the_do" },
					{ label = "That sounds fake", next = "quest_declined" },
				},
			},

			quest_declined = {
				text = "Everything in this codebase is fake until a system reads it.",
				choices = {
					{ label = "Fine, I'll do the do", next = "quest_accepted", starts_quest = "do_the_do" },
					{ label = "Goodbye", next = "bye" },
				},
			},

			quest_accepted = {
				text = "Great. Go do the do. I'll know when it's done. Probably.",
				requires_quest = "do_the_do",
				requires_quest_state = "active",
				choices = {
					{ label = "What exactly is the do?", next = "quest_hint" },
					{ label = "I'm on it", next = "bye" },
				},
			},

			quest_hint = {
				text = "Touch grass. Touch code. Touch something. Then come back and tell me you did the do.",
				requires_quest = "do_the_do",
				requires_quest_state = "active",
				choices = {
					{ label = "I did the do", next = "quest_turn_in", completes_quest = "do_the_do" },
					{ label = "Still doing the do", next = "bye" },
				},
			},

			quest_turn_in = {
				text = "Incredible. The do has been done. Quest complete. Please never make me write follow-up dialogue.",
				requires_quest = "do_the_do",
				requires_quest_state = "completed",
				choices = {
					{ label = "Any more quests?", next = "quest_done" },
					{ label = "Goodbye", next = "bye" },
				},
			},

			quest_done = {
				text = "No. The quest array only had one entry and you already clicked it.",
				choices = {
					{ label = "Goodbye", next = "bye" },
				},
			},

			bye = {
				text = "Don't die. It's bad for retention.",
			},
		},
	},
}

local function get(treeId: string): DialogueTree?
	return trees[treeId]
end

local function getNode(treeId: string, nodeId: string): DialogueNode?
	local tree = trees[treeId]
	if not tree then
		return nil
	end

	return tree.nodes[nodeId]
end

return {
	get = get,
	getNode = getNode,
}
