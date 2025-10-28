--// Monster Character Sheet UI (LocalScript)
--// Designed for All Ages — Soft Colors, Rounded Corners, Clear Sections

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MonsterCharacterSheet"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Main Frame Container
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 360, 0, 500)
mainFrame.Position = UDim2.new(0.5, -180, 0.5, -250)
mainFrame.BackgroundTransparency = 0.2
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Active = true
mainFrame.Draggable = true

-- Add rounded corners
local uicorner = Instance.new("UICorner")
uicorner.CornerRadius = UDim.new(0, 16)
uicorner.Parent = mainFrame

-- Title Bar (Draggable Header)
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundTransparency = 0.5
titleBar.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = uicorner:Clone()
titleCorner.CornerRadius = UDim.new(0, 16)
titleCorner.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -20, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "✨ Monster Profile"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 18
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

-- Close Button (Top Right)
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -40, 0, 5)
closeButton.BackgroundTransparency = 0.7
closeButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeButton.Text = "✕"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 20
closeButton.Parent = titleBar

closeButton.MouseButton1Click:Connect(function()
	screenGui:Destroy()
end)

-- Scrollable Content Area
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, 0, 1, -40)
scrollFrame.Position = UDim2.new(0, 0, 0, 40)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 10)
listLayout.Parent = scrollFrame

-- Function to create a section header toggle
local function createSectionToggle(name, contentFunc)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 0, 40)
	container.BackgroundTransparency = 0.3
	container.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
	container.BorderSizePixel = 0
	container.LayoutOrder = #scrollFrame:GetChildren()

	local corner = uicorner:Clone()
	corner.Parent = container

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.Text = "▼  " .. name
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Color3.fromRGB(220, 220, 255)
	button.TextSize = 16
	button.Parent = container

	local contentFrame = Instance.new("Frame")
	contentFrame.Size = UDim2.new(1, 0, 0, 0)
	contentFrame.BackgroundTransparency = 0.5
	contentFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	contentFrame.BorderSizePixel = 0
	contentFrame.Visible = true
	contentFrame.LayoutOrder = container.LayoutOrder + 1

	local contentCorner = uicorner:Clone()
	contentCorner.Parent = contentFrame

	local contentList = Instance.new("UIListLayout")
	contentList.SortOrder = Enum.SortOrder.LayoutOrder
	contentList.Padding = UDim.new(0, 8)
	contentList.Parent = contentFrame

	-- Expand/Collapse logic
	local expanded = true
	button.MouseButton1Click:Connect(function()
		expanded = not expanded
		button.Text = (expanded and "▼" or "▶") .. "  " .. name
		contentFrame.Visible = expanded
		if expanded then
			contentFrame.Size = UDim2.new(1, 0, 0, contentList.AbsoluteContentSize.Y + 20)
		else
			contentFrame.Size = UDim2.new(1, 0, 0, 0)
		end
		-- Update canvas size after toggle
		task.defer(function()
			scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
		end)
	end)

	-- Build initial content
	contentFunc(contentFrame, contentList)

	-- Auto-size content initially
	task.defer(function()
		contentFrame.Size = UDim2.new(1, 0, 0, contentList.AbsoluteContentSize.Y + 20)
	end)

	container.Parent = scrollFrame
	contentFrame.Parent = scrollFrame

	return container
end

