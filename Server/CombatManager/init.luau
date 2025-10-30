-- ModuleScript: ServerScriptService>Main>CombatManager
local CombatManager = {}
CombatManager.__index = CombatManager

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")


-- Modules
local MOVES_MODULE = require(RS.Modules.Moves)
local PERSONALITIES_MODULE = require(RS.Modules.Personalities)
local COMBAT_ZONE = require(script.Parent.CombatZone)
local AnimationManager = require(RS.Modules.AnimationManager)
local AnimationHandler = require(script.Parent.AnimationHandler)
local Bridge = require(script.Bridge)
local CombatMath = require(script.CombatMath)
local StatusEffects = require(script.StatusEffects)
local EnhancedMovement = require(script.EnhancedMovement)
local MoveUnlocks = require(game.ReplicatedStorage.Modules.MoveUnlocks)
local Leveling = require(RS.Modules:WaitForChild("Leveling"))

local SE_TICK_ACC = 0
local function _applyDotDamage(target, amount, source, tag)
	local residual, absorbed = StatusEffects.AbsorbWithShield(target, amount)
	if residual > 0 then
		local hum = target:FindFirstChildOfClass("Humanoid")
		if hum then hum:TakeDamage(residual) end
	end
	-- optional: floating numbers
	if _G.EFFECTS then _G.EFFECTS.ShowDamage(target, math.max(1, math.floor(amount)), false) end
end

local STATE_DURATIONS = {
	deciding = 0.1,
	positioning = 2,
	repositioning = 1,
	resting = 0.1,
	reacting = 0.1
}

-- Storage
local activeCombats = {}
local combatParticipants = {}
local combatLoopConnection = nil
local onCombatEndCallbacks = {}
local DEFAULT_ATTACK = {
	id = "DefaultAttack",
	name = "Default Attack",
	rarity = "Amateur",
	power = 8,
	cooldown = 1.5,
	minRange = 0,
	maxRange = 6,
	castTime = 0.4,
	castSpeed = 1.0,
	lockMovement = true,
	effects = {},
	tags = {"Melee", "Universal"},
	accuracy = 0.92,
	critChance = 0.03,
	mpCost = 0
}

local function effectTypeOf(entry)
	if typeof(entry) == "table" then
		return entry.type
	end
	return entry
end

local function moveHasEffect(move, effectType)
	local effects = move and move.effects
	if not effects then
		return false
	end
	for _, entry in ipairs(effects) do
		if effectTypeOf(entry) == effectType then
			return true
		end
	end
	return false
end

local function iterateMoveEffects(move, callback)
	local effects = move and move.effects
	if not effects then
		return
	end
	for _, entry in ipairs(effects) do
		callback(effectTypeOf(entry), entry)
	end
end

local STAT_SYNC_RULES = {
	Hp = { attr = "Hp", alias = "HP" },
	Mp = { attr = "MaxMP", fallbackAttr = "MP", alias = "MP" },
	Strength = { attr = "Strength", alias = "STR" },
	Defense = { attr = "Defense", alias = "DEF" },
	Skill = { attr = "Skill", alias = "SKL" },
	Speed = { attr = "Speed", alias = "SPD" },
	Intelligence = { attr = "Intelligence", alias = "INT" },
	Luck = { attr = "Luck", alias = "LCK" },
}

local function syncMonsterStatsIntoTables(model: Model?, targets: {table})
	if not model then
		return
	end

	local function readAttribute(rule)
		local value = model:GetAttribute(rule.attr)
		if typeof(value) ~= "number" and rule.fallbackAttr then
			value = model:GetAttribute(rule.fallbackAttr)
		end
		if typeof(value) ~= "number" and rule.attr == "Hp" then
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum then
				value = hum.MaxHealth
			end
		end
		return typeof(value) == "number" and value or nil
	end

	for _, stats in ipairs(targets) do
		if type(stats) == "table" then
			for key, rule in pairs(STAT_SYNC_RULES) do
				local value = readAttribute(rule)
				if value then
					stats[key] = value
					if rule.alias then
						stats[rule.alias] = value
					end
				end
			end
		end
	end
end

local function gatherStatsTables(ownerId: number?, entry)
	local targets = {}
	local seen = setmetatable({}, { __mode = "k" })

	local function push(tbl)
		if type(tbl) ~= "table" then
			return
		end
		if not seen[tbl] then
			seen[tbl] = true
			table.insert(targets, tbl)
		end
	end

	if entry and type(entry) == "table" and type(entry.Data) == "table" then
		if type(entry.Data.Stats) ~= "table" then
			entry.Data.Stats = {}
		end
		push(entry.Data.Stats)
	end

	if ownerId and _G and _G.DATA and typeof(_G.DATA.Get) == "function" then
		local ok, store = pcall(function()
			return _G.DATA:Get(ownerId)
		end)
		if ok and type(store) == "table" and type(store.Monster) == "table" then
			if type(store.Monster.Stats) ~= "table" then
				store.Monster.Stats = {}
			end
			push(store.Monster.Stats)
		end
	end

	return targets
end

-- Utility Functions

local function setTacticalState(participant, newState)
	local oldState = participant.combatState
	local oldKey = participant.combatStateKey
	local monster = participant.instance

	if not monster or not monster.Parent then return end

	-- 1. Remove the old tactical state, *unless* it was "CASTING".
	--    "CASTING" is removed manually by ExecuteTacticalMove because it has a unique key.
	if oldState and oldKey and oldState ~= "CASTING" then
		if _G.STATES:IsInState(monster, oldState) then
			_G.STATES:RemoveState(monster, oldState, oldKey)
		end
	end

	-- 2. Set the new state
	participant.combatState = newState
	participant.stateStartTime = os.clock()

	-- 3. If the new state is *not* "CASTING", set it in _G.STATES and store the key.
	if newState ~= "CASTING" then
		participant.combatStateKey = _G.STATES:SetState(monster, newState)
	else
		-- If new state *is* "CASTING", clear the key.
		-- ExecuteTacticalMove will set the _G.STATES "Casting" state and store its own key.
		participant.combatStateKey = nil 
	end
end

local function getPrimaryPart(m)
	return m and (m.PrimaryPart or m:FindFirstChild("HumanoidRootPart"))
end

local function _fadeAndCleanup(model: Model, t: number)
	if not (model and model.Parent) then return end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local ti = TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			pcall(function() TweenService:Create(d, ti, {Transparency = 1}):Play() end)
			if d:FindFirstChildOfClass("Decal") then
				for _, dec in ipairs(d:GetDescendants()) do
					if dec:IsA("Decal") then
						pcall(function() TweenService:Create(dec, ti, {Transparency = 1}):Play() end)
					end
				end
			end
		end
	end
	task.delay(t + 0.05, function()
		if model and model.Parent then pcall(model.Destroy, model) end
	end)
end

local function _playDeath(model: Model)
	if not (model and model.Parent) then return end
	if _G.FUNCTIONS and _G.FUNCTIONS.playDeathFrozen then
		pcall(function() _G.FUNCTIONS.playDeathFrozen(model, 0.6, 1.5, {fallbackLen = 1.2}) end)
	else
		-- fallback: little ragdoll-ish nudge
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.FallingDown) end) end
	end
end

local function isAlive(model)
	if not model or not model.Parent then return false end
	local hum = model:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0
end

local function inRange(a, b, minR, maxR)
	local pa, pb = getPrimaryPart(a), getPrimaryPart(b)
	if not pa or not pb then return false end
	local d = (pa.Position - pb.Position).Magnitude
	if minR and d < minR then return false end
	if maxR and d > maxR then return false end
	return true
end

local resolveOwnedMonsterData

local PRIMARY_STAT_KEYS = {
	"Strength",
	"Defense",
	"Skill",
	"Speed",
	"Intelligence",
	"Luck",
}

local DEFAULT_STAT_VALUES = {
	Strength = 10,
	Defense = 10,
	Skill = 10,
	Speed = 10,
	Intelligence = 10,
	Luck = 10,
}

local DEFAULT_RESOURCE_VALUES = {
	MP = 0,
	MaxMP = 100,
}

local function pushStatSource(target, seen, tbl)
	if type(tbl) ~= "table" then
		return
	end
	if not seen[tbl] then
		seen[tbl] = true
		table.insert(target, tbl)
	end
end

