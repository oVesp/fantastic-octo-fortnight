--!strict
-- Script: ServerScriptService>MonsterSpawningServer

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create or get remote events folder
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Create new remotes for monster spawning
local RequestMonsterSpawn = Instance.new("RemoteEvent")
RequestMonsterSpawn.Name = "RequestMonsterSpawn"
RequestMonsterSpawn.Parent = Remotes

local MonsterSpawned = Instance.new("RemoteEvent")
MonsterSpawned.Name = "MonsterSpawned"
MonsterSpawned.Parent = Remotes

-- Validate ownership
local function validateOwnership(player, nurse: Model): boolean
	if not nurse or not nurse.Parent then
		return false
	end

	local base = nurse.Parent
	local baseOwnerId = base:GetAttribute("BaseOwnerId")

	-- BaseOwnerId is stored as a string, convert it to number for comparison
	return baseOwnerId and tonumber(baseOwnerId) == player.UserId
end

-- Handle spawn request from client
RequestMonsterSpawn.OnServerEvent:Connect(function(player, nurse: Model)
	local playerData = _G.DATA:Get(player)
	--[[Only way to edit data:
	playerData.Stats.Strength = 999]]
	-- Validate the nurse exists and player owns it
	if not nurse or not nurse:IsDescendantOf(workspace) then
		warn("Invalid nurse model")
		return
	end

	if not CollectionService:HasTag(nurse, "Nurse") then
		warn("Object is not tagged as Nurse")
		return
	end

	if not validateOwnership(player, nurse) then
		warn(player.Name, "does not own this base")
		return
	end

	-- Generate monster using server-side global
	if not _G.MONSTERGENERATOR then
		warn("MONSTERGENERATOR not found in _G")
		return
	end

	-- Check if this is a SpawnOnly nurse (just builds without rolling custom data)
	local isSpawnOnly = nurse:GetAttribute("SpawnOnly")

	local monsterModel, data

	if isSpawnOnly == true then
		-- SpawnOnly mode: BuildMonster will automatically call RollMonster internally
		print(string.format("[SpawnOnly] Building monster for %s without pre-rolling", player.Name))
		monsterModel, data = _G.MONSTERGENERATOR.BuildMonster(playerData.Monster, player.UserId)
	else
	print(string.format("[Normal] Rolling and building monster for %s", player.Name))

	-- 1) Roll into _G.DATA for this owner
	local monsterData = _G.MONSTERGENERATOR.RollMonster(player.UserId, false)
	print('test1')
	--print(monsterData.Monster.Stats.Strength, playerData.Stats.Monster.Strength)
	-- You can also replace moves here; proxy persists automatically. 
	-- e.g. pd.Moves = { { move = Moves:GetMove("RealitySeed","BasicAttack"), rarity="Amateur" } }

	-- 3) Build from the rolled+overridden data object (monsterData)
	monsterModel, data = _G.MONSTERGENERATOR.BuildMonster(playerData.Monster, player.UserId)
	print('test2')
end

	if not monsterModel then
		warn("Failed to build monster")
		return
	end

	-- Calculate spawn position (right side of nurse)
	local nurseCF = nurse:GetPivot()
	local spawnOffset = nurseCF.RightVector * -5 -- 5 studs to the right
	local spawnCF = nurseCF + spawnOffset

	-- Position and parent the monster
	monsterModel:PivotTo(spawnCF)
	monsterModel.Parent = workspace

	-- Notify the client that monster has spawned
	MonsterSpawned:FireClient(player, monsterModel)
	_G.EFFECTS.PlaySound("Impact_VoidRay",{
		Where = monsterModel.HumanoidRootPart,
		RandomPitch = true,
		Volume = 0.8
	})
	
	local mode = isSpawnOnly and "SpawnOnly" or "Normal"
	print(string.format("Monster spawned for %s at %s [Mode: %s]", player.Name, nurse.Name, mode))
end)

