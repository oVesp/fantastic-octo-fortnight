-- ServerScriptService>Main>TrainingSystem>Trainings>WhackAMole.lua

local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Utils = require(script.Parent.Parent.Utils)
local AnimationHandler = require(game.ServerScriptService.Main:WaitForChild("AnimationHandler"))
local AnimationManager = require(RS:WaitForChild("Modules"):WaitForChild("AnimationManager"))

-- Remotes do TrainingSystem
local Remotes = RS:WaitForChild("Remotes")
local EvFocus   = Remotes:WaitForChild("TrainingCameraFocus")
local EvRestore = Remotes:WaitForChild("TrainingCameraRestore")

local Training = {}
Training.Name = "WhackAMole"
Training.Duration = 10
Training.BaseBonus = { Skill = 20 }

-- === Enhanced Helpers ===

local function getCastAnimationData(monster: Model)
	local race = monster:GetAttribute("Race")
	if not race then return nil end
	return AnimationManager:GetCastAnimation(race)
end

local function playCastAnimation(monster: Model)
	local castData = getCastAnimationData(monster)
	if castData and castData.AnimationId then
		local success = pcall(function()
			AnimationHandler:PlayCastOnce(monster, castData.AnimationId, { 
				fallback = castData.Duration or 0.6, 
				replace = false 
			})
		end)
		if success then
			return castData.Duration or 0.6
		end
	end
	-- Fallback to simple wait
	task.wait(0.6)
	return 0.6
end

local function createClone(original: Model): Model
	local clone = original:Clone()

	-- Enhanced cleanup - remove scripts and unwanted components
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		elseif descendant:IsA("Humanoid") then
			-- Configure humanoid for mole behavior
			descendant.WalkSpeed = 0
			descendant.JumpPower = 0
			descendant.AutoRotate = false
		end
	end

	-- Make all parts non-collidable and configure for smooth movement
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Anchored = false
			part.Massless = true
			part.CastShadow = false -- Reduce visual clutter
		end
	end

	return clone
end

local function popUpClone(clone: Model, spawnPart: BasePart, duration: number)
	local hrp = clone:FindFirstChild("HumanoidRootPart") or clone.PrimaryPart
	if not hrp then return nil end

	-- Start deep underground to ensure no sticking
	local startPos = spawnPart.Position - Vector3.new(0, 15, 0)
	-- End position - nice high pop-up
	local endPos = spawnPart.Position + Vector3.new(0,3,0)

	clone:PivotTo(CFrame.new(startPos))
	clone.Parent = Workspace

	-- Enhanced tween with better easing
	local tweenInfo = TweenInfo.new(
		duration * 0.5, 
		Enum.EasingStyle.Back, 
		Enum.EasingDirection.InOut, 
		0, -- RepeatCount
		false, -- Reverses
		0 -- Delay
	)
	local tween = TweenService:Create(hrp, tweenInfo, {Position = endPos})
	tween:Play()

	return tween
end

local function popDownClone(clone: Model, spawnPart: BasePart, duration: number)
	local hrp = clone:FindFirstChild("HumanoidRootPart") or clone.PrimaryPart
	if not hrp then return end

	local startPos = hrp.Position
	-- Go very deep to ensure complete disappearance
	local endPos = spawnPart.Position - Vector3.new(0, 20, 0)

	local tweenInfo = TweenInfo.new(
		duration * 0.5, 
		Enum.EasingStyle.Back, 
		Enum.EasingDirection.In
	)
	local tween = TweenService:Create(hrp, tweenInfo, {Position = endPos})
	tween:Play()
	clone:Destroy()
	-- Return the tween so we can wait for it
	return tween
end

local function calculateDirectionOffset(monsterPos: Vector3, targetPos: Vector3)
	local direction = (targetPos - monsterPos).Unit
	local yawOffset = math.deg(math.atan2(direction.X, direction.Z))

	-- Calculate distance for camera radius adjustment
	local distance = (targetPos - monsterPos).Magnitude
	local optimalRadius = math.clamp(distance * 1.5, 8, 15)

	return yawOffset, optimalRadius
