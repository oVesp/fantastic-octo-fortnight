-- TrainingSystem/Utils.lua
local RS = game:GetService("ReplicatedStorage")
local Personalities = require(RS.Modules.Personalities)

local Utils = {}

local function findStatsTableForMonster(player, monster)
	if not (_G and _G.DATA and player) then
		return nil
	end

	local ok, store = pcall(function()
		return _G.DATA:Get(player)
	end)
	if not ok or type(store) ~= "table" then
		return nil
	end

	local monsterData = store.Monster
	if type(monsterData) ~= "table" then
		return nil
	end

	if type(monsterData.Stats) == "table" then
		return monsterData.Stats
	end

	local activeMonster = monsterData.ActiveMonster
	if type(activeMonster) == "table" and type(activeMonster.Stats) == "table" then
		return activeMonster.Stats
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
				return directMatch.Stats
			end

			for _, m in pairs(monsters) do
				if type(m) == "table" and (m.id == monsterId or m.Id == monsterId) and type(m.Stats) == "table" then
					return m.Stats
				end
			end
		end

		for _, m in pairs(monsters) do
			if type(m) == "table" and type(m.Stats) == "table" then
				return m.Stats
			end
		end
	end

	return nil
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

	local Personalities = require(game.ReplicatedStorage.Modules.Personalities)
	local Races = require(game.ReplicatedStorage.Modules.Races)

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

function Utils.ApplyGains(monster: Model, gains: table, player: Player?)
	-- Runtime attributes
	for stat, v in pairs(gains) do
		local cur = monster:GetAttribute(stat) or 0
		monster:SetAttribute(stat, cur + v)
	end

	-- Persistent data via proxy
	local statsTable = findStatsTableForMonster(player, monster)
	if statsTable then
		for stat, v in pairs(gains) do
			local cur = tonumber(statsTable[stat]) or tonumber(statsTable[string.upper(string.sub(stat,1,1))..string.sub(stat,2)]) or 0
			statsTable[stat] = cur + v
		end
		-- No need to call save: proxy tracks changes and will persist automatically
	end
end

return Utils
