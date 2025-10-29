-- Races.lua
-- Define stages, race metadata (includes "baseRaceFamily"), and Digimon-like evolution rules.
-- Compatible with Summon restricted to Fledgeling for MVP.

local Races = {}
Races.__index = Races

-- ===== Progressive Stage Caps =====
Races.StageCaps = {
        Proto = 120,        -- Pre-evolution stage
        Fledgeling = 300,   -- Total stats cap
        Rookie = 800,
        Champion = 1200,
        Elder = 1800,
        Unique = 2000
}

-- ===== Stage Order =====
local STAGE = {
        Proto = 0,
        Fledgeling = 1,
        Rookie = 2,
        Champion = 3,
        Elder = 4,
        Unique = 5,
}

Races.STAGE = STAGE

-- ===== Summonable Stages =====
Races.SUMMONABLE_STAGES = {
        Proto = true,
        Fledgeling = true,
}

-- ===== Utility Functions =====
local function clamp(x, a, b) return math.max(a, math.min(b, x)) end
local function normStat(v, minV, maxV)
        if maxV == minV then return 0 end
        return clamp((v - minV) / (maxV - minV), 0, 1)
end

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

-- ===== Race Definitions =====
local DEFINITIONS = {
        -- ===== UNIVERSAL PRE-EVOLUTION =====
        Blank = {
                displayName = "Blank",
                stage = "Proto",
                baseRaceFamily = "Proto",
                isSummonable = true,
                evolutions = {
                        {
                                target = "RealitySeed",
                                requiredStage = "Fledgeling",
                                weights = function(ctx)
                                        local stats = ctx.stats or {}
                                        local stageCap = Races.StageCaps.Proto or 120
                                        local function stat(...)
                                                for _, key in ipairs({...}) do
                                                        local v = stats[key]
                                                        if typeof(v) == "number" then
                                                                return v
                                                        end
                                                end
                                                return 0
                                        end

                                        local INT = normStat(stat("Intelligence", "INT"), 0, stageCap * 0.9)
                                        local SPD = normStat(stat("Speed", "SPD"), 0, stageCap * 0.9)
                                        local bond = math.clamp((ctx.bond or 0) / 100, 0, 1)
                                        local alignment = 0.05 + 0.35 * INT + 0.35 * SPD + 0.1 * bond
                                        return math.clamp(alignment * 0.6, 0, 0.6)
                                end,
                        },
                        {
                                target = "Core",
                                requiredStage = "Fledgeling",
                                weights = function(ctx)
                                        local stats = ctx.stats or {}
                                        local stageCap = Races.StageCaps.Proto or 120
                                        local function stat(...)
                                                for _, key in ipairs({...}) do
                                                        local v = stats[key]
                                                        if typeof(v) == "number" then
                                                                return v
                                                        end
                                                end
                                                return 0
                                        end

                                        local STR = normStat(stat("Strength", "STR"), 0, stageCap * 0.5)
                                        local DEF = normStat(stat("Defense", "DEF"), 0, stageCap * 0.5)
                                        local HP = normStat(stat("Hp", "HP"), 0, stageCap)
                                        local alignment = 0.25 + 0.45 * STR + 0.35 * DEF + 0.1 * HP
                                        return math.clamp(alignment, 0, 1.2)
                                end,
                        },
                        {
                                target = "Hopling",
                                requiredStage = "Fledgeling",
                                weights = function(ctx)
                                        local stats = ctx.stats or {}
                                        local stageCap = Races.StageCaps.Proto or 120
                                        local function stat(...)
                                                for _, key in ipairs({...}) do
                                                        local v = stats[key]
                                                        if typeof(v) == "number" then
                                                                return v
                                                        end
                                                end
                                                return 0
                                        end

                                        local SPD = normStat(stat("Speed", "SPD"), 0, stageCap * 0.6)
                                        local SKL = normStat(stat("Skill", "SKL"), 0, stageCap * 0.6)
                                        local LCK = normStat(stat("Luck", "LCK"), 0, stageCap * 0.6)
                                        local alignment = 0.3 + 0.4 * SPD + 0.35 * SKL + 0.1 * LCK
                                        return math.clamp(alignment, 0, 1.3)
                                end,
                        },
                }
        },

        -- ===== PROGENITOR FAMILY =====
        RealitySeed = {
                displayName = "Reality Seed",
		stage = "Fledgeling",
		baseRaceFamily = "Progenitor",
		isSummonable = true,
		evolutions = {
			{
				target = "CosmicWeaver",
				requiredStage = "Champion",
				gates = {
					minStats = { Intelligence = 70, Speed = 50 },
					baseRaceFamily = "Progenitor",
				},
				weights = function(ctx)
					local intStat = ctx.stats.Intelligence or 0
					local spdStat = ctx.stats.Speed or 0
					local stageCap = Races.StageCaps[ctx.stage] or 300
					local INT = normStat(intStat, 0, stageCap * 0.5)
					local SPD = normStat(spdStat, 0, stageCap * 0.5)
					local BOND = normStat(ctx.bond or 0, 0, 100)
					local pathBonus = (ctx.cameFrom == "RealitySeed") and 0.1 or 0
					return 0.45 * INT + 0.35 * SPD + 0.2 * BOND + pathBonus
				end,
			},
		}
	},

	CosmicWeaver = {
		displayName = "Cosmic Weaver",
		stage = "Champion",
		baseRaceFamily = "Progenitor",
		isSummonable = false,
		evolutions = {
			{
				target = "VoidWalker",
				requiredStage = "Elder",
				gates = {
					minStats = { Intelligence = 150, Speed = 90 },
					minWins = 8,
					baseRaceFamily = "Progenitor",
				},
				weights = function(ctx)
					local intStat = ctx.stats.Intelligence or 0
					local spdStat = ctx.stats.Speed or 0
					local stageCap = Races.StageCaps[ctx.stage] or 1200
					local INT = normStat(intStat, 0, stageCap * 0.5)
					local SPD = normStat(spdStat, 0, stageCap * 0.5)
					local WINS = normStat(ctx.wins or 0, 0, 20)
					local pathBonus = (ctx.cameFrom == "CosmicWeaver") and 0.15 or 0
					return 0.4 * INT + 0.3 * SPD + 0.3 * WINS + pathBonus
				end,
			},
			{
				target = "Architect",
				requiredStage = "Elder",
				gates = {
					minStats = { Intelligence = 160, Defense = 100 },
					minBond = 40,
					baseRaceFamily = "Progenitor",
				},
				weights = function(ctx)
					local intStat = ctx.stats.Intelligence or 0
					local defStat = ctx.stats.Defense or 0
					local stageCap = Races.StageCaps[ctx.stage] or 1200
					local INT = normStat(intStat, 0, stageCap * 0.5)
					local DEF = normStat(defStat, 0, stageCap * 0.5)
					local BOND = normStat(ctx.bond or 0, 0, 100)
					local pathBonus = (ctx.cameFrom == "CosmicWeaver") and 0.12 or 0
					return 0.5 * INT + 0.3 * DEF + 0.2 * BOND + pathBonus
				end,
			},
		}
	},

	VoidWalker = {
		displayName = "Void Walker",
		stage = "Elder",
		baseRaceFamily = "Progenitor",
		isSummonable = false,
		evolutions = {
			{
				target = "EntropicVoid",
				requiredStage = "Unique",
				gates = {
					minStats = { Strength = 200, Intelligence = 180 },
					minWins = 15,
					baseRaceFamily = "Progenitor",
				},
				weights = function(ctx)
					local strStat = ctx.stats.Strength or 0
					local intStat = ctx.stats.Intelligence or 0
					local stageCap = Races.StageCaps[ctx.stage] or 1800
					local STR = normStat(strStat, 0, stageCap * 0.5)
					local INT = normStat(intStat, 0, stageCap * 0.5)
					local WINS = normStat(ctx.wins or 0, 0, 30)
					local pathBonus = (ctx.cameFrom == "VoidWalker") and 0.2 or 0
					return 0.45 * STR + 0.35 * INT + 0.2 * WINS + pathBonus
				end,
			},
		}
	},

	Architect = {
		displayName = "Architect",
		stage = "Elder",
		baseRaceFamily = "Progenitor",
		isSummonable = false,
		evolutions = {
			{
				target = "PrimeConcept",
				requiredStage = "Unique",
				gates = {
					minStats = { Intelligence = 220, Skill = 150 },
					minBond = 70,
					maxCareMistakes = 2,
					baseRaceFamily = "Progenitor",
				},
				weights = function(ctx)
					local intStat = ctx.stats.Intelligence or 0
					local sklStat = ctx.stats.Skill or 0
					local stageCap = Races.StageCaps[ctx.stage] or 1800
					local INT = normStat(intStat, 0, stageCap * 0.5)
					local SKL = normStat(sklStat, 0, stageCap * 0.5)
					local BOND = normStat(ctx.bond or 0, 0, 100)
					local careBonus = (ctx.careMistakes or 0) <= 2 and 0.1 or 0
					local pathBonus = (ctx.cameFrom == "Architect") and 0.25 or 0
					return 0.4 * INT + 0.3 * SKL + 0.2 * BOND + careBonus + pathBonus
				end,
			},
		}
	},

	PrimeConcept = {
		displayName = "Prime Concept",
		stage = "Unique",
		baseRaceFamily = "Progenitor",
		isSummonable = false,
		evolutions = {},
	},

	EntropicVoid = {
		displayName = "Entropic Void",
		stage = "Unique",
		baseRaceFamily = "Progenitor",
		isSummonable = false,
		evolutions = {},
	},

	-- ===== CONSTRUCT FAMILY =====
	Core = {
		displayName = "Core",
		stage = "Fledgeling",
		baseRaceFamily = "Construct",
		isSummonable = true,
		evolutions = {
			{
				target = "Golem",
				requiredStage = "Rookie",
				gates = {
					minStats = { Defense = 60, Strength = 40 },
					baseRaceFamily = "Construct",
				},
				weights = function(ctx)
					local defStat = ctx.stats.Defense or 0
					local strStat = ctx.stats.Strength or 0
					local stageCap = Races.StageCaps[ctx.stage] or 300
					local DEF = normStat(defStat, 0, stageCap * 0.5)
					local STR = normStat(strStat, 0, stageCap * 0.5)
					local pathBonus = (ctx.cameFrom == "Core") and 0.1 or 0
					return 0.6 * DEF + 0.4 * STR + pathBonus
				end,
			},
		}
	},

	Golem = {
		displayName = "Golem",
		stage = "Rookie",
		baseRaceFamily = "Construct",
		isSummonable = false,
		evolutions = {
			{
				target = "Titan",
				requiredStage = "Champion",
				gates = {
					minStats = { Defense = 120, Strength = 100 },
					minWins = 5,
					baseRaceFamily = "Construct",
				},
				weights = function(ctx)
					local defStat = ctx.stats.Defense or 0
					local strStat = ctx.stats.Strength or 0
					local stageCap = Races.StageCaps[ctx.stage] or 600
					local DEF = normStat(defStat, 0, stageCap * 0.5)
					local STR = normStat(strStat, 0, stageCap * 0.5)
					local WINS = normStat(ctx.wins or 0, 0, 15)
					local pathBonus = (ctx.cameFrom == "Golem") and 0.15 or 0
					return 0.5 * DEF + 0.3 * STR + 0.2 * WINS + pathBonus
				end,
			},
		}
	},

	Titan = {
		displayName = "Titan",
		stage = "Champion",
		baseRaceFamily = "Construct",
		isSummonable = false,
		evolutions = {
			{
				target = "Colossus",
				requiredStage = "Elder",
				gates = {
					minStats = { Defense = 200, Hp = 180 },
					minWins = 10,
					baseRaceFamily = "Construct",
				},
				weights = function(ctx)
					local defStat = ctx.stats.Defense or 0
					local hpStat = ctx.stats.Hp or 0
					local stageCap = Races.StageCaps[ctx.stage] or 1200
					local DEF = normStat(defStat, 0, stageCap * 0.5)
					local HP = normStat(hpStat, 0, stageCap * 0.6)
					local WINS = normStat(ctx.wins or 0, 0, 25)
					local pathBonus = (ctx.cameFrom == "Titan") and 0.2 or 0
					return 0.5 * DEF + 0.3 * HP + 0.2 * WINS + pathBonus
				end,
			},
		}
	},

	Colossus = {
		displayName = "Colossus",
		stage = "Elder",
		baseRaceFamily = "Construct",
		isSummonable = false,
		evolutions = {
			{
				target = "IronColoss",
				requiredStage = "Unique",
				gates = {
					minStats = { Defense = 280, Hp = 250 },
					minBond = 60,
					maxCareMistakes = 3,
					baseRaceFamily = "Construct",
				},
				weights = function(ctx)
					local defStat = ctx.stats.Defense or 0
					local hpStat = ctx.stats.Hp or 0
					local stageCap = Races.StageCaps[ctx.stage] or 1800
					local DEF = normStat(defStat, 0, stageCap * 0.5)
					local HP = normStat(hpStat, 0, stageCap * 0.6)
					local BOND = normStat(ctx.bond or 0, 0, 100)
					local careBonus = (ctx.careMistakes or 0) <= 3 and 0.15 or 0
					local pathBonus = (ctx.cameFrom == "Colossus") and 0.25 or 0
					return 0.4 * DEF + 0.3 * HP + 0.2 * BOND + careBonus + pathBonus
				end,
			},
		}
	},

	IronColoss = {
		displayName = "Iron Coloss",
		stage = "Unique",
		baseRaceFamily = "Construct",
		isSummonable = false,
		evolutions = {},
	},

	-- ===== BEAST FAMILY =====
	Hopling = {
		displayName = "Hopling",
		stage = "Fledgeling",
		baseRaceFamily = "Beast",
		isSummonable = true,
		evolutions = {
			{
				target = "LightFoot",
				requiredStage = "Rookie",
				gates = {
					minStats = { Skill = 50, Speed = 45 },
					baseRaceFamily = "Beast",
				},
				weights = function(ctx)
					local sklStat = ctx.stats.Skill or 0
					local spdStat = ctx.stats.Speed or 0
					local stageCap = Races.StageCaps[ctx.stage] or 300
					local SKL = normStat(sklStat, 0, stageCap * 0.5)
					local SPD = normStat(spdStat, 0, stageCap * 0.5)
					local pathBonus = (ctx.cameFrom == "Hopling") and 0.1 or 0
					return 0.5 * SKL + 0.5 * SPD + pathBonus
				end,
			},
		}
	},

	LightFoot = {
		displayName = "LightFoot",
		stage = "Rookie",
		baseRaceFamily = "Beast",
		isSummonable = false,
		evolutions = {
			{
				target = "Strikeron",
				requiredStage = "Champion",
				gates = {
					minStats = { Strength = 100, Skill = 90 },
					minWins = 6,
					baseRaceFamily = "Beast",
				},
				weights = function(ctx)
					local strStat = ctx.stats.Strength or 0
					local sklStat = ctx.stats.Skill or 0
					local stageCap = Races.StageCaps[ctx.stage] or 600
					local STR = normStat(strStat, 0, stageCap * 0.5)
					local SKL = normStat(sklStat, 0, stageCap * 0.5)
					local WINS = normStat(ctx.wins or 0, 0, 15)
					local pathBonus = (ctx.cameFrom == "LightFoot") and 0.15 or 0
					return 0.5 * STR + 0.3 * SKL + 0.2 * WINS + pathBonus
				end,
			},
		}
	},

	Strikeron = {
		displayName = "Strikeron",
		stage = "Champion",
		baseRaceFamily = "Beast",
		isSummonable = false,
		evolutions = {
			{
				target = "Monarchare",
				requiredStage = "Elder",
				gates = {
					minStats = { Strength = 180, Skill = 160 },
					minWins = 12,
					baseRaceFamily = "Beast",
				},
				weights = function(ctx)
					local strStat = ctx.stats.Strength or 0
					local sklStat = ctx.stats.Skill or 0
					local stageCap = Races.StageCaps[ctx.stage] or 1200
					local STR = normStat(strStat, 0, stageCap * 0.5)
					local SKL = normStat(sklStat, 0, stageCap * 0.5)
					local WINS = normStat(ctx.wins or 0, 0, 25)
					local pathBonus = (ctx.cameFrom == "Strikeron") and 0.2 or 0
					return 0.5 * STR + 0.3 * SKL + 0.2 * WINS + pathBonus
				end,
			},
		}
	},

	Monarchare = {
		displayName = "Monarchare",
		stage = "Elder",
		baseRaceFamily = "Beast",
		isSummonable = false,
		evolutions = {
			{
				target = "SteelBoxer",
				requiredStage = "Unique",
				gates = {
					minStats = { Strength = 250, Skill = 220 },
					minBond = 50,
					baseRaceFamily = "Beast",
				},
				weights = function(ctx)
					local strStat = ctx.stats.Strength or 0
					local sklStat = ctx.stats.Skill or 0
					local stageCap = Races.StageCaps[ctx.stage] or 1800
					local STR = normStat(strStat, 0, stageCap * 0.5)
					local SKL = normStat(sklStat, 0, stageCap * 0.5)
					local BOND = normStat(ctx.bond or 0, 0, 100)
					local pathBonus = (ctx.cameFrom == "Monarchare") and 0.25 or 0
					return 0.4 * STR + 0.3 * SKL + 0.3 * BOND + pathBonus
				end,
			},
		}
	},

	SteelBoxer = {
		displayName = "Steel Boxer",
		stage = "Unique",
		baseRaceFamily = "Beast",
		isSummonable = false,
		evolutions = {},
	},

	-- ===== RAPTOR FAMILY =====
	--Raptor = {
	--	displayName = "Raptor",
	--	stage = "Fledgeling",
	--	baseRaceFamily = "Raptor",
	--	isSummonable = true,
	--	evolutions = {
	--		{
	--			target = "Dino",
	--			requiredStage = "Rookie",
	--			gates = {
	--				minStats = { Strength = 50, Speed = 40 },
	--				baseRaceFamily = "Raptor",
	--			},
	--			weights = function(ctx)
	--				local strStat = ctx.stats.Strength or 0
	--				local spdStat = ctx.stats.Speed or 0
	--				local stageCap = Races.StageCaps[ctx.stage] or 300
	--				local STR = normStat(strStat, 0, stageCap * 0.5)
	--				local SPD = normStat(spdStat, 0, stageCap * 0.5)
	--				local pathBonus = (ctx.cameFrom == "Raptor") and 0.1 or 0
	--				return 0.6 * STR + 0.4 * SPD + pathBonus
	--			end,
	--		},
	--	}
	--},

	Dino = {
		displayName = "Dino",
		stage = "Rookie",
		baseRaceFamily = "Raptor",
		isSummonable = false,
		evolutions = {
			{
				target = "Beast",
				requiredStage = "Champion",
				gates = {
					minStats = { Strength = 110, Defense = 80 },
					minWins = 5,
					baseRaceFamily = "Raptor",
				},
				weights = function(ctx)
					local strStat = ctx.stats.Strength or 0
					local defStat = ctx.stats.Defense or 0
					local stageCap = Races.StageCaps[ctx.stage] or 600
					local STR = normStat(strStat, 0, stageCap * 0.5)
					local DEF = normStat(defStat, 0, stageCap * 0.5)
					local WINS = normStat(ctx.wins or 0, 0, 15)
					local pathBonus = (ctx.cameFrom == "Dino") and 0.15 or 0
					return 0.5 * STR + 0.3 * DEF + 0.2 * WINS + pathBonus
				end,
			},
		}
	},

	Beast = {
		displayName = "Beast",
		stage = "Champion",
		baseRaceFamily = "Raptor",
		isSummonable = false,
		evolutions = {
			{
				target = "Dragon",
				requiredStage = "Elder",
				gates = {
					minStats = { Strength = 190, Intelligence = 120 },
					minWins = 10,
					baseRaceFamily = "Raptor",
				},
				weights = function(ctx)
					local strStat = ctx.stats.Strength or 0
					local intStat = ctx.stats.Intelligence or 0
					local stageCap = Races.StageCaps[ctx.stage] or 1200
					local STR = normStat(strStat, 0, stageCap * 0.5)
					local INT = normStat(intStat, 0, stageCap * 0.5)
					local WINS = normStat(ctx.wins or 0, 0, 25)
					local pathBonus = (ctx.cameFrom == "Beast") and 0.2 or 0
					return 0.5 * STR + 0.3 * INT + 0.2 * WINS + pathBonus
				end,
			},
		}
	},

	Dragon = {
		displayName = "Dragon",
		stage = "Elder",
		baseRaceFamily = "Raptor",
		isSummonable = false,
		evolutions = {
			{
				target = "NetherDragon",
				requiredStage = "Unique",
				gates = {
					minStats = { Strength = 260, Intelligence = 200 },
					minBond = 55,
					baseRaceFamily = "Raptor",
				},
				weights = function(ctx)
					local strStat = ctx.stats.Strength or 0
					local intStat = ctx.stats.Intelligence or 0
					local stageCap = Races.StageCaps[ctx.stage] or 1800
					local STR = normStat(strStat, 0, stageCap * 0.5)
					local INT = normStat(intStat, 0, stageCap * 0.5)
					local BOND = normStat(ctx.bond or 0, 0, 100)
					local pathBonus = (ctx.cameFrom == "Dragon") and 0.25 or 0
					return 0.4 * STR + 0.3 * INT + 0.3 * BOND + pathBonus
				end,
			},
		}
	},

	NetherDragon = {
		displayName = "Nether Dragon",
		stage = "Unique",
		baseRaceFamily = "Raptor",
		isSummonable = false,
		evolutions = {},
	},
}