end

local function withHumanoidFrozen(monster: Model, fn)
	local hum = monster:FindFirstChildOfClass("Humanoid")
	local root = monster:FindFirstChild("HumanoidRootPart") or monster.PrimaryPart
	local prevWS, prevAuto
	if hum and root then
		prevWS, prevAuto = hum.WalkSpeed, hum.AutoRotate
		hum:MoveTo(root.Position)
		hum.WalkSpeed = 0
		hum.AutoRotate = false
	end

	local ok, err = pcall(fn)
	if not ok then warn("[WhackAMole] error:", err) end

	if hum then
		hum.WalkSpeed = prevWS or 16
		hum.AutoRotate = (prevAuto == nil) and true or prevAuto
	end
	return ok
end

-- === Enhanced START ===
function Training:Start(monster: Model, player: Player, ctx)
	assert(monster and player, "WhackAMole: missing monster/player")

	-- Get spawn points from Interactables
	local interactables = ctx.Interactables
	assert(interactables, "WhackAMole: missing Interactables in context")

	local spawnPoints = {}
	for i = 1, 6 do
		local spawnPart = interactables:FindFirstChild("Spawn" .. i)
		if spawnPart and spawnPart:IsA("BasePart") then
			table.insert(spawnPoints, spawnPart)
		end
	end

	assert(#spawnPoints > 0, "WhackAMole: no spawn points found")

	-- Create session folder
	local sessionFolder = Instance.new("Folder")
	sessionFolder.Name = "WhackAMole_Session"
	sessionFolder.Parent = Workspace

	-- Teleport monster to Start
	if ctx.Start and monster.PrimaryPart then
		monster:PivotTo(ctx.Start.CFrame + Vector3.new(0, 2, 0))
	end

	local skill = monster:GetAttribute("Skill") or 0
	local baseSuccessChance = 0.6
	local successChance = math.clamp(baseSuccessChance + (skill * 0.02), 0.3, 0.9)

	local successfulHits = 0
	local totalAttempts = 4

	withHumanoidFrozen(monster, function()
		for attempt = 1, totalAttempts do
			-- Select random spawn point
			local spawnIndex = math.random(1, #spawnPoints)
			local spawnPoint = spawnPoints[spawnIndex]

			-- Create clone and make it pop up
			local clone = createClone(monster)
			local popUpTween = popUpClone(clone, spawnPoint, 0.8)

			-- Calculate camera direction and parameters
			local monsterPos = monster:GetPivot().Position
			local clonePos = spawnPoint.Position
			local yawOffset, optimalRadius = calculateDirectionOffset(monsterPos, clonePos)

			-- Enhanced camera setup
			EvFocus:FireClient(player, monster, Training.Name, {
				mode = "orbit",
				duration = 2.0, -- Longer duration for smoother transition
				radius = optimalRadius,
				height = 7,
				yawOffsetDeg = yawOffset,
				fov = 68,
				target = "monster",
			})

			-- Wait for pop-up to complete
			if popUpTween then
				popUpTween.Completed:Wait()
			else
				task.wait(0.6)
			end

			-- Brief pause to see the mole before attacking
			task.wait(0.3)

			-- Play cast animation and get its duration
			local castDuration = playCastAnimation(monster)

			-- Determine success
			local success = math.random() < successChance

			if success then
				successfulHits += 1

				-- Enhanced success effects
				if _G.EFFECTS then
					_G.EFFECTS.PlaySound("DefaultImpact", { 
						Where = clone.PrimaryPart or spawnPoint,
						Volume = 0.8 
					})
					_G.EFFECTS.EmitterEffect({
						Name = "DefaultImpact", 
						Duration = 1.2,
						Position = CFrame.new(clone:GetPivot().Position),
						Size = 1.5 -- Slightly larger for whack effect
					})
					_G.EFFECTS.FovEffect({ 
						Fov = 60, 
						Start = 0.1, 
						Duration = 0.15 
					})
				end

				-- Wait for impact effects to fully play, THEN pop down
				task.wait(0.5)
				local popDownTween = popDownClone(clone, spawnPoint, 0.5)
				if popDownTween then
					popDownTween.Completed:Wait()
				end

			else
				-- Enhanced failure effects at a different spawn point
				local failSpawnIndex
				repeat
					failSpawnIndex = math.random(1, #spawnPoints)
				until failSpawnIndex ~= spawnIndex

				local failSpawnPoint = spawnPoints[failSpawnIndex]

				if _G.EFFECTS then
					_G.EFFECTS.PlaySound("Fail", { 
						Where = failSpawnPoint,
						Volume = 0.6 
					})
					_G.EFFECTS.EmitterEffect({
						Name = "Fail", 
						Duration = 1.5,
						Position = CFrame.new(failSpawnPoint.Position + Vector3.new(0, 4, 0))
					})
				end

				-- Wait for cast animation to fully complete, THEN pop down
				task.wait(castDuration + 0.2) -- Extra buffer after cast
				local popDownTween = popDownClone(clone, spawnPoint, 0.7)
				if popDownTween then
					popDownTween.Completed:Wait()
				end
			end

			-- Brief pause between attempts
			if attempt < totalAttempts then
				task.wait(0.5)
			end
		end
	end)

	-- Determine overall success
	local overallSuccess = successfulHits >= 3

	if overallSuccess then
		-- Success sequence
		if ctx.End and monster.PrimaryPart then
			monster:PivotTo(ctx.End.CFrame + Vector3.new(0, 2, 0))
		end

		if _G.EFFECTS and monster.PrimaryPart then
			_G.EFFECTS.PlaySound("Success", { 
				Where = monster.PrimaryPart,
				Volume = 0.7 
			})
		end

		-- Cleanup with delay
		task.delay(1.5, function() 
			if sessionFolder and sessionFolder.Parent then 
				sessionFolder:Destroy() 
			end 
		end)

		return { 
			success = true, 
			reason = "whack_success", 
			hits = successfulHits,
			total = totalAttempts 
		}
	else
		-- Enhanced failure sequence using _G.FUNCTIONS.playDeathFrozen
		local hum = monster:FindFirstChildOfClass("Humanoid")
		local root = monster:FindFirstChild("HumanoidRootPart") or monster.PrimaryPart

		if hum and root then
			hum:MoveTo(root.Position)
			hum.WalkSpeed = 0
			hum.AutoRotate = false
		end

		-- Failure sound
		if _G.EFFECTS and root then
			_G.EFFECTS.PlaySound("Fail", {Where = root})
		end

		-- Enhanced failure camera
		local camFailDuration = 2.0 -- Slightly longer for better effect
		local ownerId = monster:GetAttribute("OwnerId")
		local plr = ownerId and Players:GetPlayerByUserId(tonumber(ownerId)) or player

		if plr then
			local EvFail = Remotes:WaitForChild("TrainingCameraFail")
			EvFail:FireClient(plr, monster, {
				mode = "death",
				duration = camFailDuration,
				radiusStart = 14, 
				radiusEnd = 10,
				heightStart = 7, 
				heightEnd = 8,
				angularSpeedDeg = 45, -- Slower rotation for dramatic effect
				fovStart = 72, 
				fovEnd = 65,
				easeTime = 0.3,
			})
		end

		-- Use the enhanced playDeathFrozen from _G.FUNCTIONS
		_G.FUNCTIONS.playDeathFrozen(monster, 0.6, camFailDuration, { 
			fallbackLen = 1.5, 
			playFade = 0.15,
			stopFade = 0.2,
			block = false 
		})

		-- Wait for failure sequence
		task.wait(camFailDuration)

		-- Restore movement
		if hum then
			hum.WalkSpeed = 16
			hum.AutoRotate = true
		end

		-- Cleanup
		task.delay(1.0, function() 
			if sessionFolder and sessionFolder.Parent then 
				sessionFolder:Destroy() 
			end 
		end)

		return { 
			success = false, 
			reason = "whack_failed", 
			hits = successfulHits,
			total = totalAttempts 
		}
	end
end

return Training