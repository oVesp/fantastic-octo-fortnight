-- ModuleScript: ServerScriptService > NurseMonsterSpawner
-- Handles monster spawning when players interact with Nurse NPCs

local NurseMonsterSpawner = {}
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Remote Events for client-server communication
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NurseSpawnRequest = Instance.new("RemoteEvent")
NurseSpawnRequest.Name = "NurseSpawnRequest"
NurseSpawnRequest.Parent = Remotes

local NurseSpawnComplete = Instance.new("RemoteEvent")
NurseSpawnComplete.Name = "NurseSpawnComplete"
NurseSpawnComplete.Parent = Remotes

-- Animation details
local SPAWN_ANIMATION_ID = "99935535976756"
local SPAWN_MARKER_NAME = "Spawn"

-- Track player animation states to prevent spam
local playerAnimationStates = {}

-- Function to validate Nurse ownership and setup
function NurseMonsterSpawner.SetupNurse(nurse)
	local prompt = nurse:FindFirstChildWhichIsA("ProximityPrompt")
	local parent = nurse.Parent

	if not prompt or not parent then
		return false
	end

	-- Check if this nurse has the BaseOwnerId attribute on its parent
	if not parent:GetAttribute("BaseOwnerId") then
		return false
	end

	print("Nurse setup completed:", nurse.Name)
	return true
end

-- Function to get spawn position (right side of nurse)
function NurseMonsterSpawner.GetSpawnPosition(nurse)
	local nurseCFrame = nurse:GetPivot()
	local rightOffset = nurseCFrame.RightVector * 4 -- 4 studs to the right
	local upOffset = Vector3.new(0, 2, 0) -- Slightly above ground

	return nurseCFrame.Position + rightOffset + upOffset
end

-- Function to spawn monster for player
function NurseMonsterSpawner.SpawnMonsterForPlayer(player, nurse)
	-- Check if player is already in an animation
	if playerAnimationStates[player.UserId] then
		return false, "Player is already spawning a monster"
	end

	-- Validate nurse ownership
	local baseOwnerId = nurse.Parent:GetAttribute("BaseOwnerId")
	print(player.UserId, baseOwnerId)
	if baseOwnerId ~= player.UserId then
		return false, "Player does not own this Nurse"
	end

	-- Check if MONSTERGENERATOR exists
	if not _G.MONSTERGENERATOR then
		return false, "MONSTERGENERATOR not found"
	end

	-- Set player state
	playerAnimationStates[player.UserId] = true

	-- Tell client to play animation
	NurseSpawnRequest:FireClient(player, nurse)

	return true, "Animation started"
end

-- Function to handle the actual monster spawning (called when client reports marker reached)
function NurseMonsterSpawner.HandleMonsterSpawn(player, nurse)
	if not playerAnimationStates[player.UserId] then
		return false, "No active spawn session for player"
	end

	-- Generate and build monster
	local success, monsterDataOrError = pcall(function()
		return _G.MONSTERGENERATOR.RollMonster(_G.DATA:Get(player), player.UserId, false)
	end)

	if not success then
		playerAnimationStates[player.UserId] = nil
		return false, "Failed to roll monster: " .. tostring(monsterDataOrError)
	end

	local success2, monsterModelOrError = pcall(function()
		return _G.MONSTERGENERATOR.BuildMonster(monsterDataOrError, player.UserId)
	end)

	if not success2 then
		playerAnimationStates[player.UserId] = nil
		return false, "Failed to build monster: " .. tostring(monsterModelOrError)
	end

	-- Position monster
	if monsterModelOrError and monsterModelOrError.PrimaryPart then
		local spawnPosition = NurseMonsterSpawner.GetSpawnPosition(nurse)
		monsterModelOrError:SetPrimaryPartCFrame(CFrame.new(spawnPosition))

		print("Monster spawned for player", player.Name, ":", monsterModelOrError.Name)
	end

	-- Clear player state
	playerAnimationStates[player.UserId] = nil

	-- Notify client that spawning is complete
	NurseSpawnComplete:FireClient(player)

	return true, "Monster spawned successfully"
end

-- Initialize the system
function NurseMonsterSpawner.Initialize()
	print("Initializing NurseMonsterSpawner...")

	-- Setup existing Nurses
	for _, nurse in ipairs(CollectionService:GetTagged("Nurse")) do
		NurseMonsterSpawner.SetupNurse(nurse)
	end

	-- Setup new Nurses as they're added
	CollectionService:GetInstanceAddedSignal("Nurse"):Connect(function(nurse)
		NurseMonsterSpawner.SetupNurse(nurse)
	end)

	-- Handle client spawn requests
	NurseSpawnRequest.OnServerEvent:Connect(function(player, nurse)
		local success, message = NurseMonsterSpawner.SpawnMonsterForPlayer(player, nurse)
		if not success then
			warn("Nurse spawn failed for", player.Name, ":", message)
		end
	end)

	-- Handle monster creation when animation marker is reached
	local MonsterSpawnMarker = Instance.new("RemoteEvent")
	MonsterSpawnMarker.Name = "MonsterSpawnMarker"
	MonsterSpawnMarker.Parent = Remotes

	MonsterSpawnMarker.OnServerEvent:Connect(function(player, nurse)
		NurseMonsterSpawner.HandleMonsterSpawn(player, nurse)
	end)

	-- Clean up player states when they leave
	Players.PlayerRemoving:Connect(function(player)
		playerAnimationStates[player.UserId] = nil
	end)

	print("NurseMonsterSpawner initialized successfully")
end



return NurseMonsterSpawner