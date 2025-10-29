-- ModuleScript: ReplicatedStorage>Modules>Moves
local Moves = {}
Moves.__index = Moves

local StatusEffectDefs = require(script.Parent.StatusEffectDefs)

-- Constantes e configurações padrão
local DEFAULTS = {
        baseAccuracy = 0.88,
	baseCrit = 0.05,
	mpCostBase = 0,
	mpPerPower = 0.30,
	minMpCost = 0,
	maxAccuracy = 0.98,
	minAccuracy = 0.55,
	maxCrit = 0.35,
	rarityMpMult = {
		Amateur = 1.00,
		Advanced = 1.10,
		Specialist = 1.20,
		Ascended = 1.35,
		Primordial = 1.50,
	},
	tagAccuracyAdj = {
		Melee = 0.04,
		Ranged = -0.03,
		Magic = -0.02,
		AoE = -0.04,
		Mobility = 0.03,
		Defensive = 0.02,
	},
	tagCritAdj = {
		Melee = 0.01,
		Ranged = 0.00,
		Magic = 0.00,
		GapClose = 0.02,
		MultiHit = -0.01,
		AoE = -0.01,
	},
	tagMpMult = {
		Magic = 1.15,
		Ranged = 1.05,
		Melee = 0.95,
		Defensive = 1.10,
		Mobility = 0.90,
		Universal = 1.00,
	},
	castAccuracyPenaltyPerSec = 0.06,
        rangeAccuracyPenaltyPer10 = 0.015,
}

local EFFECT_DEFAULTS = {
        Slow = { status = "Slow", target = "target" },
        Stun = { status = "Stun", target = "target" },
        Burn = { status = "Burn", target = "target" },
        DamageOverTime = { status = "Poison", target = "target" },
        Shield = { status = "Shield", target = "target" },
        BuffSelf = { status = "GuardUp", target = "attacker" },
        Haste = { status = "Haste", target = "attacker" },
        Silence = { status = "Silence", target = "target" },
        Root = { status = "Root", target = "target" },
        Invulnerability = { status = "Invulnerability", target = "attacker" },
        Disarm = { status = "Weaken", target = "target" },
        Pull = { status = "Root", target = "target", duration = 1 },
        FortifyAura = { status = "GuardUp", target = "attacker", duration = 8, refreshDuration = 4 },
}

-- Funções utilitárias locais
local function clamp(x, a, b)
        return math.max(a, math.min(b, x))
end

local function cloneValue(value)
        if typeof(value) == "table" then
                return table.clone(value)
        end
        return value
end

local function applyStatusDefinitionDefaults(effect)
        local statusName = effect.status
        if typeof(statusName) ~= "string" then
                return
        end

        local def = StatusEffectDefs[statusName]
        if not def then
                return
        end

        if effect.duration == nil and def.defaultDuration then
                effect.duration = def.defaultDuration
        end

        if effect.power == nil and def.defaultPower ~= nil then
                effect.power = def.defaultPower
        end

        if effect.dps == nil and def.dot and def.dot.dps ~= nil then
                effect.dps = def.dot.dps
        end
end

local function normalizeEffects(move)
        local rawEffects = move.effects
        if not rawEffects then
                return
        end

        local normalized = {}
        for _, entry in ipairs(rawEffects) do
                local effect
                local entryType = typeof(entry)
                if entryType == "table" then
                        effect = table.clone(entry)
                elseif entryType == "string" then
                        effect = { type = entry }
                else
                        effect = nil
                end

                if effect then
                        local effectType = effect.type or effect.name or effect.status
                        if typeof(effectType) == "string" then
                                effect.type = effectType
                                local defaults = EFFECT_DEFAULTS[effectType]
                                if defaults then
                                        for key, value in pairs(defaults) do
                                                if effect[key] == nil then
                                                        effect[key] = cloneValue(value)
                                                end
                                        end
                                end

                                effect.target = effect.target or (defaults and defaults.target) or "target"
                                effect.stacks = effect.stacks or 1
                                if effect.status == nil then
                                        effect.status = (defaults and defaults.status) or effect.type
                                end
                                applyStatusDefinitionDefaults(effect)

                                table.insert(normalized, effect)
                        else
                                warn(string.format("[Moves] Ignoring malformed effect entry on move %s", tostring(move.id)))
                        end
                else
                        warn(string.format("[Moves] Ignoring unsupported effect entry on move %s", tostring(move.id)))
                end
        end

        move.effects = normalized
