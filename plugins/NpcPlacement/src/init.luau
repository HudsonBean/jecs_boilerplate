-- Studio plugin: swap translucent npc prefabs for real models from ServerStorage.NpcModels.
--
-- Install (pick one):
-- 1. Rojo: rojo serve plugins/NpcPlacement --port 34873, then connect Studio plugin to that project
-- 2. Copy plugins/NpcPlacement/src/init.luau into a local Plugin Script under your Roblox Plugins folder

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")

local TAG = "npc"
local NPC_ID_ATTRIBUTE = "npc_id"
local MODELS_FOLDER_NAME = "NpcModels"
local NPCS_FOLDER_NAME = "Npcs"
local DEFAULT_PREFAB_NAME = "_default"
local CAMERA_PLACEMENT_DISTANCE = 12
local SURFACE_RAY_HEIGHT = 10000
local SURFACE_RAY_LENGTH = 20000

type UndoEntry = {
	parent: Instance,
	cframe: CFrame,
	kind: "prefab" | "npc",
	npcId: string?,
	createdModel: Model,
}

local lastUndoBatch: { UndoEntry }? = nil

local toolbar = plugin:CreateToolbar("RPG Tools")
local toggleButton = toolbar:CreateButton(
	"NPC Placement",
	"Replace selected npc prefabs with models from ServerStorage.NpcModels",
	"rbxassetid://6034509993"
)

local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 320, 260, 280, 220)

local widget = plugin:CreateDockWidgetPluginGui("RpgNpcPlacement", widgetInfo)
widget.Title = "NPC Placement"

local root = Instance.new("Frame")
root.BackgroundColor3 = Color3.fromRGB(47, 47, 47)
root.BorderSizePixel = 0
root.Size = UDim2.fromScale(1, 1)
root.Parent = widget

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 12)
padding.PaddingBottom = UDim.new(0, 12)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = root

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = root