local function collectSavedStatSources(monsterData, entry)
	local sources = {}
	local seen = setmetatable({}, { __mode = "k" })

	local function consider(node)
		if type(node) ~= "table" then
			return
		end
		if type(node.Stats) == "table" then
			pushStatSource(sources, seen, node.Stats)
		end
		if type(node.stats) == "table" then
			pushStatSource(sources, seen, node.stats)
		end

		local hasDirectStat = false
		for _, statName in ipairs(PRIMARY_STAT_KEYS) do
			local value = node[statName]
			if typeof(value) == "number" then
				hasDirectStat = true
				break
			end
		end
		if not hasDirectStat then
			local mpValue = node.MP or node.Mp or node.mp
			local maxMp = node.MaxMP or node.maxMP or node.maxMp
			if typeof(mpValue) == "number" or typeof(maxMp) == "number" then
				hasDirectStat = true
			end
		end
		if hasDirectStat then
			pushStatSource(sources, seen, node)
		end
	end

	consider(monsterData)

	if type(monsterData) == "table" then
		consider(monsterData.ActiveMonster)
		consider(monsterData.ActiveMonsterData)

		local monsters = monsterData.Monsters
		if type(monsters) == "table" then
			for _, candidate in pairs(monsters) do
				consider(candidate)
			end
		end
	end

	if entry and type(entry.Data) == "table" then
		consider(entry.Data)
		consider(entry.Data.ActiveMonster)
	end

	if #sources == 0 then
		local visited = setmetatable({}, { __mode = "k" })

		local function scan(node)
			if type(node) ~= "table" or visited[node] then
				return
			end
			visited[node] = true
			consider(node)
			for _, value in pairs(node) do
				if type(value) == "table" then
					scan(value)
				end
			end
		end

		scan(monsterData)
		if entry and type(entry.Data) == "table" then
			scan(entry.Data)
		end
	end

	return sources
end

local function readScalarStatFromSource(source, canonical)
	if type(source) ~= "table" then
		return nil
	end

	local rule = STAT_SYNC_RULES[canonical]
	local seenKeys = {}

	local function try(key)
		if typeof(key) ~= "string" or seenKeys[key] then
			return nil
		end
		seenKeys[key] = true
		local value = source[key]
		if typeof(value) == "number" then
			return value
		end
		return nil
	end

	local value = try(canonical)
	if value ~= nil then
		return value
	end

	if rule then
		value = try(rule.attr)
		if value ~= nil then
			return value
		end
		value = try(rule.alias)
		if value ~= nil then
			return value
		end
		value = try(rule.fallbackAttr)
		if value ~= nil then
			return value
		end
	end

	value = try(string.upper(canonical))
	if value ~= nil then
		return value
	end

	value = try(string.lower(canonical))
	if value ~= nil then
		return value
	end

	return nil
end

local function readScalarStatFromSources(sources, canonical)
	for _, source in ipairs(sources) do
		local value = readScalarStatFromSource(source, canonical)
		if value ~= nil then
			return value
		end
	end
	return nil
end

local function readMpFromSources(sources)
	local mpValue, maxValue
	for _, source in ipairs(sources) do
		if not mpValue then
			local v = source.MP or source.Mp or source.mp
			if typeof(v) == "number" then
				mpValue = v
			end
		end
		if not maxValue then
			local v = source.MaxMP or source.maxMP or source.maxMp
			if typeof(v) == "number" then
				maxValue = v
			end
		end
		if mpValue and maxValue then
			break
		end
	end
	return mpValue, maxValue
end

local function readHpFromSources(sources)
	local hpValue, maxHpValue
	for _, source in ipairs(sources) do
		if not hpValue then
			local v = source.Hp or source.HP or source.hp
			if typeof(v) == "number" then
				hpValue = v
			end
		end
		if not maxHpValue then
			local v = source.MaxHP or source.maxHP or source.maxHp
			if typeof(v) == "number" then
				maxHpValue = v
			end
		end
		if hpValue and maxHpValue then
			break
		end
	end
	return hpValue, maxHpValue
end

local function getEffectiveStats(model)
	local base = {}

	local ownerId = model and model:GetAttribute("OwnerId")
	local statSources = nil
	if ownerId and resolveOwnedMonsterData then
		local monsterData, entry = resolveOwnedMonsterData(ownerId)
		if monsterData or entry then
			statSources = collectSavedStatSources(monsterData, entry)
		end
	end
	statSources = statSources or {}

	for _, statName in ipairs(PRIMARY_STAT_KEYS) do
		local value = readScalarStatFromSources(statSources, statName)
		if typeof(value) ~= "number" then
			local attrValue = model and model:GetAttribute(statName)
			if typeof(attrValue) == "number" then
				value = attrValue
			end
		end
		if typeof(value) ~= "number" then
			value = DEFAULT_STAT_VALUES[statName]
		end
		base[statName] = value
	end

	local mpValue, maxMpValue = readMpFromSources(statSources)
	local attrMp = model and model:GetAttribute("MP")
	local attrMaxMp = model and model:GetAttribute("MaxMP")

	if typeof(mpValue) ~= "number" then
		if typeof(attrMp) == "number" then
			mpValue = attrMp
		elseif typeof(attrMaxMp) == "number" then
			mpValue = attrMaxMp
		else
			mpValue = DEFAULT_RESOURCE_VALUES.MP
		end
	end

	if typeof(maxMpValue) ~= "number" then
		if typeof(attrMaxMp) == "number" then
			maxMpValue = attrMaxMp
		elseif typeof(mpValue) == "number" then
			maxMpValue = mpValue
		else
			maxMpValue = DEFAULT_RESOURCE_VALUES.MaxMP
		end
	end

	base.MP = mpValue
	base.MaxMP = maxMpValue

	local hpValue, maxHpValue = readHpFromSources(statSources)
	if typeof(hpValue) ~= "number" and model then
		local attrHp = model:GetAttribute("Hp") or model:GetAttribute("HP")
		if typeof(attrHp) ~= "number" then
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum then
				attrHp = hum.MaxHealth
				maxHpValue = maxHpValue or hum.MaxHealth
			end
		end
		if typeof(attrHp) == "number" then
			hpValue = attrHp
		end
	end

	if typeof(maxHpValue) ~= "number" and typeof(hpValue) == "number" then
		maxHpValue = hpValue
	end

	if typeof(hpValue) == "number" then
		base.Hp = hpValue
		base.HP = hpValue
	end
	if typeof(maxHpValue) == "number" then
		base.MaxHP = maxHpValue
	end

	if typeof(base.MaxMP) == "number" and typeof(base.MP) == "number" then
		if base.MP > base.MaxMP then
			base.MaxMP = base.MP
		end
	else
		base.MP = base.MP or DEFAULT_RESOURCE_VALUES.MP
		base.MaxMP = base.MaxMP or DEFAULT_RESOURCE_VALUES.MaxMP
	end

	local mods, flags = StatusEffects.GetStatModifiers(model)
	for stat, v in pairs(mods.add) do
		base[stat] = (base[stat] or 0) + v
	end
	for stat, m in pairs(mods.mult) do
		base[stat] = math.floor((base[stat] or 0) * m + 0.5)
	end
	base.__flags = flags
	return base
end

local function payMp(model, cost)
	if cost <= 0 then return true end

	local mp = model:GetAttribute("MP")
	if mp == nil then
		local maxMp = model:GetAttribute("MaxMP") or 100
		model:SetAttribute("MP", maxMp)
		mp = maxMp
	end

	if mp < cost then return false end

	model:SetAttribute("MP", mp - cost)
	return true
end

local function regenMp(model, dt)
	local mp = model:GetAttribute("MP") or 0
	local maxmp = model:GetAttribute("MaxMP") or 100
	mp = math.min(maxmp, mp + (50 * dt))
	model:SetAttribute("MP", mp)
end

local function getMonsterMoves(monsterInstance)
	local race = monsterInstance:GetAttribute("Race") or "Default"
	local moves = {}
	local ownerIdAttr = monsterInstance:GetAttribute("OwnerId")
	local monsterData = nil

	if _G.MONSTERGENERATOR and ownerIdAttr then
		monsterData = _G.MONSTERGENERATOR.GetPlayerMonsterData(tonumber(ownerIdAttr))
	end

	if monsterData and monsterData.Data and monsterData.Data.Moves then
		-- FIX: Properly extract move data from the stored format
		for _, moveInfo in (monsterData.Data.Moves) do
			local moveData = moveInfo.move or moveInfo
			local id = moveData.id or moveData
			if type(id) == "string" then
				local m = MOVES_MODULE:GetMove(race, id)
				if m then
					table.insert(moves, m)
				else
					-- Fallback to BasicAttack if move not found
					local basicAttack = MOVES_MODULE:GetMove(race, "BasicAttack")
					if basicAttack then
						table.insert(moves, basicAttack)
					end
				end
			end
		end
	else
		-- FIX: Fallback to attribute-based move loading
		local count = monsterInstance:GetAttribute("MoveCount") or 0
		for i = 1, count do
			local id = monsterInstance:GetAttribute("Move" .. i)
			if id then
				local m = MOVES_MODULE:GetMove(race, id)
				if m then
					table.insert(moves, m)
				end
			end
		end
	end

	-- FIX: Ensure at least BasicAttack is available
	if #moves == 0 then
		local basicAttack = MOVES_MODULE:GetMove(race, "BasicAttack")
		if basicAttack then
			table.insert(moves, basicAttack)
		else
			-- Ultimate fallback
			table.insert(moves, DEFAULT_ATTACK)
		end
	end

	return moves
end

