-- LocalScript: monsterSheet
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Moves = require(ReplicatedStorage.Modules.Moves)

local MonsterSheetUIBtn: TextButton = player.PlayerGui.Interface.Frame.MonsterSheet

-- Wait for RemoteEvent
local GetMonsterDataEvent: RemoteEvent = ReplicatedStorage:WaitForChild("GetMonsterData")


local function updateMonsterSheet(data, model)
	local monsterSheet = player:WaitForChild("PlayerGui"):WaitForChild("MonsterSheetUI")
	local FrameMain = monsterSheet:WaitForChild("FrameMain")
	local StatsPanel = FrameMain:WaitForChild("Content"):WaitForChild("StatsPanel")
	local MovesPanel = FrameMain:WaitForChild("Content"):WaitForChild("MovesPanel")
	local StatsGrid = StatsPanel:WaitForChild("StatsGrid")
	local Header =  FrameMain.Header
	Header.Badges.ChampionBadge.Text = data.Stage	

	
	--Update UI
	Header.NameLabel.Text = data.Name
	Header.Subline.Text = data.Race
	--HPBar.ValueText is 0/0 make it so it gets the Hp from the data and current HP by finding the monster with data.OwnerId attribute in workspace
	
	--calculate hpBar.Size to be the difference between health and maxHealth
	local function calculateBarSize(health, maxHealth)
		return math.clamp(health / maxHealth, 0, 1)
	end
	Header.HPBar.Fill.Size = UDim2.new(calculateBarSize(model.Humanoid.Health, data.Stats["Hp"]), 0, 1, 0)
	Header.MPBar.Fill.Size = UDim2.new(calculateBarSize(model:GetAttribute("MP"), data.Stats["Mp"]), 0, 1, 0)
	local KeyRow = FrameMain.KeyRow
	KeyRow["Bond LevelCard"].Value.Text = data.Bond
	KeyRow.VictoriesCard.Value.Text = data.Wins
	
	--Setup Stats
	StatsGrid.Defense.Value.Text = data.Stats["Defense"]
	StatsGrid.Strength.Value.Text = data.Stats["Strength"]
	StatsGrid.Skill.Value.Text = data.Stats["Skill"]
	StatsGrid.Speed.Value.Text = data.Stats["Speed"]
	StatsGrid.Intelligence.Value.Text = data.Stats["Intelligence"]
	StatsGrid.Luck.Value.Text = data.Stats["Luck"]
	--Setup Moves
	for _, child in MovesPanel.MovesList:GetChildren() do
		child:Destroy()
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
	
	for _, move in data.Moves do
		local Card = ReplicatedStorage.Assets.UI.MoveTemplate:Clone()
		Card.Parent = MovesPanel.MovesList
		Card.MoveName.Text = move.move.name or move.id
		Card.Rarity.Text = move.move.rarity
		Card.Power.Text = move.move.power
		Card.Metrics.Cooldown.Value.Text = move.move.cooldown
		Card.Metrics.MaxRange.Value.Text = move.move.maxRange
		Card.Metrics.MinRange.Value.Text = move.move.minRange
		Card.Metrics.MpCost.Value.Text = move.move.mpCost
		Card.Metrics.Accuracy.Value.Text = math.floor(move.move.accuracy*100) .. "%"
		Card.Metrics.CritChance.Value.Text = math.floor(move.move.critChance*100) .. "%"
	end
	
	
	Header.HPBar.ValueText.Text = model.Humanoid.Health .. "/" .. data.Stats["Hp"] or "100/100"
	Header.MPBar.ValueText.Text = model:GetAttribute("MP") .. "/" .. data.Stats["Mp"] or "100/100"
	
	
end

MonsterSheetUIBtn.Activated:Connect(function(plr, data)
	print("MonsterSheetUIBtn")
	GetMonsterDataEvent:FireServer()

end)

GetMonsterDataEvent.OnClientEvent:Connect(function(data, model)
	print("GetMonsterDataEvent.OnClientEvent")
	updateMonsterSheet(data, model)
end)