end

local function computeAccuracy(move)
        local acc = DEFAULTS.baseAccuracy
        if move.castTime and move.castTime > 0 then
		acc = acc - (move.castTime * DEFAULTS.castAccuracyPenaltyPerSec)
	end
	local mr = move.maxRange or 0
	acc = acc - (mr / 10) * DEFAULTS.rangeAccuracyPenaltyPer10

	if move.tags then
		for _, tag in ipairs(move.tags) do
			local adj = DEFAULTS.tagAccuracyAdj[tag]
			if adj then
				acc = acc + adj
			end
		end
	end

	return clamp(acc, DEFAULTS.minAccuracy, DEFAULTS.maxAccuracy)
end

local function computeCrit(move)
	local crit = DEFAULTS.baseCrit
	if move.tags then
		for _, tag in ipairs(move.tags) do
			local adj = DEFAULTS.tagCritAdj[tag]
			if adj then
				crit = crit + adj
			end
		end
	end

	if (move.power or 0) >= 35 then
		crit = crit + 0.02
	end
	if (move.power or 0) >= 45 then
		crit = crit + 0.01
	end

	return clamp(crit, 0, DEFAULTS.maxCrit)
end

local function computeMpCost(move)
	local power = math.max(0, move.power or 0)
	local rarity = move.rarity or "Amateur"
	local base = DEFAULTS.mpCostBase + power * DEFAULTS.mpPerPower
	local mult = DEFAULTS.rarityMpMult[rarity] or 1.0

	if move.tags then
		for _, tag in ipairs(move.tags) do
			mult = mult * (DEFAULTS.tagMpMult[tag] or 1.0)
		end
	end

	if power == 0 then
		base = 6
	end

	local cost = math.max(DEFAULTS.minMpCost, math.floor(base * mult + 0.5))
	return cost
end

-- Normaliza um movimento, preenchendo os campos derivados se não estiverem definidos
local function normalizeMove(move)
        if move.effects then
                normalizeEffects(move)
        end
        if move.accuracy == nil then
                move.accuracy = computeAccuracy(move)
        end
	if move.critChance == nil then
		move.critChance = computeCrit(move)
	end
	if move.mpCost == nil then
		move.mpCost = computeMpCost(move)
	end
	return move
end

-- Carrega todos os módulos de movimentos da pasta MovesModules
local function loadAllMoves()
	local moves = {}
	local movesFolder = script.Parent:WaitForChild("MovesModules")

	for _, moduleScript in ipairs(movesFolder:GetChildren()) do
		if moduleScript:IsA("ModuleScript") then
			local success, moveData = pcall(require, moduleScript)
			if success and moveData and moveData.id then
				moves[moveData.id] = moveData
			else
				warn("[Moves] Failed to load move module: " .. moduleScript.Name)
			end
		end
	end

	return moves
end

-- Tabela interna de movimentos (carregada uma vez)
local MOVES = loadAllMoves()

-- Aplica normalização a todos os movimentos
for _, move in pairs(MOVES) do
	normalizeMove(move)
end

-- Constantes de raridade
local RARITY = {
	Amateur = "C",
	Advanced = "B",
	Specialist = "A",
	Ascended = "S",
	Primordial = "SSS",
}

local DEFAULT_RARITY_WEIGHTS = {
	Amateur = 500,
	Advanced = 300,
	Specialist = 150,
	Ascended = 40,
	Primordial = 1,
}

local ORDERED_RARITIES = {"Amateur", "Advanced", "Specialist", "Ascended", "Primordial"}