-- Core Combat Functions
function CombatManager.StartCombat(participants, maybeOptsOrCb, maybeCb)
	local opts, onCompleteCallback
	if typeof(maybeOptsOrCb) == "table" then
		opts, onCompleteCallback = maybeOptsOrCb, maybeCb
	else
		onCompleteCallback = maybeOptsOrCb
		opts = nil
	end

	local combatId = HttpService:GenerateGUID(false)
	print("Starting combat with ID:", combatId)

	onCombatEndCallbacks[combatId] = onCompleteCallback

	local combatData = {
		id = combatId,
		participants = {},
		teams = {},
		startTime = tick(),
		zone = nil
	}

	combatData.zone = COMBAT_ZONE.Create(combatId, participants, opts)


	for _, p in ipairs(combatData.participants) do
		if p.instance and p.instance.Parent then
			EnhancedMovement.InitializeMonster(p.instance)
			EnhancedMovement.SetZone(p.instance, combatData.zone) -- NEW
		end
	end

	local function safeRoot(model)
		return model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
	end

	local n = #combatData.participants
	if n > 0 then
		local center = combatData.zone.center
		local radius = math.max(6, (combatData.zone.radius or 30) * 0.75)
		local baseAngle = math.random() * math.pi * 2

		-- Compute ring slots
		local slots = table.create(n)
		for i = 1, n do
			local angle = baseAngle + ((i - 1) * (2 * math.pi / n))
			local pos = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			slots[i] = pos
		end

		-- Teleport + face opposite slot (i ↔ i + n/2)
		for i, profile in ipairs(combatData.participants) do
			local root = safeRoot(profile.instance)
			if root then
				local myPos = slots[i]
				local oppositeIndex = ((i - 1 + math.floor(n / 2)) % n) + 1
				local lookAt = slots[oppositeIndex]
				profile.instance:PivotTo(CFrame.lookAt(myPos, Vector3.new(lookAt.X, myPos.Y, lookAt.Z)))
			end
		end
	end

	for _, monsterInstance in ipairs(participants) do
		if not monsterInstance or not monsterInstance.Parent then continue end
		_G.STATES:RemoveState( monsterInstance, "Following")
		local participantId = monsterInstance:GetAttribute("OwnerId") or monsterInstance.Name
		local team = monsterInstance:GetAttribute("Team") or 1
		local humanoid = monsterInstance:FindFirstChildOfClass("Humanoid")
		local maxHp = humanoid and humanoid.MaxHealth or 100

		-- Initialize MP if needed
		local currentMp = monsterInstance:GetAttribute("MP")
		if currentMp == nil then
			local maxMp = monsterInstance:GetAttribute("MaxMP") or 100
			monsterInstance:SetAttribute("MP", maxMp)
			currentMp = maxMp
		end

		local personalityName = monsterInstance:GetAttribute("Personality") or "Unpredictable"
		local personalityData = PERSONALITIES_MODULE.Personalities[personalityName] or PERSONALITIES_MODULE.Personalities.Unpredictable

		local combatantProfile = {
			id = participantId,
			instance = monsterInstance,
			team = team,
			stats = { Hp = maxHp },
			currentHp = humanoid and humanoid.Health or maxHp,
			currentMp = currentMp,
			moves = getMonsterMoves(monsterInstance),
			personality = personalityData,
			target = nil,
			cooldowns = {},
			combatState = "DECIDING", -- Use string literal
			combatStateKey = nil, -- To store the key from _G.STATES
			stateStartTime = os.clock(),
			currentPlan = nil,
			maxTargetLevel = 0,
			behaviorProfile = {
				aggression = personalityData.movementStyle.aggressionMultiplier or 1.0,
				patience = 1.0,
				caution = 0.5,
				adaptability = 0.7,
			}
		}

		-- Initialize cooldowns
		for _, move in ipairs(combatantProfile.moves) do
			combatantProfile.cooldowns[move.id] = 0
		end

		if not combatantProfile.target then
			-- Set initial target to first enemy found
			for _, otherInstance in ipairs(participants) do
				if otherInstance ~= monsterInstance then
					local otherId = otherInstance:GetAttribute("OwnerId") or otherInstance.Name
					combatantProfile.target = combatData.participants[otherId]
					EnhancedMovement.SetTarget(monsterInstance, otherInstance)
					print(string.format("[Combat] %s initial target set to %s", participantId, otherId))
					break
				end
			end
		end

		combatData.participants[participantId] = combatantProfile
		combatParticipants[monsterInstance] = combatId

		if not combatData.teams[team] then
			combatData.teams[team] = {}
		end
		table.insert(combatData.teams[team], combatantProfile)

		combatantProfile.combatStateKey = _G.STATES:SetState(monsterInstance, "DECIDING")
		EnhancedMovement.InitializeMonster(monsterInstance)

		if _G.STATES:IsInState(monsterInstance, "Following") then
			local st = _G.STATES:GetStorage(monsterInstance)
			if st and st.Following then
				_G.STATES:RemoveState(monsterInstance, "Following", st.Following.self_key)
			end
		end

		_G.STATES:SetState(monsterInstance, "InCombat")
		combatantProfile.combatStateKey = _G.STATES:SetState(monsterInstance, "DECIDING")
		EnhancedMovement.InitializeMonster(monsterInstance)
		EnhancedMovement.SetZone(monsterInstance, combatData.zone)
	end



	--combatData.zone = COMBAT_ZONE.Create(combatId, participants, opts)
	activeCombats[combatId] = combatData

	if not combatLoopConnection or not combatLoopConnection.Connected then
		combatLoopConnection = RunService.Heartbeat:Connect(CombatManager.StateBasedCombatLoop)
	end

	return combatId
end

local function _reconcileControlStates(model)
	local _, flags = StatusEffects.GetStatModifiers(model)
	local isStun  = flags.Stunned or false
	local noMove  = flags.NoMove or false
	local noCast  = flags.NoCast or false

	-- Mirror "Stunned" into States (so Movement respects it)
	local st = _G.STATES and _G.STATES:GetStorage(model)
	if isStun and (not st or not st.Stunned) then
		_G.STATES:SetState(model, "Stunned") -- no duration; SE owns the timer
	elseif (not isStun) and st and st.Stunned then
		_G.STATES:RemoveState(model, "Stunned", st.Stunned.self_key)
	end

	-- Optional: expose convenience attributes for UI/logic
	model:SetAttribute("NoMove", noMove and true or nil)
	model:SetAttribute("NoCast", noCast and true or nil)
end

function CombatManager.EndCombat(combatId, results)
	local combatData = activeCombats[combatId]
	if not combatData or combatData._ended then return end

	combatData._ended = true
	print("Ending combat", combatId)

	-- IMPROVED WIN DETECTION
	local winningTeam = nil
	local winningInstance = nil

	-- Check which teams still have alive members
	local aliveTeams = {}
	for teamId, members in pairs(combatData.teams) do
		for _, member in ipairs(members) do
			if member.currentHp > 0 and isAlive(member.instance) then
				aliveTeams[teamId] = true
				winningInstance = member.instance
				break
			end
		end
	end

	-- Determine winner
	local aliveCount = 0
	local lastAliveTeam = nil
	for teamId in pairs(aliveTeams) do
		aliveCount += 1
		lastAliveTeam = teamId
	end

	if aliveCount == 1 then
		winningTeam = lastAliveTeam
		-- Find the actual winning instance
		for _, member in ipairs(combatData.teams[winningTeam]) do
			if member.currentHp > 0 and isAlive(member.instance) then
				winningInstance = member.instance
				break
			end
		end
	end

	print(string.format("[CombatEnd] Winner: Team %s, Instance: %s", 
		tostring(winningTeam), winningInstance and winningInstance.Name or "None"))

	CombatManager.ProcessCombatResults(combatData, winningTeam, winningInstance)

	-- Cleanup
	COMBAT_ZONE.Remove(combatId)

	for _, participant in pairs(combatData.participants) do
		if participant.instance then
			combatParticipants[participant.instance] = nil
			EnhancedMovement.Cleanup(participant.instance)
		end
	end

	activeCombats[combatId] = nil

	-- Call callback
	if onCombatEndCallbacks[combatId] then
		pcall(onCombatEndCallbacks[combatId], combatId, combatData, winningTeam)
		onCombatEndCallbacks[combatId] = nil
	end
end

-- State-Based Combat Loop
function CombatManager.StateBasedCombatLoop(dt)
	local currentTime = os.clock()

	SE_TICK_ACC += dt
	if SE_TICK_ACC >= 0.10 then
		StatusEffects.Tick(SE_TICK_ACC, _applyDotDamage)
		SE_TICK_ACC = 0
	end

	for combatId, combatData in pairs(activeCombats) do
		-- Count participants correctly
		local participantCount = 0
		for _ in pairs(combatData.participants) do participantCount += 1 end
		--print(string.format("[CombatLoop] Combat %s: %d participants", combatId, participantCount))

		-- Check for combat end
		local teamsAlive = {}
		for teamId, members in pairs(combatData.teams) do
			local isTeamAlive = false
			for _, member in ipairs(members) do
				if member.currentHp > 0 and isAlive(member.instance) then
					isTeamAlive = true
					break
				end
			end
			if isTeamAlive then
				teamsAlive[teamId] = true
			end
		end

		local aliveCount = 0
		for _ in pairs(teamsAlive) do aliveCount += 1 end

		if aliveCount <= 1 then
			local winner = nil
			if aliveCount == 1 then
				for teamId in pairs(teamsAlive) do
					if combatData.teams[teamId] and #combatData.teams[teamId] > 0 then
						winner = combatData.teams[teamId][1].instance
						break
					end
				end
			end
			CombatManager.EndCombat(combatId, {winner = winner})
			continue
		end

		-- Process each participant CORRECTLY
		for participantId, participant in pairs(combatData.participants) do
			if participant.currentHp <= 0 or not isAlive(participant.instance) then 
				--print(string.format("[CombatLoop] %s is dead, skipping", participantId))
				continue 
			end

			local stateDuration = currentTime - participant.stateStartTime
			--print(string.format("[CombatLoop] %s: state=%s, duration=%.2f/%.2f", 
			--participantId, participant.combatState, stateDuration, STATE_DURATIONS[participant.combatState] or 0))

			CombatManager.ProcessParticipantState(participant, combatData, currentTime, dt)
		end
	end
