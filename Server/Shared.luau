-- ServerScriptService/Main/Shared.luau
-- Reformulated to ensure required Remotes are present and handlers wired.
-- Defensive: uses pcall when calling optional global modules.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- Ensure Remotes folder exists
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
	warn("[Shared] Created missing ReplicatedStorage.Remotes folder (debug auto-create).")
end

-- Wait for remotes used by this module
local MonsterSummon        = remotesFolder:WaitForChild("MonsterSummon")
local GenerateMonster      = remotesFolder:WaitForChild("GenerateMonster")
local EvolutionRequest     = remotesFolder:WaitForChild("EvolutionRequest")
local EvolutionEffect      = remotesFolder:FindFirstChild("EvolutionEffect")      -- optional
local EvolutionComplete    = remotesFolder:FindFirstChild("EvolutionComplete")    -- optional
local spinResult           = remotesFolder:FindFirstChild("TrainingSpinResult")   -- optional
local TestEvolutionTemplate= remotesFolder:FindFirstChild("TestEvolutionTemplate")-- optional
local UIRemote = remotesFolder:FindFirstChild("UIRemote") 

-- Required game modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Races = nil
if Modules:FindFirstChild("Races") then
	Races = require(Modules:WaitForChild("Races"))
else
	warn("[Shared] Races module not found in ReplicatedStorage.Modules")
end

local BASE_GAIN = {
	Strength = 2, Defense = 2, Speed = 3, Wisdom = 2
}

local module = {}

-- Local caches
local playerMonster = {}   -- map: tostring(UserId) -> { Instance = model, Data = data }
local serverMonsters = {}  -- map: mobId (GUID) -> { Instance = model, Data = data }
local spawnLocks = {}      -- map: playerId -> boolean (prevent double-spawn)

-- Helper: get player's monster instance (multiple lookup strategies)
function module.GetPlayerMonster(player)
	if not player then return nil end

	local playerId
	if typeof(player) == "number" then
		playerId = tostring(player)
	elseif typeof(player) == "Instance" and player:IsA("Player") then
		playerId = tostring(player.UserId)
	else
		-- try UserId if a table or other passed
		if type(player) == "table" and player.UserId then
			playerId = tostring(player.UserId)
		else
			return nil
		end
	end

	-- 1) Use _G.MONSTERGENERATOR.PlayerMonsters if available
	if _G and _G.MONSTERGENERATOR and type(_G.MONSTERGENERATOR.PlayerMonsters) == "table" then
		local entry = _G.MONSTERGENERATOR.PlayerMonsters[playerId]
		if entry and entry.Model and entry.Model.Parent then
			return entry.Model
		end
	end

	-- 2) Use local cache
	if playerMonster[playerId] and playerMonster[playerId].Instance and playerMonster[playerId].Instance.Parent then
		return playerMonster[playerId].Instance
	end

	-- 3) Search workspace by OwnerId attribute
	for _, obj in pairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("OwnerId") then
			local ownerAttr = obj:GetAttribute("OwnerId")
			if ownerAttr and tonumber(ownerAttr) == tonumber(playerId) then
				return obj
			end
		end
	end

	-- 4) If a Player instance was passed, try to find a nearby following monster
	if typeof(player) == "Instance" and player:IsA("Player") then
		local character = player.Character
		if character and character.PrimaryPart then
			local closest, dist = nil, math.huge
			for _, obj in pairs(workspace:GetChildren()) do
				if obj:IsA("Model") and obj.PrimaryPart and obj ~= character then
					local humanoid = obj:FindFirstChildOfClass("Humanoid")
					if humanoid then
						local d = (obj.PrimaryPart.Position - character.PrimaryPart.Position).Magnitude
						if d < 50 and d < dist then
							dist = d
							closest = obj
						end
					end
				end
			end
			return closest
		end
	end

	return nil
end

