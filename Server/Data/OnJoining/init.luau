local queue_functions = require(script:WaitForChild('QueueFunctions'));

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Moves = require(ReplicatedStorage.Modules.Moves)
local Leveling = require(ReplicatedStorage.Modules.Leveling)

local CURRENT_UPDATE = 1

local STAT_ALIAS_MAP = {
        Hp = {"HP"},
        Mp = {"MP"},
        Strength = {"STR"},
        Defense = {"DEF"},
        Skill = {"SKL"},
        Speed = {"SPD"},
        Intelligence = {"INT"},
        Luck = {"LCK"},
}

local function deepCopy(value)
        if typeof(value) ~= "table" then
                return value
        end

        local copy = {}
        for key, entry in pairs(value) do
                copy[key] = deepCopy(entry)
        end
        return copy
end

local function normalizeMoveEntry(entry)
        if typeof(entry) == "table" then
                local moveId = entry.id or entry.Id or (entry.move and (entry.move.id or entry.move.Id))
                if typeof(moveId) ~= "string" or moveId == "" then
                        return nil, true
                end

                local rarity = entry.rarity
                if rarity == nil then
                        local def = Moves:GetMove(nil, moveId)
                        rarity = (def and def.rarity) or "Amateur"
                end

                local needsCopy = entry.id ~= moveId or entry.Id ~= moveId or entry.rarity ~= rarity
                if typeof(entry.move) == "table" then
                        local moveTable = entry.move
                        if moveTable.id ~= moveId or moveTable.Id ~= moveId then
                                needsCopy = true
                        end
                end

                if not needsCopy then
                        return entry, false
                end

                local copy = deepCopy(entry)
                copy.id = moveId
                copy.Id = moveId
                copy.rarity = rarity
                if typeof(copy.move) == "table" then
                        copy.move.id = moveId
                        copy.move.Id = moveId
                end

                return copy, true
        elseif typeof(entry) == "string" then
                if entry == "" then
                        return nil, true
                end

                local def = Moves:GetMove(nil, entry)
                return {
                        id = entry,
                        Id = entry,
                        rarity = (def and def.rarity) or "Amateur",
                }, true
        end

        return nil, true
end

local function setStat(stats, key, value)
        local mutated = false
        if stats[key] ~= value then
                        stats[key] = value
                        mutated = true
        end

        local aliases = STAT_ALIAS_MAP[key]
        if aliases then
                for _, alias in ipairs(aliases) do
                        if stats[alias] ~= value then
                                stats[alias] = value
                                mutated = true
                        end
                end
        end

        return mutated
end

local function ensureStats(monsterData)
        local mutated = false
        local stats = monsterData.Stats
        if typeof(stats) ~= "table" then
                stats = {}
                monsterData.Stats = stats
                mutated = true
        end

        local hasNumeric = false
        for _, value in pairs(stats) do
                if typeof(value) == "number" then
                        hasNumeric = true
                        break
                end
        end

        if not hasNumeric then
                local baseline = monsterData.LevelingBaseStats
                if typeof(baseline) == "table" then
                        local level = tonumber(monsterData.Level) or tonumber(monsterData.GeneratedWithLevel) or 1
                        local multiplier = Leveling.GetStatMultiplier(level)
                        for key, baseValue in pairs(baseline) do
                                if typeof(baseValue) == "number" then
                                        local scaled = math.max(1, math.floor(baseValue * multiplier))
                                        if setStat(stats, key, scaled) then
                                                mutated = true
                                        end
                                end
                        end
                end
        end

        for key, aliases in pairs(STAT_ALIAS_MAP) do
                local primary = stats[key]
                if typeof(primary) == "number" then
                        if setStat(stats, key, primary) then
                                mutated = true
                        end
                else
                        for _, alias in ipairs(aliases) do
                                local aliasValue = stats[alias]
                                if typeof(aliasValue) == "number" then
                                        if setStat(stats, key, aliasValue) then
                                                mutated = true
                                        end
                                        break
                                end
                        end
                end
        end

        return mutated
end

local function normalizeMonster(monsterData, ownerId)
        if typeof(monsterData) ~= "table" then
                return false
        end

        local mutated = false

        local existingId = monsterData.id or monsterData.Id
        if typeof(existingId) == "string" and existingId ~= "" then
                if monsterData.id ~= existingId then
                        monsterData.id = existingId
                        mutated = true
                end
                if monsterData.Id ~= existingId then
                        monsterData.Id = existingId
                        mutated = true
                end
        else
                local newId = HttpService:GenerateGUID(false)
                monsterData.id = newId
                monsterData.Id = newId
                mutated = true
        end

        if ownerId and monsterData.OwnerId ~= ownerId then
                monsterData.OwnerId = ownerId
                mutated = true
        end

        local level = tonumber(monsterData.Level) or tonumber(monsterData.GeneratedWithLevel) or 1
        if monsterData.Level ~= level then
                monsterData.Level = level
                mutated = true
        end

        if monsterData.GeneratedWithLevel == nil then
                monsterData.GeneratedWithLevel = level
                mutated = true
        end

        if typeof(monsterData.Experience) ~= "number" then
                monsterData.Experience = Leveling.GetExperienceForLevel(level)
                mutated = true
        end

        local movesTable = monsterData.Moves
        if typeof(movesTable) ~= "table" then
                movesTable = {}
                monsterData.Moves = movesTable
                mutated = true
        end

        local normalizedMoves = {}
        local movesMutated = false
        for _, entry in ipairs(movesTable) do
                local normalized, changed = normalizeMoveEntry(entry)
                if normalized then
                        table.insert(normalizedMoves, normalized)
                        if changed or normalized ~= entry then
                                movesMutated = true
                        end
                else
                        movesMutated = true
                end
        end

        if #normalizedMoves ~= #movesTable then
                movesMutated = true
        end

        if movesMutated then
                monsterData.Moves = normalizedMoves
                mutated = true
        end

        if ensureStats(monsterData) then
                mutated = true
        end

        return mutated
end

local module = {

        --function(plr, data) -- initial values
        --      if not data.Value.NewPlayer then return end

        --      data.Value.NewPlayer = false;
        --end,

        function(plr, data)

                local monsterData = data.Value.Monster
                if typeof(monsterData) == "table" then
                        local mutated = normalizeMonster(monsterData, plr.UserId)

                        data.Value.Monster = monsterData
                        data.Value.Level = monsterData.Level or data.Value.Level or 1
                        data.Value.Experience = monsterData.Experience or data.Value.Experience or 0
                        data.Value.NewPlayer = false

                        if mutated then
                                local saveResult = data:Save()
                                if saveResult ~= "Saved" then
                                        warn("[Data.OnJoining] Failed to persist normalized monster for", plr, saveResult)
                                end
                        end

                        local existingId = monsterData.id or monsterData.Id
                        if typeof(existingId) == "string" and existingId ~= "" then
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

                local normalizedMonster = deepCopy(monster)
                normalizeMonster(normalizedMonster, plr.UserId)

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
