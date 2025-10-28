local module = {}
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Import SimplePath module
local SimplePath = require(game.ReplicatedStorage.Modules.Movement.SimplePath)
-- Namespace de modos de treino
local Modes = {}
module.Modes = Modes  -- exporta se quiser acessar externamente

-- simple mapping; tweak to your economy/balance
local BONUS = {
	Sprint      = { Speed = 2 },
	Sparing     = { Strength = 1, Speed = 1, Defense = -1},
	Parrying    = { Defense = 1, Skill = 1, Strength = -1 },
	MindBend    = { Intelligence = 2 },
	LuckyBlocks   = function()
		return { Luck = math.random(-3,3) }
	end,
	RockSmash = { Strength = 2}, 
	BoulderCarry = { Defense = 2 },
	WhackAMole   = { Skill = 2 },
}

-- =========================
--  MODO: BoulderCarry
-- =========================
do
	local B = {}
	Modes.BoulderCarry = B

	-- storage privado por monstro para limpar depois
	local activeLinks = {} :: {[Model]: {constraints: {Instance}, tempAttachments: {Attachment}}}

	local function parseVector3(str)
		if typeof(str) == "Vector3" then return str end
		if typeof(str) ~= "string" then return nil end
		local x,y,z = string.match(str, "([^,]+),([^,]+),([^,]+)")
		x,y,z = tonumber(x), tonumber(y), tonumber(z)
		if x and y and z then return Vector3.new(x,y,z) end
		return nil
	end

	local function getAttrNum(obj: Instance, key: string, default: number?)
		local v = obj:GetAttribute(key)
		if typeof(v) == "number" then return v end
		return default
	end

	local function getAttrBool(obj: Instance, key: string, default: boolean?)
		local v = obj:GetAttribute(key)
		if typeof(v) == "boolean" then return v end
		return default
	end

	local function getAttrStr(obj: Instance, key: string, default: string?)
		local v = obj:GetAttribute(key)
		if typeof(v) == "string" then return v end
		return default
	end

	local function toConstraint(item: Instance, linkType: string): Instance
		if linkType == "Rod" then
			return Instance.new("RodConstraint")
		else
			return Instance.new("RopeConstraint")
		end
	end

	local function findAttachmentOnItem(itemModel: Instance, attachName: string): Attachment?
		for _,desc in ipairs(itemModel:GetDescendants()) do
			if desc:IsA("Attachment") and desc.Name == attachName then
				return desc
			end
		end
		return nil
	end

	local function ensureMonsterAttachment(hrp: BasePart, name: string, offset: Vector3?): Attachment
		local att = hrp:FindFirstChild(name)
		if not att then
			att = Instance.new("Attachment")
			att.Name = name
			att.Parent = hrp
		end
		att.Position = offset or Vector3.new()
		return att
	end

	-- PREPARE: cria vínculos com o que estiver em Route/Interactables
	function B.Prepare(monster: Model, routeFolder: Folder)
		if not monster or not routeFolder then return end
		local hrp = monster:FindFirstChild("HumanoidRootPart") :: BasePart
		if not hrp then return end

		activeLinks[monster] = activeLinks[monster] or {constraints = {}, tempAttachments = {}}
		local bucket = activeLinks[monster]

		local interactables = routeFolder:FindFirstChild("Interactables")
		if not interactables or not interactables:IsA("Folder") then return end

		for _, item in ipairs(interactables:GetChildren()) do
			local linkType = getAttrStr(item, "LinkType", "Rope")
			local attItemName = getAttrStr(item, "AttachmentNameOnItem", "Attachment")
			local attMonsterName = getAttrStr(item, "AttachmentNameOnMonster", "TrainingLink")
			local offset = parseVector3(getAttrStr(item, "OffsetOnMonster", nil))

			local itemAttachment = findAttachmentOnItem(item, attItemName)
			if not itemAttachment then
				warn("[BoulderCarry] Attachment não encontrado:", item:GetFullName(), "nome:", attItemName)
				continue
			end

			local basePart = itemAttachment.Parent :: BasePart
			if basePart and basePart:IsA("BasePart") then
				basePart.Anchored = false
			end

			local monsterAttachment = ensureMonsterAttachment(hrp, attMonsterName, offset)

			local constraint = toConstraint(item, linkType)
			constraint.Attachment0 = monsterAttachment
			constraint.Attachment1 = itemAttachment

			-- parâmetros genéricos por atributo, com defaults razoáveis
			local defaultLen = (monsterAttachment.WorldPosition - itemAttachment.WorldPosition).Magnitude

			if constraint:IsA("RopeConstraint") then
				constraint.Length = getAttrNum(item, "LinkLength", defaultLen)
				constraint.Restitution = getAttrNum(item, "Restitution", constraint.Restitution)
				constraint.Thickness = getAttrNum(item, "Thickness", constraint.Thickness)
				constraint.Visible = getAttrBool(item, "Visible", constraint.Visible)
				--constraint.RigidityEnabled = getAttrBool(item, "RigidityEnabled", constraint.RigidityEnabled)
			else -- RodConstraint
				constraint.Length = getAttrNum(item, "LinkLength", defaultLen)
				constraint.Visible = getAttrBool(item, "Visible", constraint.Visible)
				if constraint:FindFirstChild("Thickness") then
					-- algumas builds têm plugin que injeta prop; ignore se não existir
					(constraint :: any).Thickness = getAttrNum(item, "Thickness", (constraint :: any).Thickness)
				end
			end

			constraint.Parent = itemAttachment.Parent

			table.insert(bucket.constraints, constraint)
			-- track do attachment criado no HRP
			local seen = false
			for _, a in ipairs(bucket.tempAttachments) do
				if a == monsterAttachment then seen = true break end
			end
			if not seen then
				table.insert(bucket.tempAttachments, monsterAttachment)
			end
		end
	end

	-- EXECUTE: opcional (ex.: ajustes finos, peso/drag). Aqui mantemos noops.
	function B.Execute(monster: Model, routeFolder: Folder)
		-- Example: poderia ajustar velocidade, alterar Length dinamicamente, etc.
	end

	-- CLEANUP: destrói constraints + attachments temporários
	function B.Cleanup(monster: Model)
		local bucket = activeLinks[monster]
		if not bucket then return end

		for _, c in ipairs(bucket.constraints) do
			if c and c.Destroy then c:Destroy() end
		end
		for _, a in ipairs(bucket.tempAttachments) do
			if a and a.Parent then a:Destroy() end
		end
		activeLinks[monster] = nil
	end
