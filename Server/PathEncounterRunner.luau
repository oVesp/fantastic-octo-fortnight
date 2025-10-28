local PathEncounterRunner = {}
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")

-- Configuration
local CONFIG = {
	SPAWN_INTERVAL = 5,
	WALK_SPEED = 12,
	BATTLE_TIMEOUT = 999,
	RESPAWN_DELAY = 8,
	PROMPT_HOLD_DURATION = 0,
	PROMPT_RANGE = 18,
	MAX_ACTIVE_MONSTERS = 10,
	PATH_UPDATE_INTERVAL = 1,
	STUCK_THRESHOLD = 8,
	ARRIVAL_DISTANCE = 5,
	WAYPOINT_REACH_DISTANCE = 4,
	-- New configuration for monster variety
	ENABLE_ANY_MONSTER = true, -- Flag to enable any kind of monster
	LEVEL_RANGE = {1, 50}, -- Level range for spawned monsters
}

local activeMonsters = {}
local playersInCombat = {}
local pathFolder = workspace:FindFirstChild("Path")

function PathEncounterRunner.Initialize()
	if not pathFolder then
		warn("[PathEncounterRunner] Path folder not found in workspace!")
		return
	end

	local startPart = pathFolder:FindFirstChild("start1")
	local endPart = pathFolder:FindFirstChild("end1")

	if not startPart or not endPart then
		warn("[PathEncounterRunner] Start or end parts not found!")
		return
	end

	print("[PathEncounterRunner] Initializing path encounter system...")
	PathEncounterRunner.Cleanup()

	task.spawn(function()
		while true do
			local activeCount = 0
			for _, monster in ipairs(activeMonsters) do
				if monster.model and monster.model.Parent then
					activeCount += 1
				end
			end

			if activeCount < CONFIG.MAX_ACTIVE_MONSTERS then
				PathEncounterRunner.SpawnMonster(startPart, endPart)
			end

			task.wait(CONFIG.SPAWN_INTERVAL)
		end
	end)

	task.spawn(function()
		while true do
			PathEncounterRunner.UpdateMonsterMovement()
			task.wait()
		end
	end)
end

