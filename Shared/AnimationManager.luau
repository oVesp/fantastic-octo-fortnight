-- ModuleScript: ReplicatedStorage>Modules>AnimationManager
local AnimationManager = {}
AnimationManager.__index = AnimationManager

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ContentProvider = game:GetService("ContentProvider")

-- Cache for animation lookups
local animationCache = {}

function AnimationManager:GetCastAnimation(race)
	-- Normalize race name (remove spaces, handle case variations)
	local normalizedRace = tostring(race):gsub("%s+", ""):gsub("[^%w]", ""):lower()

	-- Check cache first
	if animationCache[normalizedRace] then
		return animationCache[normalizedRace]
	end

	-- Search in Animations folder
	local animationsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not animationsFolder then
		warn("Assets folder not found in ReplicatedStorage")
		return nil
	end

	animationsFolder = animationsFolder:FindFirstChild("Animations")
	if not animationsFolder then
		warn("Animations folder not found in ReplicatedStorage/Assets")
		return nil
	end

	-- Search for race folder
	local raceFolder = nil

	-- First try exact match
	raceFolder = animationsFolder:FindFirstChild(race)

	-- If not found, try case-insensitive search
	if not raceFolder then
		for _, folder in pairs(animationsFolder:GetChildren()) do
			if folder:IsA("Folder") then
				local folderName = folder.Name:gsub("%s+", ""):gsub("[^%w]", ""):lower()
				if folderName == normalizedRace then
					raceFolder = folder
					break
				end
			end
		end
	end

	if not raceFolder then
		warn("No animation folder found for race: " .. race)
		return nil
	end

	-- Search for cast animation in race folder
	local castAnimation = nil

	-- Look for animations containing "cast" (case insensitive)
	for _, anim in pairs(raceFolder:GetChildren()) do
		if anim:IsA("Animation") then
			local animName = anim.Name:lower()
			if animName:find("cast") then
				castAnimation = anim
				break
			end
		end
	end

	-- If no "cast" animation found, look for any animation in the folder
	if not castAnimation then
		for _, anim in pairs(raceFolder:GetChildren()) do
			if anim:IsA("Animation") then
				castAnimation = anim
				break
			end
		end
	end

	if castAnimation then
		local result = {
			AnimationId = castAnimation.AnimationId,
			Animation = castAnimation,
			Duration = AnimationManager:GetAnimationDuration(castAnimation)
		}

		-- Cache the result
		animationCache[normalizedRace] = result
		return result
	end

	warn("No cast animation found for race: " .. race .. " in folder: " .. raceFolder.Name)
	return nil
end

function AnimationManager:GetAnimationDuration(animation)
	-- Try to get duration from animation if it's loaded
	if animation and animation:IsA("Animation") then
		-- Note: This might not work on the server for all animations
		-- We'll use a fallback system
		local success, length = pcall(function()
			return animation.Length
		end)

		if success and length and length > 0 then
			return length
		end
	end

	-- Fallback: Use predefined durations based on race or animation type
	local fallbackDurations = {
		["realityseed"] = 1.5,
		["dino"] = 1.2,
		["golem"] = 1.8,
		["devil"] = 1.0,
		["angel"] = 1.3,
		["progenitor"] = 2.0,
		["beast"] = 1.1
	}

	local raceName = tostring(animation and animation.Parent and animation.Parent.Name or "default"):lower()
	return fallbackDurations[raceName] or 1.5 -- Default fallback
end

function AnimationManager:GetAllRaceAnimations()
	local animationsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not animationsFolder then return {} end

	animationsFolder = animationsFolder:FindFirstChild("Animations")
	if not animationsFolder then return {} end

	local races = {}

	for _, raceFolder in pairs(animationsFolder:GetChildren()) do
		if raceFolder:IsA("Folder") then
			local raceData = {
				Name = raceFolder.Name,
				Animations = {}
			}

			for _, anim in pairs(raceFolder:GetChildren()) do
				if anim:IsA("Animation") then
					table.insert(raceData.Animations, {
						Name = anim.Name,
						AnimationId = anim.AnimationId,
						Duration = AnimationManager:GetAnimationDuration(anim)
					})
				end
			end

			races[raceFolder.Name] = raceData
		end
	end

	return races
end

local function countKeys(t)
	local c = 0
	for _ in pairs(t) do c += 1 end
	return c
end

function AnimationManager:PreloadAnimations()
	local allRaces = self:GetAllRaceAnimations()
	print(("Preloaded animations for %d races"):format(countKeys(allRaces)))
	return allRaces
end

-- Preload on require
AnimationManager:PreloadAnimations()

return AnimationManager