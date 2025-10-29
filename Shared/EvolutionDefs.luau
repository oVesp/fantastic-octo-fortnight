-- ReplicatedStorage/Modules/EvolutionDefs.lua
-- Digimon-like branching + convergence. Races decidem moves (com exceções opcionais).

local EvolutionDefs = {}

-- ===== Progressive Stage Caps =====
EvolutionDefs.StageCaps = {
        Proto = 120,
        Fledgeling = 300,   -- Total stats cap
        Rookie = 600,
        Champion = 1200,
        Elder = 1800,
        Unique = 2000
}

-- ===== Stage Order =====
EvolutionDefs.StageOrder = { "Proto","Fledgeling","Rookie","Champion","Elder","Unique" }

-- ===== Race Stage Mapping =====
EvolutionDefs.RaceStage = {
	-- Raptor line
	--Raptor="Fledgeling", Dino="Rookie", Beast="Champion", Dragon="Elder", Behemoth="Elder",
	-- Construct / Core line
        GenesisLarva="Proto",
        Core="Fledgeling", Golem="Rookie", Titan="Champion", Colossus="Elder", PrimordialConstruct="Unique",
	-- Demonic line
	Imp="Fledgeling", Devil="Rookie", Archdemon="Champion", AbyssLord="Elder",
	-- Progenitor / Reality line
	RealitySeed="Fledgeling", CosmicWeaver="Champion", VoidWalker="Elder", Architect="Elder", PrimeConcept="Unique",
	-- Boxer / Lagomorph line
	Hopling="Fledgeling", LightFoot="Rookie", Strikeron="Champion", Monarchare="Elder",
	-- Convergences
	SteelBoxer="Elder", IronColoss="Unique", DreadBeast="Elder", SkyBehemoth="Elder",
	NetherDragon="Unique", OrderArchitect="Unique", EntropicVoid="Unique",
}

function EvolutionDefs:GetEvolutionChance(currentRace, ctx, candidate)
	if not candidate or not candidate.gates then return 0 end

	local progress = 0
	local totalGates = 0

	-- Calculate progress towards requirements
	if candidate.gates.minStats then
		for stat, minV in pairs(candidate.gates.minStats) do
			local current = ctx.stats[stat] or 0
			local statProgress = math.min(1, current / minV)
			progress = progress + statProgress
			totalGates = totalGates + 1
		end
	end

	if candidate.gates.minBond then
		local bondProgress = math.min(1, (ctx.bond or 0) / candidate.gates.minBond)
		progress = progress + bondProgress
		totalGates = totalGates + 1
	end

	if candidate.gates.minWins then
		local winProgress = math.min(1, (ctx.wins or 0) / candidate.gates.minWins)
		progress = progress + winProgress
		totalGates = totalGates + 1
	end

	if totalGates == 0 then return 1.0 end -- No requirements = 100% chance

        local overallProgress = progress / totalGates
	-- Base chance increases with progress, with forced evolution at very low progress
	if overallProgress >= 0.9 then
		return 0.95 -- 95% chance when nearly all requirements met
	elseif overallProgress >= 0.7 then
		return 0.75 -- 75% chance when most requirements met
	elseif overallProgress >= 0.5 then
		return 0.5 -- 50% chance when half requirements met
	elseif overallProgress >= 0.3 then
		return 0.25 -- 25% chance when some progress
	elseif overallProgress >= 0.1 then
		return 0.1 -- 10% base chance with minimal progress
	else
		return 0.05 -- 5% forced evolution chance even with no progress
	end
end

-- ===== Defaults por Path (aplica quando o edge não define prioridade/gates) =====
EvolutionDefs.DefaultPathMeta = {
	Natural     = { priority = 5 },
	Power       = { priority = 7, gates = { minWins = 3 } },
	Wisdom      = { priority = 7, gates = { minStats = { Intelligence = 15 } } },
	Friendship  = { priority = 8, gates = { minBond = 25, maxCareMistakes = 3 } },
	Corrupted   = { priority = 6, gates = { maxCareMistakes = 999 } },
}

