local RS = game:GetService("ReplicatedStorage")
local Remotes = RS:WaitForChild("Remotes")
local EvolutionEffect = Remotes:WaitForChild("EvolutionEffect")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local EFFECTS = _G.EFFECTS or require(RS.Modules["Effects&SFX"])

-- Evolution effect sequences for different stages
local EVOLUTION_EFFECTS = {
	-- Basic evolution (Rookie -> Champion)
	Basic = {
		duration = 4,
		sequence = {
			{time = 0.0, effect = "LightEffect", params = {Name = "EvolutionLight", Where = nil, Brightness = 3, Range = 15, Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 100)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 0))}), Duration = 3}},
			{time = 0.2, effect = "EmitterEffect", params = {Name = "EvolutionSparks", Duration = 3}},
			{time = 0.5, effect = "AuraEffect", params = {Name = "EvolutionAura", Duration = 3, Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 180, 50)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 140, 0)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 180, 50))})}},
			{time = 1.0, effect = "PlaySound", params = {Name = "EvolutionStart", Where = nil, Volume = 0.8}},
			{time = 1.5, effect = "ColorCorrection", params = {Brightness = 0.3, Saturation = 0.4, TintColor = Color3.fromRGB(255, 200, 100), Duration = 2}},
			{time = 2.0, effect = "ScreenShake", params = {Intensity = 0.3, Duration = 1.5}},
			{time = 3.0, effect = "PlaySound", params = {Name = "EvolutionComplete", Where = nil, Volume = 1.0}},
		}
	},

	-- Advanced evolution (Champion -> Elder)
	Advanced = {
		duration = 6,
		sequence = {
			{time = 0.0, effect = "LightEffect", params = {Name = "EvolutionLight", Where = nil, Brightness = 5, Range = 20, Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 220)), ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 50, 200))}), Duration = 5}},
			{time = 0.3, effect = "EmitterEffect", params = {Name = "EvolutionEnergy", Duration = 5}},
			{time = 0.8, effect = "AuraEffect", params = {Name = "MythicAura", Duration = 5, Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 40, 200)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 90, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 40, 200))})}},
			{time = 1.2, effect = "PlaySound", params = {Name = "EvolutionRumble", Where = nil, Volume = 0.7, Duration = 4}},
			{time = 2.0, effect = "ColorCorrection", params = {Brightness = 0.5, Saturation = 0.6, Contrast = 0.3, TintColor = Color3.fromRGB(200, 100, 255), Duration = 3}},
			{time = 2.5, effect = "ScreenShake", params = {Intensity = 0.5, Duration = 2}},
			{time = 3.5, effect = "FovEffect", params = {Start = 0.5, End = 0.8, Fov = 80, Duration = 1.5}},
			{time = 4.0, effect = "PlaySound", params = {Name = "EvolutionTransform", Where = nil, Volume = 1.0}},
			{time = 5.0, effect = "LightEffect", params = {Name = "EvolutionFlash", Where = nil, Brightness = 10, Range = 25, Duration = 1}},
		}
	},

	-- Ultimate evolution (Elder -> Unique)
	Ultimate = {
		duration = 8,
		sequence = {
			{time = 0.0, effect = "LightEffect", params = {Name = "EvolutionLight", Where = nil, Brightness = 8, Range = 30, Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 255, 150)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 0))}), Duration = 7}},
			{time = 0.5, effect = "EmitterEffect", params = {Name = "CosmicParticles", Duration = 7}},
			{time = 1.0, effect = "AuraEffect", params = {Name = "DivineAura", Duration = 7, Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 100)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 220)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 100))})}},
			{time = 1.5, effect = "PlaySound", params = {Name = "CosmicEvolution", Where = nil, Volume = 0.9, Duration = 6}},
			{time = 2.5, effect = "ColorCorrection", params = {Brightness = 0.8, Saturation = 0.8, Contrast = 0.5, TintColor = Color3.fromRGB(255, 255, 150), Duration = 4}},
			{time = 3.0, effect = "ScreenShake", params = {Intensity = 0.8, Duration = 3}},
			{time = 4.0, effect = "FovEffect", params = {Start = 0.8, End = 1.2, Fov = 100, Duration = 2}},
			{time = 4.5, effect = "SpeedLines", params = {Duration = 3, Size = 0.6, Color = ColorSequence.new(Color3.new(1, 1, 0.5))}},
			{time = 5.5, effect = "LightEffect", params = {Name = "Supernova", Where = nil, Brightness = 15, Range = 40, Duration = 2}},
			{time = 6.5, effect = "PlaySound", params = {Name = "AscensionComplete", Where = nil, Volume = 1.2}},
			{time = 7.0, effect = "SlashCameraTransition", params = {Duration = 1, Speed = 20, Color = ColorSequence.new(Color3.new(1, 1, 0.3))}},
		}
	}
}

