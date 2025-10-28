-- ReplicatedStorage/Modules/MoveUnlocks.lua
local Races = require(game.ReplicatedStorage.Modules.Races)

local MoveUnlocks = {}

-- Normalized move unlock requirements for 1-999 stat scale
MoveUnlocks.DEFS = {
	-- ===== Universal & Basic Moves =====
	BasicAttack = {
		triggers = { "start" },
		gates = {
			minStage = "Fledgeling",
		},
	},

	-- ===== Progenitor Family Moves =====
	WeavePulse = {
		triggers = { "evolution", "training" },
		gates = {
			minStage = "Fledgeling",
			raceAnyOf = {"RealitySeed"},
			minStats = { Intelligence = 30 },
		},
		weights = function(ctx)
			local intStat = ctx.stats.Intelligence or 0
			return 0.3 + math.min(0.7, intStat / 100)
		end,
	},

	CosmicThread = {
		triggers = { "evolution", "training" },
		gates = {
			minStage = "Fledgeling",
			raceAnyOf = {"RealitySeed"},
			minStats = { Intelligence = 60 },
			requiresAnyOfMoves = {"WeavePulse"},
		},
		weights = function(ctx)
			local intStat = ctx.stats.Intelligence or 0
			return 0.4 + math.min(0.6, intStat / 150)
		end,
	},

	VoidRay = {
		triggers = { "evolution", "combat" },
		gates = {
			minStage = "Rookie",
			raceAnyOf = {"CosmicWeaver", "VoidWalker"},
			minStats = { Intelligence = 90 },
		},
		weights = function(ctx)
			local intStat = ctx.stats.Intelligence or 0
			local wins = ctx.wins or 0
			return 0.3 + math.min(0.7, (intStat / 200 + wins / 20) / 2)
		end,
	},

	ArchitectShield = {
		triggers = { "evolution", "training" },
		gates = {
			minStage = "Champion",
			raceAnyOf = {"Architect", "CosmicWeaver"},
			minStats = { Intelligence = 120, Defense = 80 },
		},
		weights = function(ctx)
			local intStat = ctx.stats.Intelligence or 0
			local defStat = ctx.stats.Defense or 0
			return 0.4 + math.min(0.6, (intStat + defStat) / 400)
		end,
	},

	PrimeConceptOverload = {
		triggers = { "evolution" },
		gates = {
			minStage = "Unique",
			raceAnyOf = {"PrimeConcept"},
			minStats = { Intelligence = 200 },
			minBond = 70,
		},
		weights = function(ctx)
			local intStat = ctx.stats.Intelligence or 0
			local bond = ctx.bond or 0
			return 0.5 + math.min(0.5, (intStat / 300 + bond / 140) / 2)
		end,
	},

	Singularity = {
		triggers = { "evolution", "combat" },
		gates = {
			minStage = "Champion",
			minStats = { Intelligence = 150, Speed = 100 },
			personalityAnyOf = {"Strategist","Unpredictable"},
			raceAnyOf = {"CosmicWeaver","Architect","VoidWalker"},
		},
		weights = function(ctx)
			local intStat = ctx.stats.Intelligence or 0
			local spdStat = ctx.stats.Speed or 0
			return 0.4 + math.min(0.6, (intStat + spdStat) / 500)
		end,
	},

	WarpLance = {
		triggers = { "evolution", "training" },
		gates = {
			minStage = "Rookie",
			raceAnyOf = {"CosmicWeaver", "VoidWalker"},
			minStats = { Intelligence = 110, Speed = 70 },
		},
		weights = function(ctx)
			local intStat = ctx.stats.Intelligence or 0
			local spdStat = ctx.stats.Speed or 0
			return 0.3 + math.min(0.7, (intStat + spdStat) / 360)
		end,
	},

	ChronoBreak = {
		triggers = { "evolution" },
		gates = {
			minStage = "Elder",
			raceAnyOf = {"Architect", "PrimeConcept"},
			minStats = { Intelligence = 180, Skill = 120 },
			minWins = 15,
		},
		weights = function(ctx)
			local intStat = ctx.stats.Intelligence or 0
			local sklStat = ctx.stats.Skill or 0
			local wins = ctx.wins or 0
			return 0.4 + math.min(0.6, (intStat / 250 + sklStat / 200 + wins / 30) / 3)
		end,
	},

	RealityShift = {
		triggers = { "evolution" },
		gates = {
			minStage = "Unique",
			raceAnyOf = {"PrimeConcept", "EntropicVoid"},
			minStats = { Intelligence = 220 },
			minBond = 80,
		},
		weights = function(ctx)
			local intStat = ctx.stats.Intelligence or 0
			local bond = ctx.bond or 0
			return 0.6 + math.min(0.4, (intStat / 300 + bond / 160) / 2)
		end,
	},

	GenesisBeam = {
		triggers = { "evolution", "combat" },
		gates = {
			minStage = "Elder",
			raceAnyOf = {"Architect", "CosmicWeaver"},
			minStats = { Intelligence = 190, Speed = 130 },
			minWins = 20,
		},
		weights = function(ctx)
			local intStat = ctx.stats.Intelligence or 0
			local spdStat = ctx.stats.Speed or 0
			local wins = ctx.wins or 0
			return 0.5 + math.min(0.5, (intStat / 250 + spdStat / 200 + wins / 40) / 3)
		end,
	},

	-- ===== Construct Family Moves =====
	CoreBash = {
		triggers = { "evolution", "training" },
		gates = {
			minStage = "Fledgeling",
			raceAnyOf = {"Core"},
			minStats = { Strength = 40, Defense = 30 },
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			local defStat = ctx.stats.Defense or 0
			return 0.3 + math.min(0.7, (strStat + defStat) / 140)
		end,
	},

	KineticSlam = {
		triggers = { "evolution", "combat" },
		gates = {
			minStage = "Rookie",
			raceAnyOf = {"Golem", "Titan"},
			minStats = { Strength = 80, Defense = 60 },
			minWins = 3,
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			local defStat = ctx.stats.Defense or 0
			local wins = ctx.wins or 0
			return 0.3 + math.min(0.7, (strStat / 160 + defStat / 120 + wins / 6) / 3)
		end,
	},

	Overcrank = {
		triggers = { "training" },
		gates = {
			minStage = "Rookie",
			raceAnyOf = {"Golem", "Titan", "Colossus"},
			minStats = { Strength = 70, Skill = 50 },
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			local sklStat = ctx.stats.Skill or 0
			return 0.4 + math.min(0.6, (strStat + sklStat) / 240)
		end,
	},

	Hyperdrive = {
		triggers = { "evolution", "training" },
		gates = {
			minStage = "Champion",
			raceAnyOf = {"Titan", "Colossus"},
			minStats = { Speed = 90, Skill = 70 },
		},
		weights = function(ctx)
			local spdStat = ctx.stats.Speed or 0
			local sklStat = ctx.stats.Skill or 0
			return 0.3 + math.min(0.7, (spdStat + sklStat) / 320)
		end,
	},

	MagneticVortex = {
		triggers = { "evolution", "combat" },
		gates = {
			minStage = "Champion",
			raceAnyOf = {"Titan", "Colossus"},
			minStats = { Intelligence = 100, Strength = 90 },
			minWins = 8,
		},
		weights = function(ctx)
			local intStat = ctx.stats.Intelligence or 0
			local strStat = ctx.stats.Strength or 0
			local wins = ctx.wins or 0
			return 0.4 + math.min(0.6, (intStat / 200 + strStat / 180 + wins / 16) / 3)
		end,
	},

	PlasmaDischarge = {
		triggers = { "evolution" },
		gates = {
			minStage = "Elder",
			raceAnyOf = {"Colossus", "IronColoss"},
			minStats = { Intelligence = 140, Strength = 120 },
			minWins = 12,
		},
		weights = function(ctx)
			local intStat = ctx.stats.Intelligence or 0
			local strStat = ctx.stats.Strength or 0
			local wins = ctx.wins or 0
			return 0.5 + math.min(0.5, (intStat / 280 + strStat / 240 + wins / 24) / 3)
		end,
	},

	NanoSwarm = {
		triggers = { "training", "combat" },
		gates = {
			minStage = "Rookie",
			raceAnyOf = {"Golem", "Titan", "Colossus"},
			minStats = { Intelligence = 85 },
			requiresAnyOfMoves = {"CoreBash"},
		},
		weights = function(ctx)
			local intStat = ctx.stats.Intelligence or 0
			local progress = ctx.progress and (ctx.progress.Tech or 0) or 0
			return 0.3 + math.min(0.7, (intStat / 170 + progress / 50) / 2)
		end,
	},

	QuantumSlip = {
		triggers = { "evolution" },
		gates = {
			minStage = "Elder",
			raceAnyOf = {"IronColoss", "PrimordialConstruct"},
			minStats = { Speed = 150, Skill = 120 },
			minBond = 50,
		},
		weights = function(ctx)
			local spdStat = ctx.stats.Speed or 0
			local sklStat = ctx.stats.Skill or 0
			local bond = ctx.bond or 0
			return 0.4 + math.min(0.6, (spdStat / 300 + sklStat / 240 + bond / 100) / 3)
		end,
	},

	-- ===== Beast Family Moves =====
	PhotonJab = {
		triggers = { "evolution", "training" },
		gates = {
			minStage = "Fledgeling",
			raceAnyOf = {"Hopling"},
			minStats = { Skill = 35, Speed = 30 },
		},
		weights = function(ctx)
			local sklStat = ctx.stats.Skill or 0
			local spdStat = ctx.stats.Speed or 0
			return 0.3 + math.min(0.7, (sklStat + spdStat) / 130)
		end,
	},

	FeintDash = {
		triggers = { "evolution", "training" },
		gates = {
			minStage = "Fledgeling",
			raceAnyOf = {"Hopling", "LightFoot"},
			minStats = { Speed = 45, Skill = 40 },
			requiresAnyOfMoves = {"PhotonJab"},
		},
		weights = function(ctx)
			local spdStat = ctx.stats.Speed or 0
			local sklStat = ctx.stats.Skill or 0
			return 0.4 + math.min(0.6, (spdStat + sklStat) / 170)
		end,
	},

	StarUppercut = {
		triggers = { "evolution", "training", "combat" },
		gates = {
			minStage = "Rookie",
			personalityAnyOf = {"Aggressive","Reckless"},
			minStats = { Strength = 72, Skill = 48 },
			minWins = 3,
			raceAnyOf = {"LightFoot","Strikeron","Monarchare"},
			requiresAnyOfMoves = {"PhotonJab","FeintDash"},
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			local sklStat = ctx.stats.Skill or 0
			local progress = ctx.progress and (ctx.progress.Melee or 0) or 0
			return 0.5 + math.min(0.5, (strStat / 144 + sklStat / 96 + progress / 50) / 3)
		end,
	},

	GuardUp = {
		triggers = { "training" },
		gates = {
			minStage = "Rookie",
			minStats = { Defense = 54 },
			raceAnyOf = {"Hopling", "LightFoot", "Strikeron"},
		},
		weights = function(ctx)
			local defStat = ctx.stats.Defense or 0
			local progress = ctx.progress and (ctx.progress.Defensive or 0) or 0
			return 0.4 + math.min(0.6, (defStat / 108 + progress / 40) / 2)
		end,
	},

	GravityWell = {
		triggers = { "evolution", "combat" },
		gates = {
			minStage = "Champion",
			raceAnyOf = {"Strikeron", "Monarchare"},
			minStats = { Intelligence = 110, Skill = 90 },
			minWins = 6,
		},
		weights = function(ctx)
			local intStat = ctx.stats.Intelligence or 0
			local sklStat = ctx.stats.Skill or 0
			local wins = ctx.wins or 0
			return 0.4 + math.min(0.6, (intStat / 220 + sklStat / 180 + wins / 12) / 3)
		end,
	},

	PhotonBarrage = {
		triggers = { "evolution", "training" },
		gates = {
			minStage = "Rookie",
			raceAnyOf = {"LightFoot", "Strikeron"},
			minStats = { Skill = 85, Speed = 70 },
			requiresAnyOfMoves = {"PhotonJab"},
		},
		weights = function(ctx)
			local sklStat = ctx.stats.Skill or 0
			local spdStat = ctx.stats.Speed or 0
			return 0.3 + math.min(0.7, (sklStat + spdStat) / 310)
		end,
	},

	TemporalRift = {
		triggers = { "evolution" },
		gates = {
			minStage = "Elder",
			raceAnyOf = {"Monarchare", "SteelBoxer"},
			minStats = { Intelligence = 150, Skill = 130 },
			minBond = 45,
		},
		weights = function(ctx)
			local intStat = ctx.stats.Intelligence or 0
			local sklStat = ctx.stats.Skill or 0
			local bond = ctx.bond or 0
			return 0.5 + math.min(0.5, (intStat / 300 + sklStat / 260 + bond / 90) / 3)
		end,
	},

	CelestialCombo = {
		triggers = { "evolution" },
		gates = {
			minStage = "Unique",
			raceAnyOf = {"SteelBoxer"},
			minStats = { Strength = 180, Skill = 160 },
			minWins = 25,
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			local sklStat = ctx.stats.Skill or 0
			local wins = ctx.wins or 0
			return 0.6 + math.min(0.4, (strStat / 360 + sklStat / 320 + wins / 50) / 3)
		end,
	},

	VoidStep = {
		triggers = { "evolution", "combat" },
		gates = {
			minStage = "Champion",
			minStats = { Intelligence = 105, Speed = 75 },
			raceAnyOf = {"VoidWalker","CosmicWeaver","Strikeron"},
		},
		weights = function(ctx)
			local intStat = ctx.stats.Intelligence or 0
			local spdStat = ctx.stats.Speed or 0
			return 0.4 + math.min(0.6, (intStat + spdStat) / 360)
		end,
	},

	-- ===== Raptor Family Moves =====
	Tackle = {
		triggers = { "evolution", "training" },
		gates = {
			minStage = "Fledgeling",
			raceAnyOf = {"Raptor"},
			minStats = { Strength = 35 },
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			return 0.3 + math.min(0.7, strStat / 70)
		end,
	},

	Bite = {
		triggers = { "evolution", "training" },
		gates = {
			minStage = "Fledgeling",
			raceAnyOf = {"Raptor"},
			minStats = { Strength = 45, Skill = 25 },
			requiresAnyOfMoves = {"Tackle"},
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			local sklStat = ctx.stats.Skill or 0
			return 0.4 + math.min(0.6, (strStat + sklStat) / 140)
		end,
	},

	Crush = {
		triggers = { "evolution", "training" },
		gates = {
			minStage = "Rookie",
			raceAnyOf = {"Dino"},
			minStats = { Strength = 70 },
			requiresAnyOfMoves = {"Tackle", "Bite"},
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			return 0.3 + math.min(0.7, strStat / 140)
		end,
	},

	Roar = {
		triggers = { "training" },
		gates = {
			minStage = "Rookie",
			raceAnyOf = {"Dino", "Beast", "Dragon"},
			minStats = { Strength = 60, Defense = 40 },
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			local defStat = ctx.stats.Defense or 0
			return 0.4 + math.min(0.6, (strStat + defStat) / 200)
		end,
	},

	TailSwipe = {
		triggers = { "evolution", "combat" },
		gates = {
			minStage = "Rookie",
			raceAnyOf = {"Dino", "Beast"},
			minStats = { Strength = 65, Skill = 50 },
			minWins = 2,
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			local sklStat = ctx.stats.Skill or 0
			local wins = ctx.wins or 0
			return 0.3 + math.min(0.7, (strStat / 130 + sklStat / 100 + wins / 4) / 3)
		end,
	},

	Pounce = {
		triggers = { "evolution", "training" },
		gates = {
			minStage = "Champion",
			raceAnyOf = {"Beast"},
			minStats = { Strength = 90, Speed = 80 },
			requiresAnyOfMoves = {"Tackle", "Bite"},
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			local spdStat = ctx.stats.Speed or 0
			return 0.4 + math.min(0.6, (strStat + spdStat) / 340)
		end,
	},

	SavageClaw = {
		triggers = { "evolution", "combat" },
		gates = {
			minStage = "Champion",
			raceAnyOf = {"Beast"},
			minStats = { Strength = 110, Skill = 70 },
			minWins = 8,
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			local sklStat = ctx.stats.Skill or 0
			local wins = ctx.wins or 0
			return 0.5 + math.min(0.5, (strStat / 220 + sklStat / 140 + wins / 16) / 3)
		end,
	},

	Intimidate = {
		triggers = { "training" },
		gates = {
			minStage = "Champion",
			raceAnyOf = {"Beast", "Dragon"},
			minStats = { Strength = 95, Defense = 75 },
			personalityAnyOf = {"Aggressive", "Reckless"},
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			local defStat = ctx.stats.Defense or 0
			return 0.4 + math.min(0.6, (strStat + defStat) / 340)
		end,
	},

	FlameBreath = {
		triggers = { "evolution" },
		gates = {
			minStage = "Elder",
			raceAnyOf = {"Dragon", "NetherDragon"},
			minStats = { Intelligence = 120, Strength = 100 },
			minWins = 10,
		},
		weights = function(ctx)
			local intStat = ctx.stats.Intelligence or 0
			local strStat = ctx.stats.Strength or 0
			local wins = ctx.wins or 0
			return 0.5 + math.min(0.5, (intStat / 240 + strStat / 200 + wins / 20) / 3)
		end,
	},

	WingBuffet = {
		triggers = { "evolution", "training" },
		gates = {
			minStage = "Elder",
			raceAnyOf = {"Dragon", "SkyBehemoth"},
			minStats = { Strength = 110, Speed = 90 },
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			local spdStat = ctx.stats.Speed or 0
			return 0.4 + math.min(0.6, (strStat + spdStat) / 400)
		end,
	},

	Quake = {
		triggers = { "evolution", "combat" },
		gates = {
			minStage = "Elder",
			raceAnyOf = {"Behemoth", "SkyBehemoth"},
			minStats = { Strength = 130, Defense = 110 },
			minWins = 15,
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			local defStat = ctx.stats.Defense or 0
			local wins = ctx.wins or 0
			return 0.5 + math.min(0.5, (strStat / 260 + defStat / 220 + wins / 30) / 3)
		end,
	},

	GuardBreak = {
		triggers = { "training" },
		gates = {
			minStage = "Rookie",
			minStats = { Strength = 54 },
			raceAnyOf = {"Dino", "Beast", "LightFoot", "Strikeron"},
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			local progress = ctx.progress and (ctx.progress.Melee or 0) or 0
			return 0.4 + math.min(0.6, (strStat / 108 + progress / 40) / 2)
		end,
	},

	Rend = {
		triggers = { "evolution", "combat" },
		gates = {
			minStage = "Elder",
			raceAnyOf = {"Behemoth", "DreadBeast"},
			minStats = { Strength = 140, Skill = 100 },
			minWins = 12,
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			local sklStat = ctx.stats.Skill or 0
			local wins = ctx.wins or 0
			return 0.5 + math.min(0.5, (strStat / 280 + sklStat / 200 + wins / 24) / 3)
		end,
	},

	NetherFlame = {
		triggers = { "evolution" },
		gates = {
			minStage = "Unique",
			raceAnyOf = {"NetherDragon"},
			minStats = { Intelligence = 180, Strength = 160 },
			minBond = 60,
		},
		weights = function(ctx)
			local intStat = ctx.stats.Intelligence or 0
			local strStat = ctx.stats.Strength or 0
			local bond = ctx.bond or 0
			return 0.6 + math.min(0.4, (intStat / 360 + strStat / 320 + bond / 120) / 3)
		end,
	},

	VoidWing = {
		triggers = { "evolution", "training" },
		gates = {
			minStage = "Unique",
			raceAnyOf = {"NetherDragon", "EntropicVoid"},
			minStats = { Speed = 170, Skill = 140 },
		},
		weights = function(ctx)
			local spdStat = ctx.stats.Speed or 0
			local sklStat = ctx.stats.Skill or 0
			return 0.5 + math.min(0.5, (spdStat + sklStat) / 620)
		end,
	},

	AbyssRoar = {
		triggers = { "evolution", "combat" },
		gates = {
			minStage = "Unique",
			raceAnyOf = {"NetherDragon"},
			minStats = { Strength = 190, Intelligence = 170 },
			minWins = 20,
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			local intStat = ctx.stats.Intelligence or 0
			local wins = ctx.wins or 0
			return 0.6 + math.min(0.4, (strStat / 380 + intStat / 340 + wins / 40) / 3)
		end,
	},

	Frenzy = {
		triggers = { "evolution" },
		gates = {
			minStage = "Elder",
			raceAnyOf = {"DreadBeast"},
			minStats = { Strength = 150, Speed = 120 },
			maxCareMistakes = 999,
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			local spdStat = ctx.stats.Speed or 0
			local careMistakes = ctx.careMistakes or 0
			-- Higher chance with more care mistakes (corrupted path)
			local corruptionBonus = math.min(0.3, careMistakes / 50)
			return 0.4 + math.min(0.6, (strStat / 300 + spdStat / 240) / 2) + corruptionBonus
		end,
	},

	Ravage = {
		triggers = { "evolution", "combat" },
		gates = {
			minStage = "Elder",
			raceAnyOf = {"DreadBeast"},
			minStats = { Strength = 160, Skill = 110 },
			minWins = 18,
			maxCareMistakes = 999,
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			local sklStat = ctx.stats.Skill or 0
			local wins = ctx.wins or 0
			local careMistakes = ctx.careMistakes or 0
			local corruptionBonus = math.min(0.2, careMistakes / 60)
			return 0.5 + math.min(0.5, (strStat / 320 + sklStat / 220 + wins / 36) / 3) + corruptionBonus
		end,
	},

	Howl = {
		triggers = { "training" },
		gates = {
			minStage = "Elder",
			raceAnyOf = {"DreadBeast", "Behemoth"},
			minStats = { Strength = 140 },
			maxCareMistakes = 999,
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			local careMistakes = ctx.careMistakes or 0
			local corruptionBonus = math.min(0.2, careMistakes / 40)
			return 0.4 + math.min(0.6, strStat / 280) + corruptionBonus
		end,
	},

	JetRush = {
		triggers = { "evolution", "training" },
		gates = {
			minStage = "Elder",
			raceAnyOf = {"SkyBehemoth"},
			minStats = { Speed = 150, Strength = 120 },
		},
		weights = function(ctx)
			local spdStat = ctx.stats.Speed or 0
			local strStat = ctx.stats.Strength or 0
			return 0.5 + math.min(0.5, (spdStat + strStat) / 540)
		end,
	},

	SkyQuake = {
		triggers = { "evolution", "combat" },
		gates = {
			minStage = "Elder",
			raceAnyOf = {"SkyBehemoth"},
			minStats = { Strength = 170, Intelligence = 130 },
			minWins = 16,
		},
		weights = function(ctx)
			local strStat = ctx.stats.Strength or 0
			local intStat = ctx.stats.Intelligence or 0
			local wins = ctx.wins or 0
			return 0.5 + math.min(0.5, (strStat / 340 + intStat / 260 + wins / 32) / 3)
		end,
	},

	AerialGuard = {
		triggers = { "training" },
		gates = {
			minStage = "Elder",
			raceAnyOf = {"SkyBehemoth"},
			minStats = { Defense = 140, Speed = 130 },
		},
		weights = function(ctx)
			local defStat = ctx.stats.Defense or 0
			local spdStat = ctx.stats.Speed or 0
			return 0.4 + math.min(0.6, (defStat + spdStat) / 540)
		end,
	},

	-- ===== Inherited Move Handler =====
	InheritedMove = {
		triggers = { "evolution" },
		gates = {
			minStage = "Rookie", -- Can inherit from Fledgeling to Rookie and beyond
		},
		weights = function(ctx)
			-- Higher chance to inherit if bond is high and care mistakes are low
			local bond = ctx.bond or 0
			local careMistakes = ctx.careMistakes or 0
			local bondBonus = math.min(0.3, bond / 200)
			local careBonus = math.max(0, 0.2 - (careMistakes * 0.05))
			return 0.5 + bondBonus + careBonus
		end,
	},
}

-- ===== Stage Order Mapping =====
local STAGE_RANK = Races.STAGE or {Fledgeling=1,Rookie=2,Champion=3,Elder=4,Unique=5}

-- ===== Utility Functions =====
local function stageOK(cur, minStage)
	if not minStage then return true end
	return (STAGE_RANK[cur] or 0) >= (STAGE_RANK[minStage] or 0)
end

local function meetsGates(ctx, gates)
	if not gates then return true end
	if gates.minStage and not stageOK(ctx.stage, gates.minStage) then return false end
	if gates.minWins and (ctx.wins or 0) < gates.minWins then return false end
	if gates.minBond and (ctx.bond or 0) < gates.minBond then return false end
	if gates.maxCareMistakes and (ctx.careMistakes or 0) > gates.maxCareMistakes then return false end
	if gates.minStats then
		for k,v in pairs(gates.minStats) do if (ctx.stats[k] or 0) < v then return false end end
	end
	if gates.personalityAnyOf and #gates.personalityAnyOf > 0 then
		local p = tostring(ctx.personality or "")
		local ok = false
		for _,nm in ipairs(gates.personalityAnyOf) do if nm==p then ok=true break end end
		if not ok then return false end
	end
	if gates.raceAnyOf and #gates.raceAnyOf > 0 then
		local ok = false
		for _,r in ipairs(gates.raceAnyOf) do if r==ctx.race then ok=true break end end
		if not ok then return false end
	end
	if gates.requiresAnyOfMoves and #gates.requiresAnyOfMoves > 0 then
		local have = {}
		for _,m in ipairs(ctx.currentMoves or {}) do
			local id = (m.id) or (m.move and m.move.id) or m
			if id then have[id] = true end
		end
		local ok = false
		for _,need in ipairs(gates.requiresAnyOfMoves) do if have[need] then ok=true break end end
		if not ok then return false end
	end
	return true
end

-- ===== Move Granting Function =====
local function grantMove(playerData, moveId, sourceTag)
	playerData.LearnedMoves = playerData.LearnedMoves or {}

	-- Check if move already learned
	for _, move in ipairs(playerData.LearnedMoves) do
		if move.id == moveId then return false end
	end

	-- Add to learned moves
	table.insert(playerData.LearnedMoves, { id = moveId, when = os.time(), source = sourceTag })

	-- Add to current moves if not already present
	local Moves = require(game.ReplicatedStorage.Modules.Moves)
	local mv = Moves:GetMove(playerData.Race, moveId) or Moves:GetMove(nil, moveId)
	if not mv then return false end

	playerData.Moves = playerData.Moves or {}
	local seen = {}
	for _,e in ipairs(playerData.Moves) do
		local id = (e.move and e.move.id) or e.id
		if id then seen[id] = true end
	end

	if not seen[mv.id] then
		table.insert(playerData.Moves, { move = mv, rarity = mv.rarity })
		-- Trim to max 4 moves, keeping the most recent
		if #playerData.Moves > 4 then
			table.remove(playerData.Moves, 1)
		end
	end
	return true
end

-- ===== Inherited Move Handling =====
function MoveUnlocks.HandleInheritedMove(playerData, previousMoves)
	if not previousMoves or #previousMoves == 0 then return nil end

	-- Create context for inherited move chance calculation
	local ctx = {
		race = playerData.Race,
		stage = playerData.Stage,
		bond = playerData.Bond or 0,
		careMistakes = playerData.CareMistakes or 0,
	}

	-- Check if we should inherit a move
	local inheritedMoveDef = MoveUnlocks.DEFS.InheritedMove
	if inheritedMoveDef and meetsGates(ctx, inheritedMoveDef.gates) then
		local chance = inheritedMoveDef.weights and inheritedMoveDef.weights(ctx) or 0.5
		if math.random() < chance then
			-- Pick a random move from previous stage (excluding BasicAttack)
			local eligibleMoves = {}
			for _, move in ipairs(previousMoves) do
				local moveId = (move.move and move.move.id) or move.id
				if moveId and moveId ~= "BasicAttack" then
					table.insert(eligibleMoves, moveId)
				end
			end

			if #eligibleMoves > 0 then
				local inheritedMoveId = eligibleMoves[math.random(1, #eligibleMoves)]
				if grantMove(playerData, inheritedMoveId, "inherited") then
					return inheritedMoveId
				end
			end
		end
	end

	return nil
end

-- ===== Main Unlock Resolution =====
function MoveUnlocks.ResolveUnlocks(playerData, trigger, opts)
	local out = {}
	local ctx = {
		race = playerData.Race,
		stage = playerData.Stage,
		stats = playerData.Stats or {},
		wins  = playerData.Wins or 0,
		bond  = playerData.Bond or 0,
		careMistakes = playerData.CareMistakes or 0,
		personality = playerData.Personality,
		currentMoves = playerData.Moves,
		progress = playerData.MoveProgress or {},
		extra = opts,
	}

	-- Handle inherited moves during evolution
	if trigger == "evolution" and opts and opts.previousMoves then
		local inheritedMove = MoveUnlocks.HandleInheritedMove(playerData, opts.previousMoves)
		if inheritedMove then
			table.insert(out, inheritedMove)
		end
	end

	-- Check all move definitions for unlocks
	for moveId, def in pairs(MoveUnlocks.DEFS) do
		-- Skip inherited move definition as it's handled separately
		if moveId ~= "InheritedMove" then
			local trigOK = (not def.triggers) or table.find(def.triggers, trigger)
			if trigOK and meetsGates(ctx, def.gates) then
				local bias = (def.weights and def.weights(ctx)) or 1
				if math.random() < math.clamp(bias,0,1) then
					if grantMove(playerData, moveId, trigger) then
						table.insert(out, moveId)
						_G.EFFECTS.EmitterEffect("EvolutionAura", {Where = _G.MONSTERGENERATOR.GetPlayerMonster()})
					end
				end
			end
		end
	end

	return out
end

return MoveUnlocks