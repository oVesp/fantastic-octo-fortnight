-- ModuleScript: ServerScriptService>Main>Functions
local module = {}
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Raycast util to find a safe ground position
local function groundAt(pos: Vector3)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}
	local origin = pos + Vector3.new(0, 50, 0)
	local result = Workspace:Raycast(origin, Vector3.new(0, -500, 0), params)
	if result then
		return result.Position + Vector3.new(0, 2, 0)
	else
		return pos + Vector3.new(0, 2, 0)
	end
end

-- Teleporta um modelo de monstro ao lado do dono (OwnerId) com offset lateral
function module:teleportToOwner(monster: Model, ownerId: number?)
	if not (monster and monster:IsA("Model")) then return false, "invalid monster" end
	local oid = ownerId or monster:GetAttribute("OwnerId") or monster:GetAttribute("Userid")
	if not oid then return false, "ownerId not set" end
	local plr = Players:GetPlayerByUserId(tonumber(oid))
	if not (plr and plr.Character and plr.Character.PrimaryPart) then
		return false, "owner character not ready"
	end

	local base = plr.Character.PrimaryPart.CFrame
	-- right side offset; falls back behind if blocked (simple check)
	local candidates = {
		base * CFrame.new(4, 0, 0),
		base * CFrame.new(-4, 0, 0),
		base * CFrame.new(0, 0, -4),
	}
	local chosen = candidates[1]
	local pos = groundAt(chosen.Position)
	if monster.PrimaryPart then
		monster:PivotTo(CFrame.new(pos))
	else
		monster:PivotTo(CFrame.new(pos))
	end
	return true
end
function module.calculateWeight(weights)
	local totalWeight = 0
	for _, weight in pairs(weights) do
		totalWeight += weight
	end

	local randomWeight = math.random() * totalWeight
	local cumulativeWeight = 0

	for choice, weight in pairs(weights) do
		cumulativeWeight += weight
		if randomWeight <= cumulativeWeight then
			return choice
		end
	end
end

