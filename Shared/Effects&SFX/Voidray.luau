-- Advanced/VoidRay.lua
-- Uses your LightningBolt module to render a procedural bolt on impact.
-- Keeps template-based Cast_/Travel_/End_ for the other stages.

local RP = game:GetService("ReplicatedStorage")
local Modules = RP:WaitForChild("Modules")
local LightningBolt = require(script.Parent:WaitForChild("LightningBolt")) -- put your lightning module here

local AdvancedVoidRay = {}

-- Optional: override the default naming pack (or just return nil to use template defaults)
function AdvancedVoidRay.getPack(moveId)
	-- Keep template behavior for cast/travel/endcast; just define impact sfx name
	return {
		cast   = { effect = "Cast_"..moveId,   sfxStart = "Cast_"..moveId },
		travel = { trail  = "Travel_"..moveId, sfxLoop  = "Travel_"..moveId },
		impact = { effect = "Impact_"..moveId, sfxHit   = "Impact_"..moveId },
		endcast= { sfxEnd = "End_"..moveId },
	}
end

-- Stage hook: draw bolt on impact
function AdvancedVoidRay.impact(moveId, where, opts)
	-- where can be target root
	local targetRoot = where
	local casterRoot = opts and opts.CasterRoot
	if not (targetRoot and casterRoot) then return end

	-- Create temporary attachments for bolt start/end
	local a0 = Instance.new("Attachment"); a0.WorldPosition = casterRoot.Position; a0.WorldAxis = casterRoot.CFrame.LookVector; a0.Parent = workspace.Terrain
	local a1 = Instance.new("Attachment"); a1.WorldPosition = targetRoot.Position; a1.WorldAxis = -casterRoot.CFrame.LookVector; a1.Parent = workspace.Terrain

	-- Configure the bolt
	local bolt = LightningBolt.new(a0, a1, 40)
	bolt.Color = Color3.fromRGB(145, 190, 255) -- pale blue (can be ColorSequence)
	bolt.Thickness = 0.4
	bolt.MinRadius, bolt.MaxRadius = 0.2, 2.0
	bolt.Frequency = 0.8
	bolt.AnimationSpeed = 6
	bolt.PulseSpeed = 3
	bolt.PulseLength = 0.5
	bolt.FadeLength = 0.18

	-- Optional extra: small scorch impact where the bolt lands
	if _G.EFFECTS and _G.EFFECTS.EmitterEffect then
		_G.EFFECTS.EmitterEffect({ Name = "Impact_"..moveId, Where = targetRoot, Duration = 0.25 })
	end
	if _G.EFFECTS and _G.EFFECTS.PlaySound then
		_G.EFFECTS:PlaySound("Impact_"..moveId, targetRoot)
	end

	-- Clean up attachments after a short delay
	task.delay(0.6, function()
		if bolt and bolt.Destroy then pcall(function() bolt:Destroy() end) end
		if a0 then a0:Destroy() end
		if a1 then a1:Destroy() end
	end)
end

return AdvancedVoidRay
