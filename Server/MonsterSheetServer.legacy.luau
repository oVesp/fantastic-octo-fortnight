-- Server: MonsterDataHandler
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Create RemoteEvents
local GetMonsterDataEvent = Instance.new("RemoteEvent")
GetMonsterDataEvent.Name = "GetMonsterData"
GetMonsterDataEvent.Parent = ReplicatedStorage


local function findMonsterByOwnerId(ownerId)
        if not ownerId then
                return nil
        end

        for _, monster in pairs(workspace:GetChildren()) do
                if monster:IsA("Model") then
                        local attr = monster:GetAttribute("OwnerId")
                        if attr and tostring(attr) == tostring(ownerId) then
                                return monster
                        end
                end
        end

        return nil
end

-- Handle data requests
local function DeepCopy(tbl)
        if typeof(tbl) ~= "table" then
                return tbl
        end

        local copy = {}
        for k, v in tbl do
                if typeof(v) == "table" then
                        copy[k] = DeepCopy(v)
                else
                        copy[k] = v
                end
        end
        return copy
end

GetMonsterDataEvent.OnServerEvent:Connect(function(player)
        local monsterData
        local model

        if _G and _G.MONSTERGENERATOR then
                local generator = _G.MONSTERGENERATOR

                if typeof(generator.GetPlayerMonsterData) == "function" then
                        local entry = generator:GetPlayerMonsterData(player.UserId)
                        if entry then
                                if entry.Data then
                                        monsterData = DeepCopy(entry.Data)
                                elseif typeof(entry) == "table" then
                                        monsterData = DeepCopy(entry)
                                end

                                if entry.Model and entry.Model.Parent then
                                        model = entry.Model
                                end
                        end
                end

                if not model and typeof(generator.GetPlayerMonster) == "function" then
                        model = generator:GetPlayerMonster(player)
                end
        end

        if not monsterData and _G and _G.DATA and typeof(_G.DATA.Get) == "function" then
                local data = _G.DATA:Get(player)
                if data and data.Monster then
                        monsterData = DeepCopy(data.Monster)
                        if not model then
                                model = findMonsterByOwnerId(data.Monster.OwnerId or player.UserId)
                        end
                end
        end

        if not monsterData then
                warn("[MonsterSheet] Unable to fetch monster data for " .. player.Name)
                monsterData = {}
        end

        local ownerId = player.UserId
        if typeof(monsterData) == "table" then
                ownerId = monsterData.OwnerId or ownerId
                monsterData.Stats = monsterData.Stats or {}
                monsterData.Moves = monsterData.Moves or {}
        end

        if not model then
                model = findMonsterByOwnerId(ownerId)
        end

        GetMonsterDataEvent:FireClient(player, monsterData, model)
end)

