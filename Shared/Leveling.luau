-- Leveling.luau
-- Implements monster experience progression using a Path of Exile-inspired curve.

local Leveling = {}

local Players = game:GetService("Players")

local XP_TABLE = table.freeze({
        0, -- Level 1
        525,
        1760,
        3781,
        7184,
        12186,
        19324,
        29377,
        43108,
        61412,
        85415,
        116288,
        154438,
        201487,
        259222,
        329554,
        414356,
        515719,
        635554,
        775888,
        938758,
        1126190,
        1341235,
        1584938,
        1859368,
        2166614,
        2508793,
        2888064,
        3306616,
        3766672,
        4270486,
        4820355,
        5418629,
        6067709,
        6770049,
        7528152,
        8344582,
        9221962,
        10162973,
        11170364,
        12246952,
        13395630,
        14619372,
        15921231,
        17304338,
        18771902,
        20327225,
        21973702,
        23714828,
        25554211,
        27495578,
        29542774,
        31700974,
        33970676,
        36359708,
        38871231,
        41509749,
        44279913,
        47186519,
        50234525,
        53429060,
        56775432,
        60279135,
        63945857,
        67781490,
        71792126,
        75984089,
        80363933,
        84938459,
        89714723,
        94699037,
        99901986,
        105327452,
        110983611,
        116877953,
        123018280,
        129412729,
        136069775,
        143003233,
        150222286,
        157733499,
        165543830,
        173660640,
        182091708,
        190845239,
        199929894,
        209354793,
        219129543,
        229264248,
        239769516,
        250656468,
        261936777,
        273622669,
        285726922,
        298262899,
        311244563,
        324686488,
        338603883,
        353012623,
        367929210,
})

Leveling.XP_TABLE = XP_TABLE
Leveling.MaxLevel = #XP_TABLE

local STAT_LAYOUT = {
        { key = "Hp", aliases = {"HP"}, attributes = {"Hp"}, humanoidField = "MaxHealth" },
        { key = "Mp", aliases = {"MP"}, attributes = {"MP", "MaxMP"} },
        { key = "Strength", aliases = {"STR"}, attributes = {"Strength"} },
        { key = "Defense", aliases = {"DEF"}, attributes = {"Defense"} },
        { key = "Skill", aliases = {"SKL"}, attributes = {"Skill"} },
        { key = "Speed", aliases = {"SPD"}, attributes = {"Speed"} },
        { key = "Intelligence", aliases = {"INT"}, attributes = {"Intelligence"} },
        { key = "Luck", aliases = {"LCK"}, attributes = {"Luck"} },
}

local function clampLevel(level: number?)
        if typeof(level) ~= "number" then
                return 1
        end
        level = math.floor(level)
        if level < 1 then
                return 1
        end
        if level > Leveling.MaxLevel then
                return Leveling.MaxLevel
        end
        return level
end

Leveling.ClampLevel = clampLevel

function Leveling.GetExperienceForLevel(level: number?): number
        local idx = clampLevel(level)
        return XP_TABLE[idx]
end

function Leveling.GetExperienceToNextLevel(level: number?): number
        local idx = clampLevel(level)
        if idx >= Leveling.MaxLevel then
                return 0
        end
        return XP_TABLE[idx + 1] - XP_TABLE[idx]
end

function Leveling.GetLevelForExperience(exp: number?): number
        exp = math.max(0, tonumber(exp) or 0)
        local low, high = 1, Leveling.MaxLevel
        while low < high do
                local mid = math.floor((low + high + 1) / 2)
                if XP_TABLE[mid] <= exp then
                        low = mid
                else
                        high = mid - 1
                end
        end
        return clampLevel(low)
end

function Leveling.GetStatMultiplier(level: number?): number
        level = clampLevel(level)
        return 1 + ((level - 1) * 0.05)
end

local function round(value: number): number
        return math.floor(value + 0.5)
end

