--!nolint
-- ServerScript: ServerScriptService>NurseMonsterSpawnerServer
-- Handles the server-side monster generation and spawning + guidance beam to the player's Nurse if they lack a monster

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Create Remote Events
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SpawnMonsterRemote = Remotes:FindFirstChild("SpawnMonsterFromNurse") or Instance.new("RemoteEvent")
SpawnMonsterRemote.Name = "SpawnMonsterFromNurse"
SpawnMonsterRemote.Parent = Remotes

local SpawnEffectRemote = Remotes:FindFirstChild("MonsterSpawnEffect") or Instance.new("RemoteEvent")
SpawnEffectRemote.Name = "MonsterSpawnEffect"
SpawnEffectRemote.Parent = Remotes

-- Animation Setup
local SPAWN_ANIMATION_ID = "rbxassetid://99935535976756"

-- Active spawn tracking to prevent spam
local activeSpawns: {[Model]: boolean} = {}

-- Guidance beam bookkeeping
local playerBeams: {[Player]: {beam: Beam, a0: Attachment, a1: Attachment}} = {}

-- ========= Utility: Monster presence =========

local function findWorkspaceOwned(uid: number): Instance?
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("Model") and inst:GetAttribute("OwnerId") == uid then
			return inst
		end
	end
	return nil
end

local function playerHasMonster(player: Player): boolean
	local uid = player.UserId
	-- Prefer "official" sources if you have them
	if _G and _G.DATA and typeof(_G.DATA.GetActiveMonsterInstance) == "function" then
		local inst = _G.DATA:GetActiveMonsterInstance(uid)
		if inst and inst.Parent then return true end
	end
	if _G and _G.MONSTERGENERATOR and typeof(_G.MONSTERGENERATOR.GetActiveInstance) == "function" then
		local inst = _G.MONSTERGENERATOR:GetActiveInstance(uid)
		if inst and inst.Parent then return true end
	end
	-- Fallback: scan workspace by OwnerId
	return findWorkspaceOwned(uid) ~= nil
end

-- ========= Utility: Find the player's Nurse (tagged "Nurse" and parented under Base with BaseOwnerId) =========

local function findPlayersNurse(player: Player): Model?
	local uid = player.UserId
	for _, inst in ipairs(CollectionService:GetTagged("Nurse")) do
		if inst and inst:IsA("Model") and inst.Parent then
			local baseOwnerId = inst.Parent:GetAttribute("BaseOwnerId")
			if baseOwnerId == uid then
				return inst
			end
		end
	end
	return nil
end

local function pickModelMainPart(model: Model): BasePart?
	if not model then return nil end
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then return model.PrimaryPart end
	local hrp = model:FindFirstChild("HumanoidRootPart", true)
	if hrp and hrp:IsA("BasePart") then return hrp end
	-- fallback to first BasePart
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then return d end
	end
	return nil
end

-- ========= Guidance Beam =========

local function destroyGuidanceBeam(player: Player)
	local pack = playerBeams[player]
	if not pack then return end
	if pack.beam then pack.beam:Destroy() end
	if pack.a0 and pack.a0.Parent then pack.a0:Destroy() end
	if pack.a1 and pack.a1.Parent then pack.a1:Destroy() end
	playerBeams[player] = nil
end

local function createOrUpdateGuidanceBeam(player: Player)
	-- Remove if player already has a monster
	if playerHasMonster(player) then
		destroyGuidanceBeam(player)
		return
	end

	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart
	if not root then return end

	local nurse = findPlayersNurse(player)
	if not nurse then
		-- No nurse found for this player; nothing to guide to
		destroyGuidanceBeam(player)
		return
	end
	local nursePart = pickModelMainPart(nurse)
	if not nursePart then return end

	-- Reuse if exists
	local existing = playerBeams[player]
	if existing and existing.beam and existing.beam.Parent then
		-- Ensure attachments are still in correct parents
		if existing.a0 and existing.a0.Parent ~= root then
			existing.a0.Parent = root
		end
		if existing.a1 and existing.a1.Parent ~= nursePart then
			existing.a1.Parent = nursePart
		end
		return
	end

	-- Build new beam + attachments
	local a0 = Instance.new("Attachment")
	a0.Name = "NurseGuide_Att_Player"
	a0.Parent = root

	local a1 = Instance.new("Attachment")
	a1.Name = "NurseGuide_Att_Nurse"
	a1.Parent = nursePart

	local beam = Instance.new("Beam")
	beam.Name = "NurseGuide_Beam"
	beam.FaceCamera = true
	beam.LightInfluence = 0
	beam.Segments = 18
	beam.Width0 = 0.25
	beam.Width1 = 0.25
	beam.Transparency = NumberSequence.new(0.15)
	beam.TextureSpeed = 0.5
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Parent = Workspace -- not strictly required; can be parented anywhere

	-- Optional texture arrow feel (comment out if undesired)
	-- beam.Texture = "rbxassetid://446111271" -- a subtle beam texture id, replace if you have a preferred one

	playerBeams[player] = { beam = beam, a0 = a0, a1 = a1 }