function PathEncounterRunner.SpawnMonster(startPart, endPart)
	if not _G.MONSTERGENERATOR then
		warn("[PathEncounterRunner] MONSTERGENERATOR not available")
		return nil
	end

	local options = {
		level = math.random(CONFIG.LEVEL_RANGE[1], CONFIG.LEVEL_RANGE[2])
	}

	-- If any monster flag is enabled, don't force a specific race
	if not CONFIG.ENABLE_ANY_MONSTER then
		-- Original behavior - use summonable races only
		options.stage = "Fledgeling"
	end
	-- If ENABLE_ANY_MONSTER is true, no race restriction is applied

	local monsterModel, monsterData = _G.MONSTERGENERATOR.BuildMonster(nil, nil, options)

	if not monsterModel then
		warn("[PathEncounterRunner] Failed to build monster")
		return nil
	end

	monsterModel.Name = "PathMonster_" .. math.random(10000, 99999)
	monsterModel:SetAttribute("IsPathMonster", true)
	monsterModel:SetAttribute("Team", 2)
	monsterModel:SetAttribute("PathStartTime", tick())
	monsterModel:PivotTo(startPart.CFrame + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
	monsterModel.Parent = workspace

	local humanoid = monsterModel:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = CONFIG.WALK_SPEED
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BattlePrompt"
	prompt.ActionText = "Battle"
	prompt.ObjectText = monsterModel.Name .. " (Lvl " .. (monsterData.Level or 1) .. ")"
	prompt.HoldDuration = CONFIG.PROMPT_HOLD_DURATION
	prompt.MaxActivationDistance = CONFIG.PROMPT_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Parent = monsterModel.PrimaryPart or monsterModel:FindFirstChild("HumanoidRootPart")

	local monsterInfo = {
		model = monsterModel,
		prompt = prompt,
		startPosition = startPart.Position,
		endPosition = endPart.Position,
		currentWaypoint = 1,
		path = nil,
		inCombat = false,
		lastPosition = startPart.Position,
		lastPositionTime = tick(),
		spawnTime = tick(),
		humanoid = humanoid,
		encounterId = "PathEncounter_" .. math.random(10000, 99999),
		level = monsterData.Level or 1,
		race = monsterData.Race
	}

	PathEncounterRunner.GeneratePath(monsterInfo)
	table.insert(activeMonsters, monsterInfo)

	task.delay(CONFIG.BATTLE_TIMEOUT, function()
		if monsterInfo.model and monsterInfo.model.Parent and not monsterInfo.inCombat then
			print("[PathEncounterRunner] Monster timed out, destroying: " .. monsterInfo.model.Name)
			PathEncounterRunner.DestroyMonster(monsterInfo)
		end
	end)

	prompt.Triggered:Connect(function(player)
		PathEncounterRunner.HandlePromptTriggered(player, monsterInfo)
	end)

	--print(string.format("[PathEncounterRunner] Spawned %s (Level %d, %s)", 
		--monsterInfo.model.Name, monsterInfo.level, monsterInfo.race))

	return monsterInfo
end

function PathEncounterRunner.GeneratePath(monsterInfo)
	if not monsterInfo.model or not monsterInfo.model.PrimaryPart then
		return
	end

	local startPos = monsterInfo.model.PrimaryPart.Position
	local endPos = monsterInfo.endPosition

	-- Use height-agnostic pathfinding for flying monsters
	-- Set agent height very high to accommodate flying monsters
	local path = PathfindingService:CreatePath({
		AgentRadius = 3,
		AgentHeight = 50, -- Very high to allow flying monsters
		AgentCanJump = true, -- Allow jumping for ground monsters, doesn't affect flyers
		WaypointSpacing = 6
	})

	-- Compute path with timeout protection
	local success, result = pcall(function()
		path:ComputeAsync(startPos, endPos)
		return path.Status
	end)

	if success and path.Status == Enum.PathStatus.Success then
		monsterInfo.path = path:GetWaypoints()
		monsterInfo.currentWaypoint = 1
		--print(string.format("[PathEncounterRunner] Generated path with %d waypoints for %s", #monsterInfo.path, monsterInfo.model.Name))

		-- Reset stuck detection
		monsterInfo.lastPosition = startPos
		monsterInfo.lastPositionTime = tick()
	else
		warn("[PathEncounterRunner] Path generation failed for: " .. monsterInfo.model.Name)
		if not success then
			warn("[PathEncounterRunner] Path computation error: " .. tostring(result))
		end

		-- Fallback: direct path with intermediate points (height-agnostic)
		local directPath = {}
		local steps = 3
		for i = 1, steps do
			local lerpFactor = i / steps
			-- Linear interpolation maintaining height variations for flying monsters
			local intermediatePos = Vector3.new(
				startPos.X + (endPos.X - startPos.X) * lerpFactor,
				startPos.Y + (endPos.Y - startPos.Y) * lerpFactor, -- Keep height interpolation
				startPos.Z + (endPos.Z - startPos.Z) * lerpFactor
			)
			table.insert(directPath, {Position = intermediatePos})
		end
		table.insert(directPath, {Position = endPos})

		monsterInfo.path = directPath
		monsterInfo.currentWaypoint = 1
	end
end

function PathEncounterRunner.TryUnstickMonster(monsterInfo)
	if not monsterInfo.model or not monsterInfo.model.PrimaryPart then
		return false
	end

	local rootPart = monsterInfo.model.PrimaryPart
	local humanoid = monsterInfo.humanoid

	if not humanoid then
		return false
	end

	-- Strategy 1: Try moving to a slightly different position (keep current height)
	local currentPos = rootPart.Position
	local offset = Vector3.new(
		math.random(-3, 3),
		0, -- Keep same height for nudging
		math.random(-3, 3)
	)

	local nudgePosition = currentPos + offset
	humanoid:MoveTo(nudgePosition)

	print("[PathEncounterRunner] Attempting to nudge monster: " .. monsterInfo.model.Name)

	-- Strategy 2: If we have a path, skip to next waypoint
	if monsterInfo.path and monsterInfo.currentWaypoint <= #monsterInfo.path then
		monsterInfo.currentWaypoint = math.min(monsterInfo.currentWaypoint + 2, #monsterInfo.path)
	end

	-- Reset the stuck timer
	monsterInfo.lastPosition = currentPos
	monsterInfo.lastPositionTime = tick()

	return true
end

function PathEncounterRunner.UpdateMonsterMovement()
	for i = #activeMonsters, 1, -1 do
		local monsterInfo = activeMonsters[i]

		if not monsterInfo.model or not monsterInfo.model.Parent then
			table.remove(activeMonsters, i)
			continue
		end

		if monsterInfo.inCombat then
			continue
		end

		local rootPart = monsterInfo.model.PrimaryPart
		if not rootPart then
			continue
		end

		local currentPos = rootPart.Position
		local currentTime = tick()

		-- Height-agnostic position comparison (ignore Y-axis for movement calculations)
		local currentPosHorizontal = Vector3.new(currentPos.X, 0, currentPos.Z)
		local lastPosHorizontal = Vector3.new(monsterInfo.lastPosition.X, 0, monsterInfo.lastPosition.Z)
		local endPosHorizontal = Vector3.new(monsterInfo.endPosition.X, 0, monsterInfo.endPosition.Z)

		-- Improved stuck detection that ignores height
		local isStuck = false

		-- Condition 1: Check horizontal movement only
		local horizontalDistanceMoved = (currentPosHorizontal - lastPosHorizontal).Magnitude
		local timeSinceLastMove = currentTime - monsterInfo.lastPositionTime

		if horizontalDistanceMoved < 2.5 and timeSinceLastMove > CONFIG.STUCK_THRESHOLD then
			-- Condition 2: Verify we're not at our destination (horizontal distance only)
			local horizontalDistanceToDestination = (currentPosHorizontal - endPosHorizontal).Magnitude
			if horizontalDistanceToDestination > CONFIG.ARRIVAL_DISTANCE then
				-- Condition 3: Check if we're actually trying to move (humanoid state)
				local humanoid = monsterInfo.humanoid
				if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
					print(string.format(
						"[PathEncounterRunner] Monster %s appears stuck (moved %.1f horizontal studs in %.1f seconds)", 
						monsterInfo.model.Name, horizontalDistanceMoved, timeSinceLastMove
						))
					isStuck = true
				end
			end
		end

		if isStuck then
			-- Try to nudge the monster first before regenerating the entire path
			local success = PathEncounterRunner.TryUnstickMonster(monsterInfo)
			if not success then
				print("[PathEncounterRunner] Nudge failed, regenerating path: " .. monsterInfo.model.Name)
				PathEncounterRunner.GeneratePath(monsterInfo)
			end
			monsterInfo.lastPosition = currentPos
			monsterInfo.lastPositionTime = currentTime
		elseif horizontalDistanceMoved > 0.5 then -- Only update if we've moved significantly horizontally
			monsterInfo.lastPosition = currentPos
			monsterInfo.lastPositionTime = currentTime
		end

		-- Check if reached destination (horizontal distance only)
		local horizontalDistanceToEnd = (currentPosHorizontal - endPosHorizontal).Magnitude
		if horizontalDistanceToEnd < CONFIG.ARRIVAL_DISTANCE then
			--print("[PathEncounterRunner] Monster reached end, destroying: " .. monsterInfo.model.Name)
			PathEncounterRunner.DestroyMonster(monsterInfo)
			continue
		end

		-- Follow path with height-agnostic waypoint checking
		if monsterInfo.path and monsterInfo.currentWaypoint <= #monsterInfo.path then
			local waypoint = monsterInfo.path[monsterInfo.currentWaypoint]
			local humanoid = monsterInfo.humanoid

			if humanoid and humanoid.Health > 0 then
				-- Check horizontal distance to waypoint (ignore height)
				local waypointPosHorizontal = Vector3.new(waypoint.Position.X, 0, waypoint.Position.Z)
				local horizontalDistanceToWaypoint = (currentPosHorizontal - waypointPosHorizontal).Magnitude

				-- Only issue new move command if we're not already close to the waypoint horizontally
				if horizontalDistanceToWaypoint > 3 then
					humanoid:MoveTo(waypoint.Position)
				end

				-- Check if reached current waypoint (horizontal distance only)
				if horizontalDistanceToWaypoint < 4 then
					monsterInfo.currentWaypoint += 1

					-- Regenerate path if we're at the last waypoint but not at destination
					if monsterInfo.currentWaypoint > #monsterInfo.path and 
						horizontalDistanceToEnd > CONFIG.ARRIVAL_DISTANCE then
						PathEncounterRunner.GeneratePath(monsterInfo)
					end
				end
			end
		else
			-- No valid path, regenerate
			PathEncounterRunner.GeneratePath(monsterInfo)
		end
	end
end


function PathEncounterRunner.HandlePromptTriggered(player, monsterInfo)
	-- Check if player is already in combat
	if playersInCombat[player.UserId] then
		-- You could show a notification to the player here
		print("[PathEncounterRunner] Player " .. player.Name .. " is already in combat")
		return
	end

	-- Check if monster is valid and not already in combat
	if not monsterInfo.model or not monsterInfo.model.Parent or monsterInfo.inCombat then
		return
	end

	monsterInfo.inCombat = true
	playersInCombat[player.UserId] = true

	-- Store current position for battle resumption
	monsterInfo.battleStartPosition = monsterInfo.model:GetPivot().Position

	-- Stop movement
	local humanoid = monsterInfo.model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:MoveTo(monsterInfo.model:GetPivot().Position)
	end

	-- Disable prompt during battle
	if monsterInfo.prompt then
		monsterInfo.prompt.Enabled = false
	end

	-- Get player's monster
	local playerMonster = _G.SHARED.GetPlayerMonster(player)
	if not playerMonster then
		warn("[PathEncounterRunner] Player has no monster to battle with")
		PathEncounterRunner.ResetMonsterAfterFailedBattle(monsterInfo, player)
		return
	end

	print(string.format("[PathEncounterRunner] Starting battle: %s vs %s", player.Name, monsterInfo.model.Name))

	-- USE THE EXACT SAME ARENA LOGIC AS ENCOUNTERMANAGER
	local npc = monsterInfo.model
	local anchorFrom = (npc and npc.PrimaryPart and npc.PrimaryPart.Position)
		or (player.Character and player.Character.PrimaryPart and player.Character.PrimaryPart.Position)
		or Vector3.new()

	local spotPos = _G.COMBAT_ZONE.FindNearestSpot and _G.COMBAT_ZONE.FindNearestSpot(anchorFrom) or nil

	-- Double-check by requiring the module directly
	local ok, CZ = pcall(function() 
		return require(script.Parent.CombatZone) 
	end)

	if ok and CZ and typeof(anchorFrom) == "Vector3" then
		spotPos = CZ.FindNearestSpot(anchorFrom)
	end

	local center = spotPos or anchorFrom
	local opts = { 
		center = center, 
		radius = 30, 
		height = 16 
	}

	-- Start combat using the exact same parameters as EncounterManager
	local combatId = _G.COMBATMANAGER.StartCombat(
		{playerMonster, monsterInfo.model},
		opts,
		function(results)
			PathEncounterRunner.HandleCombatEnd(results, monsterInfo, player)
		end
	)

	-- Set combat state
	_G.STATES:SetState(monsterInfo.model, "InCombat")
end

function PathEncounterRunner.HandleCombatEnd(results, monsterInfo, player)
	print("[PathEncounterRunner] Combat ended for: " .. (monsterInfo.model and monsterInfo.model.Name or "Unknown"))

	-- Remove player from combat tracking
	playersInCombat[player.UserId] = nil

	if not monsterInfo.model or not monsterInfo.model.Parent then
		return
	end

	local playerWon = false
	local enemyMonster = monsterInfo.model

	if results and results.winner then
		local winnerOwnerId = results.winner:GetAttribute("OwnerId")
		playerWon = (winnerOwnerId and tonumber(winnerOwnerId) == player.UserId)
	end

	-- Check if enemy monster is actually dead (health-based check)
	local humanoid = enemyMonster:FindFirstChildOfClass("Humanoid")
	local isEnemyDead = not humanoid or humanoid.Health <= 0

	if playerWon or isEnemyDead then
		-- Player won OR enemy died (double-check)
		print("[PathEncounterRunner] Enemy defeated: " .. enemyMonster.Name)

		-- Use a coroutine to handle the death sequence properly
		task.spawn(function()
			-- Wait a brief moment for combat system to settle
			task.wait(0.5)

			if not enemyMonster or not enemyMonster.Parent then
				return
			end

			-- Try to play death animation if available
			local deathPlayed = false
			if _G.FUNCTIONS and _G.FUNCTIONS.playDeathFrozen then
				local deathTrack = _G.FUNCTIONS.playDeathFrozen(
					enemyMonster, 
					0.6,
					1.5,
					{
						fallbackLen = 1.2,
						playFade = 0.10,
						stopFade = 0.12,
						block = false
					}
				)

				if deathTrack then
					deathPlayed = true
					local animationLength = deathTrack.Length or 1.7
					task.wait(animationLength + 0.3)
				else
					task.wait(1.5) -- Fallback wait time
				end
			else
				task.wait(1.5) -- Fallback wait time
			end

			-- Final destruction check
			if monsterInfo.model and monsterInfo.model.Parent then
				print("[PathEncounterRunner] Destroying defeated monster: " .. monsterInfo.model.Name)
				PathEncounterRunner.DestroyMonster(monsterInfo)
			end

			-- Respawn new monster after delay
			task.delay(CONFIG.RESPAWN_DELAY, function()
				local startPart = pathFolder:FindFirstChild("start1")
				local endPart = pathFolder:FindFirstChild("end1")
				if startPart and endPart then
					PathEncounterRunner.SpawnMonster(startPart, endPart)
				end
			end)
		end)
	else
		-- Enemy won and is still alive
		print("[PathEncounterRunner] Enemy won, resuming path: " .. monsterInfo.model.Name)

		-- Clean up combat state
		if _G.STATES then
			_G.STATES:RemoveState(monsterInfo.model, "InCombat")
		end

		-- Re-enable prompt
		if monsterInfo.prompt then
			monsterInfo.prompt.Enabled = true
		end

		monsterInfo.inCombat = false

		-- Resume movement after a delay
		task.delay(2, function()
			if monsterInfo.model and monsterInfo.model.Parent then
				local humanoid = monsterInfo.model:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					PathEncounterRunner.GeneratePath(monsterInfo)
				else
					-- Monster died after combat ended somehow
					PathEncounterRunner.DestroyMonster(monsterInfo)
				end
			end
		end)
	end
end

function PathEncounterRunner.ResetMonsterAfterFailedBattle(monsterInfo, player)
	monsterInfo.inCombat = false
	playersInCombat[player.UserId] = nil

	if monsterInfo.prompt then
		monsterInfo.prompt.Enabled = true
	end

	-- Resume movement
	task.delay(1, function()
		if monsterInfo.model and monsterInfo.model.Parent then
			PathEncounterRunner.GeneratePath(monsterInfo)
		end
	end)
end

function PathEncounterRunner.DestroyMonster(monsterInfo)
	if not monsterInfo then
		return
	end

	-- Clean up
	if monsterInfo.model and monsterInfo.model.Parent then
		monsterInfo.model:Destroy()
	end

	-- Remove from active monsters
	for i, monster in ipairs(activeMonsters) do
		if monster == monsterInfo then
			table.remove(activeMonsters, i)
			break
		end
	end

	--print("[PathEncounterRunner] Monster destroyed: " .. (monsterInfo.model and monsterInfo.model.Name or "Unknown"))
end

function PathEncounterRunner.Cleanup()
	for i = #activeMonsters, 1, -1 do
		PathEncounterRunner.DestroyMonster(activeMonsters[i])
	end

	-- Clear combat tracking
	playersInCombat = {}
end

function PathEncounterRunner.GetActiveMonsters()
	return activeMonsters
end

function PathEncounterRunner.IsPlayerInCombat(player)
	return playersInCombat[player.UserId] == true
end

-- New function to update configuration
function PathEncounterRunner.UpdateConfig(newConfig)
	for key, value in pairs(newConfig) do
		if CONFIG[key] ~= nil then
			CONFIG[key] = value
		end
	end
	print("[PathEncounterRunner] Configuration updated")
end

return PathEncounterRunner