local function captureStatValue(stats: table, keyInfo): number?
        if type(stats) ~= "table" then
                return nil
        end
        local value = stats[keyInfo.key]
        if typeof(value) ~= "number" then
                for _, alias in ipairs(keyInfo.aliases or {}) do
                        local candidate = stats[alias]
                        if typeof(candidate) == "number" then
                                value = candidate
                                break
                        end
                end
        end
        return typeof(value) == "number" and value or nil
end

local function ensureStatsTable(monsterData)
        monsterData.Stats = monsterData.Stats or {}
        return monsterData.Stats
end

local function ensureBaseline(monsterData)
        if type(monsterData.LevelingBaseStats) ~= "table" then
                monsterData.LevelingBaseStats = {}
        end
        return monsterData.LevelingBaseStats
end

function Leveling.RefreshBaseline(monsterData: table)
        if type(monsterData) ~= "table" then
                return nil
        end
        local stats = ensureStatsTable(monsterData)
        local baseline = ensureBaseline(monsterData)
        local multiplier = Leveling.GetStatMultiplier(monsterData.Level or 1)
        if multiplier <= 0 then
                multiplier = 1
        end

        for _, keyInfo in ipairs(STAT_LAYOUT) do
                local current = captureStatValue(stats, keyInfo)
                if typeof(current) == "number" then
                        baseline[keyInfo.key] = math.max(1, round(current / multiplier))
                end
        end

        return baseline
end

local function applyStatsFromBaseline(monsterData: table, level: number)
        local baseline = ensureBaseline(monsterData)
        if next(baseline) == nil then
                baseline = Leveling.RefreshBaseline(monsterData) or baseline
        end
        local stats = ensureStatsTable(monsterData)
        local multiplier = Leveling.GetStatMultiplier(level)

        for _, keyInfo in ipairs(STAT_LAYOUT) do
                local baseValue = baseline[keyInfo.key]
                if typeof(baseValue) == "number" then
                        local value = math.max(1, math.floor(baseValue * multiplier))
                        stats[keyInfo.key] = value
                        for _, alias in ipairs(keyInfo.aliases or {}) do
                                stats[alias] = value
                        end
                end
        end

        return stats
end

local function syncModelStats(monsterData: table, model: Model?)
        if not model then
                return
        end
        local stats = monsterData and monsterData.Stats
        if type(stats) ~= "table" then
                return
        end

        for _, keyInfo in ipairs(STAT_LAYOUT) do
                local value = stats[keyInfo.key]
                if typeof(value) == "number" then
                        for _, attrName in ipairs(keyInfo.attributes or {}) do
                                model:SetAttribute(attrName, value)
                        end
                        if keyInfo.humanoidField == "MaxHealth" then
                                local hum = model:FindFirstChildOfClass("Humanoid")
                                if hum then
                                        hum.MaxHealth = value
                                        hum.Health = math.clamp(hum.Health, 1, hum.MaxHealth)
                                end
                        end
                end
        end

        if typeof(monsterData.Level) == "number" then
                model:SetAttribute("Level", monsterData.Level)
        end
        if typeof(monsterData.Experience) == "number" then
                model:SetAttribute("Experience", monsterData.Experience)
        end
end

local function getPlayerFromContext(context)
        if type(context) ~= "table" then
                return nil
        end
        if context.Player and context.Player:IsA("Player") then
                        return context.Player
        end
        if typeof(context.PlayerId) == "number" then
                return Players:GetPlayerByUserId(context.PlayerId)
        end
        return nil
end

local function formatNumber(value: number): string
        local str = tostring(math.floor(value))
        local result = str
        local pattern = "(-?%d+)(%d%d%d)"
        while true do
                local newResult, replacements = result:gsub(pattern, "%1,%2")
                result = newResult
                if replacements == 0 then
                        break
                end
        end
        return result
end

