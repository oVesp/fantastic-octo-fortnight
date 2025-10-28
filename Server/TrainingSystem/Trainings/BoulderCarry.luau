--BoulderCarry.lua

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local Utils = require(script.Parent.Parent.Utils)
local AnimationHandler = require(SSS.Main:WaitForChild("AnimationHandler"))

local Training = {}
Training.Name = "BoulderCarry"
Training.Duration = 20
Training.BaseBonus = { Defense = 20 }

-- util: garantir Animator + parar quaisquer animações tocando
local function stopAllAnimations(model: Model)
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		pcall(function() track:Stop(0.05) end)
	end
end

-- pega a anima "[RaceName] Death"
local function getDeathAnimationId(monster: Model)
	local race = monster:GetAttribute("Race")
	if not race then return nil end
	local assets = RS:FindFirstChild("Assets")
	local animRoot = assets and assets:FindFirstChild("Animations")
	if not animRoot then return nil end
	local raceFolder = animRoot:FindFirstChild(race)
	if not raceFolder then
		for _, f in ipairs(animRoot:GetChildren()) do
			if f:IsA("Folder") and f.Name:lower() == tostring(race):lower() then
				raceFolder = f; break
			end
		end
	end
	if not raceFolder then return nil end
	for _, a in ipairs(raceFolder:GetChildren()) do
		if a:IsA("Animation") and a.Name:lower():find("death") then
			return a.AnimationId
		end
	end
	return nil
end

-- util para extrair índice numérico de "Node1", "Node2", "Node10", etc.
local function nodeIndex(part: BasePart)
	local n = tonumber(string.match(part.Name or "", "(%d+)$"))
	return n or math.huge
end

-- calcula fração [0..1] percorrida do startPos até targetPos
local function travelFraction(current: Vector3, startPos: Vector3, targetPos: Vector3)
	local total = (targetPos - startPos).Magnitude
	if total <= 0.001 then return 1 end
	local done = (current - startPos).Magnitude
	return math.clamp(done / total, 0, 1)
end

-- falha no meio: para tudo, anima, teleporta, reseta boulder
local function handleFailure(monster: Model, ctx, rope: RopeConstraint?, boulderModel: Model, boulderBase: BasePart?, originalPivot: CFrame, originalAnchored: table)
	-- 1) parar movemento imediatamente
	local hum = monster:FindFirstChildOfClass("Humanoid")
	local root = monster.HumanoidRootPart
	_G.EFFECTS.PlaySound("Fail", {Where = root})

	local prevWalkSpeed
	if hum then
		prevWalkSpeed = hum.WalkSpeed
		hum:MoveTo(root and root.Position or monster:GetPivot().Position)
		hum.WalkSpeed = 0
		hum.AutoRotate = false
	end

	-- 2) limpa animações pendentes antes de tocar a de falha
	stopAllAnimations(monster)

	-- 3) solta rope e deixa a boulder “deslizar”
	Utils.DetachRope(monster)
	if boulderBase then
		boulderBase.Anchored = false
	end
	local ownerId = monster:GetAttribute("OwnerId")
	local remotes = RS:WaitForChild("Remotes")
	local EvFail = remotes:WaitForChild("TrainingCameraFail")

	-- Duração pretendida = duração estimada da anima (com fallback) + delay de quase-sucesso
	local estimatedLen = 1.2
	local deathId = getDeathAnimationId(monster)
	if deathId then
		-- vamos pedir p/ cliente rodar a cine por ~estimatedLen + delay
	end
	local delayAfterAnim = (ctx and tonumber(ctx.FailTeleportDelay)) or 0.35
	local runFor = estimatedLen + delayAfterAnim

	EvFail:FireClient(Players:GetPlayerByUserId(ownerId), monster, {
		mode = "death",
		duration = runFor,         -- quanto tempo a órbita/zoom dura
		radiusStart = 12,          -- raio inicial da órbita
		radiusEnd   = 9,           -- zoom leve (raio diminui)
		heightStart = 6,           -- altura inicial
		heightEnd   = 7.5,         -- sobe um pouco
		angularSpeedDeg = 55,      -- graus/seg para girar
		fovStart = 70,             -- FOV inicial
		fovEnd   = 62,             -- FOV final (zoom leve)
		easeTime = 0.25,           -- tween inicial
	})

	---- Agora toca a anima (bloqueante)
	--local animLen = 0
	--if deathId then
	--	animLen = AnimationHandler:PlayCastOnce(monster, deathId, { fallback = estimatedLen, replace = true })
	--else
	--	task.wait(estimatedLen)
	--end

	---- pequeno delay “quase sucesso”
	--task.wait(delayAfterAnim)

	

	-- 4) toca anima “Death” e espera terminar
	local deathId = getDeathAnimationId(monster)
	if deathId then
		AnimationHandler:PlayCastOnce(monster, deathId, { fallback = 1.2, replace = true })
	end

	-- 5) pequeno delay “quase sucesso” antes do teleport
	task.wait((ctx and tonumber(ctx.FailTeleportDelay)) or 0.35)

	-- 6) teleporta de volta (Start > dono)
	local ownerId = monster:GetAttribute("OwnerId")
	if ctx and ctx.Start and monster.PrimaryPart then
		monster:PivotTo(ctx.Start.CFrame + Vector3.new(0, 2, 0))
	elseif _G.FUNCTIONS and _G.FUNCTIONS.teleportToOwner then
		_G.FUNCTIONS:teleportToOwner(monster, ownerId)
	end

	-- 7) reseta boulder ao pivot original (fim do treino por falha)
	if originalAnchored and originalPivot and boulderModel then
		for part, _ in pairs(originalAnchored) do
			if part and part:IsA("BasePart") then
				part.AssemblyLinearVelocity = Vector3.zero
				part.AssemblyAngularVelocity = Vector3.zero
				part.Anchored = true
			end
		end
		boulderModel:PivotTo(originalPivot)
		for part, wasAnchored in pairs(originalAnchored) do
			if part and part:IsA("BasePart") then
				part.Anchored = wasAnchored
			end
		end
	end

	-- 8) segurança: para qualquer track e libera movimento
	stopAllAnimations(monster)
	boulderModel:Destroy()
	if hum then
		hum.WalkSpeed = prevWalkSpeed or 16
		hum.AutoRotate = true
	end

	return { success = false, reason = "boulder_mid_fail" }
