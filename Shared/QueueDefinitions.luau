-- Shared queue definitions accessible on both client and server.
-- Keep this data lightweight: it is required by UI scripts and server systems.

local queueDefinitions = {
	Main_Arena_8 = {
		order = 1,
		displayName = "Main Arena",
		description = "Free-for-all skirmish for up to eight tamers.",
		mode = "FFA",
		minPlayers = 2,
		maxPlayers = 8,
		countdown = 8,
		fillWithBotsAfterSeconds = 10,
		uiButtonName = "JoinMainArena",
		promptName = "MainArenaPrompt",
		promptActionText = "Join Main Arena",
		promptObjectText = "Main Arena",
	},
	Small_Arena_4 = {
		order = 2,
		displayName = "Tactical Teams",
		description = "Quick 2v2 battles inside the small arena.",
		mode = "2v2",
		minPlayers = 2,
		maxPlayers = 4,
		countdown = 6,
		fillWithBotsAfterSeconds = 8,
		uiButtonName = "Join2v2",
		promptName = "SmallArenaPrompt",
		promptActionText = "Join 2v2",
		promptObjectText = "Small Arena",
	},
	Duel_1v1 = {
		order = 3,
		displayName = "Duel Pit",
		description = "Head-to-head duel with no backup.",
		mode = "DUEL",
		minPlayers = 2,
		maxPlayers = 2,
		countdown = 4,
		fillWithBotsAfterSeconds = 6,
		uiButtonName = "JoinDuel",
		promptName = "DuelPrompt",
		promptActionText = "Join Duel",
		promptObjectText = "Duel Pit",
	},
}

local orderedIds = {}
for queueId in pairs(queueDefinitions) do
	table.insert(orderedIds, queueId)
end

table.sort(orderedIds, function(a, b)
	local defA = queueDefinitions[a]
	local defB = queueDefinitions[b]
	local orderA = defA and defA.order or math.huge
	local orderB = defB and defB.order or math.huge
	if orderA == orderB then
		return a < b
	end
	return orderA < orderB
end)

local function shallowCopy(source)
	local result = {}
	for key, value in pairs(source) do
		result[key] = value
	end
	return result
end

local module = {}

function module.Get(queueId)
	return queueDefinitions[queueId]
end

function module.GetAll()
	local list = {}
	for _, queueId in ipairs(orderedIds) do
		local def = queueDefinitions[queueId]
		if def then
			local copy = shallowCopy(def)
			copy.id = queueId
			table.insert(list, copy)
		end
	end
	return list
end

function module.ForEach(callback)
	for _, queueId in ipairs(orderedIds) do
		local def = queueDefinitions[queueId]
		if def then
			callback(queueId, def)
		end
	end
end

function module.FindByButtonName(buttonName)
	if not buttonName then
		return nil
	end
	for queueId, def in pairs(queueDefinitions) do
		if def.uiButtonName == buttonName then
			return queueId, def
		end
	end
	return nil
end

function module.FindByPromptName(promptName)
	if not promptName then
		return nil
	end
	for queueId, def in pairs(queueDefinitions) do
		if def.promptName == promptName then
			return queueId, def
		end
	end
	return nil
end

function module.GetOrderedIds()
	return orderedIds
end

return module
