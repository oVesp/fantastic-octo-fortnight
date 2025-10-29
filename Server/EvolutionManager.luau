--[[
    EvolutionManager.lua
    Responsável por: checar requisitos, decidir evolução, aplicar boosts/moves,
    reconstruir o monstro, reposicionar e notificar o client.

    Dependências usadas no seu projeto:
      - _G.DATA                (sistema de dados com proxy)
      - _G.MONSTERGENERATOR    (BuildMonster / RollMonster)
      - ReplicatedStorage.Modules.Races (GetEvolutions / GetStage)
      - ReplicatedStorage.Modules.Moves (GetStarterMoves)
      - Remotes: EvolutionRequest (client->server), EvolutionEffect (server->client), EvolutionComplete (server->client)
]]

local EvolutionManager = {}
EvolutionManager.__index = EvolutionManager

-- Services
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")


-- Remotes
local Remotes = RS:WaitForChild("Remotes")
local EvolutionRequest = Remotes:WaitForChild("EvolutionRequest")
local EvolutionEffect  = Remotes:WaitForChild("EvolutionEffect")
local EvolutionComplete = Remotes:WaitForChild("EvolutionComplete")

-- Modules
local Moves = require(RS.Modules.Moves)
local Races = require(RS.Modules.Races)
local EvoDef = require(RS.Modules.EvolutionDefs)
local MoveUnlocks = require(RS.Modules.MoveUnlocks)


-- Config
local EFFECT_DURATION = 2.0 -- segundos antes de aplicar a evolução (tempo do VFX)
local MINIMUM_GATED_WEIGHT = 0.01 -- Peso mínimo para evoluções com gates não cumpridos

-- Multiplicadores por estágio (ajuste livre)
-- Multiplicadores por estágio
local EVO_GAINS = {
	Fledgeling = { HpPct=0.10, MpPct=0.10, StrPct=0.05, DefPct=0.05, SklPct=0.05, SpdPct=0.05, IntPct=0.05, LckPct=0.05, HpFlat=0,  MpFlat=0  },
	Rookie     = { HpPct=0.12, MpPct=0.12, StrPct=0.08, DefPct=0.08, SklPct=0.06, SpdPct=0.06, IntPct=0.08, LckPct=0.06, HpFlat=20, MpFlat=10 },
	Champion   = { HpPct=0.15, MpPct=0.15, StrPct=0.12, DefPct=0.12, SklPct=0.10, SpdPct=0.10, IntPct=0.12, LckPct=0.10, HpFlat=35, MpFlat=15 },
	Elder      = { HpPct=0.18, MpPct=0.18, StrPct=0.16, DefPct=0.16, SklPct=0.12, SpdPct=0.12, IntPct=0.16, LckPct=0.12, HpFlat=50, MpFlat=20 },
	Unique     = { HpPct=0.22, MpPct=0.22, StrPct=0.20, DefPct=0.20, SklPct=0.15, SpdPct=0.15, IntPct=0.20, LckPct=0.15, HpFlat=80, MpFlat=30 },
}

-- Bônus flat por estágio (ajuste fino por design)
local EVOLUTION_FLAT_ADDS = {
	Fledgeling = { Hp=0,  Mp=0 },
	Rookie     = { Hp=20, Mp=10 },
	Champion   = { Hp=35, Mp=15 },
	Elder      = { Hp=50, Mp=20 },
	Unique     = { Hp=80, Mp=30 },
}

-- ===== Utils =====

local function snapshot(tbl)
	return HttpService:JSONDecode(HttpService:JSONEncode(tbl or {}))
end

local function readNum(stats, keyA, keyB)
	local v = stats[keyA]; if typeof(v)=="number" then return v end
	if keyB then v = stats[keyB]; if typeof(v)=="number" then return v end end
	return nil
end
-- Escreve stats em-loco (sem trocar a referência da tabela do proxy)
local function assignStatsInPlace(targetStats: table, fromStats: table)
	if not targetStats or not fromStats then return end
	for k, v in pairs(fromStats) do
		-- só escreve números válidos
		if typeof(v) == "number" then
			targetStats[k] = v
		end
	end
	-- opcional: normalize aliases
	if targetStats.HP then targetStats.Hp = targetStats.HP end
	if targetStats.MP then targetStats.Mp = targetStats.MP end
	if targetStats.Hp then targetStats.HP = targetStats.Hp end
	if targetStats.Mp then targetStats.MP = targetStats.Mp end
