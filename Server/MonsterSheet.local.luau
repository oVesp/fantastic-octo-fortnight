local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Moves = require(ReplicatedStorage.Modules.Moves)

local MonsterSheetUIBtn: TextButton = player.PlayerGui.Interface.Frame.MonsterSheet

-- Wait for RemoteEvent
local GetMonsterDataEvent: RemoteEvent = ReplicatedStorage:WaitForChild("GetMonsterData")

local function findMonsterByOwner(ownerId)
        if not ownerId then
                return nil
        end

        for _, descendant in Workspace:GetDescendants() do
                if descendant:IsA("Model") and descendant:GetAttribute("OwnerId") == ownerId then
                        return descendant
                end
        end

        return nil
end

local function toNumber(value, default)
        if typeof(value) == "number" and value == value then
                return value
        end
        return default
end

local function readStat(stats, key, altKey, default)
        stats = stats or {}
        local value = stats[key]
        if typeof(value) ~= "number" and altKey then
                value = stats[altKey]
        end
        return toNumber(value, default)
end

local function calculateBarSize(health, maxHealth)
        health = toNumber(health, 0)
        maxHealth = toNumber(maxHealth, 0)
        if maxHealth <= 0 then
                return 0
        end
        return math.clamp(health / maxHealth, 0, 1)
end

