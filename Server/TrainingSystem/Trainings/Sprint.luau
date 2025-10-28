local module = {}

local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Utils = require(script.Parent.Parent.Utils)
local Functions = _G.FUNCTIONS

module.BaseBonus = {
	Speed = 20, -- Increased from 2 to 3
}

-- Configuration for better balancing
local CONFIG = {
	BASE_SPEED = 30, -- Increased base speed
	MIN_SPEED = 20, -- Increased minimum speed
	MAX_SPEED = 50, -- Increased maximum speed
	SPEED_MULTIPLIER = 1.2, -- Better speed scaling

	-- Improved failure system
	FAILURE_CHANCE_START = 0.15, -- Chance at start of path
	FAILURE_CHANCE_END = 0.25, -- Chance at end of path (increased risk/reward)
	MIN_NODES_FOR_FAILURE = 3, -- Must reach at least this many nodes before failure can occur

	-- Performance and gameplay
	NODE_TIMEOUT = 7, -- Reduced timeout for faster pacing
	TELEPORT_HEIGHT = 3,

	-- Speed tiers for bonus rewards
	SPEED_TIERS = {
		{ threshold = 800, bonusMultiplier = 1.2 }, -- High speed bonus
		{ threshold = 500, bonusMultiplier = 1.1 }, -- Medium speed bonus
		{ threshold = 200, bonusMultiplier = 1.0 }  -- Base
	}
}

function module:Start(monster: Model, player: Player, ctx: table)
	assert(monster and player and ctx, "Sprint training requires monster, player, and context")

	local nodesFolder = ctx.NodesFolder
	local startPart = ctx.Start

	if not nodesFolder or not nodesFolder:IsA("Folder") then
		warn("[Sprint] Missing or invalid NodesFolder")
		return { success = false, reason = "invalid_nodes" }
	end

	if not startPart or not startPart:IsA("BasePart") then
		warn("[Sprint] Missing or invalid Start part")
		return { success = false, reason = "invalid_start" }
	end

	local nodes = nodesFolder:GetChildren()
	table.sort(nodes, function(a, b) return a.Name < b.Name end)

	if #nodes < 2 then
		warn("[Sprint] Not enough nodes for path")
		return { success = false, reason = "not_enough_nodes" }
	end

	local humanoid = monster:FindFirstChildOfClass("Humanoid")
	if not humanoid or not monster.PrimaryPart then
		warn("[Sprint] Monster missing Humanoid or PrimaryPart")
		return { success = false, reason = "bad_monster" }
	end

	-- Teleport monster to start position
	monster:PivotTo(startPart.CFrame + Vector3.new(0, CONFIG.TELEPORT_HEIGHT, 0))
	RunService.Heartbeat:Wait()

	-- Enhanced speed calculation with better scaling
	local speedStat = monster:GetAttribute("Speed") or 0
	local walkSpeedMult = math.clamp(speedStat / 999, 0, 1)

	-- Improved speed formula for better progression
	local finalSpeed = math.clamp(
		CONFIG.BASE_SPEED * (0.6 + CONFIG.SPEED_MULTIPLIER * walkSpeedMult), 
		CONFIG.MIN_SPEED, 
		CONFIG.MAX_SPEED
	)

	local originalSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = finalSpeed

	-- Calculate speed tier bonus
	local speedTierMultiplier = 1.0
	for _, tier in ipairs(CONFIG.SPEED_TIERS) do
		if speedStat >= tier.threshold then
			speedTierMultiplier = tier.bonusMultiplier
			break
		end
	end

	local success = true
	local failedAt = nil
	local nodesCompleted = 0

	for i, node in ipairs(nodes) do
		humanoid:MoveTo(node.Position)
		local timeout = CONFIG.NODE_TIMEOUT
		local reached = false

		local conn = humanoid.MoveToFinished:Connect(function(reachedTarget)
			reached = reachedTarget
		end)

		-- Improved movement with progress tracking
		local startTime = tick()
		while not reached and tick() - startTime < timeout do
			RunService.Heartbeat:Wait()
		end
		conn:Disconnect()

		if reached then
			nodesCompleted = i

			-- Progressive failure chance system
			if i >= CONFIG.MIN_NODES_FOR_FAILURE then
				-- Failure chance increases as you progress further
				local progress = i / #nodes
				local failureChance = CONFIG.FAILURE_CHANCE_START + 
					(CONFIG.FAILURE_CHANCE_END - CONFIG.FAILURE_CHANCE_START) * progress

				-- Speed stat reduces failure chance (high speed = better control)
				local speedBonus = math.clamp(speedStat / 1000, 0, 0.3) -- Up to 30% reduction
				failureChance = math.max(0.05, failureChance - speedBonus)

				if math.random() < failureChance then
					warn("[Sprint] Monster failed during sprint at node ", i)

					-- Enhanced cinematic fail
					local EvFail = ReplicatedStorage.Remotes:FindFirstChild("TrainingCameraFail")
					if EvFail then
						EvFail:FireClient(player, monster, {
							duration = 1.2, -- Slightly shorter
							heightStart = 8,
							heightEnd = 10,
							radiusStart = 15,
							radiusEnd = 12,
							angularSpeedDeg = 65, -- Faster rotation
							fovStart = 75,
							fovEnd = 65,
						})
					end

					-- Quicker death animation for better pacing
					Functions.playDeathFrozen(monster, 0.5, 1.5)
					task.wait(1.5) -- Reduced wait time

					success = false
					failedAt = i
					break
				end
			end
		else
			warn("[Sprint] Timeout reaching node", node.Name)
			-- Don't immediately fail on timeout, but count progress
			if i > nodesCompleted then
				nodesCompleted = i
			end
		end
	end

	-- Restore original speed
	humanoid.WalkSpeed = originalSpeed

	if success then
		return { 
			success = true, 
			speedTierMultiplier = speedTierMultiplier,
			nodesCompleted = nodesCompleted,
			totalNodes = #nodes,
			finalSpeed = finalSpeed
		}
	else
		return { 
			success = false, 
			reason = "random_fail", 
			failedAt = failedAt,
			nodesCompleted = nodesCompleted,
			totalNodes = #nodes
		}
	end
end

return module