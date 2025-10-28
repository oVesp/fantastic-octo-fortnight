--!nolint
-- LocalScript: StarterPlayer>StarterPlayerScripts>ClientScripts>NurseMonsterSpawnerClient
-- Handles client-side interaction and camera effects for monster spawning

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Remote Events
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SpawnMonsterRemote = Remotes:WaitForChild("SpawnMonsterFromNurse")
local SpawnEffectRemote = Remotes:WaitForChild("MonsterSpawnEffect")

-- Camera remotes (from existing system)
local EvFocus = Remotes:WaitForChild("TrainingCameraFocus")
local EvRestore = Remotes:WaitForChild("TrainingCameraRestore")

-- Local Player
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- State management
local state = {
	activeNurse = nil,
	isSpawning = false,
	activePrompts = {},
	cameraConnection = nil,
}

-- // UTILITY FUNCTIONS \\ --

local function isOwner(nurse: Model)
	local parent = nurse.Parent
	if not parent then return false end

	local baseOwnerId = parent:GetAttribute("BaseOwnerId")
	return baseOwnerId and baseOwnerId == player.UserId
end

local function setupNursePrompt(nurse: Model)
	-- Check if we already set up this nurse
	if state.activePrompts[nurse] then return end

	-- Find proximity prompt
	local proximityPrompt = nurse:FindFirstChildOfClass("ProximityPrompt", true)
	if not proximityPrompt then return end

	-- Check ownership
	if not isOwner(nurse) then return end

	-- Setup prompt properties
	proximityPrompt.ActionText = "Spawn Monster"
	proximityPrompt.ObjectText = "Nurse"
	proximityPrompt.HoldDuration = 0.5

	-- Connect to prompt triggered
	local connection = proximityPrompt.Triggered:Connect(function(playerWhoTriggered)
		if playerWhoTriggered == player and not state.isSpawning then
			state.activeNurse = nurse
			state.isSpawning = true

			-- Disable prompt during spawning
			proximityPrompt.Enabled = false

			-- Request spawn from server
			SpawnMonsterRemote:FireServer(nurse)
		end
	end)

	-- Store connection for cleanup
	state.activePrompts[nurse] = {
		connection = connection,
		prompt = proximityPrompt
	}
end

local function cleanupNursePrompt(nurse: Model)
	local promptData = state.activePrompts[nurse]
	if promptData then
		if promptData.connection then
			promptData.connection:Disconnect()
		end
		state.activePrompts[nurse] = nil
	end

	if state.activeNurse == nurse then
		state.activeNurse = nil
	end
end

-- // CAMERA EFFECTS \\ --

local function playSpawnCamera(nurse: Model)
	-- Initial orbit around nurse
	local targetCF = nurse:GetPivot()
	local startTime = tick()

	camera.CameraType = Enum.CameraType.Scriptable

	-- Tween FOV
	TweenService:Create(
		camera,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = 65 }
	):Play()

	state.cameraConnection = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		local angle = elapsed * 30 -- degrees per second

		local radius = 8 + math.sin(elapsed) * 2
		local height = 4 + math.sin(elapsed * 2) * 1

		local x = targetCF.Position.X + math.cos(math.rad(angle)) * radius
		local z = targetCF.Position.Z + math.sin(math.rad(angle)) * radius
		local y = targetCF.Position.Y + height

		camera.CFrame = CFrame.lookAt(
			Vector3.new(x, y, z),
			targetCF.Position + Vector3.new(0, 2, 0)
		)
	end)
end

local function focusOnMonster(monster: Model)
	if state.cameraConnection then
		state.cameraConnection:Disconnect()
	end

	-- Quick focus on spawned monster
	local monsterCF = monster:GetPivot()
	local camPos = monsterCF.Position + Vector3.new(-5, 8, -8)

	TweenService:Create(
		camera,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = CFrame.lookAt(camPos, monsterCF.Position), FieldOfView = 60 }
	):Play()
end

local function restoreCamera()
	if state.cameraConnection then
		state.cameraConnection:Disconnect()
		state.cameraConnection = nil
	end

	-- Restore FOV
	TweenService:Create(
		camera,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = 70 }
	):Play()

	-- Restore camera type
	camera.CameraType = Enum.CameraType.Custom
end

-- // SPAWN EFFECT HANDLER \\ --

SpawnEffectRemote.OnClientEvent:Connect(function(nurse, action, data)
	if action == "start" then
		-- Start camera effect
		playSpawnCamera(nurse)

	elseif action == "spawned" and data then
		-- Monster was spawned, focus on it
		focusOnMonster(data)

		-- Add spawn effect
		local rootPart = data:FindFirstChild("HumanoidRootPart") or data.PrimaryPart
		if rootPart then
			local spawnEffect = Instance.new("PointLight")
			spawnEffect.Brightness = 5
			spawnEffect.Range = 15
			spawnEffect.Color = Color3.fromRGB(0, 255, 127)
			spawnEffect.Parent = rootPart

			TweenService:Create(
				spawnEffect,
				TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Brightness = 0, Range = 0 }
			):Play()

			task.wait(1)
			spawnEffect:Destroy()
		end

	elseif action == "failed" then
		-- Spawn failed
		warn("Monster spawn failed")
		restoreCamera()

	elseif action == "complete" then
		-- Animation complete, restore everything
		task.wait(1) -- Brief pause before restoring
		restoreCamera()

		-- Re-enable prompt
		if state.activeNurse then
			local promptData = state.activePrompts[state.activeNurse]
			if promptData and promptData.prompt then
				promptData.prompt.Enabled = true
			end
		end

		state.isSpawning = false
		state.activeNurse = nil
	end
end)

-- // INITIALIZATION \\ --

local function initializeNurses()
	-- Get all current nurses
	for _, nurse in ipairs(CollectionService:GetTagged("Nurse")) do
		setupNursePrompt(nurse)
	end

	-- Listen for new nurses
	CollectionService:GetInstanceAddedSignal("Nurse"):Connect(function(nurse)
		setupNursePrompt(nurse)
	end)

	-- Clean up removed nurses
	CollectionService:GetInstanceRemovedSignal("Nurse"):Connect(function(nurse)
		cleanupNursePrompt(nurse)
	end)
end

-- Start the system
initializeNurses()

-- Cleanup on character respawn
player.CharacterAdded:Connect(function()
	task.wait(1)
	initializeNurses()
end)

-- Cleanup function
local function cleanup()
	for nurse, _ in pairs(state.activePrompts) do
		cleanupNursePrompt(nurse)
	end
	state.activePrompts = {}
	state.activeNurse = nil
	state.isSpawning = false
	restoreCamera()
end

-- Clean up when player leaves
Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		cleanup()
	end
end)