end

function CombatManager.ShowStateBillboard(participant, state)
	if not _G.EFFECTS or not _G.EFFECTS.Billboard then
		return
	end

	local monster = participant.instance
	if not monster or not monster.Parent then
		return
	end

	local billboardConfig = {
		Where = monster,
		Duration = 1.5,
		FadeTime = 0.3,
		Offset = Vector3.new(0, 0, 2),
		RiseHeight = 1,
		Size = 20
	}

	-- Different billboard styles for different states
	if state == "DECIDING" then
		billboardConfig.Text = "DECIDING"
		billboardConfig.Color = Color3.fromRGB(255, 255, 0) -- Yellow
	elseif state == "POSITIONING" then
		billboardConfig.Text = "POSITIONING"
		billboardConfig.Color = Color3.fromRGB(0, 150, 255) -- Blue
	elseif state == "REPOSITIONING" then
		billboardConfig.Text = "REPOSITIONING"
		billboardConfig.Color = Color3.fromRGB(0, 200, 100) -- Green
	elseif state == "RESTING" then
		billboardConfig.Text = "..."
		billboardConfig.Color = Color3.fromRGB(150, 150, 150) -- Gray
	elseif state == "REACTING" then
		billboardConfig.Text = "⚡"
		billboardConfig.Color = Color3.fromRGB(255, 100, 0) -- Orange
	elseif state == "CASTING" then
		billboardConfig.Text = "CAST"
		billboardConfig.Color = Color3.fromRGB(200, 0, 255) -- Purple
	elseif state == "DEFENDING" then
		billboardConfig.Text = "DEFENDING"
		billboardConfig.Color = Color3.fromRGB(0, 255, 255) -- Cyan
	else
		billboardConfig.Text = "❓"
		billboardConfig.Color = Color3.fromRGB(255, 255, 255) -- White
	end

	_G.EFFECTS.Billboard(billboardConfig)
end

function CombatManager.PlayStateSound(participant, state)
	if not _G.EFFECTS or not _G.EFFECTS.PlaySound then
		return
	end

	local monster = participant.instance
	if not monster or not monster.Parent then
		return
	end

	local soundConfig = {
		Where = monster,
		Volume = 0.3,
		Duration = 1,
		FadeOutTime = 0.5
	}

	-- Different sounds for different states
	if state == "DECIDING" then
		soundConfig.RandomPitch = true
		_G.EFFECTS.PlaySound("UIHover", soundConfig)
	elseif state == "POSITIONING" or state == "REPOSITIONING" then
		soundConfig.RandomPitch = true
		_G.EFFECTS.PlaySound("Footstep", soundConfig)
	elseif state == "CASTING" then
		soundConfig.Volume = 0.5
		_G.EFFECTS.PlaySound("MagicChime", soundConfig)
	elseif state == "DEFENDING" then
		soundConfig.Volume = 0.4
		_G.EFFECTS.PlaySound("ShieldUp", soundConfig)
	elseif state == "RESTING" then
		soundConfig.Volume = 0.2
		_G.EFFECTS.PlaySound("Rest", soundConfig)
	end
end

function CombatManager.ProcessParticipantState(participant, combatData, currentTime, dt)
	local state = participant.combatState
	local stateDuration = currentTime - participant.stateStartTime

	-- Billboard and sound effects for state transitions
	if stateDuration < 0.1 then -- Only when state just started
		CombatManager.ShowStateBillboard(participant, state)
		CombatManager.PlayStateSound(participant, state)
	end

	if stateDuration > 10 then
		print(string.format("[StateSafety]%s TIMEOUT, forcing DECIDING", participant.id))
		setTacticalState(participant, "DECIDING")
		return
	end

	_reconcileControlStates(participant.instance)

	-- Rest of the existing state processing logic remains the same...
	if state == "DECIDING" then
		if stateDuration >= STATE_DURATIONS.deciding then
			CombatManager.TacticalDecision(participant, combatData)
		end

	elseif state == "POSITIONING" then
		local plan = participant.currentPlan
		if not plan then
			setTacticalState(participant, "DECIDING")
			return
		end

		if plan.type == "attack" and plan.move then
			-- FIXED RANGE CHECK: Allow close-range moves to execute
			local minRange = plan.move.minRange or 0
			local maxRange = plan.move.maxRange or 999

			-- For close-range moves, be more lenient with minimum distance
			local effectiveMinRange = minRange
			if minRange == 0 then
				effectiveMinRange = -0.5  -- Allow being slightly "inside" for melee
			end

			local inRange = inRange(participant.instance, plan.target, effectiveMinRange, maxRange)

			if inRange then
				-- CLOSE ENOUGH: Execute attack even if not at perfect desired range
				setTacticalState(participant, "CASTING")
				EnhancedMovement.FaceTarget(participant.instance, plan.target)
				task.spawn(CombatManager.ExecuteTacticalMove, participant, plan.move, combatData, plan.target, plan.targetParticipant)

			elseif stateDuration > STATE_DURATIONS.positioning then
				-- POSITIONING FAILED: Try a close-range approach
				print(string.format("[State] %s positioning failed, trying aggressive approach", participant.id))
				setTacticalState(participant, "REPOSITIONING")
			else
				-- Continue positioning with adjusted strategy for close-range
				local movementIntention = "approach"
				if plan.desiredRange and plan.desiredRange < 5 then
					movementIntention = "close_distance"  -- Special intention for closing gap
				end

				EnhancedMovement.Update(participant.instance, {
					chosenMove = plan.move,
					zone = combatData.zone,
					intention = movementIntention,
					desiredRange = plan.desiredRange
				})
			end
		else
			if plan.type == "defend" then
				-- run the defend action now
				setTacticalState(participant, "DEFENDING")
				task.spawn(function()
					CombatManager.ExecuteDefend(participant, plan.duration)
					-- after bracing, go to RESTING
					setTacticalState(participant, "RESTING")
					participant.currentPlan = {
						type = "reposition",
						intention = "create_distance",
						duration = math.random(1.0, 2.0)
					}
				end)
				return
			elseif plan.type == "utility" and plan.move then
				setTacticalState(participant, "CASTING")
				local utilityTarget = plan.target or participant.instance
				EnhancedMovement.FaceTarget(participant.instance, utilityTarget)
				task.spawn(CombatManager.ExecuteTacticalMove, participant, plan.move, combatData, utilityTarget, plan.targetParticipant)
				return
			end
			-- Non-attack positioning
			if stateDuration >= (plan.duration or STATE_DURATIONS.positioning) then
				setTacticalState(participant, "RESTING")
			else
				EnhancedMovement.Update(participant.instance, {
					zone = combatData.zone,
					intention = plan.intention or "orbit"
				})
			end
		end

	elseif state == "CASTING" then
		-- Casting state is managed by ExecuteTacticalMove
		-- Just check for timeout as safety
		if stateDuration > 5 then -- 5 second max for casting
			print(string.format("[StateSafety] %s casting timeout, forcing reposition", participant.id))
			setTacticalState(participant, "REPOSITIONING")
		end

	elseif state == "REPOSITIONING" then
		if stateDuration >= (participant.currentPlan.duration or STATE_DURATIONS.repositioning) then
			setTacticalState(participant, "RESTING")
		else
			EnhancedMovement.Update(participant.instance, {
				zone = combatData.zone,
				intention = participant.currentPlan.intention or "orbit"
			})
		end

	elseif state == "RESTING" then
		if stateDuration >= STATE_DURATIONS.resting then
			setTacticalState(participant, "DECIDING")
		end

	elseif state == "REACTING" then
		if stateDuration >= STATE_DURATIONS.reacting then
			setTacticalState(participant, "DECIDING")
		end
	end
end

