-- ServerScriptService>Main>NPCEventTrigger (REPLACE with this code)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- This new module handles creating interactive NPC encounters in the world.
local EncounterManager = {}
local CombatZone = require(script.Parent.CombatZone)
local UIB = require(ReplicatedStorage.Modules.UIBillboards)


local SPAWN_LOCATIONS = {
	Vector3.new(20, 5, 0),
	Vector3.new(-20, 5, 20),
	Vector3.new(0, 5, -20),
}

-- Store the state of our active encounters
local activeEncounters = {}

--- Gets the active monster for a given player.
local function getPlayerMonster(player)
	if not player then return nil end
	local playerId = player.UserId
	-- Prefer the official registration method
	if _G.MONSTERGENERATOR and _G.MONSTERGENERATOR.GetPlayerMonster then
		local monster = _G.MONSTERGENERATOR.GetPlayerMonster(playerId)
		if monster and monster.Parent then
			return monster
		end
	end
	-- Fallback to searching the workspace
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("OwnerId") == playerId then
			return obj
		end
	end
	return nil
end

-- Register a custom/external encounter (e.g., a walking NPC on a path).
-- opts supports:
--   onWin(player, encounter)   -> called if player wins
--   onLose(player, encounter)  -> called if player loses
--   destroyOnWin (default true), destroyOnLose (default true)
--   autoRespawnDelaySeconds (number|nil) -> if set, Respawn after this delay
function EncounterManager.RegisterEncounter(encounterId, npcModel, prompt, opts)
	opts = opts or {}
	activeEncounters[encounterId] = {
		id = encounterId,
		npc = npcModel,
		npcName = npcModel.Name,
		prompt = prompt,
		spawnPosition = npcModel.PrimaryPart and npcModel.PrimaryPart.Position or Vector3.new(),
		inCombat = false,
		_ext = {
			onWin  = opts.onWin,
			onLose = opts.onLose,
			destroyOnWin  = (opts.destroyOnWin ~= false),
			destroyOnLose = (opts.destroyOnLose ~= false),
			autoRespawnDelaySeconds = opts.autoRespawnDelaySeconds, -- nil = no auto-respawn
		}
	}
end

-- Helper to re-enable prompt after combat (used by path encounters)
function EncounterManager.EnablePrompt(encounterId, enabled)
	local e = activeEncounters[encounterId]
	if e and e.prompt then
		e.prompt.Enabled = enabled and true or false
	end
end

--- Respawns an encounter after it has been defeated.
function EncounterManager.Respawn(encounterId)
	local encounter = activeEncounters[encounterId]
	if not encounter then return end

	print("[EncounterManager] Respawning encounter: " .. encounterId)

	-- Re-create the NPC monster
	local npcModel, _ = _G.MONSTERGENERATOR.BuildMonster()
	if not npcModel then
		warn("[EncounterManager] Failed to build monster for respawn.")
		return
	end
	UIB.AttachHpBar(npcModel)
	npcModel.Name = encounter.npcName
	npcModel:SetAttribute("Name", npcModel.Name)
	npcModel:SetAttribute("Team", 2)
	npcModel:PivotTo(CFrame.new(encounter.spawnPosition))

	-- Re-create the interaction prompt
	local prompt: ProximityPrompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Battle"
	prompt.ObjectText = npcModel.Name
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 20
	prompt.Enabled = true
	prompt.Parent = npcModel.PrimaryPart
	prompt.RequiresLineOfSight = false
	UIB.AttachHpBar(npcModel)

	-- Update the encounter's state
	encounter.npc = npcModel
	encounter.prompt = prompt
	encounter.inCombat = false

	-- Re-connect the trigger
	prompt.Triggered:Connect(function(player)
		EncounterManager.StartEncounter(player, encounterId)
	end)
end

