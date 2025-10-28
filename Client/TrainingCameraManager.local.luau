--!nolint
-- LocalScript: StarterPlayer>StarterPlayerScripts>ClientScripts>TrainingCameraManager
-- This script centralizes all camera logic for training sessions and monster spawning.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- Remote Events
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EvFocus = Remotes:WaitForChild("TrainingCameraFocus")
local EvRestore = Remotes:WaitForChild("TrainingCameraRestore")
local EvFail = Remotes:WaitForChild("TrainingCameraFail")

-- Monster spawning remotes
local RequestMonsterSpawn = Remotes:WaitForChild("RequestMonsterSpawn")
local MonsterSpawned = Remotes:WaitForChild("MonsterSpawned")

-- Local Player and Camera
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- State management to prevent conflicting camera movements
local state = {
	active = false,
	stopToken = 0,
	connection = nil,
}

-- // UTILITY FUNCTIONS \\ --

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function getTargetCFrame(target: Instance)
	if target:IsA("Model") then
		local root = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
		return root and root.CFrame or target:GetPivot()
	elseif target:IsA("BasePart") then
		return target.CFrame
	end
	return CFrame.new()
end

local function getLookCFrame(fromPos: Vector3, toPos: Vector3)
	return CFrame.new(fromPos, toPos)
end

local function tweenFOV(toFov: number, duration: number)
	pcall(function()
		TweenService:Create(
			camera,
			TweenInfo.new(duration or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ FieldOfView = toFov }
		):Play()
	end)
end

-- // CORE STATE CONTROLLERS \\ --

local function setCameraScriptable(isScriptable: boolean)
	camera.CameraType = if isScriptable then Enum.CameraType.Scriptable else Enum.CameraType.Custom
end

local function startEffect()
	-- Invalidate any previous running effect
	state.stopToken += 1
	if state.connection then
		state.connection:Disconnect()
		state.connection = nil
	end

	state.active = true
	setCameraScriptable(true)
	return state.stopToken
end

-- // CAMERA MODES \\ --

-- Follows the target from the side
local function playSideFollow(target: Instance, options: table)
	local token = startEffect()

	-- Constants for follow camera
	local SIDE_DIST = 10
	local SIDE_HEIGHT = 5.5
	local BACK_NUDGE = 2.0

	local function getSideFollowCFrame(model: Model)
		if not model or not model.Parent then return camera.CFrame end
		local ref = model:FindFirstChild("Head") or model.PrimaryPart or model
		local pivot = model:GetPivot()
		local right = pivot.RightVector
		local look = pivot.LookVector
		local camPos = ref.Position + (right * SIDE_DIST) + Vector3.new(0, SIDE_HEIGHT, 0) - (look * BACK_NUDGE)
		return CFrame.new(camPos, ref.Position)
	end

	tweenFOV(options.fov or 70, 0.2)

	state.connection = RunService.RenderStepped:Connect(function(dt)
		if token ~= state.stopToken or not target or not target.Parent then
			if state.connection then
				state.connection:Disconnect()
				state.connection = nil
			end
			return
		end

		local desired = getSideFollowCFrame(target)
		camera.CFrame = camera.CFrame:Lerp(desired, 0.15)
	end)
end

-- Orbits the target for a set duration
local function playOrbit(target: Instance, options: table)
	local token = startEffect()

	local duration = tonumber(options.duration) or 1.0
	local radius = tonumber(options.radius) or 10
	local height = tonumber(options.height) or 4
	local yawOffset = tonumber(options.yawOffsetDeg) or 0
	local angularSpeed = tonumber(options.angularSpeedDeg) or 0

	if options.fov then
		tweenFOV(options.fov, 0.2)
	end

	local startTime = os.clock()

	local function computeOrbitCF(targetCF: CFrame, r: number, h: number, yawDeg: number)
		local base = targetCF * CFrame.new(0, h, 0) * CFrame.Angles(0, math.rad(yawDeg), 0)
		return base * CFrame.new(0, 0, r)
	end

	state.connection = RunService.RenderStepped:Connect(function()
		if token ~= state.stopToken then
			if state.connection then
				state.connection:Disconnect()
				state.connection = nil
			end
			return
		end

		local elapsed = os.clock() - startTime
		local fraction = math.clamp(elapsed / duration, 0, 1)

		local targetCF = getTargetCFrame(target)
		local currentYaw = yawOffset + angularSpeed * elapsed

		local camCF = computeOrbitCF(targetCF, radius, height, currentYaw)
		camera.CFrame = getLookCFrame(camCF.Position, targetCF.Position)

		if fraction >= 1 then
			if state.connection then
				state.connection:Disconnect()
				state.connection = nil
			end
		end
	end)
end