-- Function to create a label-value pair row
local function createDataRow(parent, label, value, color)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 30)
	row.BackgroundTransparency = 0.7
	row.BackgroundColor3 = color or Color3.fromRGB(50, 50, 60)
	row.BorderSizePixel = 0
	row.Parent = parent

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0, 120, 1, 0)
	lbl.Position = UDim2.new(0, 10, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = label
	lbl.Font = Enum.Font.Gotham
	lbl.TextColor3 = Color3.fromRGB(220, 220, 255)
	lbl.TextSize = 14
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local val = Instance.new("TextLabel")
	val.Size = UDim2.new(1, -140, 1, 0)
	val.Position = UDim2.new(0, 130, 0, 0)
	val.BackgroundTransparency = 1
	val.Text = tostring(value)
	val.Font = Enum.Font.GothamSemibold
	val.TextColor3 = Color3.fromRGB(255, 255, 255)
	val.TextSize = 14
	val.TextXAlignment = Enum.TextXAlignment.Left
	val.TextTruncate = Enum.TextTruncate.AtEnd
	val.Parent = row

	return row
end

-- Function to create move display
local function createMoveRow(parent, moveData)
	local move = moveData.move
	local rarity = moveData.rarity or move.rarity or "Unknown"

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -20, 0, 40)
	row.Position = UDim2.new(0, 10, 0, 0)
	row.BackgroundTransparency = 0.6
	row.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	row.BorderSizePixel = 0
	row.Parent = parent

	local corner = uicorner:Clone()
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -80, 0, 20)
	nameLabel.Position = UDim2.new(0, 10, 0, 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = move.name or "Unnamed Move"
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 14
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(0, 70, 0, 20)
	rarityLabel.Position = UDim2.new(1, -80, 0, 4)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = rarity
	rarityLabel.Font = Enum.Font.Gotham
	rarityLabel.TextSize = 12

	-- Color by rarity
	if rarity == "Amateur" then
		rarityLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
	elseif rarity == "Rare" then
		rarityLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	elseif rarity == "Epic" then
		rarityLabel.TextColor3 = Color3.fromRGB(200, 100, 255)
	elseif rarity == "Legendary" then
		rarityLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
	else
		rarityLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	end

	rarityLabel.Parent = row

	return row
end

-- MOCK DATA (Replace with your actual monster data structure)
local monsterData = {
	Name = "Fluffernutter",
	Race = "RealitySeed",
	Stage = "Fledgeling",

	-- Evolution & Move Learning Fields
	BaseRaceFamily = "Progenitor",
	Bond = 78,
	Wins = 12,
	SessionTime = 3420, -- seconds
	Personality = "Unpredictable",

	-- Stats
	Stats = {
		Hp = 100, Mp = 100,
		Strength = 10, STR = 10,
		Defense = 10, DEF = 10,
		Skill = 10, SKL = 10,
		Speed = 10, SPD = 10,
		Intelligence = 10, INT = 10,
		Luck = 10, LCK = 10
	},

	-- Moves
	Moves = {
		{ move = { id = "BasicAttack", name = "Basic Attack", rarity = "Amateur" }, rarity = "Amateur" },
		{ move = { id = "SparkleBlast", name = "Sparkle Blast", rarity = "Rare" }, rarity = "Rare" }
	},
	LearnedMoves = {},

	-- History & Metadata
	History = {"RealitySeed", "Met Player", "Won First Battle"},
	Appearance = {}
}

-- Populate UI with Data

-- Basic Info Section
createSectionToggle("Basic Info", function(frame, layout)
	createDataRow(frame, "Name:", monsterData.Name, Color3.fromRGB(60, 70, 90))
	createDataRow(frame, "Race:", monsterData.Race)
	createDataRow(frame, "Stage:", monsterData.Stage)
	createDataRow(frame, "Family:", monsterData.BaseRaceFamily)
	createDataRow(frame, "Bond:", monsterData.Bond .. "%")
	createDataRow(frame, "Wins:", monsterData.Wins)
	createDataRow(frame, "Play Time:", string.format("%.1f hrs", monsterData.SessionTime / 3600))
	createDataRow(frame, "Personality:", monsterData.Personality, Color3.fromRGB(70, 60, 90))
end)

-- Stats Section
createSectionToggle("Stats", function(frame, layout)
	local statMap = {
		{"HP", "Hp"}, {"MP", "Mp"},
		{"STR", "Strength"}, {"DEF", "Defense"},
		{"SKL", "Skill"}, {"SPD", "Speed"},
		{"INT", "Intelligence"}, {"LCK", "Luck"}
	}

	for _, pair in ipairs(statMap) do
		local displayName, key = pair[1], pair[2]
		local value = monsterData.Stats[key] or 0
		createDataRow(frame, displayName .. ":", value, Color3.fromRGB(50, 60, 80))
	end
end)

-- Moves Section
createSectionToggle("Moves", function(frame, layout)
	if #monsterData.Moves == 0 then
		local noMoves = Instance.new("TextLabel")
		noMoves.Size = UDim2.new(1, -20, 0, 30)
		noMoves.Position = UDim2.new(0, 10, 0, 0)
		noMoves.BackgroundTransparency = 1
		noMoves.Text = "No moves learned yet!"
		noMoves.Font = Enum.Font.GothamItalic
		noMoves.TextColor3 = Color3.fromRGB(180, 180, 180)
		noMoves.TextSize = 14
		noMoves.Parent = frame
	else
		for _, moveData in ipairs(monsterData.Moves) do
			createMoveRow(frame, moveData)
		end
	end
end)

-- History Section
createSectionToggle("History & Notes", function(frame, layout)
	for i, event in ipairs(monsterData.History) do
		local entry = Instance.new("TextLabel")
		entry.Size = UDim2.new(1, -20, 0, 26)
		entry.Position = UDim2.new(0, 10, 0, (i-1)*28)
		entry.BackgroundTransparency = 0.8
		entry.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
		entry.Text = "• " .. event
		entry.Font = Enum.Font.Gotham
		entry.TextColor3 = Color3.fromRGB(200, 220, 255)
		entry.TextSize = 13
		entry.TextXAlignment = Enum.TextXAlignment.Left
		entry.TextWrapped = true
		entry.Parent = frame
	end

	-- Ensure height accommodates all entries
	task.defer(function()
		frame.Size = UDim2.new(1, 0, 0, #monsterData.History * 28 + 20)
	end)
end)

-- Finalize Canvas Size
task.wait(0.1) -- Allow UI to render
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)

-- Parent GUI
mainFrame.Parent = screenGui
screenGui.Parent = playerGui

print("[MonsterSheet] UI Loaded Successfully!")