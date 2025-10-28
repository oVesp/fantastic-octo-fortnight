-- ServerScriptService/Main/QueueService
-- Bridges queue remotes and proximity prompts to the unified QueueManager.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueueManager = require(script.Parent.QueueManager)
local QueueDefinitions = require(ReplicatedStorage.Modules.QueueDefinitions)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local module = {}

local initialized = false
local connections = {}
local promptConnections = {}

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

local JoinQueueRemote = ensureRemote("JoinQueue")
local LeaveQueueRemote = ensureRemote("LeaveQueue")
local QueueStatusUpdate = ensureRemote("QueueStatusUpdate")

local function handleJoin(player, queueId)
	if typeof(queueId) ~= "string" then
		return
	end

	local success, message = QueueManager.Join(player, queueId)
	if not success then
		QueueStatusUpdate:FireClient(player, {
			status = "Failed",
			queueName = queueId,
			message = message or "Unable to join queue.",
		})
	end
end

local function handleLeave(player)
	local success = QueueManager.Leave(player)
	if not success then
		QueueStatusUpdate:FireClient(player, { status = "None" })
	end
end

local function disconnectPrompt(prompt)
	local entry = promptConnections[prompt]
	if not entry then
		return
	end

	if entry.trigger then
		entry.trigger:Disconnect()
	end
	if entry.ancestry then
		entry.ancestry:Disconnect()
	end

	promptConnections[prompt] = nil
end

local function connectPrompt(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end

	local queueId = prompt:GetAttribute("QueueId")
	if not queueId then
		local foundId = QueueDefinitions.FindByPromptName(prompt.Name)
		if foundId then
			queueId = foundId
			prompt:SetAttribute("QueueId", queueId)
		end
	end

	if not queueId then
		return
	end

	if not QueueManager.HasQueue(queueId) then
		warn(('[QueueService] Prompt "%s" references unknown queue "%s".'):format(prompt:GetFullName(), queueId))
		return
	end

	local definition = QueueDefinitions.Get(queueId)
	if definition then
		if definition.promptActionText and prompt.ActionText ~= definition.promptActionText then
			prompt.ActionText = definition.promptActionText
		end
		if definition.promptObjectText and prompt.ObjectText ~= definition.promptObjectText then
			prompt.ObjectText = definition.promptObjectText
		end
	end

	disconnectPrompt(prompt)

	local triggerConnection = prompt.Triggered:Connect(function(player)
		handleJoin(player, queueId)
	end)

	local ancestryConnection = prompt.AncestryChanged:Connect(function(_, parent)
		if not parent then
			disconnectPrompt(prompt)
		end
	end)

	promptConnections[prompt] = {
		queueId = queueId,
		trigger = triggerConnection,
		ancestry = ancestryConnection,
	}
end

local function bootstrapNamedPrompts()
	QueueDefinitions.ForEach(function(queueId, definition)
		if not definition.promptName then
			return
		end
		local prompt = workspace:FindFirstChild(definition.promptName, true)
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt:SetAttribute("QueueId", queueId)
			connectPrompt(prompt)
		end
	end)
end

local function bootstrapExistingPrompts()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		connectPrompt(descendant)
	end

	connections.promptListener = workspace.DescendantAdded:Connect(connectPrompt)
end

function module.RegisterPrompt(prompt, queueId)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end

	if queueId then
		prompt:SetAttribute("QueueId", queueId)
	end

	connectPrompt(prompt)
end

function module.Init()
	if initialized then
		return true
	end
	initialized = true

	connections.join = JoinQueueRemote.OnServerEvent:Connect(handleJoin)
	connections.leave = LeaveQueueRemote.OnServerEvent:Connect(function(player)
		handleLeave(player)
	end)

	connections.playerRemoving = Players.PlayerRemoving:Connect(function(player)
		QueueManager.Leave(player)
	end)

	bootstrapNamedPrompts()
	bootstrapExistingPrompts()

	return true
end

return module
