-- ReplicatedStorage/Modules/Moves.luau
-- Recreated to align with the new Races module (Digimon-like branching; Fledgeling MVP)
-- API kept backward-compatible with existing callers (MonsterGenerator, CombatManager)

local Moves = {}
Moves.__index = Moves

-- ⬇️ ADICIONE PRÓXIMO AO TOPO (após RARITY/DEFAULT_RARITY_WEIGHTS/ORDERED_RARITIES)
local DEFAULTS = {
	-- valores base
	baseAccuracy = 0.88,          -- 88% base
	baseCrit     = 0.05,          -- 5% base
	mpCostBase   = 0,             -- custo fixo
	mpPerPower   = 0.30,          -- custo adicional por ponto de power
	minMpCost    = 0,             -- nunca negativo
	maxAccuracy  = 0.98,
	minAccuracy  = 0.55,
	maxCrit      = 0.35,
	-- multiplicadores por raridade (encarece e às vezes reduz accuracy por moves poderosos)
	rarityMpMult = {
		Amateur=1.00, Advanced=1.10, Specialist=1.20, Ascended=1.35, Primordial=1.50
	},
	-- ajustes por tag (aditivos/multiplicativos)
	tagAccuracyAdj = {
		Melee= 0.04, Ranged=-0.03, Magic=-0.02, AoE=-0.04, Mobility= 0.03, Defensive= 0.02,
	},
	tagCritAdj = {
		Melee= 0.01, Ranged= 0.00, Magic= 0.00, ["GapClose"]= 0.02, ["MultiHit"]= -0.01, ["AoE"]=-0.01,
	},
	tagMpMult = {
		Magic=1.15, Ranged=1.05, Melee=0.95, Defensive=1.10, Mobility=0.90, Universal=1.00,
	},
	-- moves com cast longo tendem a ter menos accuracy (mais punidos se errarem)
	castAccuracyPenaltyPerSec = 0.06,
	-- moves com muito alcance tendem a ter menos accuracy
	rangeAccuracyPenaltyPer10 = 0.015,
}



local function clamp(x, a, b) return math.max(a, math.min(b, x)) end

local function computeAccuracy(m)
	local acc = DEFAULTS.baseAccuracy
	-- penaliza cast longo
	if m.castTime and m.castTime > 0 then
		acc -= (m.castTime) * DEFAULTS.castAccuracyPenaltyPerSec
	end
	-- penaliza muito alcance efetivo
	local mr = (m.maxRange or 0)
	acc -= (mr / 10) * DEFAULTS.rangeAccuracyPenaltyPer10
	-- aplica ajustes por tags
	if m.tags then
		for _, t in ipairs(m.tags) do
			local adj = DEFAULTS.tagAccuracyAdj[t]
			if adj then acc += adj end
		end
	end
	return clamp(acc, DEFAULTS.minAccuracy, DEFAULTS.maxAccuracy)
end

local function computeCrit(m)
	local crit = DEFAULTS.baseCrit
	if m.tags then
		for _, t in ipairs(m.tags) do
			local adj = DEFAULTS.tagCritAdj[t]
			if adj then crit += adj end
		end
	end
	-- golpes de alto power tendem a ter crit levemente maior
	if (m.power or 0) >= 35 then crit += 0.02 end
	if (m.power or 0) >= 45 then crit += 0.01 end
	return clamp(crit, 0, DEFAULTS.maxCrit)
end

local function computeMpCost(m)
	-- custo básico: proporcional ao poder, ajustado por raridade e tags
	local power = math.max(0, m.power or 0)
	local rar   = m.rarity or "Amateur"
	local base  = DEFAULTS.mpCostBase + power * DEFAULTS.mpPerPower
	local mult  = (DEFAULTS.rarityMpMult[rar] or 1.0)
	-- tags podem baratear/encarecer
	if m.tags then
		for _, t in ipairs(m.tags) do
			mult *= (DEFAULTS.tagMpMult[t] or 1.0)
		end
	end
	-- moves utilitários (Buff/Shield/Mobility) com power 0 ainda custam algo leve
	if power == 0 then
		base = 6
	end
	local cost = math.max(DEFAULTS.minMpCost, math.floor(base * mult + 0.5))
	return cost
end