end

-- ctx: { Start = BasePart, End = BasePart, NodesFolder = Folder, Boulder = Model, FailTeleportDelay? = number }
function Training:Start(monster: Model, player: Player, ctx)
	assert(ctx and ctx.Boulder and ctx.NodesFolder, "BoulderCarry: missing Boulder/NodesFolder in ctx")

	-- limpa qualquer anima pendente da tentativa anterior
	stopAllAnimations(monster)
	ctx.Boulder = ctx.Boulder:Clone()
	ctx.Boulder.Parent = workspace
	-- Teleporta para o Start se existir
	if ctx.Start and monster.PrimaryPart then
		monster:PivotTo(ctx.Start.CFrame + Vector3.new(0, 2, 0))
		ctx.Boulder:PivotTo(monster:GetPivot() + Vector3.new(-10,0,0))
	end
	
	-- Captura pivot/anchor originais (para resetar no fim — sucesso ou falha)
	local originalPivot = ctx.Boulder:GetPivot()
	
	local originalAnchored = {}
	for _, p in ipairs(ctx.Boulder:GetDescendants()) do
		if p:IsA("BasePart") then originalAnchored[p] = p.Anchored end
	end
	local base = ctx.Boulder:FindFirstChild("Base") or ctx.Boulder:FindFirstChildWhichIsA("BasePart")
	assert(base, "BoulderCarry: Boulder missing Base Part")
	local att = base:FindFirstChildWhichIsA("Attachment")
	assert(att, "BoulderCarry: Base missing Attachment")

	-- Anexa rope
	local rope = Utils.AttachRope(monster, att)

	

	-- Path
	local hum = monster:FindFirstChildOfClass("Humanoid")
	local success = true

	-- Ordena nodes
	local nodes = {}
	for _, n in ipairs(ctx.NodesFolder:GetChildren()) do
		if n:IsA("BasePart") then table.insert(nodes, n) end
	end
	table.sort(nodes, function(a,b) return nodeIndex(a) < nodeIndex(b) end)

	-- Pré-rolagem: esta tentativa vai falhar?
	local willFailAttempt = (math.random() < 0.25)
	
	local halfwayIndex = math.max(1, math.floor(#nodes / 2))
	
	-- Config via ctx (opcionais)
	local failAtIndex   = tonumber(ctx.FailAtIndex)   -- perna onde falha: entre nodes[failAtIndex] -> nodes[failAtIndex+1]
	local failAtFraction= tonumber(ctx.FailAtFraction) -- fração dentro da perna [0..1]
	if not failAtIndex then
		failAtIndex = math.max(1, math.floor(#nodes / 2)) -- default: “meio” da lista
	end
	if not failAtFraction or failAtFraction < 0 or failAtFraction > 1 then
		failAtFraction = 0.5 -- default: 50% do deslocamento da perna
	end

	-- Pré-rolagem da tentativa
	local willFailAttempt = (math.random() < 0.25) -- enquanto não migramos p/ Bond/Discipline

	local hrp = monster.PrimaryPart or monster:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then
		return handleFailure(monster, ctx, rope, ctx.Boulder, base, originalPivot, originalAnchored)
	end

	-- Humanoid state management
	local function ensureMovableState(monster: Model): boolean
		local humanoid = monster:FindFirstChildOfClass("Humanoid")
		if not humanoid then return false end

		-- Reset if in unwanted states
		local badStates = {
			Enum.HumanoidStateType.Physics,
			Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.GettingUp,
			Enum.HumanoidStateType.Freefall
		}

		local currentState = humanoid:GetState()
		for _, badState in ipairs(badStates) do
			if currentState == badState then
				humanoid:ChangeState(Enum.HumanoidStateType.Running)
				task.wait(0.1)
				break
			end
		end

		return humanoid:GetState() == Enum.HumanoidStateType.Running
	end

	-- Import SimplePath
	local SimplePath = require(game.ReplicatedStorage.Modules.Movement.SimplePath)

	-- Improved pathfinding movement with SimplePath for boulder carrying
	local function moveToWithSimplePathBoulder(monster: Model, targetPos: Vector3): boolean
		local humanoid = monster:FindFirstChildOfClass("Humanoid")
		if not humanoid then 
			warn("Monster has no humanoid for pathfinding")
			return false 
		end

		-- Ensure humanoid is in correct state
		if not ensureMovableState(monster) then
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
			task.wait(0.2)
		end

		-- Use slower speed for boulder carrying
		local originalSpeed = humanoid.WalkSpeed
		humanoid.WalkSpeed = 10  -- Fixed slower speed for boulder

		local path = SimplePath.new(monster)
		path.WaypointReachedDistance = 5.0  -- Increased tolerance for boulder
		path.PathMinDistance = 4
		path.PathMaxDistance = 200

		local reached = false
		local pathError = false

		local reachedConnection = path.Reached:Connect(function()
			reached = true
		end)

		local errorConnection = path.Error:Connect(function(errorType)
			pathError = true
			warn("BoulderCarry pathfinding error: " .. tostring(errorType))
		end)

		local success = path:Run(targetPos)
		if not success then
			reachedConnection:Disconnect()
			errorConnection:Disconnect()
			path:Destroy()
			humanoid.WalkSpeed = originalSpeed
			return false
		end

		local startTime = tick()
		local currentPos = monster.PrimaryPart.Position
		local dist = (targetPos - currentPos).Magnitude

		-- Very generous timeout calculation for boulder carrying
		local baseTimeout = (dist / 10) * 6.0 + 15.0  -- Much longer for boulder
		local timeout = math.clamp(baseTimeout, 15, 120)  -- 15-120 second timeouts

		local lastMovementCheck = tick()
		local lastKnownPos = currentPos
		local stuckAttempts = 0
		local maxStuckAttempts = 3

		while tick() - startTime < timeout and not reached and not pathError do
			RunService.Heartbeat:Wait()

			-- Check if humanoid is stuck in bad state
			local state = humanoid:GetState()
			if state == Enum.HumanoidStateType.GettingUp or state == Enum.HumanoidStateType.FallingDown then
				humanoid:ChangeState(Enum.HumanoidStateType.Running)
				task.wait(0.1)
			end

			-- Check if we're actually moving
			local newPos = monster.PrimaryPart.Position
			local movedDistance = (newPos - lastKnownPos).Magnitude

			-- If stuck for more than 5 seconds, try to recover
			if tick() - lastMovementCheck > 5.0 and movedDistance < 1.5 then
				stuckAttempts += 1
				warn("BoulderCarry: Monster appears stuck, attempt " .. stuckAttempts)

				if stuckAttempts >= maxStuckAttempts then
					warn("BoulderCarry: Max stuck recovery attempts reached")
					pathError = true
					break
				end

				-- Cancel current path and restart
				path:Stop()
				task.wait(0.5)

				-- Reset humanoid state
				humanoid:MoveTo(monster.PrimaryPart.Position)
				task.wait(0.3)

				-- Retry with fresh path
				local retryPath = SimplePath.new(monster)
				retryPath.WaypointReachedDistance = 5.0
				retryPath.PathMinDistance = 4
				retryPath.PathMaxDistance = 200

				local retrySuccess = retryPath:Run(targetPos)
				if retrySuccess then
					path = retryPath
					lastMovementCheck = tick()
					warn("BoulderCarry: Recovery path started")
				else
					warn("BoulderCarry: Recovery path failed")
					pathError = true
					break
				end
			elseif movedDistance > 0.3 then
				-- We're moving, reset the timer and attempts
				lastMovementCheck = tick()
				lastKnownPos = newPos
				stuckAttempts = 0
			end
		end

		reachedConnection:Disconnect()
		errorConnection:Disconnect()
		path:Destroy()
		humanoid.WalkSpeed = originalSpeed

		return reached
	end

	-- Debug info at start
	print("BoulderCarry: Starting movement with " .. #nodes .. " nodes")
	print("Monster WalkSpeed: " .. (hum and hum.WalkSpeed or "No humanoid"))
	print("Monster State: " .. (hum and tostring(hum:GetState()) or "No humanoid"))

	-- Store original speed and set boulder speed
	local originalSpeed = hum.WalkSpeed
	hum.WalkSpeed = 10  -- Slow speed for boulder carrying

	-- Main movement loop using SimplePath
	for idx, node in ipairs(nodes) do
		local targetPos = node.Position
		local attempts = 0
		local maxAttempts = 2  -- Fewer attempts but longer timeouts
		local reached = false

		print("BoulderCarry: Moving to node " .. idx .. " at " .. tostring(targetPos))

		-- Get start position for this leg for failure calculation
		local startPos = hrp.Position

		repeat
			attempts += 1

			-- Ensure humanoid is ready to move
			if not ensureMovableState(monster) then
				hum:ChangeState(Enum.HumanoidStateType.Running)
				task.wait(0.3)
			end

			-- Use SimplePath for movement with boulder-specific settings
			reached = moveToWithSimplePathBoulder(monster, targetPos)

			if not reached then
				warn("BoulderCarry: Failed to reach node " .. idx .. " on attempt " .. attempts)

				if attempts >= maxAttempts then
					-- Final attempt failed
					hum.WalkSpeed = originalSpeed  -- Restore speed before failure
					return handleFailure(monster, ctx, rope, ctx.Boulder, base, originalPivot, originalAnchored)
				end

				-- Brief pause and recovery before retry
				task.wait(1.0)
				hum:MoveTo(hrp.Position)  -- Reset movement
				task.wait(0.5)
			end

		until reached or attempts >= maxAttempts

		-- Check for mid-movement failure condition (during the movement, not after)
		if willFailAttempt and idx == failAtIndex then
			print("BoulderCarry: Triggering mid-movement failure at node " .. idx)
			hum.WalkSpeed = originalSpeed  -- Restore speed before failure
			return handleFailure(monster, ctx, rope, ctx.Boulder, base, originalPivot, originalAnchored)
		end

		-- Small pause between nodes to stabilize physics
		if idx < #nodes then
			task.wait(0.5)
		end
	end

	-- Restore original speed
	hum.WalkSpeed = originalSpeed

	-- SUCESSO: solta rope, teleporta para End e reseta boulder
	Utils.DetachRope(monster)
	base.Anchored = false

	if ctx.End and monster.PrimaryPart then
		monster:PivotTo(ctx.End.CFrame + Vector3.new(0, 0, -5))
	end

	-- reset da boulder (como no sucesso anterior)
	for part, _ in pairs(originalAnchored) do
		if part and part:IsA("BasePart") then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
			part.Anchored = true
		end
	end

	ctx.Boulder:Destroy()

	-- Use the existing teleport function
	if _G.FUNCTIONS and _G.FUNCTIONS.teleportToOwner then
		_G.FUNCTIONS:teleportToOwner(monster, player.UserId)
	elseif ctx.Start and monster.PrimaryPart then
		-- Fallback teleport
		monster:PivotTo(ctx.Start.CFrame + Vector3.new(0, 2, 0))
	end

	print("BoulderCarry: Training completed successfully")
	return { success = true }
end


return Training
