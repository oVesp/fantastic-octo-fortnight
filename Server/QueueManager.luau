-- ServerScriptService/Main/QueueManager
-- Unified queue flow powered by shared queue definitions.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueueDefinitions = require(ReplicatedStorage.Modules.QueueDefinitions)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local QueueManager = {}

local function ensureRemote(name)
	local remote = Remotes:FindFirstChild(name)
	if remote then
		return remote
	end
	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = Remotes
	return remote
end

local QueueStatusUpdate = ensureRemote("QueueStatusUpdate")

local runtimeQueues = {}
local playerMembership = {}
local UPDATE_INTERVAL = 0.5
local heartbeatAccumulator = 0

local STATES = _G.STATES
local COMBATMANAGER = _G.COMBATMANAGER

local function shallowCopy(source)
	local result = {}
	for key, value in pairs(source) do
		result[key] = value
	end
	return result
end

local function buildRuntimeQueue(queueId)
	if runtimeQueues[queueId] then
		return runtimeQueues[queueId]
	end

	local definition = QueueDefinitions.Get(queueId)
	if not definition then
		return nil
	end

	local settings = {
		mode = definition.mode or "FFA",
		minPlayers = definition.minPlayers or 2,
		maxPlayers = definition.maxPlayers or math.max(definition.minPlayers or 1, 2),
		countdown = definition.countdown or 5,
		fillWithBotsAfterSeconds = definition.fillWithBotsAfterSeconds,
	}

	runtimeQueues[queueId] = {
		id = queueId,
		definition = definition,
		settings = settings,
		players = {},
		countdownActive = false,
		startTime = 0,
		waitingStartTime = 0,
		lastPlayerCount = nil,
		lastCountdownTick = nil,
	}

	return runtimeQueues[queueId]
end

QueueDefinitions.ForEach(function(queueId)
	buildRuntimeQueue(queueId)
end)

local function isQueueBot(model)
	return model
		and model:IsA("Model")
		and (model:GetAttribute("IsBot") == true or model:GetAttribute("QueueBot") == true)
end

local function iterBattleSpots()
	local folder = workspace:FindFirstChild("BattleSpots")
	if not folder then
		return {}
	end
	return folder:GetChildren()
end

local function isSpotFree(spot)
	if not (spot and spot:IsA("BasePart")) then
		return false
	end
	local occupied = spot:GetAttribute("CZ_Occupied")
	return occupied == nil or occupied == false or occupied == ""
end

local function nearestFreeSpot(anchorPos)
	local best, bestDistance = nil, math.huge
	for _, instance in ipairs(iterBattleSpots()) do
		if instance:IsA("BasePart") and instance.Name:lower() == "spot" and isSpotFree(instance) then
			local distance = (instance.Position - anchorPos).Magnitude
			if distance < bestDistance then
				best = instance
				bestDistance = distance
			end
		end
	end
	return best
end

local function reserveSpot(spot, combatId)
	if spot and spot:IsA("BasePart") then
		spot:SetAttribute("CZ_Occupied", combatId)
	end
end

local function releaseSpot(spot)
	if spot and spot:IsA("BasePart") then
		spot:SetAttribute("CZ_Occupied", nil)
		spot:SetAttribute("CZ_Reserved", nil)
	end
end

local function getPlayerMonster(player)
	if _G.MONSTERGENERATOR and _G.MONSTERGENERATOR.GetPlayerMonster then
		local monster = _G.MONSTERGENERATOR.GetPlayerMonster(player.UserId)
		if monster and monster.Parent then
			return monster
		end
	end

	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("OwnerId") == player.UserId then
			return obj
		end
	end

	return nil
end