local function normalizeMove(m)
	-- Se o designer já definiu explicitamente, respeita.
	if m.accuracy == nil then m.accuracy = computeAccuracy(m) end            -- 0.0..1.0
	if m.critChance == nil then m.critChance = computeCrit(m) end           -- 0.0..1.0
	if m.mpCost == nil then m.mpCost = computeMpCost(m) end                 -- inteiros
	return m
end


---------------------------------------------------------------------
-- Rarity tiers and selection weights (cosmic convention retained)
---------------------------------------------------------------------
local RARITY = {
	Amateur    = "C",
	Advanced   = "B",
	Specialist = "A",
	Ascended   = "S",
	Primordial = "SSS",
}

local DEFAULT_RARITY_WEIGHTS = {
	Amateur    = 500,
	Advanced   = 300,
	Specialist = 150,
	Ascended   = 40,
	Primordial = 1,
}

local ORDERED_RARITIES = { "Amateur", "Advanced", "Specialist", "Ascended", "Primordial" }

local function normalizeWeights(t)
	local sum = 0
	for _, v in pairs(t) do sum += math.max(v, 0) end
	if sum == 0 then return t end
	for k, v in pairs(t) do t[k] = v / sum end
	return t
end

local function clampToMinimum(minTier, weights)
	-- Zero-out tiers below minTier
	local seen = false
	for _, r in ipairs(ORDERED_RARITIES) do
		if r == minTier then seen = true end
		if not seen then weights[r] = 0 end
	end
	return weights
end

local function resolveWeights(minRarity: string?, override: {[string]: number}?)
	local w = table.clone(DEFAULT_RARITY_WEIGHTS)
	if minRarity then clampToMinimum(minRarity, w) end
	if override then
		for k, v in pairs(override) do w[k] = v end
	end
	return normalizeWeights(w)
end

