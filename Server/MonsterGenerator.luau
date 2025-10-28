-- ModuleScript: ServerScriptService>Main>MonsterGenerator
local module = {}
module.__index = module
module.PlayerMonsters = {}

local RP = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Moves = require(RP.Modules.Moves)
local Personalities = require(RP.Modules.Personalities)
local Races = require(RP.Modules.Races)
--local template = require(RP.Prefabs.Default)
local models = RP.Assets.Templates
local AnimationManager = require(game.ReplicatedStorage.Modules.AnimationManager)
local EvolutionEffect = RP.Remotes:WaitForChild("EvolutionEffect")
local EvolutionComplete = RP.Remotes:WaitForChild("EvolutionComplete")
local UIB = require(RP.Modules.UIBillboards)

-- Level ranges for each stage
local STAGE_LEVEL_RANGES = {
	Fledgeling = {1, 10},
	Rookie = {11, 20},
	Champion = {21, 30},
	Elder = {31, 40},
	Unique = {41, 50}
}

-- Function to get stage from level
local function getStageFromLevel(level)
	level = level or 1
	if level <= 10 then
		return "Fledgeling"
	elseif level <= 20 then
		return "Rookie"
	elseif level <= 30 then
		return "Champion"
	elseif level <= 40 then
		return "Elder"
	else
		return "Unique"
	end
end

-- Function to apply level scaling to stats
local function applyLevelScaling(stats, level)
	local multiplier = 1 + ((level - 1) * 0.05) -- 1.5x at level 10, 3x at level 50
	local scaledStats = {}

	for stat, value in pairs(stats) do
		if stat == "Hp" or stat == "Mp" then
			scaledStats[stat] = math.floor(value * multiplier)
		else
			scaledStats[stat] = math.floor(value * multiplier)
		end
	end

	return scaledStats
end

local function applyMultipliers(stats, mult)
	if not mult or type(mult) ~= "table" then return stats end
	local map = {
		Strength = {"Strength", "STR"},
		Defense = {"Defense", "DEF"},
		Skill = {"Skill", "SKL"},
		Speed = {"Speed", "SPD"},
		Intelligence = {"Intelligence", "INT"},
		Luck = {"Luck", "LCK"},
	}

	for statName, aliases in (map) do
		local long, short = aliases[1], aliases[2]
		local multiplier = mult[statName] or 1
		if multiplier ~= 1 then
			if stats[long] then
				stats[long] = math.max(1, math.floor(stats[long] * multiplier))
			end
			if stats[short] then
				stats[short] = math.max(1, math.floor(stats[short] * multiplier))
			end
		end
	end
	return stats
end