-- ===== Public API =====
function Races:Get(name)
	return DEFINITIONS[name]
end

function Races:Exists(name)
	return DEFINITIONS[name] ~= nil
end

function Races:GetStage(name)
	local def = DEFINITIONS[name]
	return def and def.stage or nil
end

function Races:IsSummonable(name)
	local def = DEFINITIONS[name]
	if not def then return false end

	if def.isSummonable ~= nil then
		return def.isSummonable
	end

	return Races.SUMMONABLE_STAGES[def.stage] == true
end

function Races:GetBaseRaceFamily(name)
	local def = DEFINITIONS[name]
	return def and def.baseRaceFamily or nil
end

function Races:GetEvolutions(name)
	local def = DEFINITIONS[name]
	return (def and def.evolutions) or {}
end

function Races:ListByStage(stage)
	local out = {}
	for k, v in pairs(DEFINITIONS) do
		if v.stage == stage then
			table.insert(out, k)
		end
	end
	return out
end

function Races:ListSummonable()
	local out = {}
	for k, v in pairs(DEFINITIONS) do
		if self:IsSummonable(k) then
			table.insert(out, k)
		end
	end
	return out
end

function Races:ValidateEvolution(evolution, currentRace, targetRace)
	if not evolution then return false, "Evolution not found" end

	local targetDef = DEFINITIONS[targetRace]
	if not targetDef then
		return false, "Target race does not exist: " .. tostring(targetRace)
	end

	if evolution.requiredStage and evolution.requiredStage ~= targetDef.stage then
		return false, string.format("Evolution stage mismatch: required %s but target is %s", 
			evolution.requiredStage, targetDef.stage)
	end

	return true
