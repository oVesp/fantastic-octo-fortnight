--[[
	@ Módulo Movement
	@ Autor: Gemini & <Seu Nome>
	@ Data: 12/10/2025
	
	Este módulo gerencia todo o movimento dos monstros, usando SimplePath
	para pathfinding em situações fora de combate.
--]]

local Movement = {}

local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")

-- Import SimplePath module
local SimplePath = require(script:WaitForChild("SimplePath")) -- Adjust path as needed

local activePaths = {} -- Armazena os dados dos paths ativos. Chave: Model do Monstro.
local facingLoops = {} -- Armazena os loops de facing ativos
local originalWalkSpeeds = {} -- Armazena WalkSpeeds originais

local ORBIT_RADIUS = 8 -- Distância que o monstro tentará manter do jogador.
local ORBIT_HEIGHT = 2 -- Altura em relação à cabeça do jogador.
local UPDATE_INTERVAL = 0.5 -- Intervalo entre atualizações de pathfinding (segundos)
local IDLE_DISTANCE_OFFSET = 5 -- Distância que o monstro mantém do jogador parado.

-- Store original walk speed
local function storeOriginalWalkSpeed(monster)
	local humanoid = monster:FindFirstChildOfClass("Humanoid")
	if humanoid and not originalWalkSpeeds[monster] then
		originalWalkSpeeds[monster] = humanoid.WalkSpeed
	end
end

-- Restore original walk speed
local function restoreOriginalWalkSpeed(monster)
	local humanoid = monster:FindFirstChildOfClass("Humanoid")
	if humanoid and originalWalkSpeeds[monster] then
		humanoid.WalkSpeed = originalWalkSpeeds[monster]
		originalWalkSpeeds[monster] = nil
	end
end

-- Função para criar e configurar SimplePath
local function createSimplePath(monster)
	local humanoid = monster:FindFirstChildOfClass("Humanoid")
	local rootPart = monster.PrimaryPart or monster:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart then
		warn("Monster missing humanoid or root part: " .. monster.Name)
		return nil
	end

	-- Configure SimplePath
	local path = SimplePath.new(monster)

	-- Configure path parameters for smoother movement
	path.WaypointReachedDistance = 2.5
	path.PathMinDistance = 3
	path.PathMaxDistance = 150

	return path
end

-- Função para calcular posição desejada baseada no orbit
local function calculateDesiredPosition(target, monster, isCombat)
	local targetHead = target:FindFirstChild("Head") or target.PrimaryPart
	if not targetHead then return nil end

	local orbitRadius = ORBIT_RADIUS
	local orbitHeight = ORBIT_HEIGHT

	if isCombat then
		orbitRadius = 6
		orbitHeight = 3
	end

	local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
	local isTargetIdle = not targetHumanoid or targetHumanoid.MoveDirection.Magnitude < 0.1

	if isTargetIdle then
		-- Se o alvo está parado, manter distância fixa
		return targetHead.CFrame * CFrame.new(0, 0, IDLE_DISTANCE_OFFSET).Position
	else
		-- Se o alvo está se movendo, orbitar suavemente
		local monsterPos = monster.PrimaryPart.Position
		local targetToMonsterVec = (monsterPos - targetHead.Position) * Vector3.new(1, 0, 1)
		local targetLookVec = targetHead.CFrame.LookVector * Vector3.new(1, 0, 1)
		local targetAngleRad = math.atan2(targetToMonsterVec.X, targetToMonsterVec.Z) - math.atan2(targetLookVec.X, targetLookVec.Z)

		-- Usar ângulo atual ou calcular novo
		local currentAngle = activePaths[monster] and activePaths[monster].currentAngle or math.deg(targetAngleRad)

		-- Suavizar transição de ângulo
		local smoothFactor = isCombat and 0.1 or 0.08
		currentAngle = currentAngle + (math.deg(targetAngleRad) - currentAngle) * smoothFactor

		if activePaths[monster] then
			activePaths[monster].currentAngle = currentAngle
		end

		local desiredCFrame = targetHead.CFrame 
			* CFrame.Angles(0, math.rad(currentAngle), 0)
			* CFrame.new(0, orbitHeight, -orbitRadius)

		return desiredCFrame.Position
	end
end

-- FIXED: Improved state checking
local function isInCombatState(monster)
	if not _G.STATES then return false end
	return _G.STATES:IsInState(monster, "InCombat")
end

