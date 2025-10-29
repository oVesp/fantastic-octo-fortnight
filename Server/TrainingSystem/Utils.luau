-- TrainingSystem/Utils.lua
local RS = game:GetService("ReplicatedStorage")
local Personalities = require(RS.Modules.Personalities)
local Races = require(RS.Modules.Races)

local STAT_ALIASES = {
        Hp = {"Hp", "HP"},
        Mp = {"Mp", "MP"},
        Strength = {"Strength", "STR"},
        Defense = {"Defense", "DEF"},
        Skill = {"Skill", "SKL"},
        Speed = {"Speed", "SPD"},
        Intelligence = {"Intelligence", "INT"},
        Luck = {"Luck", "LCK"},
}

local CANONICAL_FROM_KEY = {}
for canonical, aliases in pairs(STAT_ALIASES) do
        local list = { canonical }
        local seen = { [canonical] = true }
        for _, alias in ipairs(aliases) do
                if not seen[alias] then
                        table.insert(list, alias)
                        seen[alias] = true
                end
        end
        STAT_ALIASES[canonical] = list
        for _, alias in ipairs(list) do
                CANONICAL_FROM_KEY[alias] = canonical
        end
end

local Utils = {}

local function findStatsTableForMonster(player, monster)
        if not (_G and _G.DATA and player) then
                return nil, nil
        end

        local ok, store = pcall(function()
                return _G.DATA:Get(player)
        end)
        if not ok or type(store) ~= "table" then
                return nil, nil
        end

        local monsterData = store.Monster
        if type(monsterData) ~= "table" then
                return nil, nil
        end

        local stage = monsterData.Stage
        if type(monsterData.Stats) == "table" then
                return monsterData.Stats, monsterData.Stage
        end

        local activeMonster = monsterData.ActiveMonster
        if type(activeMonster) == "table" and type(activeMonster.Stats) == "table" then
                return activeMonster.Stats, activeMonster.Stage or stage
        end

        local monsterId
        if monster then
                monsterId = monster:GetAttribute("id") or monster:GetAttribute("Id")
        end

        local monsters = monsterData.Monsters
        if type(monsters) == "table" then
                if monsterId then
                        local directMatch = monsters[monsterId]
                        if type(directMatch) == "table" and type(directMatch.Stats) == "table" then
                                return directMatch.Stats, directMatch.Stage or stage
                        end

                        for _, m in pairs(monsters) do
                                if type(m) == "table" and (m.id == monsterId or m.Id == monsterId) and type(m.Stats) == "table" then
                                        return m.Stats, m.Stage or stage
                                end
                        end
                end

                for _, m in pairs(monsters) do
                        if type(m) == "table" and type(m.Stats) == "table" then
                                return m.Stats, m.Stage or stage
                        end
                end
        end

        return nil, stage
end

-- === Centralized success evaluation (TEMP: 25% fail) ===
function Utils.EvaluateSuccess(monster, player, trainingName, ctx, modResult)
	-- Se o módulo explicitamente falhou (ex.: path interrompido), respeita a falha
	

	-- Temporário: 25% de chance de falhar, independente do resultado do módulo
	-- (Depois trocamos por fórmula com Bond/Discipline lidos do _G.DATA)
	if math.random() < 0.25 then
		return false, "temporary_fail_roll"
	end

	return true, nil
end

-- Resolve tabela/func do BONUS
function Utils.ResolveBaseBonus(base)
	if typeof(base) == "function" then
		local ok, tbl = pcall(base)
		if ok and type(tbl) == "table" then return tbl end
		return {}
	end
	return typeof(base) == "table" and base or {}
end

-- Anexa RopeConstraint genérico entre Attachment do monstro e da carga
function Utils.AttachRope(monster: Model, loadAttachment: Attachment)
	local root = monster:FindFirstChild("HumanoidRootPart") or monster.PrimaryPart
	if not (root and loadAttachment) then return nil end

	-- Garante um Attachment no monstro
	local monsterAtt = root:FindFirstChild("TrainingAttach")
	if not monsterAtt then
		monsterAtt = Instance.new("Attachment")
		monsterAtt.Name = "TrainingAttach"
		monsterAtt.Parent = root
	end

	local rope = Instance.new("RopeConstraint")
	rope.Name = "TrainingRope"
	rope.Attachment0 = monsterAtt
	rope.Attachment1 = loadAttachment
	rope.Length = (monsterAtt.WorldPosition - loadAttachment.WorldPosition).Magnitude
	rope.Visible = false
	rope.Parent = root
	return rope
end

function Utils.DetachRope(monster: Model)
	local root = monster:FindFirstChild("HumanoidRootPart") or monster.PrimaryPart
	if not root then return end
	local rope = root:FindFirstChild("TrainingRope")
	if rope then rope:Destroy() end
end

