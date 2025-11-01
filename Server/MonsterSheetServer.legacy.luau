-- Server: MonsterDataHandler
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local TrackValuesNormalize
do
        local ok, normalize = pcall(function()
                local data = ServerScriptService:FindFirstChild("Data")
                if not data then
                        return nil
                end

                local shared = data:FindFirstChild("Shared")
                if not shared then
                        return nil
                end

                local dataStorage = shared:FindFirstChild("DataStorage")
                if not dataStorage then
                        return nil
                end

                local trackValues = dataStorage:FindFirstChild("TrackValues")
                if not trackValues then
                        return nil
                end

                local module = require(trackValues)
                return module and module.normalize
        end)

        if ok and typeof(normalize) == "function" then
                TrackValuesNormalize = normalize
        end
end

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
local function DeepCopy(value, seen)
        if typeof(value) ~= "table" then
                return value
        end

        seen = seen or {}

        local original = value

        if TrackValuesNormalize then
                local ok, normalized = pcall(TrackValuesNormalize, value)
                if ok and normalized ~= nil then
                        value = normalized
                end
        end

        if typeof(value) == "table" then
                local mt = getmetatable(value)
                if typeof(mt) == "table" and mt.__stg then
                        value = mt.__stg
                end
        end

        if seen[original] then
                return seen[original]
        end

        if seen[value] then
                return seen[value]
        end

        local copy = {}
        seen[original] = copy

        if value ~= original then
                seen[value] = copy
        end

        for k, v in pairs(value) do
                local newKey = DeepCopy(k, seen)
                copy[newKey] = DeepCopy(v, seen)
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