-- Plays a cinematic on failure
local function playFailCinematic(target: Instance, options: table)
	local token = startEffect()

	local duration = tonumber(options.duration) or 1.3
	local r0 = tonumber(options.radiusStart) or 12
	local r1 = tonumber(options.radiusEnd) or 9
	local h0 = tonumber(options.heightStart) or 6
	local h1 = tonumber(options.heightEnd) or 7.5
	local angularSpeed = tonumber(options.angularSpeedDeg) or 55
	local fov0 = tonumber(options.fovStart) or 70
	local fov1 = tonumber(options.fovEnd) or 62
	local easeTime = tonumber(options.easeTime) or 0.25

	tweenFOV(fov0, 0.01)

	local startTime = os.clock()

	local function computeOrbitCF(targetCF: CFrame, r: number, h: number, yawDeg: number)
		local base = targetCF * CFrame.new(0, h, 0) * CFrame.Angles(0, math.rad(yawDeg), 0)
		return base * CFrame.new(0, 0, r)
	end

	state.connection = RunService.RenderStepped:Connect(function()
		if token ~= state.stopToken then
			if state.connection then
				state.connection:Disconnect()
				state.connection = nil
			end
			return
		end

		local elapsed = os.clock() - startTime
		local fraction = math.clamp(elapsed / duration, 0, 1)

		local targetCF = getTargetCFrame(target)
		local radius = lerp(r0, r1, fraction)
		local height = lerp(h0, h1, fraction)
		local yaw = angularSpeed * elapsed

		local camCF = computeOrbitCF(targetCF, radius, height, yaw)
		camera.CFrame = getLookCFrame(camCF.Position, targetCF.Position)
		camera.FieldOfView = lerp(fov0, fov1, math.clamp(elapsed / math.max(easeTime, 0.01), 0, 1))

		if fraction >= 1 then
			if state.connection then
				state.connection:Disconnect()
				state.connection = nil
			end
		end
	end)
end

-- // MONSTER SPAWNING LOGIC (CLIENT SIDE) \\ --

local function waitForAnimationMarker(animationTrack, markerName: string, timeout: number?)
	local markerReached = false
	local maxWait = timeout or 10
	local startTime = os.clock()

	local connection
	connection = animationTrack:GetMarkerReachedSignal(markerName):Connect(function()
		markerReached = true
		if connection then
			connection:Disconnect()
		end
	end)

	-- Wait until marker is reached, animation stops, or timeout
	while not markerReached and animationTrack.IsPlaying and (os.clock() - startTime) < maxWait do
		task.wait()
	end

	if connection then
		connection:Disconnect()
	end

	return markerReached
end

local function checkNurseOwnership(nurse: Model): boolean
	local base = nurse.Parent
	if not base then
		return false
	end

	local baseOwnerId = base:GetAttribute("BaseOwnerId")
	return baseOwnerId == tostring(player.UserId)
end

local function spawnMonsterAtNurse(nurse: Model)
	-- Check ownership client-side first
	if not checkNurseOwnership(nurse) then
		warn("You don't own this base")
		return
	end

	-- Find humanoid and animator in the nurse
	local humanoid = nurse:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("Nurse has no Humanoid")
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Load and play the animation
	local animationId = "rbxassetid://99935535976756"
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId

	local animTrack = animator:LoadAnimation(animation)
	animTrack:Play()

	-- Focus camera on nurse during spawn
	playOrbit(nurse, {
		duration = 3.0,
		radius = 8,
		height = 5,
		angularSpeedDeg = 30,
		fov = 65
	})

	-- Wait for the "Spawn" marker
	local success = waitForAnimationMarker(animTrack, "Spawn", 10)

	if success then
		-- Request server to spawn the monster
		RequestMonsterSpawn:FireServer(nurse)
	else
		warn("Animation marker 'Spawn' was not reached")
		-- Restore camera if spawn failed
		task.wait(0.5)
		EvRestore:FireServer()
	end

	animation:Destroy()
end

local function setupNurse(nurse: Model)
	-- Find proximity prompt
	local prompt = nurse:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		warn("Nurse missing ProximityPrompt:", nurse.Name)
		return
	end

	-- Connect to proximity prompt
	prompt.Triggered:Connect(function(playerWhoTriggered)
		if playerWhoTriggered == player then
			spawnMonsterAtNurse(nurse)
		end
	end)
end

-- Setup all existing nurses
for _, nurse in ipairs(CollectionService:GetTagged("Nurse")) do
	task.spawn(function()
		setupNurse(nurse)
	end)
end

-- Setup nurses added in the future
CollectionService:GetInstanceAddedSignal("Nurse"):Connect(setupNurse)

-- Listen for monster spawned event from server
MonsterSpawned.OnClientEvent:Connect(function(monsterModel: Model)
	if not monsterModel or not monsterModel.Parent then
		warn("Invalid monster model received")
		return
	end

	-- Wait a moment for monster to be fully loaded
	task.wait(0.3)

	-- Switch camera to follow the spawned monster
	playSideFollow(monsterModel, {
		fov = 70
	})

	-- Restore camera after 3 seconds
	task.wait(3)

	-- Stop camera effect
	state.stopToken += 1
	if state.connection then
		state.connection:Disconnect()
		state.connection = nil
	end
	state.active = false
	tweenFOV(70, 0.2)
	setCameraScriptable(false)
end)

-- // EVENT LISTENERS \\ --

EvFocus.OnClientEvent:Connect(function(target: Instance, trainingName: string, payload: table?)
	local p = payload or {}
	local mode = p.mode or "follow" -- Default to side-follow if no mode is specified

	if mode == "orbit" then
		playOrbit(target, p)
	elseif mode == "follow" then
		playSideFollow(target, p)
	else -- Handle as a simple static shot
		local token = startEffect()
		local cf = getTargetCFrame(target)
		camera.CFrame = getLookCFrame(cf.Position + Vector3.new(-8, 6, -8), cf.Position)
		tweenFOV(p.fov or 70, 0.2)
	end
end)

EvFail.OnClientEvent:Connect(function(target: Instance, payload: table?)
	playFailCinematic(target, payload or {})
end)

EvRestore.OnClientEvent:Connect(function()
	state.stopToken += 1
	if state.connection then
		state.connection:Disconnect()
		state.connection = nil
	end
	state.active = false

	tweenFOV(70, 0.2)
	setCameraScriptable(false)
end)