-- Funções auxiliares para randomização
local function normalizeWeights(t)
	local sum = 0
	for _, v in pairs(t) do
		sum = sum + math.max(v, 0)
	end
	if sum == 0 then
		return t
	end
	for k, v in pairs(t) do
		t[k] = v / sum
	end
	return t
end

local function resolveWeights(minRarity, override)
	local w = table.clone(DEFAULT_RARITY_WEIGHTS)

	if minRarity then
		local seen = false
		for _, r in ipairs(ORDERED_RARITIES) do
			if r == minRarity then
				seen = true
			end
			if not seen then
				w[r] = 0
			end
		end
	end

	if override then
		for k, v in pairs(override) do
			w[k] = v
		end
	end

	return normalizeWeights(w)
end

-- Mapeamento de famílias para raças
local FAMILY_TAG_FOR_RACE = {
	RealitySeed = "Progenitor",
	CosmicWeaver = "Progenitor",
	VoidWalker = "Progenitor",
	Architect = "Progenitor",
	PrimeConcept = "Progenitor",
	Core = "Construct",
	Hopling = "Beast",
}

-- Funções públicas

function Moves:GetMove(raceOrNil, id)
	return MOVES[id]
end

function Moves:GetPoolForRace(race)
	local function getFamilyForRace(raceName)
		local fam = FAMILY_TAG_FOR_RACE[raceName]
		if fam then
			return fam
		end

		local ok, Races = pcall(function()
			return require(game.ReplicatedStorage.Modules.Races)
		end)

		if ok and Races and typeof(Races.GetBaseRaceFamily) == "function" then
			return Races:GetBaseRaceFamily(raceName)
		end

		return nil
	end

	local function buildPoolForFamily(family)
		local pool = {}
		for id, move in pairs(MOVES) do
			if table.find(move.tags, family) or table.find(move.tags, "Universal") then
				pool[id] = move
			end
		end
		pool.BasicAttack = MOVES.BasicAttack
		return pool
	end

	local family = getFamilyForRace(race)
	if not family then
		local pool = {}
		for id, move in pairs(MOVES) do
			pool[id] = move
		end
		pool.BasicAttack = MOVES.BasicAttack
		return pool
	end

	return buildPoolForFamily(family)
end

function Moves:GetRandomMoves(race, count, minRarity, weightsOverride)
	count = math.max(1, count or 1)
	local pool = self:GetPoolForRace(race)
	local weights = resolveWeights(minRarity, weightsOverride)

	local byRarity = {}
	for r in pairs(DEFAULT_RARITY_WEIGHTS) do
		byRarity[r] = {}
	end

	for _, move in pairs(pool) do
		byRarity[move.rarity] = byRarity[move.rarity] or {}
		table.insert(byRarity[move.rarity], move)
	end

	local picked = {}
	for i = 1, count do
		local roll = math.random()
		local acc = 0
		local chosenRarity = nil

		for _, r in ipairs(ORDERED_RARITIES) do
			acc = acc + (weights[r] or 0)
			if roll <= acc then
				chosenRarity = r
				break
			end
		end

		chosenRarity = chosenRarity or ORDERED_RARITIES[#ORDERED_RARITIES]
		local bucket = byRarity[chosenRarity]

		if not bucket or #bucket == 0 then
			bucket = byRarity["Amateur"]
		end

                local move = bucket[math.random(1, math.max(1, #bucket))] or MOVES.BasicAttack
                picked[i] = {
                        id = move.id,
                        rarity = move.rarity,
                }
        end

        return picked
end

function Moves:getStarterMoves(race)
        -- Implementação simplificada - em produção, integrar com EvolutionDefs
        local basicAttack = self:GetMove(race, "BasicAttack")
        if basicAttack then
                return {{
                        id = basicAttack.id,
                        rarity = "Amateur",
                }}
        end
        return {}
end

-- Exportar constantes
Moves.RARITY = RARITY
Moves.DEFAULT_RARITY_WEIGHTS = table.clone(DEFAULT_RARITY_WEIGHTS)

return setmetatable({}, Moves)
