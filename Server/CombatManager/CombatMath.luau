-- ReplicatedStorage/Modules/CombatMath.luau
-- Skill = accuracy contest, Speed = dodge contest, Luck = crit bias
-- Nunca 0/100: clamps garantem pisos e tetos.

local CombatMath = {}

local EPS = 1e-6

-- Knobs globais (fáceis de balancear)
local CFG = {
	-- Hit chance
	minHit = 0.08,           -- 8% mínimo
	maxHit = 0.97,           -- 97% máximo
	hitSkillWeight = 0.35,   -- peso do duelo Skill vs Speed no cálculo final

	-- Crit chance
	minCrit = 0.00,
	maxCrit = 0.50,
	critLuckPerPoint = 0.003, -- +0.3% por ponto de Luck além do alvo (capado)
	critBaseLuckMitigation = 0.5, -- metade do Luck do alvo mitiga

	-- Damage
	variance = 0.05,         -- ±5% variação leve
	critMultiplier = 1.6,    -- crítico padrão
	armorMitigation = 0.06,  -- curva de mitigation por Defense (mais Defense = menos dano)
	-- escalas por tag principal
	scaleMelee = 0.65,       -- Strength
	scaleRanged = 0.45,      -- Skill + um pouco de Strength
	scaleRangedStrBlend = 0.25,
	scaleMagic = 0.60,       -- Intelligence
	-- dano mínimo após mitigação
	minDamage = 1,
}

local function clamp(x, a, b) return math.max(a, math.min(b, x)) end

-- Helpers de seleção de “via” de dano por tags
local function isTag(tags, name)
	if not tags then return false end
	for _, t in ipairs(tags) do if t == name then return true end end
	return false
end

-- Hit chance: mistura entre precisão do move e duelo Skill vs Speed
-- pSkill = SkillA / (SkillA + SpeedB)
local function computeHitChance(attStats, tgtStats, move)
	local baseAcc = move.accuracy or 0.88
	local skillA = math.max(0, attStats.Skill or 0)
	local speedB = math.max(0, tgtStats.Speed or 0)
	local pSkill = skillA / (skillA + speedB + EPS)         -- 0..1
	-- Blend: parte vem da precisão intrínseca do move, parte do duelo de stats
	local p = (1 - CFG.hitSkillWeight) * baseAcc + (CFG.hitSkillWeight) * pSkill
	return clamp(p, CFG.minHit, CFG.maxHit)
end

-- Crit chance: base do move + (LuckA - LuckB*mitig) * fator
local function computeCritChance(attStats, tgtStats, move)
	local baseCrit = move.critChance or 0.05
	local luckA = math.max(0, attStats.Luck or 0)
	local luckB = math.max(0, tgtStats.Luck or 0)
	local delta = luckA - (luckB * CFG.critBaseLuckMitigation)
	local bonus = delta * CFG.critLuckPerPoint
	local p = baseCrit + bonus
	return clamp(p, CFG.minCrit, CFG.maxCrit)
end

-- Escalonamento ofensivo por tipo do move
local function computeOffensivePower(attStats, move)
	local str = attStats.Strength or 0
	local skl = attStats.Skill or 0
	local int = attStats.Intelligence or 0

	if isTag(move.tags, "Magic") then
		return (move.power or 0) + int * CFG.scaleMagic
	elseif isTag(move.tags, "Ranged") then
		return (move.power or 0) + skl * CFG.scaleRanged + str * CFG.scaleRangedStrBlend
	else -- Melee por padrão
		return (move.power or 0) + str * CFG.scaleMelee
	end
end

-- Mitigação por Defense com retornos decrescentes
-- Fórmula simples: damageAfter = raw / (1 + Defense * armorMitigation / 100)
local function applyMitigation(raw, tgtStats)
	local def = math.max(0, tgtStats.Defense or 0)
	local factor = 1 + (def * CFG.armorMitigation / 100)
	return raw / factor
end

local function applyVariance(dmg)
	local v = CFG.variance
	local r = (math.random() * 2 - 1) * v -- [-v, +v]
	return dmg * (1 + r)
end

-- API principal -----------------------------------------------------

-- Retorna o resultado de acerto e crítico (sem consumir dano ainda)
function CombatMath.ResolveHit(attStats, tgtStats, move)
	local hitChance = computeHitChance(attStats, tgtStats, move)
	local didHit = (math.random() <= hitChance)

	local critChance = 0
	local didCrit = false
	if didHit then
		critChance = computeCritChance(attStats, tgtStats, move)
		didCrit = (math.random() <= critChance)
	end

	return {
		hit = didHit,
		hitChance = hitChance,
		crit = didCrit,
		critChance = critChance,
	}
end

-- Calcula o dano final (assume hit=true)
function CombatMath.ComputeDamage(attStats, tgtStats, move, isCrit)
	local raw = computeOffensivePower(attStats, move)
	local mitig = applyMitigation(raw, tgtStats)
	local varied = applyVariance(mitig)
	if isCrit then
		varied = varied * CFG.critMultiplier
	end
	return math.max(CFG.minDamage, math.floor(varied + 0.5))
end

return CombatMath