end

function Races:GetStatCapForStage(stage, statType)
        local stageCap = self.StageCaps[stage] or 300

        if statType == "Hp" or statType == "Mp" then
                return stageCap * 2
        else
                return stageCap * 0.6
        end
end

function Races:ClampStatsByStage(stats, stage)
        if typeof(stats) ~= "table" then
                return stats
        end

        stage = stage or "Fledgeling"

        for canonical, aliases in pairs(STAT_ALIASES) do
                local cap = self:GetStatCapForStage(stage, canonical)
                if cap then
                        for _, key in ipairs(aliases) do
                                local value = stats[key]
                                if typeof(value) == "number" then
                                        local clamped = math.max(1, math.floor(math.min(value, cap)))
                                        stats[key] = clamped
                                end
                        end
                end
        end

        return stats
end

-- ===== Evolution Helper Functions =====
function Races:CalculateEvolutionProgress(currentRace, ctx, targetEvolution)
	local progress = 0
	local totalGates = 0

	if targetEvolution.gates then
		local gates = targetEvolution.gates

		-- Stat requirements
		if gates.minStats then
			for stat, minValue in pairs(gates.minStats) do
				local currentValue = ctx.stats[stat] or 0
				local statProgress = math.min(1, currentValue / minValue)
				progress = progress + statProgress
				totalGates = totalGates + 1
			end
		end

		-- Bond requirement
		if gates.minBond then
			local bondProgress = math.min(1, (ctx.bond or 0) / gates.minBond)
			progress = progress + bondProgress
			totalGates = totalGates + 1
		end

		-- Win requirement
		if gates.minWins then
			local winProgress = math.min(1, (ctx.wins or 0) / gates.minWins)
			progress = progress + winProgress
			totalGates = totalGates + 1
		end

		-- Care mistakes (inverse progress)
		if gates.maxCareMistakes then
			local careMistakes = ctx.careMistakes or 0
			local careProgress = math.max(0, 1 - (careMistakes / gates.maxCareMistakes))
			progress = progress + careProgress
			totalGates = totalGates + 1
		end
	end

	if totalGates == 0 then return 1.0 end

	return progress / totalGates
end

function Races:GetForcedEvolutionChance(progress)
	-- Forced evolution chance increases as progress decreases to prevent hardlocking
	if progress >= 0.9 then return 0.95
	elseif progress >= 0.7 then return 0.75
	elseif progress >= 0.5 then return 0.5
	elseif progress >= 0.3 then return 0.25
	elseif progress >= 0.1 then return 0.1
	else return 0.05 end
end

return setmetatable({}, Races)