local function computeUtilityOptions(participant, context)
	local readyMoves = CombatManager.GetReadyMoves(participant)
	local attacker = participant.instance
	local options = {}
	local hasGuard = attacker and StatusEffects.Has(attacker, "GuardUp")
	local hasHaste = attacker and StatusEffects.Has(attacker, "Haste")

	for _, move in ipairs(readyMoves) do
		local tags = move.tags or {}
		local isUtility = false

		if (move.power or 0) <= 0 then
			isUtility = true
		end

		for _, tag in ipairs(tags) do
			if tag == "Buff" or tag == "Defensive" then
				isUtility = true
				break
			end
		end

		if not isUtility then
			iterateMoveEffects(move, function(effectType)
				if effectType == "BuffSelf" or effectType == "Shield" or effectType == "Haste" or effectType == "FortifyAura" or effectType == "Invulnerability" then
					isUtility = true
				end
			end)
		end

		if isUtility then
			local score = 10

			if context.isPressured then
				score += 15
			end

			if moveHasEffect(move, "Shield") then
				score += context.isPressured and 25 or 12
			end

			if moveHasEffect(move, "BuffSelf") then
				if hasGuard then
					score -= 18
				else
					score += 18
				end
			end

			if moveHasEffect(move, "Haste") then
				if hasHaste then
					score -= 12
				else
					score += 14
				end
			end

			if moveHasEffect(move, "FortifyAura") then
				score += 8
			end

			if table.find(tags, "Buff") then
				score += 6
			end

			if move.cooldown and move.cooldown > 0 then
				score += math.clamp(6 - move.cooldown, -8, 8)
			end

			table.insert(options, { move = move, score = score })
		end
	end

	return options
end

-- Tactical Decision Engine
function CombatManager.TacticalDecision(participant, combatData)
	local monster = participant.instance
	local target = participant.target and participant.target.instance

	if not target or not isAlive(target) then
		CombatManager.SelectNewTarget(participant, combatData)
		target = participant.target and participant.target.instance
		if not target then 
			-- No valid target, wait and try again
			setTacticalState(participant, "RESTING")
			participant.currentPlan = { type = "wait", duration = 2.0 }
			return 
		end
	end

	-- Reset EnhancedMovement if needed
	if not EnhancedMovement.InitializeMonster(monster) then
		print(string.format("[Decision] Failed to initialize movement for %s", participant.id))
		setTacticalState(participant, "RESTING")
		return
	end

	EnhancedMovement.SetTarget(monster, target)

	-- Build context and choose plan
	local context = CombatManager.BuildCombatContext(participant, target, combatData)
	local plan = CombatManager.ChooseActionPlan(participant, context)

	if plan then
		participant.currentPlan = plan
		setTacticalState(participant, "POSITIONING")

		-- Set preferred range for movement system
		if plan.move then
			EnhancedMovement.SetPreferredByMove(monster, plan.move)
		end
	else
		setTacticalState(participant, "RESTING")
	end

	return plan
end

function CombatManager.BuildCombatContext(participant, target, combatData)
	local myStats = getEffectiveStats(participant.instance)
	local targetStats = getEffectiveStats(target)
	local distance = (getPrimaryPart(participant.instance).Position - getPrimaryPart(target).Position).Magnitude
	local healthRatio = participant.currentHp / participant.stats.Hp
	local targetHealthRatio = 1.0
	if participant.target and participant.target.stats and participant.target.stats.Hp and participant.target.stats.Hp > 0 then
		targetHealthRatio = participant.target.currentHp / participant.target.stats.Hp
	else
		print(string.format("[Warning] Invalid target stats for %s", participant.instance))
	end
	local mpRatio = (participant.instance:GetAttribute("MP") or 0) / (participant.instance:GetAttribute("MaxMP") or 100)

	return {
		healthRatio = healthRatio,
		targetHealthRatio = targetHealthRatio,
		mpRatio = mpRatio,
		distance = distance,
		hasAdvantage = (myStats.Speed or 0) > (targetStats.Speed or 0) * 1.2,
		isPressured = healthRatio < 0.3,
		canPress = targetHealthRatio < 0.4,
		cooldownMoves = CombatManager.GetReadyMoves(participant),
		optimalRange = CombatManager.GetOptimalRange(participant)
	}
end

function CombatManager.ChooseActionPlan(participant, context)
	local personality = participant.personality
	local weights = {
		attack = personality.weights.attack or 40,
		reposition = personality.weights.reposition or 15,
		defensive = (personality.weights.defend or 5) + (personality.weights.retreat or 2),
		utility = (personality.weights.buffSelf or 0) + (personality.weights.debuff or 5)
	}

	local utilityOptions = computeUtilityOptions(participant, context)

	-- Context adjustments
	if context.isPressured then
		weights.defensive = weights.defensive * 2.5
		weights.reposition = weights.reposition * 1.8
	end

	if context.canPress then
		weights.attack = weights.attack * 1.6
	end

	if context.mpRatio < 0.3 then
		weights.attack = weights.attack * 0.5
		weights.utility = weights.utility * 0.3
	end

	-- PREVENT CHASE-RETREAT LOOPS: If very close, prefer attack over reposition
	if context.distance < 8 then
		weights.attack = weights.attack * 1.5
		weights.reposition = weights.reposition * 0.6
	end

	if #utilityOptions == 0 then
		weights.utility = math.max(weights.utility * 0.35, 1)
	else
		weights.utility = weights.utility * (1 + math.min(#utilityOptions, 3) * 0.35)
	end

	for key, value in pairs(weights) do
		local jitter = 0.9 + math.random() * 0.25
		weights[key] = math.max(0, value * jitter)
	end

	-- Choose category
	local choice = _G.FUNCTIONS:Decision(weights)

	-- Build specific plan
	if choice == "attack" then
		local move = CombatManager.SelectTacticalMove(participant, context)
		if move then
			-- DYNAMIC RANGE: Close-range moves should allow getting closer
			local desiredRange = move.maxRange * 0.7
			if move.minRange == 0 then
				-- Close-range/melee moves - get much closer
				desiredRange = math.max(2, move.maxRange * 0.3)
			elseif move.tags and (table.find(move.tags, "Melee") or table.find(move.tags, "Close")) then
				-- Melee moves - get very close
				desiredRange = math.max(1.5, move.maxRange * 0.2)
			end

			return {
				type = "attack",
				move = move,
				target = participant.target and participant.target.instance,
				targetParticipant = participant.target,
				desiredRange = desiredRange,
				followThrough = true
			}
		else
			-- Fallback to reposition if no moves available
			return {
				type = "reposition", 
				intention = "flank",
				duration = math.random(1.5, 2.5)
			}
		end
	elseif choice == "reposition" then
		-- VARIED REPOSITIONING: Not always retreat
		local intentions = {"flank", "create_distance", "orbit"}
		if context.isPressured then
			intentions = {"create_distance", "flank", "orbit"}  -- Prefer retreat when pressured
		else
			intentions = {"flank", "orbit", "create_distance"}  -- Prefer flanking normally
		end

		return {
			type = "reposition",
			intention = intentions[math.random(1, #intentions)],
			duration = math.random(1.0, 2.5)
		}
	elseif choice == "utility" then
		local move = CombatManager.SelectUtilityMove(participant, context, utilityOptions)
		if move then
			return {
				type = "utility",
				move = move,
				target = participant.instance,
				targetParticipant = participant,
				desiredRange = 0,
				followThrough = false
			}
		end
		-- fallback below if no utility move available
	end

	-- defensive fallback or default utility miss
	do
		local pick = math.random()
		if pick < 0.6 then
			return { type = "defend", duration = math.random(1.5, 2.5) }
		else
			return { type = "reposition", intention = "create_distance", duration = math.random(1.0, 2.0) }
		end
	end
end

function CombatManager.ExecuteDefend(participant, dur)
	local me = participant.instance
	local t  = math.max(1.2, dur or 2.0)

	-- Lock/pose (keep your states as you had)
	local defendKey = _G.STATES:SetState(me, "DEFENDING", t)
	_G.STATES:SetState(me, "Casting", t)
	EnhancedMovement.LockMovement(me, true, t)
	if _G.EFFECTS then _G.EFFECTS.PlaySound("Guard",{Where=me}) end

	if _G.EFFECTS then
		_G.EFFECTS.Billboard({
			Where = me,
			Text = "DEFEND",
			Color = Color3.fromRGB(80, 200, 255),
			Duration = 1.2,
			Size = 18,
			RiseHeight = 2
		})
		if _G.EFFECTS.AuraEffect then
			_G.EFFECTS.AuraEffect({
				Name = "DefendAura",
				LocationParts = {me.PrimaryPart or me:FindFirstChildWhichIsA("BasePart")},
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 200, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 120, 255))
				}),
				Duration = t,
				AuraReference = "Defend"
			})
		end
	end

	-- === CORE: damage taken reduction based on Defense ===
	local defense = me:GetAttribute("Defense") or 10
	-- DR curve: 0.20 + 0.006*Defense clamped to 50% max
	local dr = math.clamp(0.20 + defense * 0.006, 0.10, 0.50)
	me:SetAttribute("IncomingDR", dr)  -- read during damage resolution

	-- cooldown so it can't be spammed
	participant._defendCdUntil = os.clock() + 5.0

	task.delay(t, function()
		me:SetAttribute("IncomingDR", nil)
		_G.STATES:RemoveState(me, "Casting")
		_G.STATES:RemoveState(me, "DEFENDING", defendKey)
		EnhancedMovement.LockMovement(me, false)
	end)
