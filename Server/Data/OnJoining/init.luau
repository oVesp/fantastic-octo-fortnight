local HttpService = game:GetService("HttpService")

local queue_functions = require(script:WaitForChild('QueueFunctions'));

local CURRENT_UPDATE = 1

local module = {

	--function(plr, data) -- initial values
	--	if not data.Value.NewPlayer then return end

	--	data.Value.NewPlayer = false;
	--end,

        function(plr, data)

                local monsterData = data.Value.Monster
                if typeof(monsterData) == "table" then
                        local existingId = monsterData.id or monsterData.Id
                        if typeof(existingId) == "string" and existingId ~= "" then
                                monsterData.id = existingId
                                monsterData.Id = existingId
                                return
                        end
                end

                local generator = _G and _G.MONSTERGENERATOR
                if not generator or typeof(generator.RollMonster) ~= "function" then
                        warn("[Data.OnJoining] MonsterGenerator not ready; deferring monster bootstrap for", plr)
                        task.delay(1, module[1], plr, data)
                        return
                end

                local monster = generator.RollMonster(plr.UserId)
                if typeof(monster) ~= "table" then
                        warn("[Data.OnJoining] Failed to roll monster for", plr)
                        return
                end

                local function deepCopy(tbl)
                        local copy = {}
                        for key, value in pairs(tbl) do
                                if typeof(value) == "table" then
                                        copy[key] = deepCopy(value)
                                else
                                        copy[key] = value
                                end
                        end
                        return copy
                end

                local function normalizeMove(entry)
                        if typeof(entry) == "table" then
                                local copy = deepCopy(entry)
                                local moveId = copy.id or copy.Id or (copy.move and (copy.move.id or copy.move.Id))
                                if typeof(moveId) == "string" and moveId ~= "" then
                                        copy.id = moveId
                                        copy.Id = moveId
                                        if typeof(copy.move) == "table" then
                                                copy.move.id = moveId
                                                copy.move.Id = moveId
                                        end
                                        return copy
                                end
                                return nil
                        elseif typeof(entry) == "string" then
                                if entry ~= "" then
                                        return { id = entry, Id = entry }
                                end
                        end

                        return nil
                end

                local normalizedMonster = deepCopy(monster)
                normalizedMonster.id = normalizedMonster.id or normalizedMonster.Id or HttpService:GenerateGUID(false)
                normalizedMonster.Id = normalizedMonster.id
                normalizedMonster.OwnerId = normalizedMonster.OwnerId or plr.UserId
                normalizedMonster.GeneratedWithLevel = normalizedMonster.GeneratedWithLevel or normalizedMonster.Level
                normalizedMonster.Stats = deepCopy(monster.Stats or {})

                local moves = {}
                for _, entry in ipairs(monster.Moves or {}) do
                        local normalized = normalizeMove(entry)
                        if normalized then
                                table.insert(moves, normalized)
                        end
                end
                normalizedMonster.Moves = moves

                data.Value.Monster = normalizedMonster
                data.Value.Level = normalizedMonster.Level or data.Value.Level or 1
                data.Value.Experience = normalizedMonster.Experience or data.Value.Experience or 0
                data.Value.NewPlayer = false

                local saveResult = data:Save()
                if saveResult ~= "Saved" then
                        warn("[Data.OnJoining] Failed to persist starter monster for", plr, saveResult)
                end

        end,

	function(plr, data) -- update versioning: game version is now up-to-date
		local last_played = data.Value.LastUpdatePlayed;

		if last_played and tonumber(last_played) >= CURRENT_UPDATE then return end



		data.Value.LastUpdatePlayed = tostring(CURRENT_UPDATE)
	end,

	function(plr, data) -- data versioning: data is now up-to-date
		while not _G.DATA do task.wait(1) end

		data.Value.Version = _G.DATA.Template.Version
	end,

	function(plr, data) -- process_queue
		data.ProcessQueue:Connect(function(id, values_array) data:Remove(id)
			for _, pack in ipairs(values_array) do
				if not queue_functions[pack.key] then continue end

				for k, v in pairs(pack) do
					print(k, v)
				end

				queue_functions[pack.key](plr, pack.info)
			end
		end);
	end,
}

return module