-- Multiplicadores: Personalidade * random (±15%).
function Utils.ComputeGains(monster: Model, baseBonus)
	local base = Utils.ResolveBaseBonus(baseBonus)
	local gains = {}

	local personalityName = monster:GetAttribute("Personality")
	local raceName = monster:GetAttribute("Race")

        -- Load personality multipliers
        local personalityMult = {}
        if personalityName and Personalities.Personalities[personalityName] then
                personalityMult = Personalities.Personalities[personalityName].trainingMultipliers or {}
        end

	-- Race + fallback to family
	local raceMult = {}
	if raceName and typeof(Races.Get) == "function" then
		local raceDef = Races:Get(raceName)
		if raceDef then
			raceMult = raceDef.trainingMultipliers or {}

			-- Fallback to family multipliers if not defined at race level
			if not next(raceMult) and raceDef.baseRaceFamily then
				local familyDefaults = {
					Progenitor = {Strength=1.2, Speed=1.1, Intelligence=1.4, Defense=1.0, Luck=0.9, Skill=1.0},
					Construct = {Strength=1.3, Speed=0.8, Intelligence=1.0, Defense=1.4, Luck=0.7, Skill=1.0},
					Beast = {Strength=1.4, Speed=1.3, Intelligence=0.8, Defense=1.0, Luck=1.0, Skill=1.0}
				}
				raceMult = familyDefaults[raceDef.baseRaceFamily] or {}
			end
		end
	end

	for stat, val in pairs(base) do
		local pMult = personalityMult[stat] or 1.0
		local rMult = raceMult[stat] or 1.0
		local rnd = 0.85 + math.random() * 0.30
		gains[stat] = math.floor(val * pMult * rMult * rnd)
	end

	return gains
end

local function getCurrentStatValue(container, aliases)
        if not container then return nil end
        for _, key in ipairs(aliases) do
                local value = container[key]
                if typeof(value) == "number" then
                        return value
                end
        end
        return nil
end

local function getAttributeStatValue(monster, aliases)
        if not monster then return nil end
        for _, key in ipairs(aliases) do
                local value = monster:GetAttribute(key)
                if typeof(value) == "number" then
                        return value
                end
        end
        return nil
end

local function resolveStage(monster, dataStage)
        if monster then
                local attrStage = monster:GetAttribute("Stage")
                if attrStage then
                        return attrStage
                end
        end
        if dataStage then
                return dataStage
        end
        if monster then
                local race = monster:GetAttribute("Race")
                if race then
                        local ok, stage = pcall(function()
                                return Races:GetStage(race)
                        end)
                        if ok and stage then
                                return stage
                        end
                end
        end
        return nil
end

function Utils.ApplyGains(monster: Model?, gains: table, player: Player?)
        if typeof(gains) ~= "table" or not next(gains) then
                return
        end

        local statsTable, dataStage = findStatsTableForMonster(player, monster)
        local stage = resolveStage(monster, dataStage)

        local zeroedKeys = nil

        for statKey, delta in pairs(gains) do
                local canonical = CANONICAL_FROM_KEY[statKey] or statKey
                local aliases = STAT_ALIASES[canonical] or { canonical }
                local numericDelta = tonumber(delta) or 0
                if numericDelta ~= numericDelta then
                        numericDelta = 0
                end

                local currentValue = getCurrentStatValue(statsTable, aliases)
                if currentValue == nil then
                        currentValue = getAttributeStatValue(monster, aliases)
                end
                currentValue = tonumber(currentValue) or 0

                local cap = nil
                if stage then
                        local ok, capResult = pcall(function()
                                return Races:GetStatCapForStage(stage, canonical)
                        end)
                        if ok and typeof(capResult) == "number" then
                                cap = capResult
                        end
                end

                local proposed = currentValue + numericDelta
                if cap then
                        proposed = math.min(proposed, cap)
                        if currentValue > cap then
                                proposed = math.min(currentValue, cap)
                        end
                end

                if proposed < 0 then
                        proposed = 0
                end

                proposed = math.floor(proposed + 0.5)

                local appliedDelta = proposed - currentValue
                if appliedDelta <= 0 then
                        appliedDelta = 0
                        zeroedKeys = zeroedKeys or {}
                        table.insert(zeroedKeys, statKey)
                else
                        gains[statKey] = appliedDelta
                end

                if statsTable then
                        for _, key in ipairs(aliases) do
                                statsTable[key] = proposed
                        end
                end

                if monster then
                        for _, key in ipairs(aliases) do
                                if monster:GetAttribute(key) ~= nil or key == statKey then
                                        monster:SetAttribute(key, proposed)
                                end
                        end
                end
        end

        if zeroedKeys then
                for _, key in ipairs(zeroedKeys) do
                        gains[key] = nil
                end
        end
end

return Utils
