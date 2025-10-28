-- Script: ServerScriptService>Main
print("[Main] Iniciando o servidor em modo de segurança...")

local function safeRequire(moduleScript)
	local success, module = pcall(require, moduleScript)
	if not success then
		warn(("[Main] ERRO CRÍTICO: O módulo '%s' falhou ao carregar. O erro é: %s"):format(moduleScript.Name, tostring(module)))
		return nil
	end
	print(("[Main] Módulo '%s' carregado com sucesso."):format(moduleScript.Name))
	return module
end

-- Load all modules with better error handling
local function initializeModules()
	_G.DATA = safeRequire(script.Data)
	_G.STATES = safeRequire(script.States)
	_G.MOVEMENT = safeRequire(game.ReplicatedStorage.Modules.Movement)
	_G.FUNCTIONS = safeRequire(script.Functions)
	_G.COMBATMANAGER = require(script.CombatManager)
	_G.UTILS = safeRequire(script.Utils)
	_G.EFFECTS = safeRequire(game.ReplicatedStorage.Modules["Effects&SFX"])
	_G.MONSTERGENERATOR = safeRequire(script.MonsterGenerator)
	_G.COMBAT_ARENA = safeRequire(script.CombatZone)
	_G.TRAINING_SYSTEM = safeRequire(script.TrainingSystem.Main)
	_G.EVOLUTION = safeRequire(script.EvolutionManager)
	_G.SHARED = safeRequire(script.Shared)
	_G.PATHENCOUNTER = safeRequire(script.PathEncounterRunner)
	_G.COMBAT_ZONE = safeRequire(script.CombatZone)
	_G.MOVE_LEARNING = safeRequire(script.MoveLearning)

	--_G.MONSTER_SPAWNER = safeRequire(script.MonsterSpawner)

	-- Load BaseManager with extra safety
	local baseManagerSuccess, baseManager = pcall(function()
		return safeRequire(script.BaseManager)
	end)

	if baseManagerSuccess and baseManager then
		_G.BASE_MANAGER = baseManager.new()
		print("[Main] BaseManager initialized successfully")
	else
		warn("[Main] Failed to initialize BaseManager")
		_G.BASE_MANAGER = nil
	end

	if _G.PATHENCOUNTER then
		_G.PATHENCOUNTER.Initialize()
		print("[Main] Path encounter system initialized")
	end
end

initializeModules()

local Players = game:GetService("Players")

local QueueManager = safeRequire(script.QueueManager)
local QueueService = QueueManager and safeRequire(script.QueueService)
if not QueueManager or not _G.COMBATMANAGER then
	warn("[Main] ERRO GRAVE: QueueManager ou CombatManager não puderam ser carregados. O sistema de filas será desativado.")
	return
end

if QueueService and QueueService.Init then
	QueueService.Init()
	print("[Main] QueueService initialized.")
else
	warn("[Main] QueueService not available; queue remotes were not bound.")
end

-- Create bases for players when they join with better timing
Players.PlayerAdded:Connect(function(player)
	print(("[Main] Player %s joined"):format(player.Name))

	-- Wait a moment for player to fully load
	task.wait(1)

	-- Create base for player
	if _G.BASE_MANAGER then
		local success, base = pcall(function()
			return _G.BASE_MANAGER:CreateBaseForPlayer(player)
		end)
		_G.BASE_MANAGER:TeleportPlayerToBase(player, { assignTeam = false })
		--_G.MONSTER_SPAWNER.Initialize()
		if success and base then
			print(("[Main] Base criada para o jogador %s"):format(player.Name))
		else
			warn(("[Main] Falha ao criar base para o jogador %s"):format(player.Name))
		end
	else
		warn("[Main] BaseManager not available for player " .. player.Name)
	end

	-- Existing attribute change handler
	player.AttributeChanged:Connect(function(attr)
		if player:GetAttribute("DataLoaded") then
			local gameModule = safeRequire(script.Game)
			local encounterManager = safeRequire(script.EncounterManager)
			if encounterManager then
				task.wait(1)
				if encounterManager.Initialize then
					encounterManager.Initialize()
				end
			end
		end
	end)
end)

-- Handle player leaving
Players.PlayerRemoving:Connect(function(player)
	print(("[Main] Player %s leaving, cleaning up base"):format(player.Name))
	if _G.BASE_MANAGER then
		_G.BASE_MANAGER:RemoveBase(player.UserId)
	end
end)

print("[Main] Server initialization complete")