end

-- ========= Nurse spawn logic =========

local function getNurseSpawnPosition(nurse: Model)
	local nurseCFrame = nurse:GetPivot()
	local rightOffset = nurseCFrame.RightVector * -5 -- 5 studs to the right
	local forwardOffset = nurseCFrame.LookVector * 2 -- 2 studs forward
	local spawnPosition = nurseCFrame.Position + rightOffset + forwardOffset
	return CFrame.new(spawnPosition, spawnPosition + nurseCFrame.LookVector)
end

local function isOwner(nurse: Model, player: Player)
	local parent = nurse.Parent
	if not parent then return false end
	local baseOwnerId = parent:GetAttribute("BaseOwnerId")
	return baseOwnerId and baseOwnerId == player.UserId
end

local function spawnMonsterForPlayer(player: Player, nurse: Model)
	-- Check if already spawning for this nurse
	if activeSpawns[nurse] then
		return false, "Already spawning"
	end

	-- Verify ownership
	if not isOwner(nurse, player) then
		return false, "Not owner"
	end

	-- Mark as spawning
	activeSpawns[nurse] = true

	local nurseHumanoid = nurse:FindFirstChildOfClass("Humanoid")
	if not nurseHumanoid then
		activeSpawns[nurse] = nil
		return false, "No humanoid"
	end

	local animator = nurseHumanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = nurseHumanoid
	end

	local spawnAnimation = Instance.new("Animation")
	spawnAnimation.AnimationId = SPAWN_ANIMATION_ID
	local animTrack = animator:LoadAnimation(spawnAnimation)

	-- Tell client to start camera/effect
	SpawnEffectRemote:FireClient(player, nurse, "start")

	local createdModel: Model? = nil

	local markerConnection = animTrack:GetMarkerReachedSignal("Spawn"):Connect(function()
		local success, result = pcall(function()
			-- Roll monster data
			local monsterData = _G.MONSTERGENERATOR.RollMonster(nil, player.UserId, false)
			-- Build the monster
			local monsterModel, data = _G.MONSTERGENERATOR.BuildMonster(monsterData, player.UserId)

			if monsterModel then
				local spawnCFrame = getNurseSpawnPosition(nurse)
				monsterModel:PivotTo(spawnCFrame)
				monsterModel.Parent = Workspace
				monsterModel:SetAttribute("OwnerId", player.UserId)

				SpawnEffectRemote:FireClient(player, nurse, "spawned", monsterModel)

				return monsterModel, data
			end
		end)

		if success and typeof(result) == "table" then
			createdModel = result[1]
		end

		if not success or not createdModel then
			warn("Failed to spawn monster for", player.Name, ":", result)
			SpawnEffectRemote:FireClient(player, nurse, "failed")
		end

		-- If we successfully created a monster, remove any guidance beam
		if createdModel then
			destroyGuidanceBeam(player)
		end
	end)

	-- Play animation
	animTrack:Play()

	-- Clean up after animation ends
	animTrack.Stopped:Connect(function()
		if markerConnection.Connected then
			markerConnection:Disconnect()
		end
		activeSpawns[nurse] = nil
		spawnAnimation:Destroy()

		SpawnEffectRemote:FireClient(player, nurse, "complete")
	end)

	return true, "Spawning"
end

-- ========= Connections =========

-- On demand spawn from client
SpawnMonsterRemote.OnServerEvent:Connect(function(player, nurse)
	if not nurse or not CollectionService:HasTag(nurse, "Nurse") then
		return
	end
	spawnMonsterForPlayer(player, nurse)
end)

-- Create a guidance beam if player has no monster
local function refreshGuidanceFor(player: Player)
	if not player or not player.Parent then return end
	if playerHasMonster(player) then
		destroyGuidanceBeam(player)
	else
		createOrUpdateGuidanceBeam(player)
	end
end

-- Player lifecycle
Players.PlayerAdded:Connect(function(player)
	-- Character spawns: (re)anchor the A0 attachment to their HRP
	player.CharacterAdded:Connect(function()
		-- slight delay to ensure HRP exists
		task.defer(function()
			refreshGuidanceFor(player)
		end)
	end)

	-- Initial check (if character already exists or spawns later)
	task.delay(2, function()
		refreshGuidanceFor(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	destroyGuidanceBeam(player)
end)

-- Optional: periodic re-check if you want it to recover from edge cases
-- (e.g. monster destroyed externally or nurse moved). Keep it lightweight.
RunService.Stepped:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		-- Keep the beam only when needed; otherwise destroy
		if playerHasMonster(player) then
			if playerBeams[player] then
				destroyGuidanceBeam(player)
			end
		else
			-- If they don't have a beam yet (or character changed), recreate
			if not playerBeams[player] then
				createOrUpdateGuidanceBeam(player)
			else
				-- make sure attachments are still parented correctly
				createOrUpdateGuidanceBeam(player)
			end
		end
	end
end)
