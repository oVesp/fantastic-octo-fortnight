--[[
	EnhancedMovement.lua — versão centralizada compatível com CombatManager

	Compatibilidade garantida com chamadas do CombatManager:
	- EnhancedMovement.Init(monster [, opts])
	- EnhancedMovement.Cleanup(monster)
	- EnhancedMovement.SetTarget(monster, targetModel)
	- EnhancedMovement.SetPreferredByMove(monster, move)
	- EnhancedMovement.LockMovement(monster, locked [, dur])
	- EnhancedMovement.Update(monster, nil, ctx)      -- per-agente
	- EnhancedMovement.Update(dt)                     -- global (Heartbeat)

	NEW: Smoother orbit that calculates every frame without stopping
]]

local RunService = game:GetService("RunService")

local EnhancedMovement = {}
local CombatZone = require(script.Parent.Parent.CombatZone)
-- ======================
-- Config geral (distâncias maiores)
-- ======================
local CONFIG = {
	personalSpaceRadius   = 3.0,
	orbitDistance         = 12.0,
	preferredRatio        = 0.70,
	baseMinWalkSpeed      = 12,
	orbitSpeedDeg         = 90, -- Reduced for smoother movement
	approachSpeedMul      = 1.05,
	orbitSpeedMul         = 0.95,
	kiteQuickMul          = 1.6,
	kitingDistance        = 16.0,
	backstepDistance      = 12.0,
	backstepCooldown      = 1.15,
	decisionJitterMin     = 0.45,
	decisionJitterMax     = 1.25,
	minIntentionDuration  = 1.5,
	retreatMaxDur = 1.2,
	retreatCooldown = 3.0,
	retreatStopMargin = 3.5,
	movementLockDuringCast= true,
	arrivalThreshold      = 2.0,
	-- NEW: Orbit smoothness settings
	orbitUpdateInterval   = 0.1, -- Update orbit position every 0.1 seconds
	minOrbitAdjustment    = 0.5, -- Minimum distance change to trigger movement
	faceTickInterval = 0.20	
}

-- ======================
-- Estado
-- ======================
local monsterStates = setmetatable({}, {__mode = "k"})

-- NEW: setter so CombatManager can inject the zone
function EnhancedMovement.SetZone(monster, zone)
	local s = EnhancedMovement.InitializeMonster(monster)
	s.zone = zone
end

-- helper to clamp a position to agent's zone
local function _clampToZone(monster, worldPos)
	local s = EnhancedMovement.InitializeMonster(monster)
	if s.zone then
		return CombatZone.ClampPositionToZone(s.zone, worldPos)
	end
	return worldPos
end



local function getRootPart(model)
	if not model or not model.Parent then return nil end
	if model:IsA("Model") then
		return model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
	elseif model:IsA("BasePart") then
		return model
	end
	return nil
end

local function now() return os.clock() end

-- preferred baseado no move
local function _computePreferredByMove(move)
	if not move then return CONFIG.orbitDistance end
	local maxR = move.maxRange or CONFIG.orbitDistance
	local minR = move.minRange or 0
	local pref = math.clamp(math.floor(maxR * CONFIG.preferredRatio), math.max(minR, 2), math.max(6, maxR - 1))
	return pref
end

-- Começo do cast: trava e agenda desbloqueio de segurança
function EnhancedMovement.OnCastBegin(monster, dur)
	local s = EnhancedMovement.InitializeMonster(monster)
	local t = os.clock()
	s.isMovementLocked = true
	s.lockedSince = t
	s.lockedUntil = t + (dur or 0.8) + 0.2 -- folga de rede
end

-- Fim do cast: solta lock e força nova decisão imediata
function EnhancedMovement.OnCastEnd(monster, target)
	local s = EnhancedMovement.InitializeMonster(monster)
	s.isMovementLocked = false
	s.lockedUntil = nil
	s.currentIntention = nil
	s.lastDecisionTime = os.clock() - (s.decisionJitter or 0.4) -- força think já
	if target then s.target = target end
	-- coloca uma orbit curtinha para "destravar" a máquina
	if s.target then EnhancedMovement.SetMovementIntention(monster, "orbit", s.target, 0.8) end
end