-- FIXED: Completely safe path stopping - don't call Stop() at all
function Movement.StopFollowing(monster)
	if not monster or not activePaths[monster] then return end

	local pathData = activePaths[monster]

	-- Clean up connections first
	if pathData.connection then
		pathData.connection:Disconnect()
		pathData.connection = nil
	end

	-- FIX: Don't call path:Stop() at all - just destroy the path
	-- This avoids the "Attempt to run Path:Stop() in idle state" error
	if pathData.path then
		-- Simply destroy the path without stopping it
		local success, err = pcall(function()
			pathData.path:Destroy()
		end)

		if not success then
			-- If destroy fails, just log it but don't worry
			print("Path cleanup completed for " .. monster.Name)
		end
	end

	-- Restore walk speed
	restoreOriginalWalkSpeed(monster)

	-- Stop any current movement
	local humanoid = monster:FindFirstChildOfClass("Humanoid")
	if humanoid and monster.PrimaryPart then
		humanoid:MoveTo(monster.PrimaryPart.Position)
	end

	activePaths[monster] = nil
	print("Stopped following for " .. monster.Name)
end

function Movement.StartCombatMovement(monster, target, isCombat)
	if not monster or not target then return end

	-- For player monsters, use the path system
	if monster:GetAttribute("OwnerId") then
		Movement.StartFollowing(monster, target, isCombat)
	else
		-- For enemy monsters, use direct movement
		local humanoid = monster:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local targetPosition = target.PrimaryPart.Position
			humanoid:MoveTo(targetPosition)
		end
	end
end

-- Função para atualizar path individual
local function updatePathForMonster(monster, dt)
	local pathData = activePaths[monster]
	if not pathData then return end

	-- Check if monster or target is no longer valid
	if not monster.Parent or not pathData.target or not pathData.target.Parent then
		Movement.StopFollowing(monster)
		return
	end

	-- Check if we should update the path (throttle updates)
	pathData.lastUpdate = (pathData.lastUpdate or 0) + dt
	if pathData.lastUpdate < UPDATE_INTERVAL then
		return
	end

	pathData.lastUpdate = 0

	-- Only update path if monster is in Following state and not stunned
	if not _G.STATES:IsInState(monster, "Following") or _G.STATES:IsStunned(monster) then
		return
	end

	-- Calculate desired position
	local desiredPosition = calculateDesiredPosition(pathData.target, monster, pathData.isCombat)
	if not desiredPosition then
		return
	end

	-- Move to the calculated position using SimplePath
	local success, err = pcall(function()
		-- Check if path still exists and is valid
		if pathData.path and typeof(pathData.path.Run) == "function" then
			pathData.path:Run(desiredPosition)
		else
			warn("Invalid path for " .. monster.Name .. ", recreating...")
			-- Recreate the path if it's invalid
			local newPath = createSimplePath(monster)
			if newPath then
				pathData.path = newPath
				pathData.path:Run(desiredPosition)
			else
				Movement.StopFollowing(monster)
			end
		end
	end)

	if not success then
		warn("Pathfinding error for " .. monster.Name .. ": " .. tostring(err))
		-- If path is broken, stop following
		Movement.StopFollowing(monster)
	end
end

function Movement.StartFollowing(monster, target, isCombat)
	if not monster or not target then return end

	-- Don't start following if in combat state and this isn't a combat movement
	if isInCombatState(monster) and not isCombat then
		return
	end

	-- Stop any existing following
	if activePaths[monster] then
		Movement.StopFollowing(monster)
	end

	-- Create new path
	local path = createSimplePath(monster)
	if not path then return end

	-- Store original walk speed
	storeOriginalWalkSpeed(monster)

	-- Set up path data
	activePaths[monster] = {
		path = path,
		target = target,
		monster = monster,
		isCombat = isCombat or false,
		currentAngle = 0,
		lastUpdate = 0,
		connection = nil
	}

	-- Set up path connection for completion/blocked events
	activePaths[monster].connection = path.Reached:Connect(function()
		-- Path completed, we'll update again on the next interval
	end)

	print("Started SimplePath following for " .. monster.Name)

	-- Force immediate first update
	updatePathForMonster(monster, 0)
end