local function notify(context, title, description)
        local player = getPlayerFromContext(context)
        if not player then
                return
        end
        local effects = _G and _G.EFFECTS
        if not effects or type(effects.ShowNotification) ~= "function" then
                return
        end
        effects.ShowNotification({
                Player = player,
                Title = title,
                Description = description,
        })
end

local function clampExperience(exp: number): number
        local maxExp = XP_TABLE[Leveling.MaxLevel]
        if exp > maxExp then
                return maxExp
        end
        if exp < 0 then
                return 0
        end
        return exp
end

function Leveling.AddExperience(monsterData: table, amount: number, context: table?)
        if type(monsterData) ~= "table" or typeof(amount) ~= "number" then
                return nil
        end
        if amount == 0 then
                return { experienceGained = 0, newExperience = monsterData.Experience or 0, newLevel = monsterData.Level or 1, levelsGained = 0 }
        end

        Leveling.RefreshBaseline(monsterData)

        local currentExp = math.max(0, tonumber(monsterData.Experience) or 0)
        local newExp = clampExperience(currentExp + amount)
        local oldLevel = Leveling.GetLevelForExperience(currentExp)
        local newLevel = Leveling.GetLevelForExperience(newExp)
        monsterData.Experience = newExp
        monsterData.Level = newLevel

        local levelsGained = newLevel - oldLevel
        if levelsGained ~= 0 then
                        applyStatsFromBaseline(monsterData, newLevel)
        end

        if context and context.Model then
                syncModelStats(monsterData, context.Model)
        end

        if context and context.OnAfterChange then
                pcall(context.OnAfterChange, monsterData, newExp, newLevel)
        end

        if amount > 0 then
                if levelsGained > 0 then
                        notify(context, "Level Up!", string.format("Reached level %d after gaining %s EXP.", newLevel, formatNumber(amount)))
                else
                        notify(context, "Experience Gained", string.format("+%s EXP (total %s)", formatNumber(amount), formatNumber(newExp)))
                end
        else
                notify(context, "Experience Updated", string.format("%s EXP applied (total %s)", formatNumber(amount), formatNumber(newExp)))
        end

        return {
                experienceGained = amount,
                newExperience = newExp,
                newLevel = newLevel,
                levelsGained = levelsGained,
        }
end

function Leveling.ApplyDeathPenalty(monsterData: table, percent: number?, context: table?)
        if type(monsterData) ~= "table" then
                return nil
        end
        percent = tonumber(percent) or 0.2
        if percent <= 0 then
                return nil
        end

        Leveling.RefreshBaseline(monsterData)

        local currentExp = math.max(0, tonumber(monsterData.Experience) or 0)
        if currentExp <= 0 then
                return nil
        end

        local loss = math.max(1, math.floor(currentExp * percent))
        local newExp = clampExperience(currentExp - loss)
        local oldLevel = Leveling.GetLevelForExperience(currentExp)
        local newLevel = Leveling.GetLevelForExperience(newExp)
        monsterData.Experience = newExp
        monsterData.Level = newLevel

        local levelsLost = oldLevel - newLevel
        if levelsLost > 0 then
                applyStatsFromBaseline(monsterData, newLevel)
        end

        if context and context.Model then
                syncModelStats(monsterData, context.Model)
        end

        if context and context.OnAfterChange then
                pcall(context.OnAfterChange, monsterData, newExp, newLevel)
        end

        local message
        if levelsLost > 0 then
                message = string.format("Lost %s EXP and dropped to level %d.", formatNumber(loss), newLevel)
        else
                message = string.format("Lost %s EXP (total %s).", formatNumber(loss), formatNumber(newExp))
        end
        notify(context, "Experience Lost", message)

        return {
                experienceLost = loss,
                newExperience = newExp,
                newLevel = newLevel,
                levelsLost = levelsLost,
        }
end

function Leveling.SyncModel(monsterData: table, model: Model?)
        syncModelStats(monsterData, model)
end

return Leveling