local function createLabel(text: string, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.SourceSans
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Size = UDim2.new(1, 0, 0, 36)
	label.LayoutOrder = order
	label.Text = text
	label.Parent = root
	return label
end

local title = createLabel("Insert prefab, Set NPC, then use Undo Last if you picked the wrong model.", 1)
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(220, 220, 220)

local nameBox = Instance.new("TextBox")
nameBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
nameBox.BorderColor3 = Color3.fromRGB(80, 80, 80)
nameBox.ClearTextOnFocus = false
nameBox.Font = Enum.Font.SourceSans
nameBox.PlaceholderText = "Model name in ServerStorage.NpcModels"
nameBox.Text = ""
nameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
nameBox.TextSize = 16
nameBox.Size = UDim2.new(1, 0, 0, 32)
nameBox.LayoutOrder = 2
nameBox.Parent = root

local actionRow = Instance.new("Frame")
actionRow.BackgroundTransparency = 1
actionRow.Size = UDim2.new(1, 0, 0, 34)
actionRow.LayoutOrder = 3
actionRow.Parent = root

local actionLayout = Instance.new("UIListLayout")
actionLayout.FillDirection = Enum.FillDirection.Horizontal
actionLayout.Padding = UDim.new(0, 8)
actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
actionLayout.Parent = actionRow

local setButton = Instance.new("TextButton")
setButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
setButton.BorderSizePixel = 0
setButton.Font = Enum.Font.SourceSansBold
setButton.Text = "Set NPC"
setButton.TextColor3 = Color3.fromRGB(255, 255, 255)
setButton.TextSize = 16
setButton.Size = UDim2.new(0.72, -4, 1, 0)
setButton.LayoutOrder = 1
setButton.Parent = actionRow

local undoButton = Instance.new("TextButton")
undoButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
undoButton.BorderSizePixel = 0
undoButton.Font = Enum.Font.SourceSansBold
undoButton.Text = "↩"
undoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
undoButton.TextSize = 20
undoButton.Size = UDim2.new(0.28, -4, 1, 0)
undoButton.LayoutOrder = 2
undoButton.Parent = actionRow

local insertButton = Instance.new("TextButton")
insertButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
insertButton.BorderSizePixel = 0
insertButton.Font = Enum.Font.SourceSansBold
insertButton.Text = "Insert Prefab"
insertButton.TextColor3 = Color3.fromRGB(255, 255, 255)
insertButton.TextSize = 16
insertButton.Size = UDim2.new(1, 0, 0, 34)
insertButton.LayoutOrder = 4
insertButton.Parent = root

local statusLabel = createLabel("Ready.", 5)
statusLabel.TextSize = 14
statusLabel.TextColor3 = Color3.fromRGB(180, 220, 180)

local function getModelsFolder(): Folder?
	return ServerStorage:FindFirstChild(MODELS_FOLDER_NAME) :: Folder?
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

local function getDefaultPrefabTemplate(): Model?
	local modelsFolder = getModelsFolder()
	if not modelsFolder then
		return nil
	end

	local template = modelsFolder:FindFirstChild(DEFAULT_PREFAB_NAME)
	if template and template:IsA("Model") then
		return template
	end

	return nil
end

local function getModelPivot(model: Model): CFrame
	if model.PrimaryPart then
		return model.PrimaryPart.CFrame
	end

	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart.CFrame
	end

	return model:GetPivot()
end

local function isPlacementPrefab(model: Model): boolean
	if CollectionService:HasTag(model, TAG) then
		return false
	end

	local npcId = model:GetAttribute(NPC_ID_ATTRIBUTE)
	return npcId == nil or npcId == ""
end

local function getSelectedModels(): { Model }
	local models: { Model } = {}

	for _, instance in Selection:Get() do
		if instance:IsA("Model") then
			table.insert(models, instance)
		end
	end

	return models
end

local function stripNpcMetadata(model: Model)
	if CollectionService:HasTag(model, TAG) then
		CollectionService:RemoveTag(model, TAG)
	end

	model:SetAttribute(NPC_ID_ATTRIBUTE, nil)
end

local function refreshUndoButton()
	local canUndo = lastUndoBatch ~= nil and #lastUndoBatch > 0
	undoButton.Active = canUndo
	undoButton.AutoButtonColor = canUndo
	undoButton.BackgroundColor3 = if canUndo then Color3.fromRGB(80, 80, 80) else Color3.fromRGB(45, 45, 45)
end

local function getNpcModelNames(): { string }
	local modelsFolder = getModelsFolder()
	if not modelsFolder then
		return {}
	end

	local names: { string } = {}
	for _, child in modelsFolder:GetChildren() do
		if child:IsA("Model") and child.Name ~= DEFAULT_PREFAB_NAME then
			table.insert(names, child.Name)
		end
	end

	return names
end

local function levenshteinDistance(left: string, right: string): number
	local leftLength = #left
	local rightLength = #right

	if leftLength == 0 then
		return rightLength
	end

	if rightLength == 0 then
		return leftLength
	end

	local previousRow: { number } = table.create(rightLength + 1, 0)
	local currentRow: { number } = table.create(rightLength + 1, 0)

	for column = 0, rightLength do
		previousRow[column + 1] = column
	end

	for row = 1, leftLength do
		currentRow[1] = row
		local leftChar = string.byte(left, row)

		for column = 1, rightLength do
			local substitutionCost = if leftChar == string.byte(right, column) then 0 else 1
			currentRow[column + 1] =
				math.min(currentRow[column] + 1, previousRow[column + 1] + 1, previousRow[column] + substitutionCost)
		end

		previousRow, currentRow = currentRow, previousRow
	end

	return previousRow[rightLength + 1]
end

local function getFuzzyThreshold(input: string, candidate: string): number
	local maxLength = math.max(#input, #candidate)
	return math.max(2, math.floor(maxLength * 0.35))
end

local function scoreNameMatch(input: string, candidate: string): number?
	local inputLower = string.lower(input)
	local candidateLower = string.lower(candidate)

	if inputLower == candidateLower then
		return 0
	end

	local distance = levenshteinDistance(inputLower, candidateLower)
	local threshold = getFuzzyThreshold(input, candidate)

	if string.sub(candidateLower, 1, #inputLower) == inputLower then
		distance -= 1
	elseif string.sub(inputLower, 1, #candidateLower) == candidateLower then
		distance -= 1
	end

	if distance > threshold then
		return nil
	end

	return distance
end

local function resolveNpcModelName(input: string): (string?, boolean, string?)
	if input == DEFAULT_PREFAB_NAME then
		return nil, false, `"${DEFAULT_PREFAB_NAME}" is reserved for the placement prefab template.`
	end

	local modelNames = getNpcModelNames()
	if #modelNames == 0 then
		return nil, false, `No NPC models found in ServerStorage.{MODELS_FOLDER_NAME}.`
	end

	for _, modelName in modelNames do
		if modelName == input then
			return modelName, false, nil
		end
	end

	for _, modelName in modelNames do
		if string.lower(modelName) == string.lower(input) then
			return modelName, false, nil
		end
	end

	local bestName: string? = nil
	local bestScore: number? = nil

	for _, modelName in modelNames do
		local score = scoreNameMatch(input, modelName)
		if score == nil then
			continue
		end

		if bestScore == nil or score < bestScore or (score == bestScore and modelName < bestName :: string) then
			bestName = modelName
			bestScore = score
		end
	end

	if bestName then
		return bestName, true, nil
	end

	return nil, false, `No close match for "{input}" in ServerStorage.{MODELS_FOLDER_NAME}.`
end

local function getRaycastParams(exclude: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	return params
end

local function getOverlapParams(exclude: { Instance }): OverlapParams
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return params
end

local function getFeetY(model: Model): number
	local boundingCFrame, boundingSize = model:GetBoundingBox()
	return boundingCFrame.Position.Y - (boundingSize.Y / 2)
end

local function snapModelFeetToSurfaceY(model: Model, surfaceY: number)
	local pivot = model:GetPivot()
	local deltaY = surfaceY - getFeetY(model)
	model:PivotTo(pivot + Vector3.new(0, deltaY, 0))
end

local function findTopSurfaceAt(x: number, z: number, exclude: { Instance }): RaycastResult?
	return workspace:Raycast(
		Vector3.new(x, SURFACE_RAY_HEIGHT, z),
		Vector3.new(0, -SURFACE_RAY_LENGTH, 0),
		getRaycastParams(exclude)
	)
end

local function isModelInsideSolid(model: Model): boolean
	local probePart = model.PrimaryPart
		or model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChildWhichIsA("BasePart", true)

	if not probePart or not probePart:IsA("BasePart") then
		return false
	end

	local touching = workspace:GetPartsInPart(probePart, getOverlapParams({ model }))
	for _, part in touching do
		if part:IsA("BasePart") and part.CanCollide and part.Transparency < 1 then
			return true
		end
	end

	return false
end

local function snapModelToGroundOrRoof(model: Model)
	local exclude: { Instance } = { model }
	local boundingCFrame = model:GetBoundingBox()
	local x = boundingCFrame.Position.X
	local z = boundingCFrame.Position.Z

	local surface = findTopSurfaceAt(x, z, exclude)
	if surface then
		snapModelFeetToSurfaceY(model, surface.Position.Y)
	end

	if isModelInsideSolid(model) then
		boundingCFrame = model:GetBoundingBox()
		x = boundingCFrame.Position.X
		z = boundingCFrame.Position.Z

		surface = findTopSurfaceAt(x, z, exclude)
		if surface then
			snapModelFeetToSurfaceY(model, surface.Position.Y)
		end
	end
end

local function getCameraPlacementCFrame(): CFrame?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end

	local cameraCFrame = camera.CFrame
	local placementPosition = cameraCFrame.Position + (cameraCFrame.LookVector * CAMERA_PLACEMENT_DISTANCE)
	local flatLookTarget = Vector3.new(cameraCFrame.Position.X, placementPosition.Y, cameraCFrame.Position.Z)

	if (flatLookTarget - placementPosition).Magnitude < 0.001 then
		local flatForward = Vector3.new(-cameraCFrame.LookVector.X, 0, -cameraCFrame.LookVector.Z)
		if flatForward.Magnitude < 0.001 then
			return CFrame.new(placementPosition)
		end
		return CFrame.lookAt(placementPosition, placementPosition + flatForward.Unit)
	end

	return CFrame.lookAt(placementPosition, flatLookTarget)
end

local function placeModelInFrontOfCamera(model: Model)
	local targetCFrame = getCameraPlacementCFrame()
	if not targetCFrame then
		model:PivotTo(CFrame.new(0, 5, 0))
	else
		model:PivotTo(targetCFrame)
	end

	snapModelToGroundOrRoof(model)
end

local function cloneNpcModel(npcName: string): Model?
	local modelsFolder = getModelsFolder()
	if not modelsFolder then
		return nil
	end

	local template = modelsFolder:FindFirstChild(npcName)
	if not template or not template:IsA("Model") then
		return nil
	end

	return template:Clone()
end

local function restoreUndoEntry(entry: UndoEntry): Model?
	local restored: Model

	if entry.kind == "prefab" then
		local template = getDefaultPrefabTemplate()
		if not template then
			return nil
		end

		restored = template:Clone()
		restored.Name = "npc"
		stripNpcMetadata(restored)
	else
		if not entry.npcId then
			return nil
		end

		local npcModel = cloneNpcModel(entry.npcId)
		if not npcModel then
			return nil
		end

		restored = npcModel
		restored.Name = entry.npcId
		restored:SetAttribute(NPC_ID_ATTRIBUTE, entry.npcId)
		CollectionService:AddTag(restored, TAG)
	end

	restored:PivotTo(entry.cframe)
	restored.Parent = entry.parent

	return restored
end

local function setNpcOnModel(sourceModel: Model, npcName: string): (Model?, UndoEntry?, string?)
	local modelsFolder = getModelsFolder()
	if not modelsFolder then
		return nil, nil, `ServerStorage.{MODELS_FOLDER_NAME} was not found.`
	end

	local template = modelsFolder:FindFirstChild(npcName)
	if not template or not template:IsA("Model") then
		return nil, nil, `Model "{npcName}" was not found in ServerStorage.{MODELS_FOLDER_NAME}.`
	end

	local undoEntry: UndoEntry = {
		parent = getNpcsFolder(),
		cframe = getModelPivot(sourceModel),
		kind = if isPlacementPrefab(sourceModel) then "prefab" else "npc",
		npcId = if isPlacementPrefab(sourceModel) then nil else sourceModel:GetAttribute(NPC_ID_ATTRIBUTE) :: string?,
		createdModel = nil :: any,
	}

	local targetCFrame = undoEntry.cframe
	local npcsFolder = undoEntry.parent

	local npcModel = template:Clone()
	npcModel.Name = npcName
	npcModel:PivotTo(targetCFrame)
	npcModel:SetAttribute(NPC_ID_ATTRIBUTE, npcName)
	CollectionService:AddTag(npcModel, TAG)
	npcModel.Parent = npcsFolder

	sourceModel:Destroy()

	undoEntry.createdModel = npcModel

	return npcModel, undoEntry, nil
end

local function setStatus(message: string, isError: boolean?)
	statusLabel.Text = message
	statusLabel.TextColor3 = if isError then Color3.fromRGB(255, 160, 160) else Color3.fromRGB(180, 220, 180)
end

local function onUndoLastClicked()
	if not lastUndoBatch or #lastUndoBatch == 0 then
		setStatus("Nothing to undo.", true)
		return
	end

	ChangeHistoryService:SetWaypoint("Before Undo Set NPC")

	local restoredModels: { Model } = {}

	for _, entry in lastUndoBatch do
		if entry.createdModel.Parent then
			entry.createdModel:Destroy()
		end

		local restored = restoreUndoEntry(entry)
		if restored then
			table.insert(restoredModels, restored)
		end
	end

	ChangeHistoryService:SetWaypoint("After Undo Set NPC")

	lastUndoBatch = nil
	refreshUndoButton()

	if #restoredModels > 0 then
		Selection:Set(restoredModels)
	end

	setStatus(`Restored {#restoredModels} placement(s).`, false)
end

local function insertDefaultPrefab(): Model?
	local template = getDefaultPrefabTemplate()
	if not template then
		setStatus(`Add a "${DEFAULT_PREFAB_NAME}" model to ServerStorage.{MODELS_FOLDER_NAME}.`, true)
		return nil
	end

	ChangeHistoryService:SetWaypoint("Before Insert NPC Prefab")

	local prefab = template:Clone()
	prefab.Name = "npc"
	stripNpcMetadata(prefab)
	prefab.Parent = getNpcsFolder()
	placeModelInFrontOfCamera(prefab)

	ChangeHistoryService:SetWaypoint("After Insert NPC Prefab")

	Selection:Set({ prefab })
	setStatus("Inserted prefab in front of camera.", false)

	return prefab
end

local function onSetNpcClicked()
	local npcName = string.gsub(nameBox.Text, "^%s*(.-)%s*$", "%1")
	if npcName == "" then
		setStatus("Enter a model name first.", true)
		return
	end

	local resolvedName, wasFuzzy, resolveErr = resolveNpcModelName(npcName)
	if not resolvedName then
		setStatus(resolveErr or "Could not resolve model name.", true)
		return
	end

	local selectedModels = getSelectedModels()
	if #selectedModels == 0 then
		setStatus("Select one or more Models in the Explorer.", true)
		return
	end

	ChangeHistoryService:SetWaypoint("Before Set NPC")

	local createdModels: { Model } = {}
	local undoBatch: { UndoEntry } = {}
	local successCount = 0
	local errors: { string } = {}

	for _, sourceModel in selectedModels do
		local npcModel, undoEntry, err = setNpcOnModel(sourceModel, resolvedName)
		if npcModel and undoEntry then
			successCount += 1
			table.insert(createdModels, npcModel)
			table.insert(undoBatch, undoEntry)
		elseif err then
			table.insert(errors, `{sourceModel:GetFullName()}: {err}`)
		end
	end

	ChangeHistoryService:SetWaypoint("After Set NPC")

	if successCount > 0 then
		lastUndoBatch = undoBatch
		refreshUndoButton()

		task.defer(function()
			Selection:Set(createdModels)
		end)
	end

	if successCount == 0 then
		setStatus(errors[1] or "Failed to set NPC.", true)
		return
	end

	local fuzzyNote = if wasFuzzy then ` (matched "{resolvedName}" from "{npcName}")` else ""

	if #errors > 0 then
		setStatus(`Set {successCount} NPC(s). {#errors} failed.{fuzzyNote} Use ↩ to undo.`, true)
		return
	end

	setStatus(`Set {successCount} NPC(s) to "{resolvedName}".{fuzzyNote} Use ↩ to undo.`, false)
end

local function syncNameBoxFromSelection()
	if #Selection:Get() ~= 1 then
		return
	end

	local selected = Selection:Get()[1]
	if not selected or not selected:IsA("Model") then
		return
	end

	if isPlacementPrefab(selected) then
		return
	end

	local existingId = selected:GetAttribute(NPC_ID_ATTRIBUTE)
	if typeof(existingId) == "string" and existingId ~= "" then
		nameBox.Text = existingId
	end
end

toggleButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

setButton.MouseButton1Click:Connect(onSetNpcClicked)
undoButton.MouseButton1Click:Connect(onUndoLastClicked)
insertButton.MouseButton1Click:Connect(insertDefaultPrefab)
nameBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		onSetNpcClicked()
	end
end)

Selection.SelectionChanged:Connect(syncNameBoxFromSelection)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	if widget.Enabled and not getDefaultPrefabTemplate() then
		setStatus(`Add "${DEFAULT_PREFAB_NAME}" to ServerStorage.{MODELS_FOLDER_NAME}.`, true)
	end
end)

refreshUndoButton()
widget.Enabled = false