-- FIXED: Simple and reliable facing function
function Movement.FaceTargetDuring(monster, target, duration)
	if not monster or not target then return end

	-- Stop any existing facing
	Movement.StopFacing(monster)

	local hrp = monster:FindFirstChild("HumanoidRootPart")
	local targetHrp = target:FindFirstChild("HumanoidRootPart")

	if not hrp or not targetHrp then return end

	local connection
	local startTime = tick()

	connection = RunService.Heartbeat:Connect(function()
		if not monster.Parent or not target.Parent then
			if connection then connection:Disconnect() end
			return
		end

		if tick() - startTime >= duration then
			if connection then connection:Disconnect() end
			return
		end

		-- Simple and direct facing
		local monsterPos = hrp.Position
		local targetPos = targetHrp.Position

		-- Only rotate on Y axis
		local lookAt = CFrame.lookAt(
			monsterPos,
			Vector3.new(targetPos.X, monsterPos.Y, targetPos.Z)
		)

		hrp.CFrame = lookAt
	end)

	-- Store the connection for cleanup
	facingLoops[monster] = connection

	-- Auto cleanup after duration
	task.delay(duration, function()
		if connection and connection.Connected then
			connection:Disconnect()
		end
		facingLoops[monster] = nil
	end)
end

-- Stop facing for a monster
function Movement.StopFacing(monster)
	local connection = facingLoops[monster]
	if connection then
		connection:Disconnect()
		facingLoops[monster] = nil
	end
end

function Movement.ChangeTarget(monster, newTarget, isCombat)
	if not monster or not activePaths[monster] then return end

	activePaths[monster].target = newTarget
	activePaths[monster].isCombat = isCombat or false
end

function Movement.GetPathData(monster)
	return activePaths[monster]
end

-- Aproxima até entrar no "desiredRange" (>= minRange do golpe)
function Movement.StartCombatChase(attacker, target, desiredRange)
	if not attacker or not target or not attacker.Parent or not target.Parent then return end
	local hrpA = attacker:FindFirstChild("HumanoidRootPart")
	local hrpT = target:FindFirstChild("HumanoidRootPart")
	local humA = attacker:FindFirstChildOfClass("Humanoid")
	if not (hrpA and hrpT and humA) then return end

	desiredRange = desiredRange or 6
	local dir = (hrpT.Position - hrpA.Position)
	local dist = dir.Magnitude
	local goal = hrpT.Position

	-- Para fora do "ponto alvo": para na borda do desiredRange
	if dist > desiredRange + 0.5 then
		local unit = dir.Unit
		goal = hrpT.Position - unit * (desiredRange * 0.8)
	end

	humA:MoveTo(goal)
end

-- Recuo direto do alvo por "distance"
function Movement.RetreatFrom(attacker, target, distance)
	if not attacker or not target then return end
	distance = distance or 12
	local hrpA = attacker:FindFirstChild("HumanoidRootPart")
	local hrpT = target:FindFirstChild("HumanoidRootPart")
	local humA = attacker:FindFirstChildOfClass("Humanoid")
	if not (hrpA and hrpT and humA) then return end

	local away = (hrpA.Position - hrpT.Position).Unit
	humA:MoveTo(hrpA.Position + away * distance)
end

-- Strafe/Reposicionar — orbita lateralmente mantendo raio aproximado
function Movement.StrafeAround(attacker, target, radius)
	if not attacker or not target then return end
	radius = radius or 10
	local hrpA = attacker:FindFirstChild("HumanoidRootPart")
	local hrpT = target:FindFirstChild("HumanoidRootPart")
	local humA = attacker:FindFirstChildOfClass("Humanoid")
	if not (hrpA and hrpT and humA) then return end

	local toTarget = (hrpT.Position - hrpA.Position)
	local side = toTarget:Cross(Vector3.new(0,1,0)).Unit
	if math.random() > 0.5 then side = -side end

	local goal = hrpT.Position + side * radius
	humA:MoveTo(goal)
end

-- Parar movimentação de combate
function Movement.StopCombatMovement(attacker)
	if not attacker then return end
	local humA = attacker:FindFirstChildOfClass("Humanoid")
	if humA then
		humA:MoveTo(attacker.PrimaryPart and attacker.PrimaryPart.Position or attacker:GetPivot().Position)
	end
end

-- NEW: Force restore walk speed (for CombatManager to call)
function Movement.ForceRestoreWalkSpeed(monster)
	restoreOriginalWalkSpeed(monster)
end

-- NEW: Check if monster is currently following
function Movement.IsFollowing(monster)
	return activePaths[monster] ~= nil
end

-- Loop principal de atualização
local function updatePaths(dt)
	for monster, pathData in pairs(activePaths) do
		updatePathForMonster(monster, dt)
	end
end

-- Conecta o loop de atualização
RunService.Heartbeat:Connect(updatePaths)

return Movement