local function spawnNPC(name)
	if not _G.MONSTERGENERATOR or not _G.MONSTERGENERATOR.BuildMonster then
		warn("[QueueManager] MONSTERGENERATOR unavailable while spawning bots.")
		return nil
	end

	local success, result = pcall(function()
		return _G.MONSTERGENERATOR.BuildMonster(nil, nil, { force = true })
	end)

	if not success or not result then
		warn("[QueueManager] Failed to build bot monster:", tostring(result))
		return nil
	end

	local instance = result
	if name then
		instance.Name = name
		instance:SetAttribute("Name", name)
	end
	instance:SetAttribute("QueueBot", true)

	if STATES then
		STATES:SetState(instance, "Idle")
	end

	return instance
end

local function broadcastQueueStatus(queue, payload, ignorePlayer)
	for _, queuedPlayer in ipairs(queue.players) do
		if queuedPlayer ~= ignorePlayer and queuedPlayer.Parent then
			QueueStatusUpdate:FireClient(queuedPlayer, payload)
		end
	end
end

local function notifyPlayerCount(queue, ignorePlayer)
	local count = #queue.players
	if queue.lastPlayerCount == count then
		return
	end
	queue.lastPlayerCount = count

	local payload = {
		status = "InQueue",
		queueName = queue.id,
		playerCount = count,
		maxPlayers = queue.settings.maxPlayers,
	}

	broadcastQueueStatus(queue, payload, ignorePlayer)
end

local function locatePlayer(player)
	local queueId = playerMembership[player]
	if queueId then
		local queue = runtimeQueues[queueId]
		if queue then
			for index, queuedPlayer in ipairs(queue.players) do
				if queuedPlayer == player then
					return queue, index
				end
			end
		end
		playerMembership[player] = nil
	end

	for _, queue in pairs(runtimeQueues) do
		for index, queuedPlayer in ipairs(queue.players) do
			if queuedPlayer == player then
				playerMembership[player] = queue.id
				return queue, index
			end
		end
	end

	return nil, nil
end

local function assignTeams(participants, settings)
	local mode = settings.mode or "FFA"

	if mode == "DUEL" then
		local realParticipants = {}
		local botParticipants = {}
		for _, model in ipairs(participants) do
			if isQueueBot(model) then
				table.insert(botParticipants, model)
			else
				table.insert(realParticipants, model)
			end
		end

		local final = {}
		for i = 1, 2 do
			if realParticipants[i] then
				table.insert(final, realParticipants[i])
			elseif botParticipants[1] then
				table.insert(final, table.remove(botParticipants, 1))
			end
		end

		if final[1] then final[1]:SetAttribute("Team", 1) end
		if final[2] then final[2]:SetAttribute("Team", 2) end
		return final
	elseif mode == "2v2" then
		local ordered = {}
		local realParticipants = {}
		local botParticipants = {}
		for _, model in ipairs(participants) do
			if isQueueBot(model) then
				table.insert(botParticipants, model)
			else
				table.insert(realParticipants, model)
			end
		end

		for i = 1, settings.maxPlayers do
			if realParticipants[i] then
				table.insert(ordered, realParticipants[i])
			elseif botParticipants[1] then
				table.insert(ordered, table.remove(botParticipants, 1))
			end
		end

		for index, monster in ipairs(ordered) do
			local team = (index % 2 == 1) and 1 or 2
			monster:SetAttribute("Team", team)
		end

		return ordered
	else
		for index, monster in ipairs(participants) do
			monster:SetAttribute("Team", index)
		end
	end

	return participants
end

local function pickAnchor(players)
	local firstPlayer = players[1]
	if firstPlayer and firstPlayer.Character and firstPlayer.Character.PrimaryPart then
		return firstPlayer.Character.PrimaryPart.Position
	end

	for _, player in ipairs(players) do
		local character = player.Character
		if character and character.PrimaryPart then
			return character.PrimaryPart.Position
		end
	end

	return Vector3.new()
end

local function cleanupBots(bots)
	for _, bot in ipairs(bots) do
		if bot and bot.Parent then
			task.defer(function()
				if bot and bot.Parent then
					bot:Destroy()
				end
			end)
		end
	end
end