end

-- Boost calculado a partir de um snapshot (pode usar sua applyStatBoosts existente)
--local function computeBoostedStats(statsSnapshot: table, newStage: string)
--	-- use aqui sua lógica atual (multiplicadores + bônus flat)
--	-- abaixo um exemplo mínimo; troque pelos seus valores/func:
--	local boosted = table.clone(statsSnapshot)
--	local mul = EVOLUTION_BOOSTS[newStage]
--	local add = EVOLUTION_FLAT_ADDS[newStage]

--	if mul then
--		for k, m in pairs(mul) do
--			local cur = tonumber(boosted[k] or boosted[string.upper(k)] or boosted[string.sub(k,1,1):upper()..string.sub(k,2)])
--			if cur then boosted[k] = math.max(1, math.floor(cur * m)) end
--		end
--	end
--	if add then
--		for k, a in pairs(add) do
--			local cur = tonumber(boosted[k] or boosted[string.upper(k)] or boosted[string.sub(k,1,1):upper()..string.sub(k,2)]) or 0
--			boosted[k] = math.max(1, math.floor(cur + a))
--		end
--	end
--	-- normalização mínima
--	for _, key in ipairs({ "Hp","HP","Mp","MP","Strength","Defense","Skill","Speed","Intelligence","Luck" }) do
--		if typeof(boosted[key]) == "number" then
--			boosted[key] = math.max(1, math.floor(boosted[key]))
--		end
--	end
--	-- garante aliases coerentes
--	boosted.HP = boosted.Hp or boosted.HP
--	boosted.MP = boosted.Mp or boosted.MP
--	boosted.Hp = boosted.HP
--	boosted.Mp = boosted.MP
--	return boosted
--end

local function addClampFloor(x, delta)
	local v = (tonumber(x) or 0) + (tonumber(delta) or 0)
	if v ~= v then v = 0 end
	return math.max(1, math.floor(v))
end

local function writeAlias(stats, keyMain, keyAlias, value)
	if typeof(value) == "number" then
		stats[keyMain] = value
		if keyAlias then stats[keyAlias] = value end
	end
end

local function applyEvolutionGainsInPlace(stats, newStage)
	local g = EVO_GAINS[newStage]; if not g then return end
	-- HP / MP (aditivo)
	local hp = readNum(stats, "Hp", "HP") or 0
	local mp = readNum(stats, "Mp", "MP") or 0
	local hpDelta = math.floor(hp * (g.HpPct or 0)) + (g.HpFlat or 0)
	local mpDelta = math.floor(mp * (g.MpPct or 0)) + (g.MpFlat or 0)
	writeAlias(stats, "Hp", "HP", addClampFloor(hp, hpDelta))
	writeAlias(stats, "Mp", "MP", addClampFloor(mp, mpDelta))

	-- Demais atributos (percentual)
	local function addPct(key, pct)
		local cur = readNum(stats, key); if not cur then return end
		local delta = math.floor(cur * (pct or 0))
		stats[key] = addClampFloor(cur, delta)
	end
	addPct("Strength", g.StrPct); addPct("Defense", g.DefPct)
	addPct("Skill", g.SklPct);    addPct("Speed", g.SpdPct)
	addPct("Intelligence", g.IntPct); addPct("Luck", g.LckPct)
end

-- Procura o modelo do monstro do jogador por atributo "OwnerId" (fallback robusto).
function EvolutionManager.FindPlayerMonster(player: Player)
	local uid = player.UserId
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("Model") and inst:GetAttribute("OwnerId") == uid then
			return inst
		end
	end
	-- Se você tiver um cache próprio (ex.: _G.PlayerMonsters[uid]), pode usar aqui.
	return nil
end

