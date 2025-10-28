-- StarterPlayerScripts/UIOpenClient.luau
-- Opens UIs from models tagged "UIOpen" only if the local player is the owner (BaseOwnerId).
-- Reusable via AttributeHandlers for different UI attributes; includes TrainingUI handler.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local LOCAL_PLAYER = Players.LocalPlayer
local PLAYER_GUI = LOCAL_PLAYER:WaitForChild("PlayerGui")

-- ========== Helpers ==========

local function findDescendantOfClass(inst: Instance, className: string): Instance?
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA(className) then return d end
	end
	return nil
end

local function findOwnerModelAndId(inst: Instance, attrName: string): (Model?, string?)
	-- Walk up a few generations to find a Model with BaseOwnerId
	local cur = inst
	for _ = 1, 8 do
		if not cur then break end
		if cur:IsA("Model") then
			local v = cur:GetAttribute(attrName)
			if v ~= nil then
				return cur, tostring(v)
			end
		end
		cur = cur.Parent
	end
	return nil, nil
end

local function getPlayerMonster(player: Player): Model?
	local uid = player.UserId
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("Model") and tonumber(inst:GetAttribute("OwnerId") or 0) == uid then
			return inst
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

local function readMonsterStats(monster: Model?, statNames: {string}): {[string]: number}
	local out = {}
	for _, name in ipairs(statNames) do out[name] = 0 end
	if not monster then return out end
	for _, name in ipairs(statNames) do
		local v = monster:GetAttribute(name)
		if typeof(v) == "number" then
			out[name] = v
		else
			local n = tonumber(v)
			if n then out[name] = n end
		end
	end
	return out
end

-- ========== Attribute Handlers ==========

local AttributeHandlers: {[string]: (Model, ProximityPrompt?) -> ()} = {}

AttributeHandlers["TrainingUI"] = function(model: Model, _prompt: ProximityPrompt?)
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

	local monster = getPlayerMonster(Players.LocalPlayer)
	local stats = readMonsterStats(monster, {"Strength","Defense","Skill","Speed","Intelligence","Luck"})

	local statsDisplay = safeWaitPath(ui, {"FrameMain","StatsDisplay"})
	if not statsDisplay then
		warn("[UIOpen] StatsDisplay not found under TrainingUI.FrameMain.")
	else
		for statName, value in pairs(stats) do
			local node = statsDisplay:FindFirstChild(statName)
			if node then
				local valueLabel = node:FindFirstChild("Value")
				if valueLabel and valueLabel:IsA("TextLabel") then
					valueLabel.Text = tostring(value)
				end
			end
		end
	end

	ui.Enabled = true
end

-- ========== Wiring prompts on tagged models (with ownership gate) ==========

local function attachToModel(taggedModel: Instance)
	if not taggedModel or not taggedModel:IsA("Model") then return end

	-- (Re)use the first ProximityPrompt under the tagged model
	local prompt = findDescendantOfClass(taggedModel, "ProximityPrompt") :: ProximityPrompt?
	if not prompt then
		taggedModel.DescendantAdded:Connect(function(d)
			if d:IsA("ProximityPrompt") then attachToModel(taggedModel) end
		end)
		return
	end
	if prompt:GetAttribute("UIOpenBound") then return end
	prompt:SetAttribute("UIOpenBound", true)

	prompt.Triggered:Connect(function(player: Player)
		-- Ownership check: walk up from the prompt (or tagged model) to find BaseOwnerId
		local _, baseOwnerId = findOwnerModelAndId(prompt, "BaseOwnerId")
		if not baseOwnerId then
			-- fallback: try from tagged model
			_, baseOwnerId = findOwnerModelAndId(taggedModel, "BaseOwnerId")
		end
		if not baseOwnerId then
			-- If your design guarantees presence, just bail out
			return
		end

		if tostring(player.UserId) ~= tostring(baseOwnerId) then
			-- Not the owner -> do not open
			return
		end

		-- Find which UI attribute to handle (e.g., TrainingUI)
		for attrName, handler in pairs(AttributeHandlers) do
			local val = taggedModel:GetAttribute(attrName)
			if val ~= nil and val ~= false and tostring(val) ~= "false" then
				handler(taggedModel, prompt)
				break
			end
		end
	end)
end

for _, inst in ipairs(CollectionService:GetTagged("UIOpen")) do
	attachToModel(inst)
end

CollectionService:GetInstanceAddedSignal("UIOpen"):Connect(function(inst: Instance)
	attachToModel(inst)
end)