--- Starts the combat encounter when a player interacts with the NPC.
function EncounterManager.StartEncounter(player, encounterId)
	
	
	
	local encounter = activeEncounters[encounterId]
	if not encounter or encounter.inCombat then return end

	local npc = encounter.npc
	local anchorFrom = (npc and npc.PrimaryPart and npc.PrimaryPart.Position)
		or (player.Character and player.Character.PrimaryPart and player.Character.PrimaryPart.Position)
		or Vector3.new()

	local spotPos = CombatZone.FindNearestSpot and CombatZone.FindNearestSpot(anchorFrom) or nil
	local ok, CZ = pcall(function() return require(script.Parent.CombatZone) end)
	if ok and CZ and typeof(anchorFrom) == "Vector3" then
		spotPos = CZ.FindNearestSpot(anchorFrom) -- NEW helper we added
	end
	
	local center = spotPos or anchorFrom
	local opts = { center = center, radius = 30, height = 16 }

	local zoneCenter = spotPos or anchorFrom
	local zoneOpts = { center = zoneCenter, radius = 30, height = 16 } -- fixed range

	local playerMonster = getPlayerMonster(player)
	if not playerMonster then
		-- Optional: Add a remote event to notify the player they need a monster.
		print("[EncounterManager] Player tried to start a battle without a monster.")
		return
	end

	print(("[EncounterManager] Player %s started encounter with %s"):format(player.Name, encounter.npc.Name))

	encounter.inCombat = true
	encounter.prompt.Enabled = false -- Disable prompt during combat

	-- The combat manager will now handle the rest.
	-- We pass a callback function to be executed when the combat ends.
	_G.COMBATMANAGER.StartCombat({playerMonster, encounter.npc}, opts, function(results)
		print("[EncounterManager] Combat finished for encounter: " .. encounterId)

		local ext = encounter._ext or {}
		local playerWon = (results and results.winner == playerMonster)

		-- Default behavior flags
		local destroy = playerWon and (ext.destroyOnWin ~= false) or (not playerWon and (ext.destroyOnLose ~= false))

		-- Callbacks
		if playerWon and type(ext.onWin) == "function" then
			ext.onWin(player, encounter)
		elseif (not playerWon) and type(ext.onLose) == "function" then
			ext.onLose(player, encounter)
		end

		-- Cleanup or re-enable prompt depending on encounter type
		if destroy and encounter.npc and encounter.npc.Parent then
			encounter.npc:Destroy()
		else
			encounter.inCombat = false
			if encounter.prompt then
				encounter.prompt.Enabled = true
			end
		end

		-- Optional auto-respawn (kept for static encounters)
		if ext.autoRespawnDelaySeconds then
			task.delay(ext.autoRespawnDelaySeconds, function()
				EncounterManager.Respawn(encounterId)
			end)
		end
	end)
end


--- Initializes the manager, spawning all NPC encounters.
function EncounterManager.Initialize()
	print("[EncounterManager] Initializing NPC encounters...")

	-- Wait for required modules to be available
	while not (_G.MONSTERGENERATOR and _G.COMBATMANAGER) do
		task.wait(1)
	end

	for i, pos in ipairs(SPAWN_LOCATIONS) do
		local encounterId = "Encounter_" .. i

		local npcModel, _ = _G.MONSTERGENERATOR.BuildMonster()
		if not npcModel then continue end
		
		--local RS = game:GetService("ReplicatedStorage")
		UIB.AttachHpBar(npcModel)

		npcModel.Name = "Wild Creature " .. i
		npcModel:SetAttribute("Name", npcModel.Name)
		npcModel:SetAttribute("Team", 2) -- Set to a non-player team
		npcModel:PivotTo(CFrame.new(pos))

		-- Use ProximityPrompt for player-initiated interaction
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Battle"
		prompt.ObjectText = npcModel.Name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 20
		prompt.Parent = npcModel.PrimaryPart
		prompt.RequiresLineOfSight = false

		local encounter = {
			id = encounterId,
			npc = npcModel,
			npcName = npcModel.Name,
			prompt = prompt,
			spawnPosition = pos,
			inCombat = false,
		}
		activeEncounters[encounterId] = encounter

		-- Connect the trigger to start the battle
		prompt.Triggered:Connect(function(player)
			EncounterManager.StartEncounter(player, encounterId)
		end)
	end
	print(("[EncounterManager] Initialized %d encounters."):format(#SPAWN_LOCATIONS))
end

--task.spawn(EncounterManager.Initialize)

return EncounterManager