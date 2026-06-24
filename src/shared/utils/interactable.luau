local CollectionService = game:GetService("CollectionService")

local TAG = "interactable"

local interactable = {}

interactable.TAG = TAG

function interactable.resolveRoot(from: Instance): Instance?
	local current: Instance? = from

	while current do
		if CollectionService:HasTag(current, TAG) then
			return current
		end

		current = current.Parent
	end

	return nil
end

function interactable.getPosition(root: Instance): Vector3?
	if root:IsA("BasePart") then
		return root.Position
	end

	if root:IsA("Model") then
		return root:GetPivot().Position
	end

	return nil
end

-- Slight buffer for replication latency and character hitbox vs prompt origin.
function interactable.isWithinPromptRange(player: Player, prompt: ProximityPrompt, root: Instance): boolean
	local character = player.Character
	if not character then
		return false
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return false
	end

	local targetPosition = interactable.getPosition(root)
	if not targetPosition then
		return false
	end

	local distance = (rootPart.Position - targetPosition).Magnitude
	local maxDistance = prompt.MaxActivationDistance + 2

	return distance <= maxDistance
end

return interactable