---------------------------------------------------------------------
-- Move database schema
-- Each move:
--   id, name, rarity, power, cooldown, minRange, maxRange,
--   castTime, castSpeed?, lockMovement?, effects {"Debuff"/"BuffSelf"/"Shield"/"HealSelf"/...}
--   tags {"Melee","Ranged","Magic","Progenitor","Construct","Beast"}
---------------------------------------------------------------------
local MOVES: {[string]: any} = {
	-- Universal basic
	BasicAttack = {
		id = "BasicAttack", name = "Basic Attack", rarity = "Amateur",
		power = 10, cooldown = 1.2, minRange = 0, maxRange = 6,
		castTime = 0.4, castSpeed = 1.0, lockMovement = true,
		effects = { }, tags = {"Melee", "Universal"},
	},

	-- PROGENITOR / RealitySeed line thematics
	WeavePulse = {
		id = "WeavePulse", name = "Weave Pulse", rarity = "Amateur",
		power = 14, cooldown = 2.0, minRange = 2, maxRange = 12,
		castTime = 0.6, effects = { }, tags = {"Magic","Progenitor","Ranged"},
	},
	CosmicThread = {
		id = "CosmicThread", name = "Cosmic Thread", rarity = "Advanced",
		power = 20, cooldown = 3.0, minRange = 4, maxRange = 14,
		castTime = 0.75, effects = {"Slow"}, tags = {"Magic","Progenitor","Ranged"},
	},
	VoidRay = {
		id = "VoidRay", name = "Void Ray", rarity = "Amateur",
		power = 30, cooldown = 4.0, minRange = 6, maxRange = 18,
		castTime = 0.9, effects = {"Debuff"}, tags = {"Magic","Progenitor","Ranged"},
	},
	ArchitectShield = {
		id = "ArchitectShield", name = "Architect's Shield", rarity = "Advanced",
		power = 0, cooldown = 6.0, minRange = 0, maxRange = 0,
		castTime = 0.6, effects = {"Shield","BuffSelf"}, tags = {"Progenitor","Defensive"},
	},
	PrimeConceptOverload = {
		id = "PrimeConceptOverload", name = "Prime Overload", rarity = "Ascended",
		power = 42, cooldown = 7.0, minRange = 4, maxRange = 16,
		castTime = 1.1, effects = {"Silence"}, tags = {"Magic","Progenitor"},
	},
	Singularity = {
		id = "Singularity", name = "Singularity", rarity = "Specialist",
		power = 35, cooldown = 5.0, minRange = 1, maxRange = 15,
		castTime = 1.0, effects = {"Pull", "Debuff"}, tags = {"Magic","Progenitor","Ranged","AoE"},
	},
	WarpLance = {
		id = "WarpLance", name = "Warp Lance", rarity = "Advanced",
		power = 25, cooldown = 3.5, minRange = 5, maxRange = 20,
		castTime = 0.8, effects = {"Pierce"}, tags = {"Magzic","Progenitor","Ranged"},
	},
	ChronoBreak = {
		id = "ChronoBreak", name = "Chrono Break", rarity = "Ascended",
		power = 38, cooldown = 8.0, minRange = 0, maxRange = 12,
		castTime = 1.2, effects = {"Stun", "Slow"}, tags = {"Magic","Progenitor","AoE"},
	},
	RealityShift = {
		id = "RealityShift", name = "Reality Shift", rarity = "Primordial",
		power = 50, cooldown = 12.0, minRange = 0, maxRange = 0,
		castTime = 1.5, effects = {"BuffSelf", "Debuff"}, tags = {"Magic","Progenitor","AoE"},
	},
	GenesisBeam = {
		id = "GenesisBeam", name = "Genesis Beam", rarity = "Ascended",
		power = 45, cooldown = 9.0, minRange = 8, maxRange = 25,
		castTime = 1.3, lockMovement = true, effects = {"Burn"}, tags = {"Magic","Progenitor","Ranged"},
	},

	-- CONSTRUCT / Core thematics
	CoreBash = {
		id = "CoreBash", name = "Core Bash", rarity = "Amateur",
		power = 16, cooldown = 1.8, minRange = 0, maxRange = 5,
		castTime = 0.55, lockMovement = true, effects = {}, tags = {"Melee","Construct"},
	},
	KineticSlam = {
		id = "KineticSlam", name = "Kinetic Slam", rarity = "Advanced",
		power = 26, cooldown = 3.5, minRange = 0, maxRange = 7,
		castTime = 0.8, lockMovement = true, effects = {"Knockdown"}, tags = {"Melee","Construct"},
	},
	Overcrank = {
		id = "Overcrank", name = "Overcrank", rarity = "Specialist",
		power = 0, cooldown = 8.0, minRange = 0, maxRange = 0,
		castTime = 0.6, effects = {"BuffSelf"}, tags = {"Construct"},
	},
	Hyperdrive = {
		id = "Hyperdrive", name = "Hyperdrive", rarity = "Advanced",
		power = 0, cooldown = 10.0, minRange = 0, maxRange = 0,
		castTime = 0.5, effects = {"BuffSelf", "Haste"}, tags = {"Construct","Mobility"},
	},
	MagneticVortex = {
		id = "MagneticVortex", name = "Magnetic Vortex", rarity = "Specialist",
		power = 28, cooldown = 6.0, minRange = 3, maxRange = 10,
		castTime = 0.9, effects = {"Pull", "Disarm"}, tags = {"Construct","AoE"},
	},
	PlasmaDischarge = {
		id = "PlasmaDischarge", name = "Plasma Discharge", rarity = "Ascended",
		power = 40, cooldown = 7.0, minRange = 0, maxRange = 8,
		castTime = 1.1, effects = {"Burn", "Stun"}, tags = {"Construct","AoE"},
	},
	NanoSwarm = {
		id = "NanoSwarm", name = "Nano Swarm", rarity = "Advanced",
		power = 18, cooldown = 4.0, minRange = 4, maxRange = 14,
		castTime = 0.7, effects = {"Debuff", "DamageOverTime"}, tags = {"Construct","Ranged"},
	},
	QuantumSlip = {
		id = "QuantumSlip", name = "Quantum Slip", rarity = "Specialist",
		power = 0, cooldown = 15.0, minRange = 0, maxRange = 0,
		castTime = 0.4, effects = {"Invulnerability", "Reposition"}, tags = {"Construct","Defensive","Mobility"},
	},

	-- BEAST / Hopling (boxer theme)
	PhotonJab = {
		id = "PhotonJab", name = "Photon Jab", rarity = "Amateur",
		power = 15, cooldown = 1.4, minRange = 0, maxRange = 4,
		castTime = 0.4, lockMovement = true, effects = { }, tags = {"Melee","Beast"},
	},
	FeintDash = {
		id = "FeintDash", name = "Feint Dash", rarity = "Advanced",
		power = 18, cooldown = 2.2, minRange = 0, maxRange = 10,
		castTime = 0.5, effects = {"Reposition"}, tags = {"Melee","GapClose","Beast"},
	},
	StarUppercut = {
		id = "StarUppercut", name = "Star Uppercut", rarity = "Specialist",
		power = 28, cooldown = 3.0, minRange = 0, maxRange = 5,
		castTime = 0.7, lockMovement = true, effects = {"Stun"}, tags = {"Melee","Beast"},
	},
	GuardUp = {
		id = "GuardUp", name = "Guard Up", rarity = "Amateur",
		power = 0, cooldown = 5.0, minRange = 0, maxRange = 0,
		castTime = 0.4, effects = {"BuffSelf","Shield"}, tags = {"Defensive","Beast"},
	},
	GravityWell = {
		id = "GravityWell", name = "Gravity Well", rarity = "Specialist",
		power = 22, cooldown = 4.5, minRange = 3, maxRange = 12,
		castTime = 0.8, effects = {"Slow", "Root"}, tags = {"Beast","Ranged","AoE"},
	},
	PhotonBarrage = {
		id = "PhotonBarrage", name = "Photon Barrage", rarity = "Advanced",
		power = 24, cooldown = 3.0, minRange = 0, maxRange = 6,
		castTime = 0.6, lockMovement = true, effects = {"MultiHit"}, tags = {"Melee","Beast"},
	},
	TemporalRift = {
		id = "TemporalRift", name = "Temporal Rift", rarity = "Ascended",
		power = 35, cooldown = 10.0, minRange = 5, maxRange = 18,
		castTime = 1.2, effects = {"Slow", "DamageOverTime"}, tags = {"Beast","Ranged","AoE"},
	},
	CelestialCombo = {
		id = "CelestialCombo", name = "Celestial Combo", rarity = "Ascended",
		power = 42, cooldown = 8.0, minRange = 0, maxRange = 4,
		castTime = 1.0, lockMovement = true, effects = {"MultiHit", "Stun"}, tags = {"Melee","Beast"},
	},
	VoidStep = {
		id = "VoidStep", name = "Void Step", rarity = "Specialist",
		power = 0, cooldown = 6.0, minRange = 0, maxRange = 15,
		castTime = 0.3, effects = {"Reposition", "Invulnerability"}, tags = {"Beast","Mobility"},
	},
}

