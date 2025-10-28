-- ModuleScript: ServerScriptService/Main/BaseManager
local BaseManager = {}
BaseManager.__index = BaseManager

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local Teams = game:GetService("Teams")

-- ========= Internal Utils =========

local function asPlayerIdKey(playerOrId): string
	if typeof(playerOrId) == "Instance" and playerOrId:IsA("Player") then
		return tostring(playerOrId.UserId)
	end
	return tostring(playerOrId)
end

local function findNearestSpot(spots: {BasePart}, cf: CFrame): BasePart?
	local best, bestDist
	for _, spot in ipairs(spots) do
		if spot and spot:IsA("BasePart") then
			local d = (spot.Position - cf.Position).Magnitude
			if not best or d < bestDist then
				best, bestDist = spot, d
			end
		end
	end
	return best
end

-- ========= Constructor / Singleton =========

function BaseManager.new()
	local self = setmetatable({}, BaseManager)
	self.playerBases = {}   -- [playerId:string] = { Instance = Model, Spot = BasePart }
	self.availableSpots = {} -- array of BasePart
	self.occupiedSpots = {}  -- [BasePart] = true
	self._removingConnections = {} -- [playerId] = RBXScriptConnection
	self:InitializeSpots()
	self:BootstrapFromWorkspace()
	return self
end

local _singleton
function BaseManager.Get(): BaseManager
	if not _singleton then
		_singleton = BaseManager.new()
	end
	return _singleton
end

-- ========= Spots =========