-- cria/garante estado do monstro
function EnhancedMovement.InitializeMonster(monster)
	local s = monsterStates[monster]
	if s then return s end

	s = {
		target = nil,
		preferredDist = CONFIG.orbitDistance,
		orbitClockwise = (math.random() > 0.5),
		isMovementLocked = false,
		currentDestination = nil,
		moveTimeout = nil,
		lastBackstep = 0,
		lastDecisionTime = 0,
		decisionJitter = math.random(CONFIG.decisionJitterMin*100, CONFIG.decisionJitterMax*100)/100,
		currentIntention = nil,
		ringJitter = (math.random(-12,12)/10),
		biasSide = (math.random() < 0.5) and -1 or 1,
		biasUntil = now() + math.random(2,4),
		lastNudgeT = 0,
		lastRetreatAt = 0,
		-- NEW: Smooth orbit tracking
		lastOrbitUpdate = 0,
		currentOrbitGoal = nil,
		isOrbiting = false,
		lastFaceTick = 0
	}
	monsterStates[monster] = s

	local hum = monster:FindFirstChildOfClass("Humanoid")
	if hum then
		if hum.WalkSpeed < CONFIG.baseMinWalkSpeed then hum.WalkSpeed = CONFIG.baseMinWalkSpeed end
		hum.AutoRotate = true
	end

	return s
end

function EnhancedMovement.CleanupMonster(monster)
	monsterStates[monster] = nil
end

-- ======================
-- Helpers de orientação suave
-- ======================
local function _faceTarget(mon, tgt)
	local ra = getRootPart(mon); local rb = getRootPart(tgt)
	if not (ra and rb) then return end
	local dir = (rb.Position - ra.Position); dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.1 then return end
	local existing = ra:FindFirstChild("_FaceAlign")
	if existing and existing:IsA("AlignOrientation") then
		existing.CFrame = CFrame.lookAt(ra.Position, ra.Position + dir)
		return
	end
	local align = Instance.new("AlignOrientation")
	align.Name = "_FaceAlign"
	align.MaxTorque = 50000
	align.Responsiveness = 22
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	local att = Instance.new("Attachment"); att.Name = "_FaceAttachment"; att.Parent = ra
	align.Attachment0 = att
	align.CFrame = CFrame.lookAt(Vector3.zero, dir)
	align.Parent = ra
	task.delay(1.5, function()
		if align.Parent then align:Destroy() end
		if att.Parent then att:Destroy() end
	end)
end

-- ======================
-- Movimento baixo nível
-- ======================
local function _setWalkSpeed(monster, mul, quick)
	local hum = monster:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	-- salva WalkSpeed original se ainda não salvo
	local s = EnhancedMovement.InitializeMonster(monster)
	if not s._baseWalkSpeed then
		s._baseWalkSpeed = math.max(hum.WalkSpeed, CONFIG.baseMinWalkSpeed)
	end

	-- usa base constante
	local base = s._baseWalkSpeed
	local final = base * (mul or 1.0)
	if quick then final *= 1.4 end

	-- clampa para segurança
	final = math.clamp(final, CONFIG.baseMinWalkSpeed, base * 3)

	hum.WalkSpeed = final
end



-- NEW: Smooth orbit function that updates continuously
function EnhancedMovement.UpdateSmoothOrbit(monster, target, radius, clockwise, dt)
	local s = EnhancedMovement.InitializeMonster(monster)
	if s.isMovementLocked then return end

	local rpA = getRootPart(monster); local rpT = getRootPart(target)
	if not (rpA and rpT) then return end

	local currentTime = now()

	-- Only update orbit position at intervals for performance
	if currentTime - s.lastOrbitUpdate < CONFIG.orbitUpdateInterval then
		return
	end

	s.lastOrbitUpdate = currentTime

	local center = rpT.Position
	local me = rpA.Position

	-- Calculate current angle and distance
	local toTarget = Vector3.new(center.X - me.X, 0, center.Z - me.Z)
	local currentDist = toTarget.Magnitude
	local currentAngle = math.atan2(toTarget.Z, toTarget.X)

	-- Calculate desired orbit position
	local dir = (clockwise and -1 or 1)
	local angleDelta = math.rad(CONFIG.orbitSpeedDeg) * dt * dir
	local desiredAngle = currentAngle + angleDelta
	local r = radius or CONFIG.orbitDistance

	local desiredPos = Vector3.new(
		center.X + math.cos(desiredAngle) * r,
		center.Y,
		center.Z + math.sin(desiredAngle) * r
	)

	-- Only update if the move is significant enough
	if not s.currentOrbitGoal or (desiredPos - s.currentOrbitGoal).Magnitude > CONFIG.minOrbitAdjustment then
		s.currentOrbitGoal = desiredPos
		desiredPos = _clampToZone(monster, desiredPos)
		EnhancedMovement.MoveToPosition(monster, desiredPos, CONFIG.orbitSpeedMul, false)
	end

	-- Face target during orbit
	_faceTarget(monster, target)