local function startMatch(queue, bots)
	bots = bots or {}
	local settings = queue.settings

	local playersSnapshot = {}
	for _, player in ipairs(queue.players) do
		if player and player.Parent then
			table.insert(playersSnapshot, player)
		end
	end

	queue.players = {}
	queue.countdownActive = false
	queue.startTime = 0
	queue.waitingStartTime = 0
	queue.lastPlayerCount = nil
	queue.lastCountdownTick = nil

	for _, player in ipairs(playersSnapshot) do
		playerMembership[player] = nil
	end

	local participants = {}
	local validPlayers = {}
	for _, player in ipairs(playersSnapshot) do
		local monster = getPlayerMonster(player)
		if monster and monster.Parent then
			table.insert(participants, monster)
			table.insert(validPlayers, player)
		else
			QueueStatusUpdate:FireClient(player, { status = "Failed", message = "No active monster found." })
		end
	end

	for _, bot in ipairs(bots) do
		if bot then
			table.insert(participants, bot)
		end
	end

	if #participants < settings.minPlayers then
		cleanupBots(bots)
		for _, player in ipairs(validPlayers) do
			QueueStatusUpdate:FireClient(player, { status = "Cancelled" })
		end
		return
	end

	participants = assignTeams(participants, settings)

	if STATES then
		for _, monster in ipairs(participants) do
			STATES:SetState(monster, "InCombat")
		end
	end

	local spot = nearestFreeSpot(pickAnchor(validPlayers))
	if not spot then
		warn("[QueueManager] No free BattleSpot found. Match aborted.")
		cleanupBots(bots)
		for _, player in ipairs(validPlayers) do
			QueueStatusUpdate:FireClient(player, { status = "Cancelled", message = "Arena unavailable." })
		end
		return
	end

	spot:SetAttribute("CZ_Reserved", true)

	COMBATMANAGER = COMBATMANAGER or _G.COMBATMANAGER
	if not (COMBATMANAGER and COMBATMANAGER.StartCombat) then
		warn("[QueueManager] CombatManager not ready; aborting match start.")
		releaseSpot(spot)
		cleanupBots(bots)
		for _, player in ipairs(validPlayers) do
			QueueStatusUpdate:FireClient(player, { status = "Cancelled", message = "Combat system unavailable." })
		end
		return
	end

	local opts = {
		center = spot.Position,
		radius = 30,
		height = 16,
	}

	local botsForCleanup = {}
	for _, monster in ipairs(participants) do
		if isQueueBot(monster) then
			table.insert(botsForCleanup, monster)
		end
	end

	local combatId = COMBATMANAGER.StartCombat(participants, opts, function(results)
		releaseSpot(spot)
		cleanupBots(botsForCleanup)
		for _, player in ipairs(validPlayers) do
			if player.Parent then
				QueueStatusUpdate:FireClient(player, { status = "Finished", results = results })
			end
		end
	end)

	if not combatId then
		releaseSpot(spot)
		cleanupBots(botsForCleanup)
		for _, player in ipairs(validPlayers) do
			QueueStatusUpdate:FireClient(player, { status = "Cancelled", message = "Failed to start combat." })
		end
		return
	end

	reserveSpot(spot, combatId)
	spot:SetAttribute("CZ_Reserved", nil)

	for _, player in ipairs(validPlayers) do
		if player.Parent then
			QueueStatusUpdate:FireClient(player, { status = "Started", queueName = queue.id })
		end
	end
end

function QueueManager.Join(player, queueId)
	local queue = buildRuntimeQueue(queueId)
	if not queue then
		return false, "Queue not found."
	end

	local currentQueue = QueueManager.GetPlayerQueue(player)
	if currentQueue == queueId then
		return true, "Already in queue."
	elseif currentQueue then
		QueueManager.Leave(player)
	end

	if #queue.players >= queue.settings.maxPlayers then
		return false, "Queue is full."
	end

	if not getPlayerMonster(player) then
		return false, "You need a monster before joining."
	end

	table.insert(queue.players, player)
	playerMembership[player] = queue.id

	if #queue.players == 1 then
		queue.waitingStartTime = os.clock()
	end

	local joinPayload = {
		status = "InQueue",
		queueName = queue.id,
		playerCount = #queue.players,
		maxPlayers = queue.settings.maxPlayers,
	}
	QueueStatusUpdate:FireClient(player, joinPayload)

	notifyPlayerCount(queue, player)

	if #queue.players >= queue.settings.minPlayers and not queue.countdownActive then
		queue.countdownActive = true
		queue.startTime = os.clock()
		queue.lastCountdownTick = nil
	end

	return true, "Joined queue."
