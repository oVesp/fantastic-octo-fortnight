-- LocalScript: PlayerGui -> MonsterSheetUI - MonsterSheet.local.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Moves = require(ReplicatedStorage.Modules.Moves)

local MonsterSheetUIBtn: TextButton = player.PlayerGui.Interface.Frame.MonsterSheet

-- Wait for RemoteEvent
local GetMonsterDataEvent: RemoteEvent = ReplicatedStorage:WaitForChild("GetMonsterData")


local function resolveMoveInfo(moveEntry)
        if not moveEntry then
                return nil, nil
        end

        if typeof(moveEntry) == "string" then
                return moveEntry, nil
        end

        if typeof(moveEntry) == "table" then
                local moveId = moveEntry.id or moveEntry.moveId or moveEntry.MoveId or moveEntry.MoveID
                return moveId, moveEntry.rarity or moveEntry.Rarity
        end

        return nil, nil
end

local function updateMonsterSheet(data, model)
        if not data then
                warn("[MonsterSheet] Missing monster data")
                return
        end

        local monsterSheet = player:WaitForChild("PlayerGui"):WaitForChild("MonsterSheetUI")
        local FrameMain = monsterSheet:WaitForChild("FrameMain")
        local StatsPanel = FrameMain:WaitForChild("Content"):WaitForChild("StatsPanel")
        local MovesPanel = FrameMain:WaitForChild("Content"):WaitForChild("MovesPanel")
        local StatsGrid = StatsPanel:WaitForChild("StatsGrid")
        local Header =  FrameMain.Header
        Header.Badges.ChampionBadge.Text = tostring(data.Stage or "-")


        --Update UI
        Header.NameLabel.Text = tostring(data.Name or "Unknown")
        Header.Subline.Text = tostring(data.Race or "-")
        -- Update HP/MP bars and text using current model state
        local KeyRow = FrameMain.KeyRow
        KeyRow["Bond LevelCard"].Value.Text = tostring(data.Bond or 0)
        KeyRow.VictoriesCard.Value.Text = tostring(data.Wins or 0)
	
        local stats = data.Stats or {}
        --Setup Stats
        StatsGrid.Defense.Value.Text = tostring(stats["Defense"] or stats["DEF"] or 0)
        StatsGrid.Strength.Value.Text = tostring(stats["Strength"] or stats["STR"] or 0)
        StatsGrid.Skill.Value.Text = tostring(stats["Skill"] or stats["SKL"] or 0)
        StatsGrid.Speed.Value.Text = tostring(stats["Speed"] or stats["SPD"] or 0)
        StatsGrid.Intelligence.Value.Text = tostring(stats["Intelligence"] or stats["INT"] or 0)
        StatsGrid.Luck.Value.Text = tostring(stats["Luck"] or stats["LCK"] or 0)
	--Setup Moves
        for _, child in MovesPanel.MovesList:GetChildren() do
                if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                        child:Destroy()
                end
        end
	--[[ {
                    ["move"] =  ▼  {
                       ["accuracy"] = 0.96,
                       ["castSpeed"] = 1,
                       ["castTime"] = 0.4,
                       ["cooldown"] = 1.2,
                       ["critChance"] = 0.06,
                       ["effects"] = {},
                       ["id"] = "BasicAttack",
                       ["lockMovement"] = true,
                       ["maxRange"] = 6,
                       ["minRange"] = 0,
                       ["mpCost"] = 0,
                       ["name"] = "Basic Attack",
                       ["power"] = 10,
                       ["rarity"] = "Amateur",
                       ["tags"] =  ▶ {...}
                    },
                    ["rarity"] = "Amateur"
                 }
                 ]]
	
        local movesList = data.Moves or {}
        for _, moveEntry in ipairs(movesList) do
                local moveId, storedRarity = resolveMoveInfo(moveEntry)
                if moveId then
                        local moveData = Moves:GetMove(data.Race, moveId) or Moves:GetMove(nil, moveId)
                        if moveData then
                                local Card = ReplicatedStorage.Assets.UI.MoveTemplate:Clone()
                                Card.Parent = MovesPanel.MovesList
                                Card.MoveName.Text = moveData.name or moveId
                                Card.Rarity.Text = storedRarity or moveData.rarity or "Unknown"
                                Card.Power.Text = tostring(moveData.power or 0)
                                Card.Metrics.Cooldown.Value.Text = tostring(moveData.cooldown or 0)
                                Card.Metrics.MaxRange.Value.Text = tostring(moveData.maxRange or 0)
                                Card.Metrics.MinRange.Value.Text = tostring(moveData.minRange or 0)
                                Card.Metrics.MpCost.Value.Text = tostring(moveData.mpCost or 0)
                                Card.Metrics.Accuracy.Value.Text = string.format("%d%%", math.floor((moveData.accuracy or 0) * 100 + 0.5))
                                Card.Metrics.CritChance.Value.Text = string.format("%d%%", math.floor((moveData.critChance or 0) * 100 + 0.5))
                        end
                end
        end


        local maxHp = stats["Hp"] or stats["HP"] or 0
        local maxMp = stats["Mp"] or stats["MP"] or 0
        local humanoid = model and model:FindFirstChildOfClass("Humanoid")
        if model and humanoid then
                Header.HPBar.ValueText.Text = string.format("%d/%d", math.floor(humanoid.Health + 0.5), maxHp)
                Header.MPBar.ValueText.Text = string.format("%d/%d", math.floor((model:GetAttribute("MP") or 0) + 0.5), maxMp)
                local function calculateBarSize(health, maxHealth)
                        if not maxHealth or maxHealth <= 0 then
                                return 0
                        end
                        return math.clamp(health / maxHealth, 0, 1)
                end
                Header.HPBar.Fill.Size = UDim2.new(calculateBarSize(humanoid.Health, maxHp), 0, 1, 0)
                Header.MPBar.Fill.Size = UDim2.new(calculateBarSize(model:GetAttribute("MP") or 0, maxMp), 0, 1, 0)
        else
                Header.HPBar.Fill.Size = UDim2.new(0, 0, 1, 0)
                Header.MPBar.Fill.Size = UDim2.new(0, 0, 1, 0)
                Header.HPBar.ValueText.Text = string.format("0/%d", maxHp)
                Header.MPBar.ValueText.Text = string.format("0/%d", maxMp)
        end
	
	
end

MonsterSheetUIBtn.Activated:Connect(function(plr, data)
	print("MonsterSheetUIBtn")
	GetMonsterDataEvent:FireServer()

end)

GetMonsterDataEvent.OnClientEvent:Connect(function(data, model)
	print("GetMonsterDataEvent.OnClientEvent")
	updateMonsterSheet(data, model)
end)