end

local function _maybeFace(monster, state, force)
	-- Requires a valid target (Model) since _faceTarget expects two chars
	local tgt = state and state.target
	if not (tgt and tgt.Parent) then return end
	local t = now()
	if force or (t - (state.lastFaceTick or 0)) >= CONFIG.faceTickInterval then
		_faceTarget(monster, tgt)
		state.lastFaceTick = t
	end
end

-- Legacy orbit function (kept for compatibility)
function EnhancedMovement.OrbitTarget(monster, target, radius, clockwise)
	local s = EnhancedMovement.InitializeMonster(monster)
	s.isOrbiting = true
	EnhancedMovement.UpdateSmoothOrbit(monster, target, radius, clockwise, 1/60) -- Approximate frame time
end

function EnhancedMovement.KiteFromTarget(monster, target, distance)
	local rpA = getRootPart(monster); local rpT = getRootPart(target)
	if not (rpA and rpT) then return end
	local away = (rpA.Position - rpT.Position).Unit
	local want = rpA.Position + away * (distance or CONFIG.kitingDistance)
	_maybeFace(monster, EnhancedMovement.InitializeMonster(monster), false)
	EnhancedMovement.MoveToPosition(monster, want, 1.05, false)
end

-- NEW: Close distance intention - aggressive gap closing
function EnhancedMovement.CloseDistance(monster, target, desiredDistance)
	local rpA = getRootPart(monster); local rpT = getRootPart(target)
	if not (rpA and rpT) then return end

	local currentDist = (rpA.Position - rpT.Position).Magnitude
	local desiredDist = desiredDistance or 2.0

	if currentDist > desiredDist + 0.5 then
		-- Move closer aggressively
		local direction = (rpT.Position - rpA.Position).Unit
		local goal = rpT.Position - (direction * desiredDist)
		EnhancedMovement.MoveToPosition(monster, goal, 1.2, true)  -- Faster movement for closing gap
	else
		-- Close enough, face target and prepare for attack
		_faceTarget(monster, target)
	end
end

function EnhancedMovement.ExecuteBackstep(monster, target)
	local s = EnhancedMovement.InitializeMonster(monster)
	if (now() - (s.lastBackstep or 0)) < CONFIG.backstepCooldown then return end
	if (now() - (s.lastRetreatAt or 0)) < CONFIG.retreatCooldown then return end
	local rpA = getRootPart(monster); local rpT = getRootPart(target)
	if not (rpA and rpT) then return end
	local away = (rpA.Position - rpT.Position).Unit
	local want = rpA.Position + away * CONFIG.backstepDistance
	
	_maybeFace(monster, s, false)
	EnhancedMovement.MoveToPosition(monster, want, 0.95, false)
	s.lastBackstep = now()
	s.lastRetreatAt = s.lastBackstep
	if _G and _G.EFFECTS then
		_G.EFFECTS.EmitterEffect({Name="BackstepDust", Position=rpA, Duration=0.4})
		if _G.EFFECTS.PlaySound then _G.EFFECTS.PlaySound("Dash",{Where=monster, Duration=0.2, RandomPitch=true}) end
	end
end

-- ======================
-- Intenção & decisão
-- ======================
function EnhancedMovement.ShouldMakeDecision(monster, t)
	local s = EnhancedMovement.InitializeMonster(monster)
	return t >= (s.lastDecisionTime + s.decisionJitter)
end