function module.distributePoints(keys, maxPoints)
	local keyList = {}
	if type(keys) == "table" then
		local isValueTable = false
		for k, v in (keys) do
			if type(v) == "number" then
				isValueTable = true
				break
			end
		end

		if isValueTable then
			for k, v in (keys) do
				table.insert(keyList, k)
			end
		else
			keyList = keys
		end
	else
		error("distributePoints: keys must be a table")
	end

	local distribution = {}
	local remainingPoints = maxPoints

	-- Initialize all keys with at least 1 point
	for _, key in ipairs(keyList) do
		distribution[key] = 1
		remainingPoints = remainingPoints - 1
	end

	-- Handle case where maxPoints is less than number of keys
	if remainingPoints < 0 then
		while remainingPoints < 0 do
			local randomKey = keyList[math.random(1, #keyList)]
			if distribution[randomKey] > 0 then
				distribution[randomKey] = distribution[randomKey] - 1
				remainingPoints = remainingPoints + 1
			end
		end
		return distribution
	end

	-- Archetype-based distribution
	local archetypes = {
		{weights = {Hp = 3, Mp = 1, Strength = 2, Defense = 2, Skill = 1, Speed = 1, Intelligence = 1}},
		{weights = {Hp = 1, Mp = 3, Strength = 1, Defense = 1, Skill = 2, Speed = 1, Intelligence = 2}},
		{weights = {Hp = 2, Mp = 1, Strength = 3, Defense = 2, Skill = 2, Speed = 1, Intelligence = 1}},
		{weights = {Hp = 2, Mp = 2, Strength = 1, Defense = 3, Skill = 1, Speed = 1, Intelligence = 1}},
		{weights = {Hp = 1, Mp = 2, Strength = 1, Defense = 1, Skill = 3, Speed = 2, Intelligence = 1}},
		{weights = {Hp = 1, Mp = 1, Strength = 1, Defense = 1, Skill = 2, Speed = 3, Intelligence = 2}},
		{weights = {Hp = 1, Mp = 2, Strength = 1, Defense = 1, Skill = 1, Speed = 1, Intelligence = 3}}
	}

	local archetype = archetypes[math.random(1, #archetypes)]

	-- Distribute remaining points based on archetype weights
	for i = 1, remainingPoints do
		local weightedKeys = {}
		for _, key in (keyList) do
			local weight = archetype.weights[key] or 1
			for j = 1, weight do
				table.insert(weightedKeys, key)
			end
		end

		if #weightedKeys == 0 then
			for _, key in (keyList) do
				table.insert(weightedKeys, key)
			end
		end

		local selectedKey = weightedKeys[math.random(1, #weightedKeys)]
		distribution[selectedKey] = distribution[selectedKey] + 1
	end

	-- Smooth distribution
	local iterations = math.min(5, math.floor(maxPoints * 0.3))
	for i = 1, iterations do
		local key1 = keyList[math.random(1, #keyList)]
		local key2 = keyList[math.random(1, #keyList)]
		if key1 ~= key2 and distribution[key1] > 1 then
			distribution[key1] = distribution[key1] - 1
			distribution[key2] = distribution[key2] + 1
		end
	end

	-- Ensure total points match maxPoints
	local total = 0
	for _, key in ipairs(keyList) do
		total = total + distribution[key]
	end

	if total ~= maxPoints then
		local diff = maxPoints - total
		if diff > 0 then
			local randomKey = keyList[math.random(1, #keyList)]
			distribution[randomKey] = distribution[randomKey] + diff
		elseif diff < 0 then
			while diff < 0 do
				local randomKey = keyList[math.random(1, #keyList)]
				if distribution[randomKey] > 1 then
					distribution[randomKey] = distribution[randomKey] - 1
					diff = diff + 1
				end
			end
		end
	end

	return distribution
end

function module.playDeathFrozen(monster: Model, freezeFrac: number?, holdSeconds: number?, opts: table?)
	opts = opts or {}
	local freezeAtFrac = math.clamp(tonumber(freezeFrac) or 0.6, 0.05, 0.95)
	local hold = tonumber(holdSeconds) or 1.5
	local fallbackLen = tonumber(opts.fallbackLen) or 1.2
	local playFade = tonumber(opts.playFade) or 0.10
	local stopFade = tonumber(opts.stopFade) or 0.12
	local block = opts.block == true

	local hum = monster and monster:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)

	-- Descobrir AnimationId da death
	local RS = game:GetService("ReplicatedStorage")
	local race = monster:GetAttribute("Race")
	local animRoot = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("Animations")
	local function resolveDeathId()
		if not (race and animRoot) then return nil end
		local folder = animRoot:FindFirstChild(race)
		if not folder then
			for _, f in ipairs(animRoot:GetChildren()) do
				if f:IsA("Folder") and f.Name:lower() == tostring(race):lower() then folder = f; break end
			end
		end
		if not folder then return nil end
		for _, a in ipairs(folder:GetChildren()) do
			if a:IsA("Animation") and a.Name:lower():find("death") then
				return a.AnimationId
			end
		end
		return nil
	end

	local animId = resolveDeathId()
	if not animId then
		warn("[playDeathFrozen] Death animation not found for race:", race)
		return nil
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = false
	track:Play(playFade)

	-- dá um respiro pro comprimento ser calculado (quando disponível)
	task.wait(0.03)

	local length = fallbackLen
	pcall(function()
		length = track.Length or track:GetTimeLength() or fallbackLen
	end)
	if not length or length <= 0 then length = fallbackLen end

	local freezeAtTime = math.clamp(length * freezeAtFrac, 0.05, math.max(0.06, length - 0.05))

	-- Em vez de esperar TimePosition (instável no server), usamos timers:
	local froze = false
	local unfreezeConn, stoppedConn

	-- Congelar no instante alvo
	task.delay(freezeAtTime, function()
		if track and track.IsPlaying then
			pcall(function() track:AdjustSpeed(0) end)
			froze = true
		end
	end)

	-- Descongelar/parar após hold
	task.delay(freezeAtTime + hold, function()
		if track then
			-- se nunca congelou por timing, ainda assim para
			pcall(function()
				if track.IsPlaying then
					track:AdjustSpeed(1)
					track:Stop(stopFade)
				end
			end)
		end
	end)

	-- Opcional: modo bloqueante (evite — pode contar pro timeout)
	if block then
		task.wait(freezeAtTime + hold + stopFade + 0.05)
	end

	return track
end

--COMBAT FUNCTIONS

function module:Decision(weights)
	local total = 0
	for key, value in pairs(weights) do
		total += value
	end

	if total == 0 then
		return "attack"
	end

	local rng = Random.new()
	local roll = rng:NextNumber(0, total)
	local cumulative = 0

	for key, value in pairs(weights) do
		cumulative += value
		if roll <= cumulative then
			return key
		end
	end

	return "attack"
end



function GetCastAnimationForRace(race)
	local AnimationManager = require(game.ReplicatedStorage.Modules.AnimationManager)
	return AnimationManager:GetCastAnimation(race)
end

return module