local OVERRIDES: {[string]: {accuracy:number?, critChance:number?, mpCost:number?}} = {
	BasicAttack = { mpCost = 0, accuracy = 0.96 },                 -- ataque básico sempre barato e confiável
	GenesisBeam = { accuracy = 0.78, critChance = 0.10 },          -- feixe forte: menos accuracy, mais crit
	StarUppercut = { critChance = 0.12 },                          -- uppercut tem mais crit base
	CelestialCombo = { accuracy = 0.82 },                          -- combo multi-hit levemente menos preciso
	QuantumSlip = { mpCost = 10, accuracy = 1.0 },                  -- mobilidade pura: sempre acerta (auto-buff)
	ArchitectShield = { mpCost = 14, accuracy = 1.0 },              -- escudo/buff self garantido
}

-- Aplica normalização e overrides
for id, m in pairs(MOVES) do
	normalizeMove(m)
	local ov = OVERRIDES[id]
	if ov then
		if ov.accuracy ~= nil then m.accuracy = ov.accuracy end
		if ov.critChance ~= nil then m.critChance = ov.critChance end
		if ov.mpCost ~= nil then m.mpCost = ov.mpCost end
	end
end

---------------------------------------------------------------------
-- Race -> Starter pool mapping (by BaseRaceFamily)
---------------------------------------------------------------------
local STARTERS_BY_FAMILY = {
	Progenitor = {
		"BasicAttack", "WeavePulse", "CosmicThread", -- early thematic options
	},
	Construct = {
		"BasicAttack", "CoreBash",
	},
	Beast = {
		"BasicAttack", "PhotonJab", "FeintDash", "GuardUp",
	},
}

-- Fallback starters if family missing
local DEFAULT_STARTERS = { "BasicAttack" }

-- Race-specific exclusions/inclusions (extend as needed)
local FAMILY_TAG_FOR_RACE = {
	RealitySeed = "Progenitor",
	CosmicWeaver = "Progenitor",
	VoidWalker = "Progenitor",
	Architect = "Progenitor",
	PrimeConcept = "Progenitor",
	Core = "Construct",
	Hopling = "Beast",
}