local function updateMonsterSheet(data, model)
        data = data or {}
        data.Stats = data.Stats or {}
        data.Moves = data.Moves or {}

        if (not model or not model.Parent) then
                model = findMonsterByOwner(data.OwnerId or player.UserId)
        end

        local monsterSheet = player:WaitForChild("PlayerGui", 5)
        monsterSheet = monsterSheet and monsterSheet:FindFirstChild("MonsterSheetUI")
        if not monsterSheet then
                warn("[MonsterSheet] MonsterSheetUI not found for player")
                return
        end

        local FrameMain = monsterSheet:FindFirstChild("FrameMain")
        if not FrameMain then
                warn("[MonsterSheet] FrameMain missing inside MonsterSheetUI")
                return
        end

        local content = FrameMain:FindFirstChild("Content")
        if not content then
                warn("[MonsterSheet] Content frame missing inside FrameMain")
                return
        end

        local StatsPanel = content:FindFirstChild("StatsPanel")
        local MovesPanel = content:FindFirstChild("MovesPanel")
        if not StatsPanel or not MovesPanel then
                warn("[MonsterSheet] StatsPanel or MovesPanel missing inside Content")
                return
        end

        local StatsGrid = StatsPanel:FindFirstChild("StatsGrid")
        if not StatsGrid then
                warn("[MonsterSheet] StatsGrid missing inside StatsPanel")
                return
        end

        local Header = FrameMain:FindFirstChild("Header")
        if not Header then
                warn("[MonsterSheet] Header missing inside FrameMain")
                return
        end

        Header.Badges.ChampionBadge.Text = tostring(data.Stage or "")

        -- Update UI text
        Header.NameLabel.Text = tostring(data.Name or "Unknown")
        Header.Subline.Text = tostring(data.Race or "")

        local humanoid = model and model:FindFirstChildOfClass("Humanoid")
        local currentHp = humanoid and humanoid.Health
                or (model and model:GetAttribute("Hp"))
                or readStat(data.Stats, "Hp", "HP", 0)
        local maxHp = (humanoid and humanoid.MaxHealth)
                or (model and model:GetAttribute("MaxHp"))
                or readStat(data.Stats, "Hp", "HP", 100)

        local currentMp = (model and model:GetAttribute("MP"))
                or readStat(data.Stats, "Mp", "MP", 0)
        local maxMp = (model and model:GetAttribute("MaxMP"))
                or readStat(data.Stats, "Mp", "MP", 100)

        Header.HPBar.Fill.Size = UDim2.new(calculateBarSize(currentHp, maxHp), 0, 1, 0)
        Header.MPBar.Fill.Size = UDim2.new(calculateBarSize(currentMp, maxMp), 0, 1, 0)

        local KeyRow = FrameMain:FindFirstChild("KeyRow")
        if KeyRow then
                local bondCard = KeyRow:FindFirstChild("Bond LevelCard")
                if bondCard and bondCard:FindFirstChild("Value") then
                        bondCard.Value.Text = tostring(data.Bond or 0)
                end

                local victoriesCard = KeyRow:FindFirstChild("VictoriesCard")
                if victoriesCard and victoriesCard:FindFirstChild("Value") then
                        victoriesCard.Value.Text = tostring(data.Wins or 0)
                end
        end

        -- Setup Stats
        StatsGrid.Defense.Value.Text = tostring(readStat(data.Stats, "Defense", nil, 0))
        StatsGrid.Strength.Value.Text = tostring(readStat(data.Stats, "Strength", nil, 0))
        StatsGrid.Skill.Value.Text = tostring(readStat(data.Stats, "Skill", nil, 0))
        StatsGrid.Speed.Value.Text = tostring(readStat(data.Stats, "Speed", nil, 0))
        StatsGrid.Intelligence.Value.Text = tostring(readStat(data.Stats, "Intelligence", nil, 0))
        StatsGrid.Luck.Value.Text = tostring(readStat(data.Stats, "Luck", nil, 0))

        -- Setup Moves
        local moveList = MovesPanel:FindFirstChild("MovesList")
        if moveList then
                for _, child in moveList:GetChildren() do
                        if child:IsA("GuiObject") then
                                child:Destroy()
                        end
                end

                local uiAssets = ReplicatedStorage:FindFirstChild("Assets")
                uiAssets = uiAssets and uiAssets:FindFirstChild("UI")
                local template = uiAssets and uiAssets:FindFirstChild("MoveTemplate")
                if template then
                        for _, moveData in ipairs(data.Moves) do
                                local moveId = moveData.id or moveData.Id
                                local move = Moves:GetMove(nil, moveId) or moveData
                                local card = template:Clone()
                                card.Parent = moveList
                                card.MoveName.Text = move.name or moveId or "Unknown Move"
                                card.Rarity.Text = tostring(move.rarity or moveData.rarity or "")
                                card.Power.Text = tostring(toNumber(move.power or moveData.power, 0))
                                card.Metrics.Cooldown.Value.Text = tostring(move.cooldown or moveData.cooldown or "-")
                                card.Metrics.MaxRange.Value.Text = tostring(move.maxRange or moveData.maxRange or "-")
                                card.Metrics.MinRange.Value.Text = tostring(move.minRange or moveData.minRange or "-")
                                card.Metrics.MpCost.Value.Text = tostring(move.mpCost or moveData.mpCost or 0)
                                local accuracy = toNumber(move.accuracy or moveData.accuracy, nil)
                                card.Metrics.Accuracy.Value.Text = accuracy and (math.floor(accuracy * 100 + 0.5) .. "%") or "-"
                                local critChance = toNumber(move.critChance or moveData.critChance, nil)
                                card.Metrics.CritChance.Value.Text = critChance and (math.floor(critChance * 100 + 0.5) .. "%") or "-"
                        end
                else
                        warn("[MonsterSheet] MoveTemplate not found in ReplicatedStorage.Assets.UI")
                end
        end

        Header.HPBar.ValueText.Text = string.format("%d/%d",
                math.floor(toNumber(currentHp, 0) + 0.5),
                math.floor(toNumber(maxHp, 0) + 0.5)
        )
        Header.MPBar.ValueText.Text = string.format("%d/%d",
                math.floor(toNumber(currentMp, 0) + 0.5),
                math.floor(toNumber(maxMp, 0) + 0.5)
        )
end

if MonsterSheetUIBtn then
        MonsterSheetUIBtn.Activated:Connect(function()
                print("MonsterSheetUIBtn")
                GetMonsterDataEvent:FireServer()
        end)
else
        warn("[MonsterSheet] MonsterSheet button not found in interface")
end

GetMonsterDataEvent.OnClientEvent:Connect(function(data, model)
        print("GetMonsterDataEvent.OnClientEvent")
        updateMonsterSheet(data, model)
end)