UIRemote.OnServerEvent:Connect(function(plr, ui)
	local ui = plr:WaitForChild("PlayerGui"):WaitForChild("MonsterSheetUI"):WaitForChild("MonsterSheet")
	ui.Enabled = not ui.Enabled
end)
-- BuildMonster: wraps _G.MONSTERGENERATOR.BuildMonster safely and tracks monster for player or server
-- data: data table for monster generator
-- playerId: numeric UserId or nil for server monster
-- opts: { force = boolean }
function module.BuildMonster(data, playerId, opts)
	opts = opts or {}

	if playerId then
		playerId = tostring(playerId)
		if spawnLocks[playerId] then
			return false, "spawn in progress"
		end
		spawnLocks[playerId] = true

		-- If player already has a monster and not forcing, abort
		local existing = playerMonster[playerId] and playerMonster[playerId].Instance
		if existing and existing.Parent and not opts.force then
			spawnLocks[playerId] = nil
			return false, "player already has a monster"
		elseif existing and existing.Parent and opts.force then
			-- destroy existing before creating new
			pcall(function() existing:Destroy() end)
			playerMonster[playerId] = nil
		end
	end

	if not (_G and _G.MONSTERGENERATOR and type(_G.MONSTERGENERATOR.BuildMonster) == "function") then
		if playerId then spawnLocks[playerId] = nil end
		return false, "MONSTERGENERATOR.BuildMonster not available"
	end

	-- Call generator safely
	local ok, ret1, ret2 = pcall(function()
		return _G.MONSTERGENERATOR.BuildMonster(data, tonumber(playerId))
	end)

	if playerId then spawnLocks[playerId] = nil end

	if not ok then
		return false, ("BuildMonster error: %s"):format(tostring(ret1))
	end

	local monsterInstance, monsterData
	if typeof(ret1) == "Instance" then
		monsterInstance = ret1
		monsterData = ret2
	elseif type(ret1) == "table" and ret1.Instance then
		monsterInstance = ret1.Instance
		monsterData = ret1.Data
	else
		-- If BuildMonster returned non-standard output, return it as a result but warn
		return true, { Instance = nil, Data = ret1 }
	end

	if monsterInstance then
		if playerId then
			playerMonster[playerId] = { Instance = monsterInstance, Data = monsterData }
			print("[Shared] Registered monster for player " .. tostring(playerId) .. " -> " .. tostring(monsterInstance.Name))

			-- Cleanup when destroyed
			monsterInstance.Destroying:Connect(function()
				if playerMonster[playerId] and playerMonster[playerId].Instance == monsterInstance then
					playerMonster[playerId] = nil
					print("[Shared] Removed destroyed monster from cache for player " .. tostring(playerId))
				end
			end)

			return true, { Instance = monsterInstance, Data = monsterData }
		else
			local mobId = HttpService:GenerateGUID(false)
			serverMonsters[mobId] = { Instance = monsterInstance, Data = monsterData }
			monsterInstance.Destroying:Connect(function()
				serverMonsters[mobId] = nil
			end)
			return true, { Instance = monsterInstance, Data = monsterData, MobId = mobId }
		end
	end

	return false, "BuildMonster did not return a valid instance"
end

-- MonsterSummon: spawn player's monster (not forceful)
MonsterSummon.OnServerEvent:Connect(function(player)
	if not player then return end
	local playerData = _G.DATA:Get(player.UserId)
	if not playerData then
		warn(("[Shared] MonsterSummon: no player data for %s"):format(player.Name))
		return
	end

	local ok, res = module.BuildMonster(playerData.Monster, player.UserId, { force = false })
	if not ok then
		warn(("[Shared] MonsterSummon failed for %s: %s"):format(player.Name, tostring(res)))
	else
		print(("[Shared] MonsterSummon spawned for %s"):format(player.Name))
	end
end)

-- GenerateMonster: force a new monster for the player (used by debug UI)
GenerateMonster.OnServerEvent:Connect(function(player)
	if not player then return end
	local playerData = (_G and _G.DATA and type(_G.DATA.Get) == "function") and _G.DATA:Get(player.UserId)
	if not playerData then
		warn(("[Shared] GenerateMonster: no player data for %s"):format(player.Name))
		return
	end

	local monsterData = _G.MONSTERGENERATOR.RollMonster(player.UserId, false)


	local success, result = module.BuildMonster(monsterData, player.UserId, { force = true })
	if not success then
		warn(("[Shared] GenerateMonster failed to build/spawn for %s: %s"):format(player.Name, tostring(result)))
	else
		print(("[Shared] Generated and spawned new monster for %s"):format(player.Name))
	end
end)

-- TrainingSpinResult handler (optional)
if spinResult then
	spinResult.OnServerEvent:Connect(function(player, result)
		-- result = { name = "Good", multiplier = 1.5 }
		if not player or type(result) ~= "table" then return end
		local targetStat = "Strength"
		local gain = math.floor((BASE_GAIN[targetStat] or 2) * (result.multiplier or 1))
		-- TODO: apply to player's monster data via _G.DATA or MONSTERGENERATOR data store
		print(("[Shared] Player %s: %s +%d"):format(player.Name, targetStat, gain))
	end)
end

-- EvolutionRequest: start evolution process for player's current monster (server-side)
EvolutionRequest.OnServerEvent:Connect(function(player)
	if not player then return end
	if not (_G and _G.DATA and type(_G.DATA.Get) == "function") then
		warn("[Shared] EvolutionRequest: _G.DATA not available")
		return
	end

	local playerData = _G.DATA:Get(player.UserId)
	if not playerData then
		warn(("[Shared] EvolutionRequest: no player data for %s"):format(player.Name))
		return
	end

	if not (_G and _G.EVOLUTION and type(_G.EVOLUTION.StartEvolution) == "function") then
		warn("[Shared] EvolutionRequest: EVOLUTION module not available")
		return
	end

	local ok, res = pcall(function()
		return _G.EVOLUTION.StartEvolution(player, playerData)
	end)

	if ok and res then
		print(("Evolution started for %s (%s)"):format(player.Name, tostring(playerData.Race or "unknown")))
		-- Optionally notify client via EvolutionEffect/EvolutionComplete remotes
		if EvolutionEffect then
			EvolutionEffect:FireClient(player, { event = "start" })
		end
	else
		warn(("Evolution failed for %s: %s"):format(player.Name, tostring(res)))
		if EvolutionComplete then
			EvolutionComplete:FireClient(player, { success = false, reason = tostring(res) })
		end
	end
end)


-- Optional EvolutionEffect/EvolutionComplete server-side usage could be extended elsewhere
-- Example: _G.EVOLUTION can call EvolutionComplete:FireClient(player, result) when finished.

-- Module export
return module