-- Get evolution tier based on target stage
local function getEvolutionTier(targetStage)
	if targetStage == "Unique" then return "Ultimate" end
	if targetStage == "Elder" then return "Advanced" end
	return "Basic"
end

-- Create screen shake effect
local function screenShake(intensity, duration)
	local camera = workspace.CurrentCamera
	if not camera then return end

	local originalPosition = camera.CFrame.Position
	local startTime = tick()
	local endTime = startTime + duration

	local connection
	connection = RunService.Heartbeat:Connect(function()
		local currentTime = tick()
		if currentTime >= endTime then
			connection:Disconnect()
			-- Reset to original position
			camera.CFrame = CFrame.new(originalPosition) * camera.CFrame.Rotation
			return
		end

		local progress = (currentTime - startTime) / duration
		local currentIntensity = intensity * (1 - progress)  -- Fade out over time

		-- Create smooth shake using sine waves
		local shakeOffset = Vector3.new(
			math.sin(currentTime * 30) * currentIntensity * 0.5,
			math.cos(currentTime * 25) * currentIntensity * 0.3,
			math.sin(currentTime * 35) * currentIntensity * 0.5
		)

		camera.CFrame = CFrame.new(originalPosition + shakeOffset) * camera.CFrame.Rotation
	end)
end

-- Add screen shake to effects module if not exists
if not EFFECTS.ScreenShake then
	EFFECTS.ScreenShake = function(info)
		screenShake(info.Intensity or 0.5, info.Duration or 1)
	end
end

-- Create a temporary monster placeholder for aura effects
local function createEvolutionPlaceholder(position)
	local placeholder = Instance.new("Part")
	placeholder.Name = "EvolutionPlaceholder"
	placeholder.Size = Vector3.new(4, 6, 4)
	placeholder.Anchored = true
	placeholder.CanCollide = false
	placeholder.Transparency = 1
	placeholder.CFrame = CFrame.new(position)
	placeholder.Parent = workspace.Debris

	return placeholder
end

-- Main evolution effect handler
EvolutionEffect.OnClientEvent:Connect(function(worldPos, targetRaceName, targetStage)
	local tier = getEvolutionTier(targetStage)
	local effectSequence = EVOLUTION_EFFECTS[tier] or EVOLUTION_EFFECTS.Basic

	print("Playing " .. tier .. " evolution effect for " .. targetRaceName)

	-- Create central effect anchor and placeholder for aura
	local anchor = Instance.new("Part")
	anchor.Name = "EvolutionAnchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(worldPos)
	anchor.Parent = workspace.Debris

	-- Create placeholder for aura effects
	local auraPlaceholder = createEvolutionPlaceholder(worldPos)

	-- Store active effects for cleanup
	local activeEffects = {}

	-- Function to play individual effects
	local function playEffect(effectData)
		local params = table.clone(effectData.params or {})

		-- Set position for effects that need it
		if effectData.effect == "EmitterEffect" or effectData.effect == "LightEffect" then
			params.Position = anchor
		end

		-- Handle aura effects - they need LocationParts
		if effectData.effect == "AuraEffect" then
			params.LocationParts = {auraPlaceholder}
		end

		-- Handle sound effects
		if effectData.effect == "PlaySound" then
			params.Where = anchor
		end



		-- Use existing effect functions
		if EFFECTS[effectData.effect] then
			local success, result = pcall(function()
				return EFFECTS[effectData.effect](params)
			end)

			if success and result then
				table.insert(activeEffects, result)
			elseif not success then
				warn("Failed to play effect " .. effectData.effect .. ": " .. tostring(result))
			end
		else
			warn("Effect function not found: " .. effectData.effect)
		end
	end

	-- Schedule all effects in the sequence
	for _, effectStep in ipairs(effectSequence.sequence) do
		task.delay(effectStep.time, function()
			if anchor and anchor.Parent then
				playEffect(effectStep)
			end
		end)
	end

	-- Cleanup after evolution completes
	task.delay(effectSequence.duration + 2, function()
		-- Clean up any remaining effects
		for _, effect in ipairs(activeEffects) do
			if effect and effect.Parent then
				pcall(function() effect:Destroy() end)
			end
		end

		if anchor and anchor.Parent then
			anchor:Destroy()
		end

		if auraPlaceholder and auraPlaceholder.Parent then
			auraPlaceholder:Destroy()
		end
	end)
end)

return EVOLUTION_EFFECTS