function EnhancedMovement.SetMovementIntention(monster, intentType, target, duration)
	local s = EnhancedMovement.InitializeMonster(monster)
	s.currentIntention = { type = intentType, untilT = now() + (duration or CONFIG.minIntentionDuration) }
	if target then s.target = target end

	-- NEW: Reset orbit state when setting new intention
	if intentType == "orbit" then
		s.isOrbiting = true
		s.lastOrbitUpdate = 0 -- Force immediate update
	else
		s.isOrbiting = false
		s.currentOrbitGoal = nil
	end
end

function EnhancedMovement.GetCurrentIntention(monster)
	local s = monsterStates[monster]
	if not s then return nil end
	if s.currentIntention and now() > s.currentIntention.untilT then
		s.currentIntention = nil
		s.isOrbiting = false -- Stop orbiting when intention expires
	end
	return s.currentIntention
end

-- jitter efetivo do anel
local function _effectivePreferred(state)
	local t = now()
	if t > (state.biasUntil or 0) then
		state.ringJitter = (math.random(-12,12)/10)
		state.biasSide   = (math.random() < 0.5) and -1 or 1
		state.biasUntil  = t + math.random(2,4)
	end
	local base = state.preferredDist or CONFIG.orbitDistance
	return math.max(2, base + (state.ringJitter or 0))
end


function EnhancedMovement.MoveToPosition(monster, worldPos, speedMul, quick)
	local s = EnhancedMovement.InitializeMonster(monster)
	if s.isMovementLocked then return end

	local hum = monster:FindFirstChildOfClass("Humanoid")
	if not (hum and worldPos) then return end

	worldPos = _clampToZone(monster, worldPos) -- NEW

	hum:MoveTo(worldPos)
	_maybeFace(monster, s, false)
	_setWalkSpeed(monster, speedMul or 1.0, quick)

	s.currentDestination = worldPos
	s.moveTimeout = now() + 2.5
end


-- ======================
-- Locks
-- ======================
function EnhancedMovement.SetMovementLock(monster, locked, dur)
	local s = EnhancedMovement.InitializeMonster(monster)
	s.isMovementLocked = locked and true or false
	if locked and dur and dur > 0 then
		task.delay(dur, function()
			if monsterStates[monster] then
				s.isMovementLocked = false
				-- aplica pendente, se houver
				if s.moveTargetPosition then
					EnhancedMovement.MoveToPosition(monster, s.moveTargetPosition, 1.0, false)
					s.moveTargetPosition = nil
				end
			end
		end)
	end
end

-- ======================
-- Compat API com CombatManager
-- ======================
function EnhancedMovement.Init(monster, opts)
	local s = EnhancedMovement.InitializeMonster(monster)
	if opts and opts.preferredDist then s.preferredDist = opts.preferredDist end
	return s
end
function EnhancedMovement.Cleanup(monster) return EnhancedMovement.CleanupMonster(monster) end

function EnhancedMovement.SetTarget(monster, targetModel)
	local s = EnhancedMovement.InitializeMonster(monster); s.target = targetModel
	_maybeFace(monster, s, true) -- immediate snap toward new target
end

function EnhancedMovement.SetPreferredByMove(monster, move)
	local s = EnhancedMovement.InitializeMonster(monster); s.preferredDist = _computePreferredByMove(move)
end
function EnhancedMovement.LockMovement(monster, locked, dur)
	return EnhancedMovement.SetMovementLock(monster, locked, dur)
end

-- ======================
-- Update (per-agente OU global)
-- ======================
local function _engageWithSideBias(monster, target, state)
	_maybeFace(monster, EnhancedMovement.InitializeMonster(monster), false)
	local rpA = getRootPart(monster); local rpT = getRootPart(target)
	if not (rpA and rpT) then return end
	local pref = _effectivePreferred(state)
	local stopAt = math.max(pref, CONFIG.personalSpaceRadius)
	local dir = (rpT.Position - rpA.Position).Unit
	local right = Vector3.new(0,1,0):Cross(dir).Unit
	local side = (1.5 + math.random()) * (state.biasSide or 1)
	local goal = rpT.Position - (dir * stopAt) + (right * side)
	EnhancedMovement.MoveToPosition(monster, goal, CONFIG.approachSpeedMul, false)
end

