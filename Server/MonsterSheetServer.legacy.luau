-- Server: MonsterDataHandler
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Create RemoteEvents
local GetMonsterDataEvent = Instance.new("RemoteEvent")
GetMonsterDataEvent.Name = "GetMonsterData"
GetMonsterDataEvent.Parent = ReplicatedStorage

-- Handle data requests
GetMonsterDataEvent.OnServerEvent:Connect(function(player)
	local Data = require(game.ServerScriptService.Main.Data)
	local MovesModule = require(ReplicatedStorage.Modules.Moves)

	local success, monsterData = pcall(function()
		return Data:Get(player).Monster
	end)

	if success and monsterData then
		print("🔍 [SERVER] Processing monster data for:", player.Name)

		-- Convert proxy data to a simple table for client
		local dataTable = {}

		-- Direct property access
		dataTable.id = monsterData.id
		dataTable.Name = monsterData.Name
		dataTable.Race = monsterData.Race
		dataTable.Stage = monsterData.Stage
		dataTable.Level = monsterData.Level
		dataTable.BaseRaceFamily = monsterData.BaseRaceFamily
		dataTable.Bond = monsterData.Bond
		dataTable.Wins = monsterData.Wins
		dataTable.SessionTime = monsterData.SessionTime
		dataTable.CareMistakes = monsterData.CareMistakes
		dataTable.Personality = monsterData.Personality

		-- Stats - handle both full names and abbreviations
		dataTable.Stats = {}
		if monsterData.Stats then
			dataTable.Stats.Hp = monsterData.Stats.Hp or 100
			dataTable.Stats.Mp = monsterData.Stats.Mp or 100
			dataTable.Stats.Strength = monsterData.Stats.Strength or monsterData.Stats.STR or 10
			dataTable.Stats.Defense = monsterData.Stats.Defense or monsterData.Stats.DEF or 10
			dataTable.Stats.Skill = monsterData.Stats.Skill or monsterData.Stats.SKL or 10
			dataTable.Stats.Speed = monsterData.Stats.Speed or monsterData.Stats.SPD or 10
			dataTable.Stats.Intelligence = monsterData.Stats.Intelligence or monsterData.Stats.INT or 10
			dataTable.Stats.Luck = monsterData.Stats.Luck or monsterData.Stats.LCK or 10
		else
			-- Default stats if none exist
			dataTable.Stats = {
				Hp = 100, Mp = 100,
				Strength = 10, Defense = 10, Skill = 10,
				Speed = 10, Intelligence = 10, Luck = 10
			}
		end

		-- DEBUG: Print monster data structure
		print("🔍 [SERVER] Monster Moves raw data:", monsterData.Moves)
		print("🔍 [SERVER] Monster Moves raw data:", monsterData.Moves)

		-- Process moves - FIXED: Handle empty tables and get starter moves if needed
		dataTable.Moves = {}

		-- Check if we need to get starter moves
		local hasRealMoves = false
		if monsterData.Moves then
			print("🔍 [SERVER] Moves table exists, type:", type(monsterData.Moves))
			--print("🔍 [SERVER] Moves count:", #monsterData.Moves)

			-- Check if any move entry has actual data
			for i, moveEntry in (monsterData.Moves) do
				if moveEntry and (moveEntry.id or moveEntry.move or (type(moveEntry) == "string" and moveEntry ~= "")) then
					hasRealMoves = true
					break
				end
			end

			if hasRealMoves then
				-- Process actual moves
				for i, moveEntry in pairs(monsterData.Moves) do
					print("🔍 [SERVER] Processing move entry", i, ":", moveEntry)

					if moveEntry and (moveEntry.id or moveEntry.move or (type(moveEntry) == "string" and moveEntry ~= "")) then
						-- Check if moveEntry already has the move data directly
						if moveEntry.id then
							-- This is already a move object
							print("🔍 [SERVER] Move entry has direct move data:", moveEntry.name)
							dataTable.Moves[i] = {
								move = moveEntry,
								equipped = true
							}
						elseif moveEntry.move then
							-- This has a nested move object
							print("🔍 [SERVER] Move entry has nested move data:", moveEntry.move.name)
							dataTable.Moves[i] = {
								move = moveEntry.move,
								equipped = true
							}
						else
							-- Try to get move data by ID if it's just a string
							local moveId = moveEntry
							if type(moveEntry) == "string" then
								moveId = moveEntry
							elseif moveEntry.id then
								moveId = moveEntry.id
							end

							if moveId and moveId ~= "" then
								local fullMoveData = MovesModule:GetMove(nil, moveId)
								if fullMoveData then
									print("🔍 [SERVER] Found move data for ID:", moveId)
									dataTable.Moves[i] = {
										move = fullMoveData,
										equipped = true
									}
								else
									print("🔍 [SERVER] Could not find move data for ID:", moveId)
									-- Create basic move data as fallback
									dataTable.Moves[i] = {
										move = {
											id = moveId,
											name = moveId,
											rarity = "Common",
											power = 10,
											cooldown = 1.0,
											minRange = 1,
											maxRange = 3,
											tags = {"Universal"}
										},
										equipped = true
									}
								end
							end
						end
					else
						print("🔍 [SERVER] Move entry", i, "is empty, skipping")
					end
				end
			end
		end

		-- If no real moves found, get starter moves for the race
		if not hasRealMoves or #dataTable.Moves == 0 then
			print("🔍 [SERVER] No real moves found, getting starter moves for race:", monsterData.Race)
			local starterMoves = MovesModule:getStarterMoves(monsterData.Race)
			print("🔍 [SERVER] Starter moves count:", #starterMoves)

			for i, moveData in ipairs(starterMoves) do
				if moveData and moveData.move then
					dataTable.Moves[i] = {
						move = moveData.move,
						equipped = true
					}
					print("🔍 [SERVER] Added starter move:", moveData.move.name)
				end
			end
		end

		-- Process learned moves - FIXED: Handle empty tables
		dataTable.Moves = {}
		if monsterData.Moves then
			print("🔍 [SERVER] Moves table exists, count:", #monsterData.Moves)

			for i, moveEntry in (monsterData.Moves) do
				if moveEntry and (moveEntry.id or moveEntry.move or (type(moveEntry) == "string" and moveEntry ~= "")) then
					-- Check if moveEntry already has the move data directly
					if moveEntry.id then
						-- This is already a move object
						dataTable.Moves[i] = {
							move = moveEntry,
							equipped = false
						}
					elseif moveEntry.move then
						-- This has a nested move object
						dataTable.Moves[i] = {
							move = moveEntry.move,
							equipped = false
						}
					else
						-- Try to get move data by ID
						local moveId = moveEntry
						if type(moveEntry) == "string" then
							moveId = moveEntry
						end

						if moveId and moveId ~= "" then
							local fullMoveData = MovesModule:GetMove(nil, moveId)
							if fullMoveData then
								dataTable.Moves[i] = {
									move = fullMoveData,
									equipped = false
								}
							else
								-- Create basic move data as fallback
								dataTable.Moves[i] = {
									move = {
										id = moveId,
										name = moveId,
										rarity = "Common",
										power = 10,
										cooldown = 1.0,
										minRange = 1,
										maxRange = 3,
										tags = {"Universal"}
									},
									equipped = false
								}
							end
						end
					end
				else
					print("🔍 [SERVER] Learned move entry", i, "is empty, skipping")
				end
			end
		else
			print("🔍 [SERVER] monsterData.Moves is nil")
		end

		-- DEBUG: Print what we're sending to client
		print("🔍 [SERVER] Sending to client - Moves count:", #dataTable.Moves)
		print("🔍 [SERVER] Sending to client - Moves count:", #dataTable.Moves)

		for i, move in ipairs(dataTable.Moves) do
			print("🔍 [SERVER] Sending move", i, ":", move.move.name)
		end

		GetMonsterDataEvent:FireClient(player, dataTable)
	else
		print("❌ [SERVER] Failed to get monster data for:", player.Name)
		GetMonsterDataEvent:FireClient(player, nil)
	end
end)

local UpdateMonsterSheetEvent = ReplicatedStorage:FindFirstChild("UpdateMonsterSheetEvent")
if not UpdateMonsterSheetEvent then
	UpdateMonsterSheetEvent = Instance.new("RemoteEvent")
	UpdateMonsterSheetEvent.Name = "UpdateMonsterSheetEvent"
	UpdateMonsterSheetEvent.Parent = ReplicatedStorage
end

-- Function to notify all clients about monster data changes
local function notifyMonsterDataUpdate(player)
	-- Small delay to ensure data is saved
	wait(0.1)
	UpdateMonsterSheetEvent:FireClient(player)
	print("🔔 [SERVER] Notified client about monster data update:", player.Name)
end