local function analyzeGates(ctx, gates)
        if not gates then return true, {} end

        local ok = true
        local issues = {}

        local function pushIssue(text)
                table.insert(issues, text)
        end

        if gates.baseRaceFamily and gates.baseRaceFamily ~= ctx.baseRaceFamily then
                ok = false
                pushIssue(string.format("baseRaceFamily=%s (needs %s)", tostring(ctx.baseRaceFamily), tostring(gates.baseRaceFamily)))
        end
        if gates.minBond then
                local bond = ctx.bond or 0
                if bond < gates.minBond then
                        ok = false
                        pushIssue(string.format("bond=%d/%d", bond, gates.minBond))
                end
        end
        if gates.minWins then
                local wins = ctx.wins or 0
                if wins < gates.minWins then
                        ok = false
                        pushIssue(string.format("wins=%d/%d", wins, gates.minWins))
                end
        end
        if gates.maxCareMistakes then
                local careMistakes = ctx.careMistakes or 0
                if careMistakes > gates.maxCareMistakes then
                        ok = false
                        pushIssue(string.format("careMistakes=%d>%d", careMistakes, gates.maxCareMistakes))
                end
        end
        if gates.minStats then
                local stats = ctx.stats or {}
                for stat, minV in pairs(gates.minStats) do
                        local current = stats[stat] or 0
                        if current < minV then
                                ok = false
                                pushIssue(string.format("%s=%d/%d", tostring(stat), current, minV))
                        end
                end
        end

        return ok, issues
end

-- ===== Core API =====