end

local function weightedChoice(scoredMoves)
	if #scoredMoves == 0 then
		return nil
	end

	local minScore = math.huge
	for _, entry in ipairs(scoredMoves) do
		minScore = math.min(minScore, entry.score)
	end

	local totalWeight = 0
	for _, entry in ipairs(scoredMoves) do
		local baseWeight = math.max(0.1, (entry.score - minScore) + 1)
		-- Small random jitter to avoid deterministic loops
		local jitter = 0.85 + math.random() * 0.3
		entry._weight = baseWeight * jitter
		totalWeight += entry._weight
	end

	if totalWeight <= 0 then
		return scoredMoves[1].move
	end

	local roll = math.random() * totalWeight
	for _, entry in ipairs(scoredMoves) do
		roll -= entry._weight
		if roll <= 0 then
			return entry.move
		end
	end

	return scoredMoves[#scoredMoves].move
end



function CombatManager.SelectUtilityMove(participant, context, cachedOptions)
	local options = cachedOptions or computeUtilityOptions(participant, context)
	if #options == 0 then
		return nil
	end

	return weightedChoice(options)
end

function CombatManager.SelectTacticalMove(participant, context)
	local readyMoves = CombatManager.GetReadyMoves(participant)
	if #readyMoves == 0 then
		-- FIX: Return DefaultAttack if no moves are ready
		print(string.format("[Combat] No moves ready for %s, using DefaultAttack", participant.id))
		return DEFAULT_ATTACK
	end

	-- Rest of the existing move selection logic...
	local scoredMoves = {}
	for _, move in ipairs(readyMoves) do
		local score = 0

		-- Only score damage moves, skip pure utility moves for attack selection
		if (move.power or 0) > 0 then
			score = score + (move.power or 0) * 0.1

			local rangeScore = 0
			if context.distance <= (move.maxRange or 999) and context.distance >= (move.minRange or 0) then
				rangeScore = 50
			elseif context.distance < (move.minRange or 0) then
				rangeScore = -30
			else
				local rangeDiff = context.distance - (move.maxRange or 999)
				rangeScore = -rangeDiff * 2
			end
			score = score + rangeScore

			local mpCost = move.mpCost or 0
			if mpCost > 0 then
				score = score - (mpCost * 0.5)
			end

			if context.distance < 6 and move.tags and table.find(move.tags, "Melee") then
				score = score + 25
			end

			if context.isPressured and moveHasEffect(move, "Stun") then
				score = score + 25
			end

			if context.canPress and move.power and move.power > 30 then
				score = score + 20
			end

			table.insert(scoredMoves, {move = move, score = score})
		end
	end

	-- FIX: If no damage moves scored, use DefaultAttack
	if #scoredMoves == 0 then
		return DEFAULT_ATTACK
	end

	local chosen = weightedChoice(scoredMoves)
	return chosen or DEFAULT_ATTACK
end

function CombatManager.GetReadyMoves(participant)
	local ready = {}
	local currentTime = os.clock()

	for _, move in ipairs(participant.moves) do
		local cooldownEnd = participant.cooldowns[move.id] or 0
		local hasMp = (participant.instance:GetAttribute("MP") or 0) >= (move.mpCost or 0)
		if currentTime >= cooldownEnd and hasMp then
			table.insert(ready, move)
		end
	end

	-- FIX: If no damage moves available, add DefaultAttack
	if #ready == 0 then
		local hasDamageMove = false
		for _, move in ipairs(participant.moves) do
			if (move.power or 0) > 0 then
				hasDamageMove = true
				break
			end
		end

		if not hasDamageMove then
			-- Add DefaultAttack as fallback
			table.insert(ready, DEFAULT_ATTACK)
			print(string.format("[Combat] No damage moves available for %s, using DefaultAttack", participant.id))
		end
	end

	return ready
end


function CombatManager.GetOptimalRange(participant)
	local maxRange = 0
	for _, move in ipairs(participant.moves) do
		if move.maxRange and move.maxRange > maxRange then
			maxRange = move.maxRange
		end
	end
	return maxRange * 0.7
end

-- Move Execution
function CombatManager.ExecuteTacticalMove(participant, move, combatData, explicitTarget, explicitTargetParticipant)
	local attacker = participant.instance
	local targetParticipant = explicitTargetParticipant or participant.target
	local target = explicitTarget or (targetParticipant and targetParticipant.instance)

	if not attacker or not target or not attacker.Parent or not target.Parent then
		setTacticalState(participant, "DECIDING")
		return
	end

	if not isAlive(attacker) or not isAlive(target) then
		setTacticalState(participant, "DECIDING")
		return
	end
	-- Set casting state
	-- Set casting state
	local castKey = _G.STATES:SetState(attacker, "Casting", (move.castTime or 0.8) + 0.2)
	participant.combatStateKey = castKey -- Store the key
	EnhancedMovement.LockMovement(attacker, true)

	-- Check MP and cast restrictions
	local _, flags = StatusEffects.GetStatModifiers(attacker)
	if flags.NoCast or not payMp(attacker, move.mpCost or 0) then
		_G.STATES:RemoveState(attacker, "Casting", castKey) -- Use the key
		EnhancedMovement.LockMovement(attacker, false)
		setTacticalState(participant, "DECIDING")
		return
	end

	-- Play cast animation and effects
	Bridge.PlayCast(attacker, move.id, move.castTime)

	if _G.EFFECTS then
		_G.EFFECTS.PlaySound(move.sfxStart or "DefaultImpact", {Where = attacker})
		if move.vfxCast then
			_G.EFFECTS.EmitterEffect({Name = move.vfxCast, Position = getPrimaryPart(attacker)})
		end
	end

	-- Wait for cast time
	local race = attacker:GetAttribute("Race") or "Default"
	local animData = AnimationManager:GetCastAnimation(race)

	if animData and animData.AnimationId ~= "" then
		AnimationHandler:PlayCastOnce(attacker, animData.AnimationId, {
			fallback = move.castTime,
			speed = move.castSpeed or 1.0,
		})
		task.wait(move.castTime)
	else
		task.wait(move.castTime)
	end

	-- Check if still valid after cast
	if not attacker or not target or not attacker.Parent or not target.Parent then
		_G.STATES:RemoveState(attacker, "Casting", castKey) -- Use the key
		EnhancedMovement.LockMovement(attacker, false)
		setTacticalState(participant, "DECIDING")
		return
	end

	local targetLevelValue = target:GetAttribute("Level")
	local isEnemyTarget = true
	if targetParticipant and targetParticipant.team == participant.team then
		isEnemyTarget = false
	elseif target == attacker then
		isEnemyTarget = false
	end

	if isEnemyTarget and typeof(targetLevelValue) == "number" then
		local currentMax = participant.maxTargetLevel
		if typeof(currentMax) ~= "number" or targetLevelValue > currentMax then
			participant.maxTargetLevel = targetLevelValue
		end
	end

	-- Resolve the attack
	local attStats = getEffectiveStats(attacker)
	local tgtStats = getEffectiveStats(target)
	local tags = move.tags or {}
	local isUtilityMove = (move.power or 0) <= 0

	if not isUtilityMove then
		for _, tag in ipairs(tags) do
			if tag == "Buff" or tag == "Defensive" then
				isUtilityMove = true
				break
			end
		end
	end

	if not isUtilityMove then
		iterateMoveEffects(move, function(effectType)
			if effectType == "BuffSelf" or effectType == "Shield" or effectType == "FortifyAura" or effectType == "Haste" or effectType == "Invulnerability" then
				isUtilityMove = true
			end
		end)
	end

	if not isUtilityMove then
		local outcome = CombatMath.ResolveHit(attStats, tgtStats, move)
		if outcome.hit then
			local dmg = CombatMath.ComputeDamage(attStats, tgtStats, move, outcome.crit)
			local dr = target:GetAttribute("IncomingDR")
			if dr and dr > 0 then
				dmg = math.max(0, math.floor(dmg * (1 - math.clamp(dr, 0, 0.8)) + 0.5))
			end

			local residual, absorbed = StatusEffects.AbsorbWithShield(target, dmg)
			if residual > 0 then
				local humanoid = target:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid:TakeDamage(residual)
					if targetParticipant then
						targetParticipant.currentHp = humanoid.Health
					end
				end

				-- Show damage billboard
				if _G.EFFECTS and _G.EFFECTS.Billboard then
					_G.EFFECTS.Billboard({
						Where = target,
						Text = tostring(math.max(1, math.floor(residual))),
						Color = outcome.crit and Color3.fromRGB(255, 100, 0) or Color3.fromRGB(255, 50, 50),
						Duration = 1.2,
						Size = outcome.crit and 25 or 20,
						Offset = Vector3.new(0, 4, 0)
					})
				end

				-- Play hit sound and effect
				if _G.EFFECTS then
					if outcome.crit then
						_G.EFFECTS.PlaySound("CriticalHit", {Where = target, Volume = 0.6})
						_G.EFFECTS.HitGlow({
							Where = target,
							Type = "Full",
							FillColor = Color3.fromRGB(255, 200, 0),
							OutlineColor = Color3.fromRGB(255, 100, 0),
							GlowDuration = 0.8
						})
					else
						_G.EFFECTS.PlaySound("Hit", {Where = target, Volume = 0.4, RandomPitch = true})
						_G.EFFECTS.HitGlow({
							Where = target,
							Type = "Outline",
							OutlineColor = Color3.fromRGB(255, 50, 50),
							GlowDuration = 0.4
						})
					end
				end
			end

			Bridge.PlayImpact(attacker, target, move.id)
			CombatManager.ApplyMoveEffects(attacker, target, move)
		else
			-- Show miss effect
			if _G.EFFECTS then
				_G.EFFECTS.Billboard({
					Where = target,
					Text = "MISS",
					Color = Color3.fromRGB(150, 150, 150),
					Duration = 1.2,
					Size = 18
				})
				_G.EFFECTS.PlaySound("Miss", {Where = target, Volume = 0.3})
			end
		end
	else
		CombatManager.ApplyMoveEffects(attacker, target, move)
		if _G.EFFECTS and _G.EFFECTS.Billboard then
			_G.EFFECTS.Billboard({
				Where = attacker,
				Text = move.name or "BUFF",
				Color = Color3.fromRGB(200, 255, 120),
				Duration = 1.2,
				Size = 18,
				RiseHeight = 2.5
			})
		end
	end

	-- Set cooldown
	participant.cooldowns[move.id] = os.clock() + (move.cooldown or 0)

	-- Cleanup and transition to repositioning
	_G.STATES:RemoveState(attacker, "Casting", castKey) -- Use the key
	EnhancedMovement.LockMovement(attacker, false)
	Bridge.PlayEnd(attacker, move.id)

	setTacticalState(participant, "REPOSITIONING")
	participant.currentPlan = {
		type = "reposition",
		intention = "create_distance",
		duration = math.random(1.0, 2.0)
	}
end

function CombatManager.ApplyMoveEffects(attacker, target, move)
	if not move or not move.effects or #move.effects == 0 then
		return
	end

	local function resolveRecipient(effect)
		local destination = effect.target
		if destination == "attacker" or destination == "self" then
			return attacker
		end
		return target
	end

	local function findAuraPart(model)
		if not model then
			return nil
		end
		return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	end

	iterateMoveEffects(move, function(effectType, entry)
		local effect = typeof(entry) == "table" and entry or { type = effectType, status = effectType }
		local statusName = effect.status or effectType
		local recipient = resolveRecipient(effect)

		local alreadyFortified = nil
		if effectType == "FortifyAura" and attacker then
			alreadyFortified = StatusEffects.Has(attacker, "GuardUp")
		end

		if recipient and statusName then
			local payload = {
				name = statusName,
				dur = effect.duration or effect.dur or 0,
				stacks = effect.stacks or 1,
				power = effect.power,
				dps = effect.dps,
			}
			StatusEffects.Apply(recipient, payload, attacker)
		end

		if not (_G.EFFECTS and _G.EFFECTS.AuraEffect) then
			return
		end

		if effectType == "FortifyAura" and attacker then
			local basePart = findAuraPart(attacker)
			if basePart then
				_G.EFFECTS.AuraEffect({
					Name = "FortifyAura",
					LocationParts = {basePart},
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(160, 215, 255)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 140, 255))
					}),
					Duration = alreadyFortified and (effect.refreshDuration or effect.duration or effect.dur or 0) or (effect.duration or effect.dur or 0),
					AuraReference = "Fortify",
				})
			end
			return
		end

		if effectType == "Shield" then
			local basePart = findAuraPart(recipient)
			if basePart then
				_G.EFFECTS.AuraEffect({
					Name = "ShieldAura",
					LocationParts = {basePart},
					Color = ColorSequence.new(Color3.fromRGB(100, 150, 255)),
					Duration = effect.duration or effect.dur or 0,
					AuraReference = "Shield",
				})
			end
		elseif effectType == "BuffSelf" and attacker then
			local basePart = findAuraPart(attacker)
			if basePart then
				_G.EFFECTS.AuraEffect({
					Name = "BuffAura",
					LocationParts = {basePart},
					Color = ColorSequence.new(Color3.fromRGB(255, 200, 0)),
					Duration = effect.duration or effect.dur or 0,
					AuraReference = "GuardUp",
				})
			end
		elseif effectType == "Haste" and attacker then
			local basePart = findAuraPart(attacker)
			if basePart then
				_G.EFFECTS.AuraEffect({
					Name = "SpeedAura",
					LocationParts = {basePart},
					Color = ColorSequence.new(Color3.fromRGB(0, 255, 100)),
					Duration = effect.duration or effect.dur or 0,
					AuraReference = "Haste",
				})
			end
		end
	end)