-- ===== Ferramentas internas =====
local function meetsGates(ctx, gates)
	if not gates then return true end
	if gates.minBond and (ctx.bond or 0) < gates.minBond then return false end
	if gates.minWins and (ctx.wins or 0) < gates.minWins then return false end
	if gates.maxCareMistakes and (ctx.careMistakes or 0) > gates.maxCareMistakes then return false end
	if gates.minStats then
		for stat, minV in pairs(gates.minStats) do
			if (ctx.stats[stat] or 0) < minV then return false end
		end
	end
	if gates.personalityAnyOf and #gates.personalityAnyOf > 0 then
		local p = tostring(ctx.personality or "")
		local ok = false
		for _, name in ipairs(gates.personalityAnyOf) do
			if name == p then ok = true break end
		end
		if not ok then return false end
	end
	return true
end

local function normalizeEdges(list)
	local out = {}
	for _, v in ipairs(list or {}) do
		if typeof(v) == "string" then
			table.insert(out, { target = v })
		else
			table.insert(out, {
				target   = v.target,
				path     = v.path,
				priority = v.priority,
				gates    = v.gates,
			})
		end
	end
	return out
end

-- ===== Evolution Graph is now sourced from Races module =====
-- This provides unified evolution definitions across the codebase
-- Use GetCandidates() to access evolution paths

-- ===== API =====
function EvolutionDefs:GetStage(race)
	-- Delegate to Races module for single source of truth
	local ok, Races = pcall(function() return require(game.ReplicatedStorage.Modules.Races) end)
	if ok and Races and Races.GetStage then
		return Races:GetStage(race) or self.RaceStage[race] or "Fledgeling"
	end
	return self.RaceStage[race] or "Fledgeling"
end

function EvolutionDefs:GetCandidates(currentRace, ctx)
	-- Use Races module as primary source for evolution data
	local ok, Races = pcall(function() return require(game.ReplicatedStorage.Modules.Races) end)
	if not ok or not Races then return {} end

	local evolutions = Races:GetEvolutions(currentRace)
	if not evolutions or #evolutions == 0 then return {} end

	local candidates = {}
	for _, evo in ipairs(evolutions) do
		-- Convert Races format to EvolutionDefs format
		local priority = 5 -- default priority

		-- Calculate priority based on requirements
		if evo.gates then
			if evo.gates.minBond and evo.gates.minBond >= 50 then priority = priority + 3 end
			if evo.gates.minWins and evo.gates.minWins >= 10 then priority = priority + 2 end
			if evo.gates.maxCareMistakes and evo.gates.maxCareMistakes <= 3 then priority = priority + 2 end
		end

		-- Check if gates are met
		if meetsGates(ctx or {}, evo.gates) then
			table.insert(candidates, {
				target = evo.target,
				priority = priority,
				gates = evo.gates,
				weights = evo.weights
			})
		end
	end

	table.sort(candidates, function(a,b)
		if (a.priority or 0) == (b.priority or 0) then
			return (a.target or "") < (b.target or "")
		end
		return (a.priority or 0) > (b.priority or 0)
	end)

	return candidates
end

-- Critério padrão: maior priority; empate → alfabética. (Troque por ponderado se quiser)
function EvolutionDefs:PickEvolution(currentRace, ctx)
	local cands = self:GetCandidates(currentRace, ctx)
	return cands[1] and cands[1].target or nil
end

