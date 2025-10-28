-- ServerScriptService>Main>TrainingSystem>Trainings>LuckyBlocks.lua

-- Services & Modules
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local AnimationHandler = require(game.ServerScriptService.Main:WaitForChild("AnimationHandler"))
local AnimationManager = require(RS.Modules.AnimationManager)
local Remotes = RS:WaitForChild("Remotes")

--============================================================================--
--[[ CONFIGURATION ]]--
--============================================================================--

local CONFIG = {
	-- Names of assets in the training area model
	LEVER_MODEL_NAME = "Lever",
	BLOCKS_FOLDER_NAME = "Blocks",
	NODE_PREFIX = "node",
	BLOCK_NAMES = {"block+1", "block+2", "block+3", "block-1", "block-2", "block-3"},

	-- Timings
	LEVER_PULL_DURATION = 0.5,
	BLOCK_HIDE_DURATION = 0.8,
	BLOCK_SHUFFLE_DURATION = 1.5,
	BLOCK_REVEAL_DURATION = 0.8,

	-- Positioning & Animation
	MONSTER_LEVER_OFFSET = CFrame.new(0, 0, -5), -- Monster stands 5 studs away from lever
	MONSTER_CHOICE_OFFSET = CFrame.new(0, 0, 5), -- Monster stands 5 studs in front of chosen block
	LEVER_PULL_ANGLE = CFrame.Angles(math.rad(60), 0, 0),
	BLOCK_HIDE_ROTATION = CFrame.Angles(0, math.rad(180), 0),
}

--============================================================================--
--[[ HELPER FUNCTIONS ]]--
--============================================================================--

-- Freezes a monster's movement for the duration of a function call
local function withHumanoidFrozen(monster, fn)
	local hum = monster:FindFirstChildOfClass("Humanoid")
	local prevWS, prevAuto
	if hum then
		prevWS, prevAuto = hum.WalkSpeed, hum.AutoRotate
		hum.WalkSpeed = 0
		hum.AutoRotate = false
	end

	local success, err = pcall(fn)
	if not success then warn("[LuckyBlocks] Error during frozen sequence:", err) end

	if hum then
		hum.WalkSpeed = prevWS or 16
		hum.AutoRotate = (prevAuto == nil) and true or prevAuto
	end
end

-- Plays a monster's cast animation
local function playCastAnimation(monster)
	local castData = AnimationManager:GetCastAnimation(monster:GetAttribute("Race"))
	if castData and castData.AnimationId then
		AnimationHandler:PlayCastOnce(monster, castData.AnimationId, { fallback = castData.Duration or 1.2 })
		task.wait(castData.Duration or 1.2)
	else
		task.wait(1.2)
	end
end

-- A robust way to tween an entire model's pivot
local function tweenModel(model, info, goal)
	local proxy = Instance.new("CFrameValue")
	proxy.Value = model:GetPivot()

	proxy:GetPropertyChangedSignal("Value"):Connect(function()
		model:PivotTo(proxy.Value)
	end)

	local tween = TweenService:Create(proxy, info, goal)
	tween.Completed:Connect(function()
		proxy:Destroy()
	end)

	tween:Play()
	return tween
end

-- Waits for an entire table of tweens to complete in parallel
local function waitForTweens(tweens)
	if #tweens == 0 then return end

	local counter = #tweens
	for _, t in ipairs(tweens) do
		t.Completed:Once(function()
			counter -= 1
		end)
	end

	while counter > 0 do
		task.wait()
	end
end

-- Fisher-Yates shuffle algorithm
local function shuffleTable(tbl)
	for i = #tbl, 2, -1 do
		local j = math.random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
	return tbl
end

--============================================================================--
--[[ TRAINING "CHAPTERS" ]]--
--============================================================================--

