-- ServerScriptService/TrainingHandlers.lua
-- Uses BaseManager to get training area within player's Base
-- Maintains fallback to workspace.Training if base isn't ready

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SelectTrainingEvent = Remotes:WaitForChild("SelectTrainingEvent")
local OpenTrainingUIEvent = Remotes:WaitForChild("OpenTrainingUIEvent")
local UpdateTrainingStatsEvent = Remotes:WaitForChild("UpdateTrainingStatsEvent")

-- Dependencies
local TrainingSystem = require(game.ServerScriptService.Main.TrainingSystem.Main)
local BaseManager = require(game.ServerScriptService.Main.BaseManager).Get()

-- ========= monster resolution helpers =========

local function findWorkspaceOwned(uid: number): Instance?
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("Model") and inst:GetAttribute("OwnerId") == uid then
			return inst
		end
	end
	return nil
end

local function getPlayerMonster(player: Player): Instance?
	local uid = player.UserId

	-- 1) "official" sources
	if _G and _G.DATA and typeof(_G.DATA.GetActiveMonsterInstance) == "function" then
		local inst = _G.DATA:GetActiveMonsterInstance(uid)
		if inst then return inst end
	end
	if _G and _G.MONSTERGENERATOR and typeof(_G.MONSTERGENERATOR.GetActiveInstance) == "function" then
		local inst = _G.MONSTERGENERATOR:GetActiveInstance(uid)
		if inst then return inst end
	end

	-- 2) fallback: search Workspace by OwnerId
	return findWorkspaceOwned(uid)
end

-- ========= context helpers =========

local function debugCheckBoulder()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		warn("Assets folder not found in ReplicatedStorage")
		return false
	end

	local boulderCarry = assets:FindFirstChild("BoulderCarry")
	if not boulderCarry then
		warn("BoulderCarry folder not found in ReplicatedStorage/Assets")
		return false
	end

	local boulder = boulderCarry:FindFirstChild("Boulder")
	if not boulder then
		warn("Boulder not found in ReplicatedStorage/Assets/BoulderCarry")
		return false
	end

	print("Boulder asset found:", boulder:GetFullName())
	return true
end

local function ctxFromBase(player: Player, trainingType: string): table?
	-- Expected structure in Base:
	-- Base
	--   └─ <trainingType> (Folder/Model)
	--        ├─ Start (Part)
	--        ├─ Finish (Part)   [optional, depends on training]
	--        ├─ Nodes (Folder)  [optional]
	--        └─ Interactables (Folder/Model) [optional]
	local baseCtx = BaseManager:GetTrainingAreaContext(player, trainingType)
	if not baseCtx then return nil end

	-- Build minimal context from what exists
	local ctx = {
		Start = baseCtx.Start,
		Finish = baseCtx.Finish or baseCtx.End,
		End = baseCtx.End or baseCtx.Finish,
		NodesFolder = baseCtx.NodesFolder or baseCtx.Nodes,
		Nodes = baseCtx.Nodes or baseCtx.NodesFolder,
		Interactables = baseCtx.Interactables,
		Base = baseCtx.Base,
	}

	-- Type-specific adjustments (e.g., specific part names)
	if trainingType == "BoulderCarry" then
		-- FIX: Get Boulder from ReplicatedStorage Assets instead of just Interactables
		local assets = ReplicatedStorage:FindFirstChild("Assets").TrainingAssets
		if assets then
			local boulderCarryAssets = assets:FindFirstChild("BoulderCarry")
			if boulderCarryAssets then
				ctx.Boulder = boulderCarryAssets:FindFirstChild("Boulder")
				if ctx.Boulder then
					print("Found Boulder in ReplicatedStorage/Assets/BoulderCarry for player: " .. player.Name)
				end
			end
		end

		-- Also check Interactables as fallback
		if not ctx.Boulder and ctx.Interactables then
			ctx.Boulder = ctx.Interactables:FindFirstChild("Boulder")
			if ctx.Boulder then
				print("Found Boulder in Interactables (fallback) for player: " .. player.Name)
			end
		end

		if not ctx.Boulder then
			warn("BoulderCarry: Could not find Boulder asset in ReplicatedStorage/Assets/BoulderCarry or Interactables for player: " .. player.Name)
			-- Debug: check what's available
			debugCheckBoulder()
		end

		ctx.FailAtIndex = 2
		ctx.FailAtFraction = 0.5
	elseif trainingType == "RockSmash" then
		-- Allow RockSmash with multiple "rocks" within Interactables
		if ctx.Interactables then
			ctx.Boulder = ctx.Interactables -- training module can iterate children
		end
	elseif trainingType == "Sprint" then
		-- already mapped: Start + Nodes/NodesFolder
	elseif trainingType == "MindBend" or trainingType == "WhackAMole" or trainingType == "LuckyBlocks" then
		-- already mapped via Interactables (+ Nodes when available)
	end

	return ctx