-- ===== Moves por Raça (raça decide por padrão) =====
EvolutionDefs.MovesByRace = {
        GenesisLarva = { "BasicAttack" },
        -- Raptor
        Raptor = { "Tackle", "Bite" },
	Dino = { "Crush", "Roar", "TailSwipe" },
	Beast = { "Pounce", "SavageClaw", "Intimidate" },
	Dragon = { "FlameBreath", "WingBuffet", "Roar" },
	Behemoth = { "Quake", "GuardBreak", "Rend" },
	NetherDragon = { "NetherFlame", "VoidWing", "AbyssRoar" },
	DreadBeast = { "Frenzy", "Ravage", "Howl" },
	SkyBehemoth = { "JetRush", "SkyQuake", "AerialGuard" },

	-- Construct
	Core = { "PebbleShot", "Harden" },
	Golem = { "RockFist", "Fortify" },
	Titan = { "Earthshatter", "Bulwark" },
	Colossus = { "SeismicSlam", "StoneWall" },
	PrimordialConstruct = { "PrimeStrike", "AegisMatrix" },
	IronColoss = { "IronDread", "MagnaWall", "CataclysmicSlam" },

	-- Demonic
	Imp = { "ImpFire", "Taunt" },
	Devil = { "HellClaw", "DarkPulse" },
	Archdemon = { "AbyssalHowl", "SoulDrain" },
	AbyssLord = { "Cataclysm", "OblivionMark" },

	-- Progenitor / Reality
	RealitySeed = { "CosmicThread", "Weave Pulse" },
	CosmicWeaver = { "Singularity", "WarpLance" },
	VoidWalker = { "VoidStep", "NullSlash" },
	Architect = { "Blueprint", "Construct" },
	PrimeConcept = { "PrimeLaw", "Rewrite" },
	EntropicVoid = { "EntropyWave", "NullVortex", "Erase" },
	OrderArchitect = { "PrimeEdict", "AxiomWall", "Reconstruct" },

	-- Boxer / Lagomorph
	Hopling = { "Jab", "Feint" },
	LightFoot = { "QuickHook", "Counter" },
	Strikeron = { "PowerStraight", "Weave" },
	Monarchare = { "RoyalGuard", "StarUpper" },
	SteelBoxer = { "MetalKnuckle", "SteelGuard", "DempseyRoll" },
}

-- Exceções de moves (opcionais)
function EvolutionDefs.ExceptionMovesForRace(race, ctx)
	-- Ex.: estrategista ganha "Feint" extra no ramo boxer
	if (race == "LightFoot" or race == "Strikeron") and ctx.personality == "Strategist" then
		local base = EvolutionDefs.MovesByRace[race] or {}
		local out = { table.unpack(base) }
		local hasFeint = false
		for _,m in ipairs(out) do if m=="Feint" then hasFeint=true break end end
		if not hasFeint then table.insert(out, "Feint") end
		return out
	end
	-- Ex.: SteelBoxer mantém 1 move do estágio anterior (se houver)
	if race == "SteelBoxer" and ctx.previousMoves and ctx.previousMoves[1] then
		local out = { table.unpack(EvolutionDefs.MovesByRace[race] or {}) }
		table.insert(out, 1, ctx.previousMoves[1])
		return out
	end
	return nil
end

function EvolutionDefs:GetMovesForRace(race, ctx)
	local custom = self.ExceptionMovesForRace(race, ctx or {})
	if custom then return custom end
	local base = self.MovesByRace[race]
	if base and #base > 0 then return table.clone(base) end

	-- Fallback: tenta pegar do módulo Moves, se existir
	local ok, Moves = pcall(function() return require(game.ReplicatedStorage.Modules.Moves) end)
	if ok and Moves and Moves.GetStarterMoves then
		print("STARTERMOVES")
		return Moves:GetStarterMoves(race)
	end
	return {}
end

-- ===== Utilidades de edição =====
function EvolutionDefs:Register(fromRace, edgeOrTarget)
	self.EvolutionGraph[fromRace] = self.EvolutionGraph[fromRace] or {}
	table.insert(self.EvolutionGraph[fromRace], edgeOrTarget)
end

function EvolutionDefs:Override(fromRace, list)
	self.EvolutionGraph[fromRace] = list or {}
end

function EvolutionDefs:SetStage(race, stage)
	self.RaceStage[race] = stage
end

function EvolutionDefs:Validate()
	local ok, errs = true, {}
	for from, list in pairs(self.EvolutionGraph) do
		for i, edge in ipairs(normalizeEdges(list)) do
			if type(edge.target) ~= "string" then
				ok = false; table.insert(errs, string.format("Edge inválida em %s[%d]: target ausente", from, i))
			end
		end
	end
	return ok, errs
end

return EvolutionDefs