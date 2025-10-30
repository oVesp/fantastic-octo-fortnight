local module = {}

local function safeGetMonsterEntry(player)
        if not (_G and _G.MONSTERGENERATOR) then
                return nil
        end

        local generator = _G.MONSTERGENERATOR
        local entry

        if typeof(generator.GetPlayerMonsterData) == "function" then
                local ok, result = pcall(generator.GetPlayerMonsterData, player.UserId)
                if ok then
                        entry = result
                end
        end

        return entry
end

local function resolveActiveModel(player, entry)
        if entry and typeof(entry) == "table" then
                local model = entry.Model
                if model and model.Parent then
                        return model
                end
        end

        if _G and _G.MONSTERGENERATOR and typeof(_G.MONSTERGENERATOR.GetPlayerMonster) == "function" then
                local ok, model = pcall(_G.MONSTERGENERATOR.GetPlayerMonster, player)
                if ok and model and model.Parent then
                        return model
                end
        end

        return nil
end

local trackedStats = {
        {attribute = "Hp", keys = {"Hp", "HP"}},
        {attribute = "MP", keys = {"Mp", "MP"}},
        {attribute = "MaxMP", keys = {"MaxMp", "MaxMP"}},
        {attribute = "Strength", keys = {"Strength", "STR"}},
        {attribute = "Defense", keys = {"Defense", "DEF"}},
        {attribute = "Skill", keys = {"Skill", "SKL"}},
        {attribute = "Speed", keys = {"Speed", "SPD"}},
        {attribute = "Intelligence", keys = {"Intelligence", "INT"}},
        {attribute = "Luck", keys = {"Luck", "LCK"}},
}

local function collectStatTargets(dataMonster, entry)
        local targets = {}

        local function push(tbl)
                if typeof(tbl) == "table" then
                        table.insert(targets, tbl)
                end
        end

        if typeof(dataMonster) == "table" then
                dataMonster.Stats = dataMonster.Stats or {}
                push(dataMonster.Stats)
        end

        if typeof(entry) == "table" and typeof(entry.Data) == "table" then
                entry.Data.Stats = entry.Data.Stats or {}
                push(entry.Data.Stats)
        end

        return targets
end

module[#module + 1] = function(player, dataStore)
        if not player or not dataStore then
                return
        end

        local store = dataStore.Value
        local monster = typeof(store) == "table" and store.Monster or nil

        local entry = safeGetMonsterEntry(player)
        local model = resolveActiveModel(player, entry)

        if typeof(monster) == "table" and model then
                local targets = collectStatTargets(monster, entry)

                if #targets > 0 then
                        local didMutate = false

                        for _, mapping in ipairs(trackedStats) do
                                local attributeValue = model:GetAttribute(mapping.attribute)
                                if attributeValue ~= nil then
                                        for _, target in ipairs(targets) do
                                                for _, key in ipairs(mapping.keys) do
                                                        if target[key] == nil or target[key] ~= attributeValue then
                                                                target[key] = attributeValue
                                                                didMutate = true
                                                        end
                                                end
                                        end
                                end
                        end

                        if didMutate then
                                local result = dataStore:Save()
                                if result ~= "Saved" then
                                        warn("Failed to save monster stat sync for", player, result)
                                end
                        end
                end
        end

        local monsterGenerator = _G and _G.MONSTERGENERATOR
        if monsterGenerator and typeof(monsterGenerator.UnregisterPlayerMonster) == "function" then
                monsterGenerator.UnregisterPlayerMonster(player)
        end

        local toDestroy = model or (entry and entry.Model)
        if toDestroy and toDestroy.Parent then
                pcall(function()
                        toDestroy:Destroy()
                end)
        end
end

return module