end

local function ctxFromLegacyWorkspace(trainingType: string): table?
	-- Legacy fallback: workspace.Training
	local root = Workspace:FindFirstChild("Training")
	if not root then return nil end

	local function sub(name)
		return root:FindFirstChild(name)
	end

	if trainingType == "BoulderCarry" then
		local folder = sub("BoulderCarry")
		if not folder then return nil end

		local ctx = {
			Start = folder:FindFirstChild("Start"),
			End = folder:FindFirstChild("Finish"),
			NodesFolder = folder:FindFirstChild("Nodes"),
			FailAtIndex = 2,
			FailAtFraction = 0.5,
		}

		-- FIX: Also try to get Boulder from ReplicatedStorage for legacy setup
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		if assets then
			local boulderCarryAssets = assets:FindFirstChild("BoulderCarry")
			if boulderCarryAssets then
				ctx.Boulder = boulderCarryAssets:FindFirstChild("Boulder")
				if ctx.Boulder then
					print("Found Boulder in ReplicatedStorage/Assets/BoulderCarry (legacy)")
				end
			end
		end

		-- Fallback to Interactables in legacy workspace
		if not ctx.Boulder then
			ctx.Boulder = folder:FindFirstChild("Interactables") and folder.Interactables:FindFirstChild("Boulder")
			if ctx.Boulder then
				print("Found Boulder in legacy workspace Interactables")
			end
		end

		if not ctx.Boulder then
			warn("BoulderCarry (legacy): Could not find Boulder asset")
			debugCheckBoulder()
		end

		return ctx
	elseif trainingType == "RockSmash" then
		local folder = sub("RockSmash")
		if not folder then return nil end
		return {
			Start = folder:FindFirstChild("Start"),
			Boulder = folder:FindFirstChild("Interactables"),
		}
	elseif trainingType == "Sprint" then
		local folder = sub("Sprint")
		if not folder then return nil end
		return {
			Start = folder:FindFirstChild("Start"),
			NodesFolder = folder:FindFirstChild("Nodes"),
		}
	elseif trainingType == "MindBend" then
		local folder = sub("MindBend")
		if not folder then return nil end
		return {
			Start = folder:FindFirstChild("Start"),
			Interactables = folder:FindFirstChild("Interactables"),
		}
	elseif trainingType == "WhackAMole" then
		local folder = sub("WhackAMole")
		if not folder then return nil end
		return {
			Start = folder:FindFirstChild("Start"),
			Interactables = folder:FindFirstChild("Interactables"),
		}
	elseif trainingType == "LuckyBlocks" then
		local folder = sub("LuckyBlocks")
		if not folder then return nil end
		return {
			Start = folder:FindFirstChild("Start"),
			Interactables = folder:FindFirstChild("Interactables"),
			Nodes = folder:FindFirstChild("Nodes"),
		}
	end

	return nil
end
-- ========= handlers =========
local debounce = {} -- [player.UserId..":"..trainingType] = tick()

local DEBOUNCE_SEC = 0.75

local function keyFor(p, t)
	return tostring(p.UserId) .. ":" .. tostring(t)
end

SelectTrainingEvent.OnServerEvent:Connect(function(player: Player, trainingType: string)
	if typeof(trainingType) ~= "string" then return end
	local k = keyFor(player, trainingType)
	local now = os.clock()
	if debounce[k] and (now - debounce[k]) < DEBOUNCE_SEC then
		return
	end
	debounce[k] = now	if typeof(trainingType) ~= "string" then return end

	local monster = getPlayerMonster(player)
	if not monster then
		warn("[Training] Nenhum monstro encontrado para", player.Name)
		return
	end

	-- 1) Tenta pela Base do player
	local ctx = ctxFromBase(player, trainingType)

	-- 2) Fallback para o layout antigo no workspace
	if not ctx then
		ctx = ctxFromLegacyWorkspace(trainingType)
	end

	if not ctx or not ctx.Start then
		warn(("[Training] Contexto inválido para '%s' (Base ou workspace.Training ausente)"):format(trainingType))
		return
	end

	TrainingSystem:Start(player, monster, trainingType, ctx)
end)