-- Clones and prepares all assets for the training session
local function setupScene(ctx, player)
	local session = { Folder = Instance.new("Folder", Workspace), ClonedBlocks = {} }
	session.Folder.Name = "LuckyBlocks_Session_" .. player.UserId

	local interactables = ctx.Interactables
	local leverModel = interactables:FindFirstChild(CONFIG.LEVER_MODEL_NAME)
	local blocksFolder = interactables:FindFirstChild(CONFIG.BLOCKS_FOLDER_NAME)
	assert(leverModel and blocksFolder, "Could not find Lever or Blocks folder in Interactables")

	session.ClonedLever = leverModel:Clone()
	session.ClonedLever:PivotTo(leverModel:GetPivot())
	session.ClonedLever.Parent = session.Folder

	local nodes = {}
	for i = 1, #CONFIG.BLOCK_NAMES do
		local nodeName = CONFIG.NODE_PREFIX .. i
		local nodeInstance = ctx.Nodes:FindFirstChild(nodeName)
		assert(nodeInstance, "Missing node: " .. nodeName)
		table.insert(nodes, nodeInstance)
	end
	local targetRotation = leverModel:GetPivot().Rotation

	session.BlockPositions = {}
	for i, node in ipairs(nodes) do
		local blockName = CONFIG.BLOCK_NAMES[i]
		local originalBlock = assert(blocksFolder:FindFirstChild(blockName), "Missing block: " .. blockName)
		local newBlock = originalBlock:Clone()

		--for _, part in ipairs(newBlock:GetDescendants()) do
		--	if part:IsA("BasePart") then part.Anchored = false end
		--end

		local value = tonumber(originalBlock.Name:match("([+-]%d+)"))
		newBlock:SetAttribute("Value", value)

		local targetCFrame = CFrame.new(node.Position) * targetRotation
		newBlock:PivotTo(targetCFrame)
		newBlock.Parent = session.Folder

		table.insert(session.ClonedBlocks, newBlock)
		table.insert(session.BlockPositions, targetCFrame)
	end

	return session
end

-- Handles the lever pulling animation
local function pullLever(session, monster, player)
	local lever = session.ClonedLever
	local handle = assert(lever:FindFirstChild("Handle"), "Lever model missing 'Handle'")
	local handlePart = handle:IsA("Model") and handle.PrimaryPart or handle
	for _, v in ipairs(lever:GetDescendants()) do
		if v:IsA("BasePart") then v.Transparency = 0 end
	end
	-- >> FIX: Use CFrame.lookAt to ensure monster faces the lever
	local leverPivot = lever:GetPivot()
	local monsterTargetPos = (leverPivot * CONFIG.MONSTER_LEVER_OFFSET:Inverse()).Position
	local monsterTargetCFrame = CFrame.lookAt(monsterTargetPos, leverPivot.Position)
	monster:PivotTo(monsterTargetCFrame)

	Remotes.TrainingCameraFocus:FireClient(player, lever, "LuckyBlocks", { mode="orbit", duration=3.0, radius=15, height=8 })
	task.wait(1)

	playCastAnimation(monster)

	if _G.EFFECTS then _G.EFFECTS.PlaySound("DefaultImpact", { Where = lever }) end
	local tween = TweenService:Create(handlePart, TweenInfo.new(CONFIG.LEVER_PULL_DURATION), {
		CFrame = handlePart.CFrame * CONFIG.LEVER_PULL_ANGLE
	})
	tween:Play()
	_G.EFFECTS.PlaySound("Lever", {Where = monster.HumanoidRootPart})

	tween.Completed:Wait()
end

