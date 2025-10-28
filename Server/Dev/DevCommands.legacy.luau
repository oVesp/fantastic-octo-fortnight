-- ServerScriptService/Main/Dev/ArenaCommands.lua
local Chat = game:GetService("Chat")

print("Testttttttt")

Chat:RegisterChatCallback(Enum.ChatCallbackType.OnServerReceivingMessage, function(message, speaker)
	local plr = speaker
	local words = string.split(message, " ")
	if words[1] == "/arena" then
		print("Arena")
		local sub = (words[2] or ""):lower()
		if sub == "new" then
			local mode = words[3] or "1v1"
			_G.ARENA_SERVICE.CreateArena({ TeamMode = mode, Center = plr.Character and plr.Character:GetPivot().Position })
			print("[DEV] /arena new", mode)
		elseif sub == "list" then
			print(_G.ARENA_SERVICE.List())
		elseif sub == "join" then
			-- /arena join <arenaId> [teamIndex]
			local id = words[3]
			local team = tonumber(words[4])
			local ok, msg = _G.ARENA_SERVICE.Enqueue(plr, { arenaId = id, teamIndex = team })
			print("[DEV] join:", ok, msg)
		elseif sub == "start" then
			local id = words[3]
			_G.ARENA_SERVICE.Start(id, { FillNPCs = true })
		elseif sub == "end" then
			local id = words[3]
			_G.ARENA_SERVICE.End(id)
		end
	end
end)