end

local function snapshotStats(monster: Instance)
	local out = {}
	for _,name in ipairs({"Strength","Defense","Skill","Speed","Intelligence","Luck"}) do
		out[name] = monster:GetAttribute(name) or 0
	end
	return out
end

local function sortByNumericName(a: Instance, b: Instance)
	local na = tonumber(string.match(a.Name, "%d+")) or math.huge
	local nb = tonumber(string.match(b.Name, "%d+")) or math.huge
	if na ~= nb then
		return na < nb
	else
		return a.Name < b.Name
	end
end

function module.ApplyTraining(monster: Instance, trainingType: string)
	if not monster or not monster:IsDescendantOf(game) then return {} end
	local grant = BONUS[trainingType]
	if typeof(grant) == "function" then grant = grant() end
	grant = grant or {}
	for stat, val in pairs(grant) do
		monster:SetAttribute(stat, (monster:GetAttribute(stat) or 0) + val)
	end
	return snapshotStats(monster)
end

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

-- Improved pathfinding movement with SimplePath
local function moveToWithSimplePath(monster: Model, targetPos: Vector3, speed: number): boolean
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

	local originalSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = speed or humanoid.WalkSpeed

	local path = SimplePath.new(monster)
	path.WaypointReachedDistance = 4.0  -- Increased tolerance
	path.PathMinDistance = 3
	path.PathMaxDistance = 200

	local reached = false
	local pathError = false

	local reachedConnection = path.Reached:Connect(function()
		reached = true
	end)

	local errorConnection = path.Error:Connect(function(errorType)
		pathError = true
		warn("Pathfinding error: " .. tostring(errorType))
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

	-- More generous timeout calculation for boulder carrying
	local baseTimeout = (dist / math.max(speed, 1)) * 4.0 + 8.0
	local timeout = math.clamp(baseTimeout, 10, 90)  -- Much longer timeouts

	local lastMovementCheck = tick()
	local lastKnownPos = currentPos

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

		-- If stuck for more than 3 seconds, try to recover
		if tick() - lastMovementCheck > 3.0 and movedDistance < 2.0 then
			warn("Monster appears stuck, attempting recovery")

			-- Cancel current path and restart
			path:Stop()
			task.wait(0.3)

			-- Reset humanoid state
			humanoid:MoveTo(monster.PrimaryPart.Position)
			task.wait(0.2)

			-- Retry with fresh path
			local retryPath = SimplePath.new(monster)
			retryPath.WaypointReachedDistance = 4.0
			retryPath.PathMinDistance = 3
			retryPath.PathMaxDistance = 200

			local retrySuccess = retryPath:Run(targetPos)
			if retrySuccess then
				path = retryPath
				lastMovementCheck = tick()
				warn("Recovery path started")
			else
				warn("Recovery path failed")
				pathError = true
				break
			end
		elseif movedDistance > 0.5 then
			-- We're moving, reset the timer
			lastMovementCheck = tick()
			lastKnownPos = newPos
		end
	end

	reachedConnection:Disconnect()
	errorConnection:Disconnect()
	path:Destroy()
	humanoid.WalkSpeed = originalSpeed

	return reached
end
-- Helper function to get route folder (existing)
local function getRouteFolder(trainingType: string): Folder?
	local routes = Workspace:FindFirstChild("Training")
	if not routes then return nil end
	local folder = routes:FindFirstChild(trainingType)
	return (folder and folder:IsA("Folder")) and folder or nil
end
-- NEW: Enhanced course runner using SimplePath
local function runCourse(monster: Instance, trainingType: string)
	local humanoid = monster:FindFirstChildOfClass("Humanoid")
	if not humanoid or not monster.PrimaryPart then 
		warn("Monster missing humanoid or primary part")
		return 
	end

	-- Cancel any current movement
	humanoid:MoveTo(monster.PrimaryPart.Position)

	local baseSpeed = (monster:GetAttribute("Speed") or 2)
	local travelSpeed = math.clamp(10 + baseSpeed * 2, 8, 28)

	local folder = getRouteFolder(trainingType)
	if folder then
		local points = {}
		for _, p in ipairs(folder:GetChildren()) do
			if p:IsA("BasePart") then 
				table.insert(points, p) 
			end
		end
		table.sort(points, sortByNumericName)

		-- Move through each point using SimplePath
		for _, point in ipairs(points) do
			if not moveToWithSimplePath(monster, point.Position, travelSpeed) then
				warn("Failed to reach point: " .. point.Name)
				break
			end
		end
	else
		-- Fallback: simple forward movement
		local forward = monster.PrimaryPart.CFrame * CFrame.new(0, 0, -25)
		moveToWithSimplePath(monster, forward.Position, travelSpeed)
		moveToWithSimplePath(monster, monster.PrimaryPart.Position, travelSpeed)
	end
end



function module.StartSession(player: Player, monster: Instance, trainingType: string)
	if not monster then return nil end

	-- Estado Training (para pausar Following etc.)
	if _G and _G.STATES and typeof(_G.STATES.SetState) == "function" then
		_G.STATES:SetState(monster, "Training")
	end

	-- Resolve a pasta da rota uma única vez
	local routes = workspace:FindFirstChild("Training")
	local routeFolder = routes and routes:FindFirstChild(trainingType)

	-- Se existir modo especializado, chama Prepare/Execute/Cleanup
	local mode = Modes[trainingType]

	if mode and mode.Prepare then
		mode.Prepare(monster, routeFolder)
	end

	-- Se o modo tiver execução própria, use-a; caso contrário, use seu runCourse padrão
	if mode and mode.Execute then
		mode.Execute(monster, routeFolder)
	else
		runCourse(monster, trainingType)
	end

	-- limpeza específica do modo (remove constraints/attachments)
	if mode and mode.Cleanup then
		mode.Cleanup(monster)
	end

	task.wait(0.25)

	local snap = module.ApplyTraining(monster, trainingType)

	-- Sair de Training → voltar pro que fazia sentido
	local hasOwner = monster:GetAttribute("OwnerId") ~= nil
	if _G and _G.STATES and typeof(_G.STATES.SetState) == "function" then
		_G.STATES:SetState(monster, hasOwner and "Following" or "Idle")
	end

	return snap
end

return module