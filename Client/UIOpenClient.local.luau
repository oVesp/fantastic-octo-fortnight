-- StarterPlayerScripts/UIOpenClient.luau
-- Reusable UI opener for tagged models based on attributes (e.g., "TrainingUI")

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LOCAL_PLAYER = Players.LocalPlayer
local PLAYER_GUI = LOCAL_PLAYER:WaitForChild("PlayerGui")

-- ========== Helpers ==========

local function findDescendantOfClass(inst: Instance, className: string): Instance?
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA(className) then
			return d
		end
	end
	return nil
end

local function getPlayerMonster(player: Player): Model?
	local uid = player.UserId
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("Model") then
			local ownerAttr = inst:GetAttribute("OwnerId")
			if ownerAttr and tonumber(ownerAttr) == uid then
				return inst
			end
		end
	end
	return nil
end

local function safeWaitPath(root: Instance, path: {string}): Instance?
	local cur: Instance? = root
	for _, name in ipairs(path) do
		if not cur then return nil end
		cur = cur:FindFirstChild(name) or (cur :: Instance):WaitForChild(name, 2)
		if not cur then return nil end
	end
	return cur
end

-- returns a dictionary of requested attributes from the monster
local function readMonsterStats(monster: Model?, statNames: {string}): {[string]: number}
	local out = {}
	for _, name in ipairs(statNames) do
		out[name] = 0
	end
	if not monster then return out end
	for _, name in ipairs(statNames) do
		local v = monster:GetAttribute(name)
		if typeof(v) == "number" then
			out[name] = v
		elseif typeof(v) == "string" or typeof(v) == "boolean" then
			local n = tonumber(v)
			if n then out[name] = n end
		end
	end
	return out
end

-- ========== Attribute Handlers Registry ==========
-- Add more handlers keyed by attribute name to reuse this system for other UIs.
-- Each handler receives (model: Model, sourcePrompt: ProximityPrompt?)

local AttributeHandlers: {[string]: (Model, ProximityPrompt?) -> ()} = {}

-- ---- TrainingUI Handler ----
AttributeHandlers["TrainingUI"] = function(model: Model, _prompt: ProximityPrompt?)
	-- Ensure the UI exists in PlayerGui; if it's stored in ReplicatedStorage, clone it once.
	local ui = PLAYER_GUI:FindFirstChild("TrainingUI")
	if not ui then
		local rsUI = RS:FindFirstChild("TrainingUI")
		if rsUI and rsUI:IsA("ScreenGui") then
			ui = rsUI:Clone()
			ui.Parent = PLAYER_GUI
		end
	end
	if not ui or not ui:IsA("ScreenGui") then
		warn("[UIOpen] TrainingUI not found in PlayerGui or ReplicatedStorage.")
		return
	end

	-- Find player's monster and read stats
	local monster = getPlayerMonster(LOCAL_PLAYER)
	local stats = readMonsterStats(monster, {"Strength","Defense","Skill","Speed","Intelligence","Luck"})

	-- Fill labels:
	-- TrainingUI > FrameMain > StatsDisplay > <StatName> > Value (TextLabel)
	local statsDisplay = safeWaitPath(ui, {"FrameMain","StatsDisplay"})
	if not statsDisplay then
		warn("[UIOpen] StatsDisplay not found under TrainingUI.FrameMain. Check your hierarchy.")
	else
		for statName, value in pairs(stats) do
			local statFrame = statsDisplay:FindFirstChild(statName)
			if statFrame and statFrame:IsA("Frame") then
				local valueLabel = statFrame:FindFirstChild("Value")
				if valueLabel and valueLabel:IsA("TextLabel") then
					valueLabel.Text = tostring(value)
				end
			else
				-- Allow TextButton or other container types too
				local anyContainer = statsDisplay:FindFirstChild(statName)
				if anyContainer then
					local valueLabel = anyContainer:FindFirstChild("Value")
					if valueLabel and valueLabel:IsA("TextLabel") then
						valueLabel.Text = tostring(value)
					end
				end
			end
		end
	end

	-- Show the UI
	if ui:IsA("ScreenGui") then
		ui.Enabled = true
	end
end

-- ========== Wiring prompts on tagged models ==========

-- For each model tagged "UIOpen", connect its ProximityPrompt (if any)
local function attachToModel(model: Instance)
	if not model or not model:IsA("Model") then return end

	-- If the model has no relevant attribute for our registry, skip
	local hasKnownAttribute = false
	for attrName, _ in pairs(AttributeHandlers) do
		if model:GetAttribute(attrName) ~= nil then
			hasKnownAttribute = true
			break
		end
	end
	if not hasKnownAttribute then
		-- You can still tag and later add the attribute at runtime; we’ll listen for attribute changes below.
	end

	-- Find or wait for a ProximityPrompt within the model
	local prompt = findDescendantOfClass(model, "ProximityPrompt") :: ProximityPrompt?
	if not prompt then
		-- Optional: listen for prompts added later
		model.DescendantAdded:Connect(function(desc)
			if desc:IsA("ProximityPrompt") then
				attachToModel(model) -- re-run to hook it up
			end
		end)
		return
	end

	-- Make sure we don’t double-connect
	if prompt:GetAttribute("UIOpenBound") then return end
	prompt:SetAttribute("UIOpenBound", true)

	prompt.Triggered:Connect(function(player: Player)
		if player ~= LOCAL_PLAYER then return end

		-- Pick which attribute handler to run; priority if multiple attributes exist
		for attrName, handler in pairs(AttributeHandlers) do
			local attrVal = model:GetAttribute(attrName)
			-- Accept truthy bool, “true” string, or any non-nil to indicate the UI type
			if attrVal ~= nil and attrVal ~= false and tostring(attrVal) ~= "false" then
				handler(model, prompt)
				break
			end
		end
	end)
end

-- Listen for new tagged instances
for _, inst in ipairs(CollectionService:GetTagged("UIOpen")) do
	attachToModel(inst)
end

CollectionService:GetInstanceAddedSignal("UIOpen"):Connect(function(inst: Instance)
	attachToModel(inst)
end)

-- If attributes are added later to already-tagged models, we still use the same ProximityPrompt hook.
-- The Triggered connection above checks attributes at trigger time, so late attributes work automatically.
