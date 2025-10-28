-- LocalScripts/QueueClient.local.luau
-- Wires queue UI buttons and status text to the queue remotes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueueDefinitions = require(ReplicatedStorage.Modules.QueueDefinitions)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local JoinQueueRemote = Remotes:WaitForChild("JoinQueue")
local LeaveQueueRemote = Remotes:WaitForChild("LeaveQueue")
local QueueStatusUpdate = Remotes:WaitForChild("QueueStatusUpdate")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local queueUi = playerGui:WaitForChild("QueueUI", 5)
if not queueUi then
	warn("[QueueClient] QueueUI ScreenGui not found; aborting queue bindings.")
	return
end

local function findFirstDescendant(parent, className)
	for _, descendant in ipairs(parent:GetDescendants()) do
		if descendant:IsA(className) then
			return descendant
		end
	end
	return nil
end

local listContainer = queueUi:FindFirstChild("ScrollingFrame", true)
if not listContainer then
	listContainer = findFirstDescendant(queueUi, "ScrollingFrame")
end

if not listContainer then
	warn("[QueueClient] Could not find queue button container (expecting a ScrollingFrame).")
	return
end

local statusLabel = queueUi:FindFirstChild("StatusLabel", true)
if not (statusLabel and statusLabel:IsA("TextLabel")) then
	statusLabel = nil
end

local buttonsByQueue = {}
local currentQueueId = nil

local function setStatus(text)
	if statusLabel then
		statusLabel.Text = text
	else
		print("[QueueClient]", text)
	end
end

local function findQueueButton(queueId, definition)
	local candidates = {}
	if definition and definition.uiButtonName then
		table.insert(candidates, definition.uiButtonName)
	end
	table.insert(candidates, queueId)

	for _, name in ipairs(candidates) do
		local button = queueUi:FindFirstChild(name, true)
		if button and button:IsA("TextButton") then
			return button
		end
	end

	for _, descendant in ipairs(listContainer:GetDescendants()) do
		if descendant:IsA("TextButton") then
			local attr = descendant:GetAttribute("QueueId")
			if attr == queueId then
				return descendant
			end
		end
	end

	return nil
end

local function updateButtonStates()
	for queueId, button in pairs(buttonsByQueue) do
		if button.Parent then
			local isQueued = currentQueueId == queueId
			button:SetAttribute("QueueQueued", isQueued)
		else
			buttonsByQueue[queueId] = nil
		end
	end
end

local function connectQueueButton(queueId, definition)
	local button = findQueueButton(queueId, definition)
	if not button then
		warn(('[QueueClient] Could not find button for queue "%s".'):format(queueId))
		return
	end

	button:SetAttribute("QueueId", queueId)

	if buttonsByQueue[queueId] then
		return
	end

	button.Activated:Connect(function()
		JoinQueueRemote:FireServer(queueId)
	end)

	buttonsByQueue[queueId] = button
end

QueueDefinitions.ForEach(function(queueId, definition)
	connectQueueButton(queueId, definition)
end)

local function findLeaveButton()
	for _, descendant in ipairs(queueUi:GetDescendants()) do
		if descendant:IsA("TextButton") then
			if descendant.Name == "LeaveQueue" or descendant:GetAttribute("QueueAction") == "Leave" then
				return descendant
			end
		end
	end
	return nil
end

local leaveButton = findLeaveButton()
if leaveButton then
	leaveButton.Activated:Connect(function()
		LeaveQueueRemote:FireServer()
	end)
end

setStatus("Select an arena to queue.")

QueueStatusUpdate.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local status = payload.status
	local queueId = payload.queueName

	if status == "InQueue" then
		currentQueueId = queueId
		local definition = queueId and QueueDefinitions.Get(queueId)
		local displayName = definition and definition.displayName or queueId or "Queue"
		local playerCount = payload.playerCount or 0
		local maxPlayers = payload.maxPlayers or 0
		setStatus(('%s: %d/%d tamers in queue.'):format(displayName, playerCount, maxPlayers))
	elseif status == "Countdown" then
		currentQueueId = queueId
		local definition = queueId and QueueDefinitions.Get(queueId)
		local displayName = definition and definition.displayName or queueId or "Queue"
		local timeLeft = payload.timeLeft or 0
		local playerCount = payload.playerCount or 0
		local maxPlayers = payload.maxPlayers or 0
		setStatus(('%s starting in %ds (%d/%d).'):format(displayName, timeLeft, playerCount, maxPlayers))
	elseif status == "Started" then
		setStatus("Match starting!")
	elseif status == "Finished" then
		currentQueueId = nil
		setStatus("Match finished.")
	elseif status == "Cancelled" then
		currentQueueId = nil
		setStatus("Queue cancelled.")
	elseif status == "Failed" then
		local message = payload.message or "Unable to join queue."
		setStatus(message)
	elseif status == "None" then
		currentQueueId = nil
		setStatus("You left the queue.")
	end

	updateButtonStates()
end)

return true