---------------------------------------------------------------------
-- Pool building helpers
---------------------------------------------------------------------
local function buildPoolForFamily(family: string)
	local pool = {}
	for id, m in pairs(MOVES) do
		if table.find(m.tags, family) or table.find(m.tags, "Universal") then
			pool[id] = m
		end
	end
	-- Always ensure BasicAttack
	pool.BasicAttack = MOVES.BasicAttack
	return pool
end

local function getFamilyForRace(race: string)
	-- Prefer explicit mapping, otherwise try Races module for baseRaceFamily
	local fam = FAMILY_TAG_FOR_RACE[race]
	if fam then return fam end
	local ok, Races = pcall(function()
		return require(game.ReplicatedStorage.Modules.Races)
	end)
	if ok and Races and typeof(Races.GetBaseRaceFamily) == "function" then
		return Races:GetBaseRaceFamily(race)
	end
	return nil
end

function Moves:GetPoolForRace(race: string)
	local family = getFamilyForRace(race)
	if not family then
		-- Unknown race: allow universal + everything as a safe fallback
		local pool = {}
		for id, m in pairs(MOVES) do pool[id] = m end
		pool.BasicAttack = MOVES.BasicAttack
		return pool
	end
	return buildPoolForFamily(family)
end

---------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------
function Moves:GetMove(raceOrNil: string?, id: string)
	-- race is ignored for now; kept for compatibility (future: race-tuned variants)
	return MOVES[id]
end

function Moves:getStarterMoves(race)
	-- Use the Moves module's GetStarterMoves function
	if type(Moves.GetStarterMoves) == "function" then
		local ok, result = pcall(function()
			return Moves:GetStarterMoves(race)
		end)
		if ok and result and #result > 0 then
			return result
		end
	end

	-- Fallback: Try EvolutionDefs for move names and convert to proper format
	local EvolutionDefs = require(game.ReplicatedStorage.Modules.EvolutionDefs)
	local moveNames = EvolutionDefs:GetMovesForRace(race, {})

	if moveNames and #moveNames > 0 then
		local moves = {}
		for _, moveName in ipairs(moveNames) do
			-- Handle both string move names and structured move data
			if type(moveName) == "string" then
				local moveData = Moves:GetMove(race, moveName)
				if moveData then
					table.insert(moves, {move = moveData, rarity = "Amateur"})
				end
			elseif moveName.move then
				-- Already in correct format
				table.insert(moves, moveName)
			end
		end
		if #moves > 0 then
			return moves
		end
	end

	-- Ultimate fallback: just basic attack
	local basicAttack = Moves:GetMove(race, "BasicAttack")
	if basicAttack then
		return {{move = basicAttack, rarity = "Amateur"}}
	end

	return {}
end

function Moves:GetRandomMoves(race: string, count: number?, minRarity: string?, weightsOverride: {[string]: number}?)
	count = math.max(1, count or 1)
	local pool = self:GetPoolForRace(race)
	local weights = resolveWeights(minRarity, weightsOverride)

	-- Build rarity buckets
	local byRarity: {[string]: {any}} = {}
	for r in pairs(DEFAULT_RARITY_WEIGHTS) do byRarity[r] = {} end
	for _, m in (pool) do
		byRarity[m.rarity] = byRarity[m.rarity] or {}
		table.insert(byRarity[m.rarity], m)
	end

	local picked = {}
	for i = 1, count do
		-- roulette across rarities, then pick inside that bucket uniformly
		local roll = math.random()
		local acc = 0
		local chosenRarity: string? = nil
		for _, r in ipairs(ORDERED_RARITIES) do
			acc += (weights[r] or 0)
			if roll <= acc then chosenRarity = r break end
		end
		chosenRarity = chosenRarity or ORDERED_RARITIES[#ORDERED_RARITIES]
		local bucket = byRarity[chosenRarity]
		if not bucket or #bucket == 0 then
			bucket = byRarity["Amateur"]
		end
		local mv = bucket[math.random(1, math.max(1, #bucket))] or MOVES.BasicAttack
		picked[i] = { move = mv, rarity = mv.rarity }
	end
	return picked
end

-- Optional: expose constants for external modules
Moves.RARITY = RARITY
Moves.DEFAULT_RARITY_WEIGHTS = table.clone(DEFAULT_RARITY_WEIGHTS)

return setmetatable({}, Moves)