local function _orbitNudgeIfStalled(monster, target, state)
	local t = now(); if (t - (state.lastNudgeT or 0)) < 1.2 then return end
	local rpA = getRootPart(monster); local rpT = getRootPart(target)
	if not (rpA and rpT) then return end
	local desiredR = _effectivePreferred(state)
	local d = (rpT.Position - rpA.Position).Magnitude
	if math.abs(d - desiredR) < 0.3 then
		state.orbitClockwise = not state.orbitClockwise
		local toT = (rpT.Position - rpA.Position)
		local tang = Vector3.new(0,1,0):Cross(toT).Unit * (state.orbitClockwise and -1 or 1)
		local nudge = tang * 2.0
		EnhancedMovement.MoveToPosition(monster, rpA.Position + nudge, 1.0, false)
		state.lastNudgeT = t
	end
end

local function _decideAndMove(monster, ctx)
	local s = EnhancedMovement.InitializeMonster(monster)
	local tgt = s.target
	if not (tgt and tgt.Parent) then return end

	if s.isMovementLocked then return end

	local rpA = getRootPart(monster); local rpT = getRootPart(tgt)
	if not (rpA and rpT) then return end

	-- KEY CHANGE: If we already have a destination, don't make a new decision.
	-- Let the monster finish its current movement first.
	if s.currentDestination and not s.isOrbiting then
		return
	end

	-- Decision logic (runs only when the monster is idle/has arrived)
	local t = now()
	if EnhancedMovement.ShouldMakeDecision(monster, t) then
		s.lastDecisionTime = t
		if ctx and ctx.chosenMove then s.preferredDist = _computePreferredByMove(ctx.chosenMove) end

		local d = (rpT.Position - rpA.Position).Magnitude
		local tooClose = CONFIG.personalSpaceRadius * 0.9
		local ringMin  = (s.preferredDist or CONFIG.orbitDistance) - 1.3
		local ringMax  = (s.preferredDist or CONFIG.orbitDistance) + 1.3
		local health = (ctx and ctx.healthState) or "healthy"

		local intent, dur = "orbit", CONFIG.minIntentionDuration
		-- (Decision tree for intent remains the same)
		if health == "critical" then if (now() - (s.lastRetreatAt or 0)) >= CONFIG.retreatCooldown then if d < ringMax then intent = "backstep" else intent = "kite" end; dur = math.min(CONFIG.retreatMaxDur, 1.2); s.lastRetreatAt = now() else if d >= ringMax then intent = "engage" else intent = "orbit" end end
		elseif health == "wounded" then if d < tooClose then intent = "backstep"; dur = 0.45 elseif d < ringMax and d > ringMin then intent = "orbit"; dur = 1.0 else intent = "engage"; dur = 0.9 end
		else if d < tooClose then intent = "backstep"; dur = 0.4 elseif d < ringMax and d > ringMin then intent = "orbit"; dur = 1.0 elseif d >= ringMax then intent = "engage"; dur = 0.85 else intent = "orbit"; dur = 0.85 end end

		EnhancedMovement.SetMovementIntention(monster, intent, tgt, dur)

		-- Execute the chosen intention ONCE
		local it = s.currentIntention
		if not it then return end

		if it.type == "orbit" then
			_faceTarget(monster, tgt)
			s.isOrbiting = true
			-- Don't call OrbitTarget here - it will be handled in _UpdateAll
		elseif it.type == "engage" then
			_faceTarget(monster, tgt)
			_engageWithSideBias(monster, tgt, s)
		elseif it.type == "kite" then
			EnhancedMovement.KiteFromTarget(monster, tgt, math.max(s.preferredDist + 8, CONFIG.kitingDistance))
		elseif it.type == "backstep" then
			EnhancedMovement.ExecuteBackstep(monster, tgt)
		elseif it.type == "close_distance" then
			-- NEW: Handle close_distance intention
			local desiredDist = ctx.desiredRange or 2.0
			EnhancedMovement.CloseDistance(monster, tgt, desiredDist)
		end
	end
end