-- Handles the hiding and shuffling of blocks
local function shuffleBlocks(session, monster, player)
	if _G.EFFECTS then _G.EFFECTS.PlaySound("MindBend", { Where = monster }) end
	Remotes.TrainingCameraFocus:FireClient(player, monster, "LuckyBlocks", { mode="orbit", duration=8.0, radius=25, height=15 })

	local hideTweens = {}
	for _, block in ipairs(session.ClonedBlocks) do
		local pivot = block:GetPivot()
		local goal = pivot * CONFIG.BLOCK_HIDE_ROTATION
		local info = TweenInfo.new(CONFIG.BLOCK_HIDE_DURATION, Enum.EasingStyle.Cubic)
		table.insert(hideTweens, tweenModel(block, info, { Value = goal }))
	end
	waitForTweens(hideTweens)

	shuffleTable(session.BlockPositions)
	local moveTweens = {}
	for i, block in ipairs(session.ClonedBlocks) do
		local goal = session.BlockPositions[i]
		local info = TweenInfo.new(CONFIG.BLOCK_SHUFFLE_DURATION, Enum.EasingStyle.Bounce)
		table.insert(moveTweens, tweenModel(block, info, { Value = goal }))
	end
	waitForTweens(moveTweens)
end

-- Handles the monster choosing and revealing a block
local function revealChoice(session, monster, player)
	local choiceIndex = math.random(#session.ClonedBlocks)
	local chosenBlock = session.ClonedBlocks[choiceIndex]

	monster:PivotTo(chosenBlock:GetPivot() * CONFIG.MONSTER_CHOICE_OFFSET)
	Remotes.TrainingCameraFocus:FireClient(player, chosenBlock, "LuckyBlocks", { mode="orbit", duration=4.0, radius=10, height=6 })
	task.wait(1.5)

	playCastAnimation(monster)

	local revealTweens = {}
	for _, block in ipairs(session.ClonedBlocks) do
		local pivot = block:GetPivot()
		local goal = pivot * CONFIG.BLOCK_HIDE_ROTATION:Inverse()
		local info = TweenInfo.new(CONFIG.BLOCK_REVEAL_DURATION, Enum.EasingStyle.Cubic)
		table.insert(revealTweens, tweenModel(block, info, { Value = goal }))
	end
	_G.EFFECTS.PlaySound("WoodCrank", {Where = monster.HumanoidRootPart})

	waitForTweens(revealTweens)
	
	local result = chosenBlock:GetAttribute("Value")
	local isSuccess = result > 0

	if _G.EFFECTS and chosenBlock.PrimaryPart then
		local text = isSuccess and "+" .. result or tostring(result)
		_G.EFFECTS.Billboard({ Where = chosenBlock.PrimaryPart, Text = text, Color = isSuccess and Color3.new(0,1,0) or Color3.new(1,0,0) })
		_G.EFFECTS.PlaySound(isSuccess and "Success" or "Fail", { Where = monster.PrimaryPart })
	end

	-- >> FIX: Play the fail animation immediately on a negative result
	if not isSuccess then
		if _G.FUNCTIONS and _G.FUNCTIONS.playDeathFrozen then
			_G.FUNCTIONS.playDeathFrozen(monster, 0.6, 1.8)
		end
	end

	task.wait(3.0)
	return result
end

--============================================================================--
--[[ MAIN TRAINING DEFINITION ]]--
--============================================================================--

local Training = {}
Training.Name = "LuckyBlocks"
Training.Duration = 25
Training.BaseBonus = { Luck = 2 }

function Training:Start(monster, player, ctx)
	assert(monster and player and ctx, "LuckyBlocks: Missing arguments")

	local session = setupScene(ctx, player)
	local result = 0

	withHumanoidFrozen(monster, function()
		pullLever(session, monster, player)
		shuffleBlocks(session, monster, player)
		result = revealChoice(session, monster, player)
	end)

	session.Folder:Destroy()

	-- For LuckyBlocks, the training is always "successful" because a choice was made.
	-- The stat_override table will tell the main system exactly what to change.
	local outcomeReason = result > 0 and "block_positive" or "block_negative"

	-- Teleport to the appropriate end point
	if result > 0 then
		if ctx.End then monster:PivotTo(ctx.End.CFrame) end
	else
		if ctx.Start then monster:PivotTo(ctx.Start.CFrame) end
	end

	return {
		success = true, -- Always true because the activity was completed
		reason = outcomeReason,
		roll = result,
		stat_override = { Luck = result } -- The special override with the exact value
	}
end

return Training