end

function QueueManager.Leave(player)
	local queue, index = locatePlayer(player)
	if not queue or not index then
		return false, "Player not queued."
	end

	table.remove(queue.players, index)
	playerMembership[player] = nil

	if #queue.players == 0 then
		queue.waitingStartTime = 0
		queue.countdownActive = false
		queue.startTime = 0
		queue.lastPlayerCount = nil
		queue.lastCountdownTick = nil
	elseif queue.countdownActive and #queue.players < queue.settings.minPlayers then
		queue.countdownActive = false
		queue.startTime = 0
		queue.lastCountdownTick = nil
	end

	QueueStatusUpdate:FireClient(player, { status = "None" })
	notifyPlayerCount(queue)

	return true, "Left queue."
end

function QueueManager.LeaveByUserId(userId)
	for _, queue in pairs(runtimeQueues) do
		for index, player in ipairs(queue.players) do
			if player.UserId == userId then
				QueueManager.Leave(player)
				return true
			end
		end
	end
	return false
end

function QueueManager.GetPlayerQueue(player)
	local queueId = playerMembership[player]
	if queueId then
		return queueId
	end
	for id, queue in pairs(runtimeQueues) do
		for _, queuedPlayer in ipairs(queue.players) do
			if queuedPlayer == player then
				playerMembership[player] = id
				return id
			end
		end
	end
	return nil
end

function QueueManager.HasQueue(queueId)
	return buildRuntimeQueue(queueId) ~= nil
end

function QueueManager.GetQueueSnapshot()
	local snapshot = {}
	for id, queue in pairs(runtimeQueues) do
		snapshot[id] = {
			playerCount = #queue.players,
			settings = shallowCopy(queue.settings),
		}
	end
	return snapshot
end

local function spawnBots(queue)
	local bots = {}
	local needed = queue.settings.maxPlayers - #queue.players
	for index = 1, needed do
		local bot = spawnNPC("QueueBot_" .. tostring(index))
		if bot then
			table.insert(bots, bot)
		end
	end
	return bots
end

function QueueManager.update()
	local now = os.clock()
	for _, queue in pairs(runtimeQueues) do
		if queue.countdownActive then
			local elapsed = now - queue.startTime
			local remaining = math.max(queue.settings.countdown - elapsed, 0)
			local tick = math.ceil(remaining)
			if remaining <= 0 then
				startMatch(queue)
			elseif queue.lastCountdownTick ~= tick then
				queue.lastCountdownTick = tick
				local payload = {
					status = "Countdown",
					queueName = queue.id,
					timeLeft = tick,
					playerCount = #queue.players,
					maxPlayers = queue.settings.maxPlayers,
				}
				broadcastQueueStatus(queue, payload)
			end
		else
			if #queue.players >= queue.settings.minPlayers then
				queue.countdownActive = true
				queue.startTime = now
				queue.lastCountdownTick = nil
			elseif queue.settings.fillWithBotsAfterSeconds and queue.waitingStartTime > 0 and #queue.players > 0 then
				if now - queue.waitingStartTime >= queue.settings.fillWithBotsAfterSeconds then
					local bots = spawnBots(queue)
					if #bots > 0 then
						startMatch(queue, bots)
					else
						startMatch(queue)
					end
				end
			end
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	heartbeatAccumulator += dt
	if heartbeatAccumulator >= UPDATE_INTERVAL then
		heartbeatAccumulator = 0
		QueueManager.update()
	end
end)

return QueueManager