-- Decide a evolução com base em Races:GetEvolutions(race) com sistema de chance
function EvolutionManager.TryEvolve(monsterData, trigger, opts)
        local currentRace = monsterData and monsterData.Race
        if not currentRace then
                return false, "No current race on monsterData"
        end

        local options = Races:GetEvolutions(currentRace)
        if not options or #options == 0 then
                return false, ("No evolutions available for %s"):format(tostring(currentRace))
        end

        local currentStage = Races:GetStage(currentRace)
        if monsterData and monsterData.Stats then
                Races:ClampStatsByStage(monsterData.Stats, currentStage)
        end

        local ctx = {
                race = currentRace,
                stage = currentStage,
                stats = monsterData.Stats or {},
                bond = monsterData.Bond or 0,
                wins = monsterData.Wins or 0,
                sessionTime = monsterData.SessionTime or 0,
                careMistakes = monsterData.CareMistakes or 0,
                personality = monsterData.Personality,
                baseRaceFamily = monsterData.BaseRaceFamily,
                cameFrom = currentRace,
                history = monsterData.History or {},
                trigger = trigger or "manual",
                evoItem = opts and opts.evoItem or nil,
        }

        local weightedOptions = {}
        local debugNotes = {}
        local totalWeight = 0

        for _, evo in ipairs(options) do
                local gatesMet, gateIssues = analyzeGates(ctx, evo.gates)
                local baseChance = EvoDef:GetEvolutionChance(currentRace, ctx, evo)
                local weightMultiplier = 1

                if typeof(evo.weights) == "function" then
                        local ok, value = pcall(evo.weights, ctx)
                        if ok and typeof(value) == "number" then
                                weightMultiplier = math.max(0, value)
                        end
                elseif typeof(evo.weights) == "number" then
                        weightMultiplier = math.max(0, evo.weights)
                end

                local combinedWeight = math.max(0, baseChance * weightMultiplier)
                local fallbackApplied = false

                if combinedWeight <= 0 and not gatesMet then
                        combinedWeight = MINIMUM_GATED_WEIGHT
                        fallbackApplied = true
                end

                if combinedWeight > 0 then
                        totalWeight += combinedWeight
                        table.insert(weightedOptions, {
                                target = evo.target,
                                weight = combinedWeight,
                                baseChance = baseChance,
                                weightMultiplier = weightMultiplier,
                                gates = evo.gates,
                                gatesMet = gatesMet,
                                gateIssues = gateIssues,
                                fallbackApplied = fallbackApplied,
                        })

                        if not gatesMet then
                                local reason = (gateIssues and #gateIssues > 0)
                                        and table.concat(gateIssues, ", ")
                                        or "requirements pending"
                                table.insert(debugNotes, string.format("  ! %s: gates unmet (%s)", tostring(evo.target), reason))
                        end
                        if fallbackApplied then
                                table.insert(debugNotes, string.format(
                                        "  ! %s: minimum weight %.4f applied", tostring(evo.target), combinedWeight
                                ))
                        end
                else
                        table.insert(debugNotes, string.format("  - %s: base %.2f%% x %.3f = 0 (skipped)",
                                tostring(evo.target), (baseChance or 0) * 100, weightMultiplier))
                end
        end

        if totalWeight <= 0 then
                print(string.format("[EvolutionManager] Evolution attempt for %s (%s) had no valid options",
                        tostring(currentRace), tostring(currentStage)))
                for _, line in ipairs(debugNotes) do
                        print("\t" .. line)
                end
                return false, "Evolution requirements not met"
        end

        local roll = math.random() * totalWeight
        local cumulative = 0
        local chosen

        for _, option in ipairs(weightedOptions) do
                cumulative += option.weight
                if roll <= cumulative then
                        chosen = option
                        break
                end
        end

        if not chosen then
                chosen = weightedOptions[#weightedOptions]
        end

        local finalChance = chosen.weight / totalWeight

        print(string.format("[EvolutionManager] Evolution roll for %s (%s)", tostring(currentRace), tostring(currentStage)))
        print(string.format("[EvolutionManager]  total weight: %.4f", totalWeight))
        for _, option in ipairs(weightedOptions) do
                local chancePct = (option.weight / totalWeight) * 100
                local gateStatus = option.gatesMet and "met" or "unmet"
                if option.fallbackApplied then
                        gateStatus = gateStatus .. ", minimum chance"
                end
                print(string.format("[EvolutionManager]   -> %s : %.2f%% (base %.2f%% x %.3f) [gates: %s]",
                        tostring(option.target), chancePct, (option.baseChance or 0) * 100, option.weightMultiplier or 1, gateStatus))
                if not option.gatesMet and option.gateIssues and #option.gateIssues > 0 then
                        print(string.format("[EvolutionManager]      unmet -> %s", table.concat(option.gateIssues, "; ")))
                end
        end
        for _, line in ipairs(debugNotes) do
                print("[EvolutionManager]   " .. line)
        end
        print(string.format("[EvolutionManager]  roll value: %.4f / %.4f", roll, totalWeight))
        print(string.format("[EvolutionManager]  selected: %s (%.2f%%)", tostring(chosen.target), finalChance * 100))

        return true, chosen.target, finalChance, {
                selected = chosen,
                totalWeight = totalWeight,
        }
end

-- Inicia o processo de evolução (chamado via Remote ou server)
-- trigger: optional context string (defaults to "manual")
-- opts: optional table { evoItem = itemId }
function EvolutionManager.StartEvolution(player: Player, playerData, trigger, opts)
        trigger = trigger or "manual"
        opts = opts or {}
        if not player or not player.UserId then
                return false, "Invalid player"
        end

        if not playerData then
                warn("[EvolutionManager] No playerData for", player)
                return false, "No player data"
        end

        local monsterData = playerData.Monster or playerData
        if not monsterData then
                return false, "No monster data"
        end

        local currentLevel = monsterData.Level or monsterData.level or 1
        if monsterData.LastEvolutionAttemptLevel == currentLevel then
                return false, "Evolution already attempted at this level"
        end

        local ok, targetOrReason, chance = EvolutionManager.TryEvolve(monsterData, trigger, opts)
        if not ok then
                return false, targetOrReason
        end

        monsterData.LastEvolutionAttemptLevel = currentLevel

        print(string.format("[EvolutionManager] Evolution triggered for %s via %s (%.1f%% chance)",
                player.Name, trigger, (chance or 0) * 100))

	-- Pega posição atual p/ o FX e reposicionamento
	local currentModel = EvolutionManager.FindPlayerMonster(player)
	local pivotCFrame = currentModel and currentModel:GetPivot()
		or (player.Character and player.Character:GetPivot())
		or CFrame.new()

	-- Dispara FX no cliente
	EvolutionEffect:FireClient(player, pivotCFrame.Position, targetOrReason)

	-- Agenda a aplicação real (continua assíncrono)
	task.delay(EFFECT_DURATION, function()
		EvolutionManager.CompleteEvolution(player, targetOrReason, pivotCFrame)
	end)

	return true, targetOrReason -- <- AGORA SINALIZA “começou” e qual alvo
end

-- ===== Moves Merge Config =====
-- Max moves enforced: When a new move is learned and the monster already has 4 moves,
-- the lowest rarity move (excluding BasicAttack) will be replaced.
-- Priority order: BasicAttack > Rarity (Primordial > Ascended > Specialist > Advanced > Amateur)
local MAX_MOVES = 4

local RARITY_ORDER = { Amateur = 1, Advanced = 2, Specialist = 3, Ascended = 4, Primordial = 5 }
local function rarityScore(mv)
	return RARITY_ORDER[(mv and mv.rarity) or "Amateur"] or 1
end

local MAX_MOVES = 4

local function toMoveObj(entry)
        if not entry then return nil end
        if typeof(entry) == "string" then
                return { id = entry, rarity = "Amateur" }
        elseif typeof(entry) == "table" then
                if entry.id then
                        return { id = entry.id, rarity = entry.rarity or "Amateur" }
                elseif entry.move and entry.move.id then
                        return { id = entry.move.id, rarity = entry.rarity or entry.move.rarity or "Amateur" }
                end
        end
        return nil
end

local function dedupe(list)
        local seen, out = {}, {}
        for _, e in ipairs(list or {}) do
                local obj = toMoveObj(e)
                if obj and obj.id and not seen[obj.id] then
                        table.insert(out, obj)
                        seen[obj.id] = true
                end
        end
        return out
end

local function ensureBasicAttack(list)
        for _, e in ipairs(list) do
                if e.id == "BasicAttack" then
                        return
                end
        end
        table.insert(list, { id = "BasicAttack", rarity = "Amateur" })
end

local function trimToMax(list, maxCount)
        if #list <= maxCount then return list end

        -- Sort priority:
        -- 1. BasicAttack always kept (highest priority)
        -- 2. Highest rarity moves kept
        -- 3. In case of tie, keep newer moves (later in list)
        table.sort(list, function(a, b)
                if a.id == "BasicAttack" and b.id ~= "BasicAttack" then return true end
                if b.id == "BasicAttack" and a.id ~= "BasicAttack" then return false end

                local aScore = rarityScore(a)
                local bScore = rarityScore(b)
                if aScore ~= bScore then
                        return aScore > bScore
                end

                return false
        end)

        local cut = {}
        for i = 1, maxCount do
                cut[i] = list[i]
        end
        return dedupe(cut)
end

-- In EvolutionManager.CompleteEvolution function, update the move handling:

local function toMoveReference(entry)
	if not entry then return nil end
	if typeof(entry) == "string" then
		return {id = entry, rarity = "Amateur"}
	elseif typeof(entry) == "table" then
		if entry.id then
			return {id = entry.id, rarity = entry.rarity or "Amateur"}
		elseif entry.move and entry.move.id then
			return {id = entry.move.id, rarity = entry.rarity or entry.move.rarity or "Amateur"}
		end
	end
	return nil
end

local function mergeMovesKeepingOld(prevMoves, startersAnyFormat, newRace)
	local merged = {}
	local seen = {}

	-- Add previous moves
	for _, entry in ipairs(prevMoves or {}) do
		local ref = toMoveReference(entry)
		if ref and ref.id and not seen[ref.id] then
			table.insert(merged, ref)
			seen[ref.id] = true
		end
	end

	-- Add starter moves
	for _, starter in ipairs(startersAnyFormat or {}) do
		local ref = toMoveReference(starter)
		if ref and ref.id and not seen[ref.id] then
			table.insert(merged, ref)
			seen[ref.id] = true
		end
	end

	-- Ensure BasicAttack is always present
	if not seen.BasicAttack then
		table.insert(merged, {id = "BasicAttack", rarity = "Amateur"})
		seen.BasicAttack = true
	end

	-- Trim to max moves, keeping highest rarity
	if #merged > MAX_MOVES then
		table.sort(merged, function(a, b)
			if a.id == "BasicAttack" then return true end
			if b.id == "BasicAttack" then return false end

			local aScore = rarityScore(a)
			local bScore = rarityScore(b)
			if aScore ~= bScore then
				return aScore > bScore
			end
			return false
		end)

		while #merged > MAX_MOVES do
			table.remove(merged)
		end
	end

	return merged
end

local function chooseInherited(prevMoves)
        local order = {Amateur = 1, Advanced = 2, Specialist = 3, Ascended = 4, Primordial = 5}
        local bestId, bestScore = nil, -1

        for _, entry in ipairs(prevMoves or {}) do
                local moveId = nil
                local rarity = "Amateur"

                if typeof(entry) == "table" then
                        moveId = entry.id or (entry.move and entry.move.id)
                        rarity = entry.rarity or (entry.move and entry.move.rarity) or "Amateur"
                elseif typeof(entry) == "string" then
                        moveId = entry
                end

                if moveId and moveId ~= "BasicAttack" then
                        local score = order[rarity] or 1
                        if score > bestScore then
                                bestId = moveId
                                bestScore = score
                        end
                end
        end

        if bestId then
                return Moves:GetMove(nil, bestId)
        end

        return nil
end

-- Aplica a evolução de fato (atualiza dados, reconstrói, reposiciona, notifica)
function EvolutionManager.CompleteEvolution(player: Player, newRaceName: string, oldPivot: CFrame?)
	if not player then return end

	local playerData = _G.DATA:Get(player.UserId).Monster
	if not playerData then
		warn("[EvolutionManager] No playerData on CompleteEvolution")
		return
	end

        local oldRace = playerData.Race

        -- Atualiza playerData
        playerData.Race = newRaceName
        playerData.Stage = Races:GetStage(newRaceName)
        playerData.BaseRaceFamily = Races:GetBaseRaceFamily(newRaceName) or playerData.BaseRaceFamily
	-- snapshot para cálculo (pairs pode falhar direto no proxy)

        applyEvolutionGainsInPlace(playerData.Stats, playerData.Stage)
        Races:ClampStatsByStage(playerData.Stats, playerData.Stage)



	-- Save previous moves for inheritance
	local previousMoves = {}
	for _, e in ipairs(playerData.Moves or {}) do
		table.insert(previousMoves, e)
	end

	-- Get starter moves for new race
	local startersList = EvoDef:GetMovesForRace(newRaceName, {
		personality  = playerData.Personality,
		previousMoves= previousMoves,
		stats        = playerData.Stats,
	}) or {}

	-- Resolve move unlocks from evolution trigger (this handles inherited moves)
	local gained = MoveUnlocks.ResolveUnlocks(playerData, "evolution", {
		from = oldRace,
		previousMoves = previousMoves
	})

	-- Merge moves: previous moves + starters for new race
	-- The MoveUnlocks.ResolveUnlocks already added unlocked moves to playerData.Moves
	-- So we just need to merge with starters
	playerData.Moves = mergeMovesKeepingOld(playerData.Moves, startersList, newRaceName)

	playerData.History = playerData.History or {}
	table.insert(playerData.History, newRaceName)

	-- Destroi o modelo atual (para evitar duplicatas)
	local currentModel = EvolutionManager.FindPlayerMonster(player)
	if currentModel then
		currentModel:Destroy()
	end



	-- Reconstrói com os dados atualizados
	local okBuild, res = pcall(function()
		-- We use a wrapper in Shared.luau, but the core logic is in MonsterGenerator
		return _G.SHARED.BuildMonster(playerData, player.UserId, { force = true })
	end)

	if not okBuild or not res then
		warn("[EvolutionManager] Build after evolution failed:", tostring(res))
		return
	end

	print("Evolution completed for " .. player.Name .. "'s " .. oldRace .. " -> " .. newRaceName)

	-- Reposiciona no pivot antigo (se existir)
	task.wait(0.2)
	local newModel = EvolutionManager.FindPlayerMonster(player)
	if newModel then
		if oldPivot then newModel:PivotTo(oldPivot) end

		local hum = newModel:FindFirstChildOfClass("Humanoid")
		if hum then
			local hpStat = playerData.Stats.Hp or playerData.Stats.HP or hum.MaxHealth
			-- mantém a proporção de vida (ou cure 100% se preferir)
			local oldMax = hum.MaxHealth > 0 and hum.MaxHealth or 1
			local ratio = math.clamp(hum.Health / oldMax, 0, 1)
			hum.MaxHealth = math.max(1, math.floor(hpStat))
			hum.Health = math.max(1, math.floor(hum.MaxHealth * ratio))  -- ou: hum.Health = hum.MaxHealth
		end

		newModel:SetAttribute("MP", playerData.Stats.Mp or playerData.Stats.MP or 50)

		-- Atualiza moves no modelo (seu helper)
		if _G.SHARED and _G.SHARED.UpdateMonsterMoves then
			_G.SHARED.UpdateMonsterMoves(newModel, playerData.Moves)
		end
	end

	-- Notifica conclusão
	EvolutionComplete:FireClient(player, newRaceName)
end

-- ===== Evolution Check After Triggers =====

-- Check for evolution after a trigger event (combat/training)
-- Automatically attempts evolution if requirements are close to being met
-- ===== Inicialização e binding de Remotes =====

function EvolutionManager.Init()
	-- Evita múltiplos binds (idempotente)
	if EvolutionManager._inited then return end
	EvolutionManager._inited = true

	-- Request vindo do client
	EvolutionRequest.OnServerEvent:Connect(function(player)
		-- The handler in Shared.luau now calls this directly.
		-- No need to bind here again.
	end)

	-- Export to global for easy access from other systems
	_G.EVOLUTION = EvolutionManager
	print("[EvolutionManager] Initialized and registered to _G.EVOLUTION")
end

return EvolutionManager