-- Dispatcher: per-agente OU global
function EnhancedMovement.Update(a, b, c)
	if type(a) == "number" then
		return EnhancedMovement._UpdateAll(a) -- chamada global com dt
	end

	-- Per-agente update
	local monster = a
	local ctx = c or b or {}
	local s = EnhancedMovement.InitializeMonster(monster)
	local target = s.target

	-- Se CombatManager deu uma intenção, obedeça.
	if ctx.intention and target then
		local intention = ctx.intention

		if intention == "close_distance" then
			local desiredDist = ctx.desiredRange or 2.0
			EnhancedMovement.CloseDistance(monster, target, desiredDist)

		elseif intention == "approach" then
			-- usa a lógica do engage, mas sem setar intenção
			_faceTarget(monster, target)
			_engageWithSideBias(monster, target, s)

		elseif intention == "orbit" then
			_faceTarget(monster, target)
			s.isOrbiting = true
			-- O _UpdateAll(dt) global vai cuidar do movimento

		elseif intention == "flank" then
			-- Flank é como 'approach', mas com mais 'side bias'
			s.biasSide = (s.biasSide or 1) * 1.5 -- exagera o 'side'
			_faceTarget(monster, target)
			_engageWithSideBias(monster, target, s)

		elseif intention == "create_distance" then
			local dist = (ctx.desiredRange or s.preferredDist or 15) + 4
			EnhancedMovement.KiteFromTarget(monster, target, dist)

		elseif intention == "backstep" then
			EnhancedMovement.ExecuteBackstep(monster, target)
		end

		-- A intenção do CombatManager foi executada.
		return
	end

	-- Se NENHUMA intenção veio do CombatManager, 
	-- use a lógica de movimento autônomo (fora de combate).
	return _decideAndMove(monster, ctx)
end

EnhancedMovement.FaceTarget = _faceTarget
-- Renomeia Update global ? _UpdateAll
function EnhancedMovement._UpdateAll(dt)
	local currentTime = now()
	for monster, state in pairs(monsterStates) do
		if not monster.Parent then
			EnhancedMovement.CleanupMonster(monster)
		else
			
			local rp = getRootPart(monster)
			if state.zone and rp then
				local clamped = CombatZone.ClampPositionToZone(state.zone, rp.Position)
				if (clamped - rp.Position).Magnitude > 0.15 then
					-- Teleport just inside boundary (keep current rotation)
					monster:PivotTo(
						CFrame.new(clamped)
							* CFrame.fromMatrix(Vector3.new(), rp.CFrame.XVector, rp.CFrame.YVector, rp.CFrame.ZVector)
					)
					_maybeFace(monster, state, true)

					-- Clear any stale destination so MoveTo restarts cleanly
					state.currentDestination = nil
				end
				_maybeFace(monster, state, false)
			end
			
			-- NEW: Handle continuous orbit movement
			if state.isOrbiting and state.currentIntention and state.currentIntention.type == "orbit" and not state.isMovementLocked then
				local target = state.target
				if target and target.Parent then
					EnhancedMovement.UpdateSmoothOrbit(monster, target, _effectivePreferred(state), state.orbitClockwise, dt)
				end
			end

			-- Safety timeouts for locks and moves
			if state.moveTimeout and currentTime > state.moveTimeout then
				state.currentDestination = nil; state.moveTimeout = nil
			end
			if state.isMovementLocked and state.lockedUntil and (currentTime > state.lockedUntil) then
				state.isMovementLocked = false; state.lockedUntil = nil
			end

			-- KEY CHANGE: Check if the monster has arrived at its destination.
			-- Skip this check for orbiting monsters to maintain continuous movement
			if state.currentDestination and not state.isOrbiting then
				local rp = getRootPart(monster)
				if rp then
					local distance = (rp.Position - state.currentDestination).Magnitude
					if distance < CONFIG.arrivalThreshold then
						-- Arrived! Clear the destination so a new decision can be made.
						state.currentDestination = nil
					end
				else -- Root part gone? Clear destination.
					state.currentDestination = nil
				end
			end
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	EnhancedMovement._UpdateAll(dt)
end)

-- Debug helper
function EnhancedMovement.__debugGet(mon)
	local s = monsterStates[mon]
	if not s then return "no-state" end
	return string.format(
		"[EM] tgt=%s intent=%s locked=%s orbiting=%s pref=%.1f jitter=%.2f",
		(s.target and s.target.Name or "nil"),
		(s.currentIntention and s.currentIntention.type or "nil"),
		tostring(s.isMovementLocked),
		tostring(s.isOrbiting),
		s.preferredDist or 0,
		s.decisionJitter or 0
	)
end

return EnhancedMovement