local function rollStats(stage)
	local TOTAL_BY_STAGE = {
		Fledgeling = 60,
		Rookie = 80,
		Champion = 100,
		Elder = 120,
		Unique = 140,
	}

	local totalPoints = TOTAL_BY_STAGE[stage] or 60
	local statsToDistribute = {"STR", "DEF", "SKL", "SPD", "INT", "LCK"}
	local distribution = {}

	for _, stat in ipairs(statsToDistribute) do
		distribution[stat] = 5
		totalPoints = totalPoints - 5
	end

	while totalPoints > 0 do
		local randomStat = statsToDistribute[math.random(1, #statsToDistribute)]
		distribution[randomStat] = distribution[randomStat] + 1
		totalPoints = totalPoints - 1
	end

	return {
		Hp = 100,
		Mp = 100,
		STR = distribution.STR,
		Strength = distribution.STR,
		DEF = distribution.DEF,
		Defense = distribution.DEF,
		SKL = distribution.SKL,
		Skill = distribution.SKL,
		SPD = distribution.SPD,
		Speed = distribution.SPD,
		INT = distribution.INT,
		Intelligence = distribution.INT,
		LCK = distribution.LCK,
		Luck = distribution.LCK,
	}
end

-- Modified RollMonster function with level support
function module.RollMonster(ownerId, isNPC, options)
	options = options or {}
	local level = options.level or 1
	local stage = options.stage or getStageFromLevel(level)
	local forceRace = options.race -- Allow forcing specific race

	local pool
	if forceRace and Races:Exists(forceRace) then
		-- Use specific race if forced
		pool = {forceRace}
	else
		-- Get all races for the specified stage
		pool = Races:ListByStage(stage)
		if #pool == 0 then
			-- Fallback to summonable races if no races found for stage
			pool = Races:ListSummonable()
		end
	end

	if #pool == 0 then
		error("No races available for stage: " .. stage)
	end

	local race = pool[math.random(1, #pool)]
	local family = Races:GetBaseRaceFamily(race)

	-- Get just the personality name
	local personalityName = Personalities:RollPersonality()
	--print(personalityName)
	-- Get the personality data for stat multipliers
	local personalityData = Personalities.Personalities[personalityName] or {}

	local moves
	if isNPC then
		moves = Moves:GetRandomMoves(race, 3)
	else
		moves = Moves:getStarterMoves(race)
		--print(moves)
	end

	local baseStats = rollStats(stage)
	-- Apply level scaling to base stats
	local scaledStats = applyLevelScaling(baseStats, level)

	if personalityData and personalityData.trainingMultipliers then
		scaledStats = applyMultipliers(scaledStats, personalityData.trainingMultipliers)
	end

	local name = _G.UTILS.nameGenerator()
	local data = {
		id = HttpService:GenerateGUID(false),
		Name = name,
		Race = race,
		Stage = stage,
		Level = level,
		BaseRaceFamily = family,
		OwnerId = ownerId,
		Personality = personalityName,  -- Just store the name
		Stats = scaledStats,
		Moves = moves,
		History = {race},
		IsNPC = isNPC or false,
		GeneratedWithLevel = level,
		Appearance = {},
		Age = 0,
		Bond = 0,
		Wins = 0,
		SessionTime = 0,
		CareMistakes = 0,
		Element = "None"
	}

	local worked = {}
	if ownerId then
		print(data)
		local playerData = _G.DATA:Get(ownerId)

		for key, value in (data) do
			table.insert(worked, key)
			print(worked)

			print(key, typeof(key), value, typeof(value))

			playerData.Monster[key] = value
		end
		for key, value in pairs(data.Stats) do
			playerData.Monster.Stats[key] = value
		end
	end

	return data
end

-- Rest of the MonsterGenerator module remains the same...
local ownerToMonster = setmetatable({}, {__mode = "v"})

local function _tagOwned(monsterModel, player)
	if not (monsterModel and player) then return end
	monsterModel:SetAttribute("Userid", player.UserId)
end

local function _findExistingOwned(userId)
	local reg = ownerToMonster[userId]
	if reg and reg.Parent then return reg end

	for _, m in ipairs(workspace:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("UserId") == userId then
			return m
		end
	end
	return nil
end

function module.BuildMonster(monsterData, ownerId, options)
	
	options = options or {}
	monsterData = monsterData or module.RollMonster(ownerId, nil, options)

	local isPlayerOwned = ownerId ~= nil
	local uid = isPlayerOwned and tostring(ownerId) or nil

	if isPlayerOwned then
		local existing = module.PlayerMonsters[uid]
		if existing and existing.Model and existing.Model.Parent then
			pcall(function()
				existing.Model:Destroy()
			end)
			module.PlayerMonsters[uid] = nil
		end
	end

	local template = models:FindFirstChild(monsterData.Race)
	if not template then
		warn("No template found for race: " .. tostring(monsterData.Race))
		return nil
	end

	local monsterModel = template:FindFirstChildWhichIsA("Model"):Clone()
	monsterModel.Parent = workspace
	monsterModel.Name = monsterData.Name or monsterData.Race

	local humanoid = monsterModel:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			if _G and _G.STATES then
				_G.STATES:SetState(monsterModel, "Dead")
			end
		end)
	end

	local stats = monsterData.Stats or {}
	monsterModel:SetAttribute("Hp", stats.Hp or 100)
	monsterModel:SetAttribute("MP", stats.Mp or 100)
	monsterModel:SetAttribute("MaxMP", stats.Mp or 100)
	monsterModel:SetAttribute("Strength", stats.Strength or stats.STR or 10)
	monsterModel:SetAttribute("Defense", stats.Defense or stats.DEF or 10)
	monsterModel:SetAttribute("Skill", stats.Skill or stats.SKL or 10)
	monsterModel:SetAttribute("Speed", stats.Speed or stats.SPD or 10)
	monsterModel:SetAttribute("Intelligence", stats.Intelligence or stats.INT or 10)
	monsterModel:SetAttribute("Luck", stats.Luck or stats.LCK or 10)
	monsterModel:SetAttribute("Name", monsterData.Name or monsterData.Race)
	monsterModel:SetAttribute("Race", monsterData.Race)
	monsterModel:SetAttribute("Personality", tostring(monsterData.Personality))
	monsterModel:SetAttribute("Stage", monsterData.Stage)
	monsterModel:SetAttribute("Level", monsterData.Level or 1) -- Add level attribute

	local actualOwnerId = ownerId or monsterData.OwnerId
	if actualOwnerId then
		monsterModel:SetAttribute("OwnerId", tonumber(actualOwnerId))
		module.RegisterPlayerMonster(actualOwnerId, monsterModel, monsterData)
	end

	UIB.AttachHpBar(monsterModel)

	if isPlayerOwned then
		module.PlayerMonsters[uid] = {Model = monsterModel, Data = monsterData}
	end

	monsterModel.Destroying:Connect(function()
		if isPlayerOwned and module.PlayerMonsters[uid] and module.PlayerMonsters[uid].Model == monsterModel then
			module.PlayerMonsters[uid] = nil
		end
	end)

        if monsterData.Moves then
                local moveCount = 0
                for i, moveInfo in (monsterData.Moves) do
                        local moveId: string? = nil
                        if typeof(moveInfo) == "table" then
                                moveId = moveInfo.id or (moveInfo.move and moveInfo.move.id)
                        elseif typeof(moveInfo) == "string" then
                                moveId = moveInfo
                        end

                        if moveId and moveId ~= "" then
                                monsterModel:SetAttribute("Move" .. i, moveId)
                                moveCount += 1
                        end
                end
                monsterModel:SetAttribute("MoveCount", moveCount)
        end

	if humanoid then
		humanoid.MaxHealth = stats.Hp or 100
		humanoid.Health = humanoid.MaxHealth
	else
		warn("No humanoid found in monster model: " .. monsterModel.Name)
	end

	if _G and _G.STATES and typeof(_G.STATES.SetState) == "function" then
		_G.STATES:SetState(monsterModel, "Following")
	end
	
	_G.EFFECTS.EmitterEffect({Name = "Atomic2", Position = monsterModel.PrimaryPart, Duration = 1, Weld = monsterModel.PrimaryPart })

	
	if ownerId then
		monsterModel:PivotTo(Players:GetPlayerByUserId(ownerId).Character.HumanoidRootPart.CFrame * CFrame.new(5,0,0))
		--_G.EFFECTS.EmitterEffect({Name = "Atomic2", Position = monsterModel.PrimaryPart, Duration = 3, Weld = monsterModel.PrimaryPart })
	end
	return monsterModel, monsterData
end

-- Rest of the existing functions remain the same...
function module.GetPlayerMonsterData(playerId)
	if not module.PlayerMonsters then return nil end
	return module.PlayerMonsters[tostring(playerId)]
end

function module.GetPlayerMonster(player)
	if not player then return nil end
	local m = ownerToMonster[player]
	if m and m.Parent then return m end
	return _findExistingOwned(player)
end

function module.RegisterPlayerMonster(playerId, monsterModel, monsterData)
	if not module.PlayerMonsters then
		module.PlayerMonsters = {}
	end
	module.PlayerMonsters[tostring(playerId)] = {Model = monsterModel, Data = monsterData}
	print("Registered player monster for ID: " .. tostring(playerId) .. " - " .. monsterModel.Name)
end

function module.UnregisterPlayerMonster(playerId)
	if module.PlayerMonsters then
		local playerIdStr = tostring(playerId)
		if module.PlayerMonsters[playerIdStr] then
			print("Unregistered player monster for ID: " .. playerIdStr)
			module.PlayerMonsters[playerIdStr] = nil
		end
	end
end

local function _replaceModel(oldM, newM, keepCFrame)
	local pivotCF = keepCFrame
	if not pivotCF and oldM and oldM.Parent then
		pivotCF = oldM:GetPivot()
	end
	if pivotCF then
		newM:PivotTo(pivotCF)
	end
	newM.Parent = workspace
	if oldM and oldM.Parent then
		task.defer(function()
			if oldM and oldM.Parent then
				oldM:Destroy()
			end
		end)
	end
end

return module