end

-- Target Selection
function CombatManager.SelectNewTarget(participant, combatData)
	local myTeam = participant.team
	local potentialTargets = {}

	for teamId, members in pairs(combatData.teams) do
		if teamId ~= myTeam then
			for _, member in ipairs(members) do
				if member.currentHp > 0 and isAlive(member.instance) then
					table.insert(potentialTargets, member)
				end
			end
		end
	end

	if #potentialTargets > 0 then
		participant.target = potentialTargets[math.random(1, #potentialTargets)]
		EnhancedMovement.SetTarget(participant.instance, participant.target.instance)
	end
end

-- Combat Results
local function computeTargetLevelMultiplier(participant, combatData)
	local inst = participant.instance
	if not inst or not inst.Parent then
		return 1
	end

	local tracked = participant.maxTargetLevel
	if typeof(tracked) ~= "number" or tracked <= 0 then
		tracked = nil
	end

	if not tracked then
		for teamId, members in pairs(combatData.teams) do
			if teamId ~= participant.team then
				for _, enemy in ipairs(members) do
					local enemyInst = enemy.instance
					if enemyInst and enemyInst.Parent then
						local enemyLevel = enemyInst:GetAttribute("Level")
						if typeof(enemyLevel) == "number" and enemyLevel > 0 then
							tracked = math.max(tracked or 0, enemyLevel)
						end
					end
				end
			end
		end
	end

	if not tracked then
		return 1
	end

	local ownLevel = inst:GetAttribute("Level")
	if typeof(ownLevel) ~= "number" or ownLevel <= 0 then
		ownLevel = tracked
	end

	local delta = tracked - ownLevel
	if delta == 0 then
		return 1
	end

	local STEP = 0.1
	if delta > 0 then
		return math.clamp(1 + delta * STEP, 1, 2.0)
	else
		return math.clamp(1 / (1 + (-delta) * STEP), 0.5, 1)
	end
end

local XP_REWARD_FRACTION = 0.02
local XP_REWARD_LOSS_FRACTION = 0.25

resolveOwnedMonsterData = function(ownerId)
	local ownerKey = tonumber(ownerId)
	if not ownerKey then
		return nil, nil
	end

	local monsterData
	local entry

	if _G.MONSTERGENERATOR and typeof(_G.MONSTERGENERATOR.GetPlayerMonsterData) == "function" then
		entry = _G.MONSTERGENERATOR.GetPlayerMonsterData(ownerKey)
		if entry and type(entry.Data) == "table" then
			monsterData = entry.Data
		end
	end

	if not monsterData and _G.DATA and typeof(_G.DATA.Get) == "function" then
		local ok, playerStore = pcall(function()
			return _G.DATA:Get(ownerKey)
		end)
		if ok and type(playerStore) == "table" and type(playerStore.Monster) == "table" then
			monsterData = playerStore.Monster
		end
	end

	return monsterData, entry
end

local function highestEnemyLevel(participant, combatData)
	local highest = 0
	for teamId, members in pairs(combatData.teams) do
		if teamId ~= participant.team then
			for _, enemy in ipairs(members) do
				local enemyInst = enemy.instance
				if enemyInst and enemyInst.Parent then
					local enemyLevel = enemyInst:GetAttribute("Level")
					if typeof(enemyLevel) == "number" and enemyLevel > highest then
						highest = enemyLevel
					end
				end
			end
		end
	end
	return highest
end

local function computeCombatExperience(participant, combatData, didWin, multiplier)
	local baseLevel = highestEnemyLevel(participant, combatData)
	if baseLevel <= 0 then
		local inst = participant.instance
		baseLevel = (inst and inst:GetAttribute("Level")) or 1
	end
	baseLevel = math.clamp(math.floor(baseLevel), 1, Leveling.MaxLevel)

	local xpToNext = Leveling.GetExperienceToNextLevel(baseLevel)
	if xpToNext <= 0 then
		local probe = baseLevel - 1
		while probe >= 1 and xpToNext <= 0 do
			xpToNext = Leveling.GetExperienceToNextLevel(probe)
			probe -= 1
		end
	end
	if xpToNext <= 0 then
		xpToNext = 1000
	end

	local reward = math.floor(xpToNext * XP_REWARD_FRACTION)
	reward = math.max(reward, 50)
	reward = math.floor(reward * (multiplier or 1))

	if not didWin then
		reward = math.floor(reward * XP_REWARD_LOSS_FRACTION)
	end

	return math.max(reward, 0)
end

local function applyCombatExperience(participant, combatData, didWin, multiplier, monsterData, ownerPlayer, generatorEntry)
	if not monsterData then
		return
	end

	local reward = computeCombatExperience(participant, combatData, didWin, multiplier)
	if reward <= 0 then
		return
	end

	Leveling.AddExperience(monsterData, reward, {
		Model = participant.instance,
		Player = ownerPlayer,
	})

	if generatorEntry and type(generatorEntry.Data) == "table" then
		generatorEntry.Data.Experience = monsterData.Experience
		generatorEntry.Data.Level = monsterData.Level
		generatorEntry.Data.LevelingBaseStats = monsterData.LevelingBaseStats
	end
end

function CombatManager.ProcessCombatResults(combatData, winningTeam, winningInstance)
	print("Processing combat results...")

	-- Debug: Print all participants status
	for participantId, participant in pairs(combatData.participants) do
		local alive = participant.currentHp > 0 and isAlive(participant.instance)
		print(string.format("[Result] %s: HP=%d, Alive=%s", 
			participantId, participant.currentHp, tostring(alive)))
	end

	-- === RESULTS: wins + stat increases via _G.FUNCTIONS.distributePoints ===
	local function applyResults(participant, didWin, multiplier, combatData)
		local m = participant.instance
		if not (m and m.Parent) then return end
		local ownerId = m:GetAttribute("OwnerId")
		local ownerKey = tonumber(ownerId)
		local ownerPlr = ownerKey and game.Players:GetPlayerByUserId(ownerKey) or nil
		local monsterData, entry = resolveOwnedMonsterData(ownerId)

		-- Wins/Losses as attributes (visible & simple)
		if didWin then
			m:SetAttribute("Wins", (m:GetAttribute("Wins") or 0) + 1)
			if ownerId and _G.DATA and typeof(_G.DATA.Get) == "function" then
				local ok, store = pcall(function()
					return _G.DATA:Get(ownerId)
				end)
				if ok and type(store) == "table" and type(store.Monster) == "table" then
					store.Monster.Wins = (store.Monster.Wins or 0) + 1
				end
			end
		else
			print("Loss")
		end

		-- Stat bumps: 2 points for win, 1 for loss
		local basePoints = didWin and 5 or 10
		local scaledPoints = basePoints * (multiplier or 1)
		local points = math.max(1, math.floor(scaledPoints + 0.5))
		local keys = {"Hp","Mp","Strength","Defense","Skill","Speed","Intelligence"} -- attrs you actually set

		local dist
		if _G.FUNCTIONS and _G.FUNCTIONS.distributePoints then
			local ok, res = pcall(function() return _G.FUNCTIONS.distributePoints(keys, points) end)
			dist = ok and res or nil
		end
		if not dist then
			-- simple fallback: random +1s
			dist = {}
			for i = 1, points do
				local k = keys[math.random(1, #keys)]
				dist[k] = (dist[k] or 0) + 1
			end
		end

		local StatUpdate = game.ReplicatedStorage.Remotes.StatUpdate
		if ownerPlr then
			StatUpdate:FireClient(ownerPlr, dist, ownerId)
			if didWin then
				_G.EFFECTS.PlaySound("Success", {Where = ownerPlr.Character})
			else
				_G.EFFECTS.PlaySound("Fail", {Where = ownerPlr.Character})
			end
		end
		-- Apply bumps to Attributes; for Hp also bump Humanoid.MaxHealth
		for k, add in pairs(dist) do
			if add and add ~= 0 then
				if k == "Hp" then
					local hum = m:FindFirstChildOfClass("Humanoid")
					if hum then
						hum.MaxHealth = math.max(1, math.floor(hum.MaxHealth + add))
						-- don't fully heal; but keep current within new max
						hum.Health = math.clamp(hum.Health, 1, hum.MaxHealth)
					end
					m:SetAttribute("Hp", (m:GetAttribute("Hp") or 100) + add)
				elseif k == "Mp" then
					m:SetAttribute("MP", (m:GetAttribute("MP") or 100) + add)
					m:SetAttribute("MaxMP", (m:GetAttribute("MaxMP") or 100) + add)
				else
					m:SetAttribute(k, (m:GetAttribute(k) or 0) + add)
				end
			end
		end

		m:SetAttribute("LastRewardMultiplier", multiplier or 1)

		applyCombatExperience(participant, combatData, didWin, multiplier, monsterData, ownerPlr, entry)

		-- Optionally notify your data layer
		if _G.MONSTERGENERATOR and _G.MONSTERGENERATOR.GetPlayerMonsterData then
			local pid = tonumber(ownerId or 0)
			if pid and pid > 0 then
				local generatorEntry = entry or _G.MONSTERGENERATOR.GetPlayerMonsterData(pid)
				if generatorEntry and generatorEntry.Data then
					generatorEntry.Data.Wins = m:GetAttribute("Wins") or generatorEntry.Data.Wins or 0

					local statsTargets = gatherStatsTables(pid, generatorEntry)
					if #statsTargets > 0 then
						syncMonsterStatsIntoTables(m, statsTargets)
					end
				end
			end
		end
	end

	-- Apply results to everyone
	for _, participant in pairs(combatData.participants) do
		if participant.instance and participant.instance.Parent then
			local didWin = (winningTeam ~= nil) and (participant.team == winningTeam)
			local levelMultiplier = computeTargetLevelMultiplier(participant, combatData)
			applyResults(participant, didWin, levelMultiplier, combatData)
		end
	end

	if winningTeam then
		for _, member in ipairs(combatData.teams[winningTeam]) do
			local ownerId = member.instance:GetAttribute("OwnerId")
			if ownerId and _G.DATA then
				local playerData = _G.DATA:Get(ownerId)
				local monsterData = playerData and playerData.Monster
				if monsterData then
					-- Wins were already incremented in applyResults; just resolve unlocks here.
					MoveUnlocks.ResolveUnlocks(monsterData, "combat", { damageDealt = member._damage or 0 })
				end
			end
		end
	end

	-- === Your existing reset for survivors ===
	for _, participant in pairs(combatData.participants) do
		if participant.instance and participant.instance.Parent then
			local ownerId = participant.instance:GetAttribute("OwnerId")

			if participant.currentHp <= 0 then
				if ownerId then
					local monsterData, entry = resolveOwnedMonsterData(ownerId)
					local ownerPlr = nil
					local ownerKey = tonumber(ownerId)
					if ownerKey then
						ownerPlr = game.Players:GetPlayerByUserId(ownerKey)
					end
					if monsterData then
						Leveling.ApplyDeathPenalty(monsterData, 0.2, {
							Model = participant.instance,
							Player = ownerPlr,
						})
						if entry and entry.Data then
							entry.Data.Experience = monsterData.Experience
							entry.Data.Level = monsterData.Level
							entry.Data.LevelingBaseStats = monsterData.LevelingBaseStats
						end
					end
				end
				_G.STATES:SetState(participant.instance, "Dead")
			else
				-- Reset combat states
				if participant.combatState and participant.combatStateKey then
					if _G.STATES:IsInState(participant.instance, participant.combatState) then
						_G.STATES:RemoveState(participant.instance, participant.combatState, participant.combatStateKey)
					end
				end

				local st = _G.STATES:GetStorage(participant.instance)
				if st then
					if st.InCombat then _G.STATES:RemoveState(participant.instance, "InCombat", st.InCombat.self_key) end
					if st.Attacking then _G.STATES:RemoveState(participant.instance, "Attacking", st.Attacking.self_key) end
					if st.Casting then _G.STATES:RemoveState(participant.instance, "Casting", st.Casting.self_key) end
					if st.Defending then _G.STATES:RemoveState(participant.instance, "Defending", st.Defending.self_key) end
				end

				---- Restore movement
				--local humanoid = participant.instance:FindFirstChildOfClass("Humanoid")
				--if humanoid then
				--	humanoid.AutoRotate = true
				--	if humanoid.WalkSpeed <= 0 then
				--		humanoid.WalkSpeed = 16
				--	end
				--end

				EnhancedMovement.Cleanup(participant.instance)

				-- Player monsters follow owner OR go idle
				if ownerId then
					local ownerPlr = game.Players:GetPlayerByUserId(ownerId)
					if ownerPlr and ownerPlr.Character then
						_G.STATES:SetState(participant.instance, "Following")
					else
						_G.STATES:SetState(participant.instance, "Idle")
					end
				else
					_G.STATES:SetState(participant.instance, "Idle")
				end
			end
		end
	end

	for participantId, participant in pairs(combatData.participants) do
		if participant.currentHp > 0 then
			local ownerId = participant.instance:GetAttribute("OwnerId")
			if ownerId then
				local player = game.Players:GetPlayerByUserId(ownerId)
				if player and _G.MOVE_LEARNING then
					_G.MOVE_LEARNING.OnCombatEnd(player, {
						won = participant.team == winningTeam,
						survived = true,
						damageDealt = participant.damageDealt or 0
					})
				end
			end
		end
	end
end

return CombatManager
