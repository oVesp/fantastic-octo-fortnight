local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local EvolutionVFX = require(Modules:WaitForChild("EvolutionVFX"))
local Races = require(Modules:WaitForChild("Races"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EvolutionRequest = Remotes:FindFirstChild("EvolutionRequest")
local UIRemote = Remotes:FindFirstChild("UIRemote")
local OpenUIEvent = Remotes:FindFirstChild("OpenUI")
local EvolutionComplete = Remotes:FindFirstChild("EvolutionComplete")
local EvolutionEffectRemote = Remotes:FindFirstChild("EvolutionEffect")

local GetMonsterDataEvent = ReplicatedStorage:WaitForChild("GetMonsterData")

local AssetsFolder = ReplicatedStorage:FindFirstChild("Assets")
local EvoTemplate = nil
if AssetsFolder then
    local uiFolder = AssetsFolder:FindFirstChild("UI")
    if uiFolder then
        EvoTemplate = uiFolder:FindFirstChild("EvoTemplate")
    end
end

local LOCAL_PLAYER = Players.LocalPlayer
local PLAYER_GUI = LOCAL_PLAYER:WaitForChild("PlayerGui")

local evolutionGui = PLAYER_GUI:FindFirstChild("EvolutionUI")
if not evolutionGui then
    local replicatedGui = ReplicatedStorage:FindFirstChild("EvolutionUI")
    if replicatedGui and replicatedGui:IsA("ScreenGui") then
        evolutionGui = replicatedGui:Clone()
        evolutionGui.Parent = PLAYER_GUI
    else
        evolutionGui = PLAYER_GUI:WaitForChild("EvolutionUI", 5)
    end
end

local rootFrame = nil
local layerOneFrame = nil
local layerTwoFrame = nil

if evolutionGui and evolutionGui:IsA("ScreenGui") then
    rootFrame = evolutionGui:FindFirstChild("Frame")
    if rootFrame then
        layerOneFrame = rootFrame:FindFirstChild("Layer1")
        layerTwoFrame = rootFrame:FindFirstChild("Layer2")
    end
else
    warn("[EvolutionUI] EvolutionUI ScreenGui not found for player; UI controls disabled.")
end

if not EvoTemplate or not EvoTemplate:IsA("Frame") then
    warn("[EvolutionUI] EvoTemplate missing under ReplicatedStorage.Assets.UI; cannot build evolution cards.")
end

local function shallowCopy(dict)
    local copy = {}
    for key, value in pairs(dict or {}) do
        copy[key] = value
    end
    return copy
end

local function clearContainer(container: Instance?, wipePlaceholders: boolean)
    if not container then
        return
    end

    for _, child in ipairs(container:GetChildren()) do
        if child:GetAttribute("EvolutionCard") then
            child:Destroy()
        elseif wipePlaceholders and child:IsA("Frame") and child.Name == "Blank" then
            child:Destroy()
        end
    end
end

if rootFrame then
    clearContainer(rootFrame, true)
end
if layerOneFrame then
    clearContainer(layerOneFrame, true)
end
if layerTwoFrame then
    clearContainer(layerTwoFrame, true)
end

local STAT_LABELS = {
    Strength = "STR",
    Defense = "DEF",
    Skill = "SKL",
    Speed = "SPD",
    Intelligence = "INT",
    Luck = "LCK",
    Hp = "HP",
    HP = "HP",
    Mp = "MP",
    MP = "MP",
}

local SORTED_STATS = {
    "Strength",
    "Defense",
    "Skill",
    "Speed",
    "Intelligence",
    "Luck",
    "Hp",
    "Mp",
}

local function formatRequirements(gates)
    if not gates or typeof(gates) ~= "table" then
        return "Requirements:\n• None"
    end

    local lines = {}

    if gates.minStats and typeof(gates.minStats) == "table" then
        for _, statName in ipairs(SORTED_STATS) do
            local minValue = gates.minStats[statName]
            if typeof(minValue) == "number" then
                local label = STAT_LABELS[statName] or statName
                table.insert(lines, string.format("• %s ≥ %d", label, minValue))
            end
        end
        for statName, minValue in pairs(gates.minStats) do
            if not STAT_LABELS[statName] and typeof(minValue) == "number" then
                table.insert(lines, string.format("• %s ≥ %d", tostring(statName), minValue))
            end
        end
    end

    if typeof(gates.minBond) == "number" then
        table.insert(lines, string.format("• Bond ≥ %d", gates.minBond))
    end

    if typeof(gates.minWins) == "number" then
        table.insert(lines, string.format("• Wins ≥ %d", gates.minWins))
    end

    if typeof(gates.maxCareMistakes) == "number" then
        table.insert(lines, string.format("• Care Mistakes ≤ %d", gates.maxCareMistakes))
    end

    if typeof(gates.baseRaceFamily) == "string" and gates.baseRaceFamily ~= "" then
        table.insert(lines, string.format("• Family: %s", gates.baseRaceFamily))
    end

    if typeof(gates.personalityAnyOf) == "table" and #gates.personalityAnyOf > 0 then
        table.insert(lines, string.format("• Personality: %s", table.concat(gates.personalityAnyOf, "/")))
    end

    if #lines == 0 then
        return "Requirements:\n• None"
    end

    return "Requirements:\n" .. table.concat(lines, "\n")
end

local function getRaceDisplayName(raceName: string?): string
    if not raceName or raceName == "" then
        return "Unknown"
    end

    local def = Races:Get(raceName)
    if def and def.displayName then
        return def.displayName
    end

    return raceName
end

local function computeProgress(currentRace: string, ctx: {[string]: any}?, evo: {[string]: any}?): number
    if not ctx or not evo or not currentRace then
        return 0
    end

    local ok, progress = pcall(function()
        return Races:CalculateEvolutionProgress(currentRace, ctx, evo)
    end)

    if not ok or typeof(progress) ~= "number" then
        return 0
    end

    return math.clamp(progress, 0, 1)
end

local function formatChance(progress: number): string
    local pct = math.floor((progress or 0) * 100 + 0.5)
    return string.format("Chance: %d%%", pct)
end

local function buildContext(monsterData)
    if typeof(monsterData) ~= "table" then
        return nil
    end

    local currentRace = monsterData.Race or monsterData.race
    if not currentRace then
        return nil
    end

    local currentStage = monsterData.Stage or Races:GetStage(currentRace) or "Proto"
    local statsCopy = shallowCopy(monsterData.Stats or {})
    Races:ClampStatsByStage(statsCopy, currentStage)

    return {
        race = currentRace,
        stage = currentStage,
        stats = statsCopy,
        bond = monsterData.Bond or 0,
        wins = monsterData.Wins or 0,
        sessionTime = monsterData.SessionTime or 0,
        careMistakes = monsterData.CareMistakes or 0,
        personality = monsterData.Personality,
        baseRaceFamily = monsterData.BaseRaceFamily or Races:GetBaseRaceFamily(currentRace),
        cameFrom = currentRace,
        history = monsterData.History or {},
        trigger = "manual",
    }
end

local function buildContextForRace(baseCtx, raceName)
    if not baseCtx then
        return nil
    end

    raceName = raceName or baseCtx.race
    if not raceName then
        return nil
    end

    local stage = Races:GetStage(raceName) or baseCtx.stage or "Proto"
    local statsCopy = shallowCopy(baseCtx.stats or {})
    Races:ClampStatsByStage(statsCopy, stage)

    local ctx = {
        race = raceName,
        stage = stage,
        stats = statsCopy,
        bond = baseCtx.bond,
        wins = baseCtx.wins,
        sessionTime = baseCtx.sessionTime,
        careMistakes = baseCtx.careMistakes,
        personality = baseCtx.personality,
        baseRaceFamily = Races:GetBaseRaceFamily(raceName) or baseCtx.baseRaceFamily,
        cameFrom = raceName,
        history = baseCtx.history,
        trigger = baseCtx.trigger,
    }

    return ctx
end

local function createCard(parent: Instance?, info)
    if not parent or not EvoTemplate or not EvoTemplate:IsA("Frame") then
        return nil
    end

    local card = EvoTemplate:Clone()
    card.Name = info.name or (info.target or "EvolutionCard")
    card:SetAttribute("EvolutionCard", true)
    if info.layoutOrder then
        card.LayoutOrder = info.layoutOrder
    end
    card.Parent = parent

    local raceLabel = card:FindFirstChild("RaceStageLabel")
    if raceLabel and raceLabel:IsA("TextLabel") then
        raceLabel.Text = info.title or ""
    end

    local familyLabel = card:FindFirstChild("FamilyLabel")
    if familyLabel and familyLabel:IsA("TextLabel") then
        familyLabel.Text = info.familyText or ""
    end

    local chanceLabel = card:FindFirstChild("ChanceLabel")
    if chanceLabel and chanceLabel:IsA("TextLabel") then
        chanceLabel.Text = info.chanceText or ""
    end

    local requirementsLabel = card:FindFirstChild("RequirementsLabel")
    if requirementsLabel and requirementsLabel:IsA("TextLabel") then
        requirementsLabel.Text = info.requirementsText or ""
    end

    local evolveBtn = card:FindFirstChild("EvolveBtn")
    if evolveBtn and evolveBtn:IsA("TextButton") then
        evolveBtn.Visible = info.showButton == true
        if info.showButton and typeof(info.onEvolve) == "function" then
            evolveBtn.Activated:Connect(info.onEvolve)
        else
            evolveBtn.Visible = false
        end
    end

    return card
end

local latestMonsterData = nil

local function populateEvolutionUI(monsterData)
    clearContainer(rootFrame, false)
    clearContainer(layerOneFrame, false)
    clearContainer(layerTwoFrame, false)

    if layerOneFrame then
        layerOneFrame.Visible = false
    end
    if layerTwoFrame then
        layerTwoFrame.Visible = false
    end

    if not (evolutionGui and evolutionGui:IsA("ScreenGui")) then
        return
    end

    if not monsterData then
        return
    end

    local ctx = buildContext(monsterData)
    if not ctx then
        return
    end

    local currentRace = ctx.race
    local currentStage = ctx.stage or "Unknown"
    local currentFamily = ctx.baseRaceFamily or Races:GetBaseRaceFamily(currentRace) or "Unknown"
    local currentTitle = string.format("%s (%s)", getRaceDisplayName(currentRace), currentStage)

    createCard(rootFrame, {
        target = currentRace,
        layoutOrder = -1,
        title = currentTitle,
        familyText = string.format("Family: %s", currentFamily),
        chanceText = "Current Evolution",
        requirementsText = "",
        showButton = EvolutionRequest ~= nil,
        onEvolve = function()
            if EvolutionRequest then
                EvolutionRequest:FireServer()
            end
        end,
    })

    local immediateOptions = {}
    for _, evo in ipairs(Races:GetEvolutions(currentRace) or {}) do
        if evo and evo.target then
            local progress = computeProgress(currentRace, ctx, evo)
            local targetRace = evo.target
            local stage = Races:GetStage(targetRace) or (Races:Get(targetRace) and Races:Get(targetRace).stage) or "Unknown"
            local family = Races:GetBaseRaceFamily(targetRace) or "Unknown"
            table.insert(immediateOptions, {
                target = targetRace,
                chance = progress,
                title = string.format("%s (%s)", getRaceDisplayName(targetRace), stage),
                familyText = string.format("Family: %s", family),
                chanceText = formatChance(progress),
                requirementsText = formatRequirements(evo.gates),
            })
        end
    end

    table.sort(immediateOptions, function(a, b)
        if a.chance == b.chance then
            return (a.title or "") < (b.title or "")
        end
        return a.chance > b.chance
    end)

    if layerOneFrame and #immediateOptions > 0 then
        layerOneFrame.Visible = true
        for index, info in ipairs(immediateOptions) do
            info.layoutOrder = index
            info.showButton = false
            createCard(layerOneFrame, info)
        end
    end

    local futureMap = {}
    for _, info in ipairs(immediateOptions) do
        local nextEvos = Races:GetEvolutions(info.target) or {}
        if #nextEvos > 0 then
            local nextCtx = buildContextForRace(ctx, info.target)
            for _, nextEvo in ipairs(nextEvos) do
                if nextEvo and nextEvo.target then
                    local progress = computeProgress(info.target, nextCtx, nextEvo)
                    local existing = futureMap[nextEvo.target]
                    if not existing or progress > existing.chance then
                        local targetRace = nextEvo.target
                        local stage = Races:GetStage(targetRace) or (Races:Get(targetRace) and Races:Get(targetRace).stage) or "Unknown"
                        local family = Races:GetBaseRaceFamily(targetRace) or "Unknown"
                        futureMap[targetRace] = {
                            target = targetRace,
                            chance = progress,
                            title = string.format("%s (%s)", getRaceDisplayName(targetRace), stage),
                            familyText = string.format("Family: %s", family),
                            chanceText = formatChance(progress),
                            requirementsText = formatRequirements(nextEvo.gates),
                        }
                    end
                end
            end
        end
    end

    local futureList = {}
    for _, value in pairs(futureMap) do
        table.insert(futureList, value)
    end
    table.sort(futureList, function(a, b)
        if a.chance == b.chance then
            return (a.title or "") < (b.title or "")
        end
        return a.chance > b.chance
    end)

    if layerTwoFrame and #futureList > 0 then
        layerTwoFrame.Visible = true
        for index, info in ipairs(futureList) do
            info.layoutOrder = index
            info.showButton = false
            createCard(layerTwoFrame, info)
        end
    end
end

if evolutionGui and evolutionGui:IsA("ScreenGui") then
    evolutionGui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if evolutionGui.Enabled then
            populateEvolutionUI(latestMonsterData)
            GetMonsterDataEvent:FireServer()
        end
    end)

    if evolutionGui.Enabled then
        populateEvolutionUI(latestMonsterData)
        GetMonsterDataEvent:FireServer()
    end
end

GetMonsterDataEvent.OnClientEvent:Connect(function(monsterData)
    latestMonsterData = monsterData
    if evolutionGui and evolutionGui:IsA("ScreenGui") and evolutionGui.Enabled then
        populateEvolutionUI(monsterData)
    end
end)

if EvolutionComplete and EvolutionComplete:IsA("RemoteEvent") then
    EvolutionComplete.OnClientEvent:Connect(function()
        GetMonsterDataEvent:FireServer()
    end)
end

if EvolutionEffectRemote and EvolutionEffectRemote:IsA("RemoteEvent") then
    EvolutionEffectRemote.OnClientEvent:Connect(function(worldPos)
        if typeof(worldPos) ~= "Vector3" then
            return
        end

        if evolutionGui and evolutionGui:IsA("ScreenGui") then
            evolutionGui.Enabled = false
        end
    end)
end

local function toggleEvolutionUI()
    if not (evolutionGui and evolutionGui:IsA("ScreenGui")) then
        return
    end

    if UIRemote then
        UIRemote:FireServer("EvolutionUI")
    else
        evolutionGui.Enabled = not evolutionGui.Enabled
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.E then
        toggleEvolutionUI()
    end
end)

if OpenUIEvent and OpenUIEvent:IsA("RemoteEvent") then
    OpenUIEvent.OnClientEvent:Connect(function(uiName)
        if uiName == "EvolutionUI" or uiName == "Evolution" or uiName == nil then
            toggleEvolutionUI()
        end
    end)
end