function BaseManager:InitializeSpots()
	local baseSpotsFolder = Workspace:FindFirstChild("BaseSpots")
	if not baseSpotsFolder then
		warn("[BaseManager] BaseSpots folder not found in workspace")
		return
	end
	self.availableSpots = {}
	self.occupiedSpots = {}

	for _, spot in ipairs(baseSpotsFolder:GetChildren()) do
		if spot:IsA("BasePart") then
			table.insert(self.availableSpots, spot)
		end
	end
	print(("[BaseManager] Found %d base spots"):format(#self.availableSpots))
end

function BaseManager:GetAvailableSpot(): BasePart?
	if #self.availableSpots == 0 then
		warn("[BaseManager] No available base spots")
		return nil
	end
	local spot = table.remove(self.availableSpots, 1)
	self.occupiedSpots[spot] = true
	return spot
end

function BaseManager:MarkSpotOccupied(spot: BasePart)
	-- Remove from availableSpots if present
	for i, s in ipairs(self.availableSpots) do
		if s == spot then
			table.remove(self.availableSpots, i)
			break
		end
	end
	self.occupiedSpots[spot] = true
end

function BaseManager:ReleaseSpot(spot)
	if self.occupiedSpots[spot] then
		self.occupiedSpots[spot] = nil
		table.insert(self.availableSpots, spot)
	end
end

-- ========= Bootstrap existing bases (prevents duplicates) =========

function BaseManager:BootstrapFromWorkspace()
	-- Any base models already in Workspace? Rebuild the table.
	for _, inst in ipairs(Workspace:GetChildren()) do
		if inst:IsA("Model") and inst:GetAttribute("BaseOwnerId") then
			local ownerKey = inst:GetAttribute("BaseOwnerId")
			-- If we already have an entry, prefer the first one and clean duplicates
			if not self.playerBases[ownerKey] then
				-- Try to associate a spot by proximity
				local spot = findNearestSpot(self.availableSpots, inst:GetPivot())
				if spot then
					self:MarkSpotOccupied(spot)
				end
				self.playerBases[ownerKey] = { Instance = inst, Spot = spot }
			else
				-- Duplicate in the world; optional: destroy or ignore
				warn(("[BaseManager] Duplicate base found for %s; destroying extra"):format(ownerKey))
				inst:Destroy()
			end
		end
	end
end

-- ========= Public API =========

function BaseManager:CreateBaseForPlayer(player)
	if not player then
		warn("[BaseManager] Attempted to create base for nil player")
		return nil
	end

	local playerId = asPlayerIdKey(player)
	if self.playerBases[playerId] and self.playerBases[playerId].Instance then
		return self.playerBases[playerId].Instance
	end

	local spot = self:GetAvailableSpot()
	if not spot then
		warn(("[BaseManager] No available spots for player %s"):format(player.Name))
		return nil
	end

	local baseTemplate = ServerStorage:FindFirstChild("Base")
	if not baseTemplate then
		warn("[BaseManager] Base template not found in ServerStorage")
		self:ReleaseSpot(spot)
		return nil
	end

	local base = baseTemplate:Clone()
	base.Name = "Base_" .. playerId
	base:SetAttribute("BaseOwnerId", playerId)
	base.Parent = Workspace
	base:PivotTo(spot.CFrame * CFrame.new(0, 4, 0))

	self.playerBases[playerId] = { Instance = base, Spot = spot }

	-- Clean up when player leaves (one connection per player)
	if not self._removingConnections[playerId] then
		self._removingConnections[playerId] = Players.PlayerRemoving:Connect(function(leavingPlayer)
			if leavingPlayer and tostring(leavingPlayer.UserId) == playerId then
				self:RemoveBase(playerId)
				local c = self._removingConnections[playerId]
				if c then
					self._removingConnections[playerId] = nil
					c:Disconnect()
				end
			end
		end)
	end

	print(("[BaseManager] Base created for player %s at spot %s"):format(player.Name, spot.Name))
	return base
end

function BaseManager:GetBaseSpawnLocation(player): SpawnLocation?
	local base = self:GetOrCreateBase(player)
	if not base then return nil end
	-- direct child named "SpawnLocation"
	local spawn = base:FindFirstChild("SpawnLocation")
	-- fallback: look anywhere inside the base
	if not spawn then
		spawn = base:FindFirstChildWhichIsA("SpawnLocation", true)
	end
	return spawn
end

-- Creates (if needed) a dedicated Team for this player's Base and returns it.
-- Team name: "Base_<UserId>"
function BaseManager:EnsureTeamForBase(player): Team?
	local playerId = asPlayerIdKey(player)
	if not Teams then
		warn("[BaseManager] Teams service not available")
		return nil
	end
	local teamName = "Base_" .. playerId
	local team = Teams:FindFirstChild(teamName)
	if not team then
		team = Instance.new("Team")
		team.Name = teamName
		-- Optional: stable color derived from UserId
		local hue = (tonumber(playerId) % 360) / 360
		team.TeamColor = BrickColor.new(Color3.fromHSV(hue, 0.6, 0.9))
		team.AutoAssignable = false
		team.Parent = Teams
	end
	return team
end

-- Assigns player to their Base team (creates it if missing)
function BaseManager:AssignPlayerToBaseTeam(player)
	local team = self:EnsureTeamForBase(player)
	if team then
		player.Neutral = false
		player.Team = team
	end
end

-- Teleport the player to their Base's SpawnLocation.
-- opts.assignTeam (boolean): also assign a dedicated Team for the base
-- opts.forceRespawn (boolean): if true, will set RespawnLocation and call :LoadCharacter()
function BaseManager:TeleportPlayerToBase(player, opts)
	opts = opts or {}
	local spawn = self:GetBaseSpawnLocation(player)
	if not spawn then
		warn("[BaseManager] No SpawnLocation found for player base; cannot teleport")
		return
	end

	-- Optional team assignment
	if opts.assignTeam then
		self:AssignPlayerToBaseTeam(player)
	end

	-- Make this the player's future respawn point too
	player.RespawnLocation = spawn

	-- If we want to respawn them cleanly at the spawn point:
	if opts.forceRespawn then
		-- This will spawn the character at player.RespawnLocation
		player:LoadCharacter()
		return
	end

	-- Otherwise, move the current character there gracefully
	local char = player.Character or player.CharacterAdded:Wait()
	-- Ensure primary part exists
	if not char.PrimaryPart then
		-- yield briefly for PrimaryPart; Roblox often sets it shortly after spawn
		char:GetPropertyChangedSignal("PrimaryPart"):Wait()
	end

	-- Slight lift above the SpawnLocation to avoid clipping
	local lift = spawn.CFrame.UpVector * 3
	char:PivotTo(spawn.CFrame + lift)
end

function BaseManager:GetPlayerBase(player)
	if not player then return nil end
	local playerId = asPlayerIdKey(player)
	local baseData = self.playerBases[playerId]

	-- Fallback: if table is empty/out of sync, try to find it in the world by attribute
	if (not baseData) or (not baseData.Instance) or (not baseData.Instance.Parent) then
		for _, inst in ipairs(Workspace:GetChildren()) do
			if inst:IsA("Model") and tostring(inst:GetAttribute("BaseOwnerId") or "") == playerId then
				-- If we didn’t record a spot, find the nearest and mark it
				local spot = baseData and baseData.Spot
				if not spot then
					spot = findNearestSpot(self.availableSpots, inst:GetPivot())
					if spot then self:MarkSpotOccupied(spot) end
				end
				self.playerBases[playerId] = { Instance = inst, Spot = spot }
				baseData = self.playerBases[playerId]
				break
			end
		end
	end

	return baseData and baseData.Instance or nil
end

function BaseManager:GetOrCreateBase(player)
	return self:GetPlayerBase(player) or self:CreateBaseForPlayer(player)
end

function BaseManager:RemoveBase(playerId)
	playerId = asPlayerIdKey(playerId)
	local baseData = self.playerBases[playerId]
	if baseData then
		if baseData.Spot then
			self:ReleaseSpot(baseData.Spot)
		end
		if baseData.Instance and baseData.Instance.Parent then
			baseData.Instance:Destroy()
		end
		self.playerBases[playerId] = nil
		print(("[BaseManager] Base removed for player %s"):format(playerId))
	end
end

function BaseManager:GetTrainingArea(player, trainingName)
	local base = self:GetOrCreateBase(player)
	if not base then
		warn("[BaseManager] Could not create/get base for player")
		return nil
	end
	return base:FindFirstChild(trainingName, true)
end

function BaseManager:GetTrainingAreaContext(player, trainingName)
	local trainingArea = self:GetTrainingArea(player, trainingName)
	if not trainingArea then return nil end
	return {
		Base = trainingArea,
		Start = trainingArea:FindFirstChild("Start"),
		Finish = trainingArea:FindFirstChild("Finish"),
		End = trainingArea:FindFirstChild("Finish"),
		Nodes = trainingArea:FindFirstChild("Nodes"),
		NodesFolder = trainingArea:FindFirstChild("Nodes"),
		Interactables = trainingArea:FindFirstChild("Interactables"),
		Misc = trainingArea:FindFirstChild("Misc"),
	}
end

function BaseManager:GetAvailableSpotCount()
	return #self.availableSpots
end

function BaseManager:GetOccupiedSpotCount()
	local n = 0
	for _ in pairs(self.occupiedSpots) do n += 1 end
	return n
end

return BaseManager
