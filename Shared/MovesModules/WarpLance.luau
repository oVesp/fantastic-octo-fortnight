-- ModuleScript: ReplicatedStorage>Modules>MovesModules>WarpLance
local WarpLance = {
    id = "WarpLance",
    name = "Warp Lance",
    rarity = "Advanced",
    power = 26,
    cooldown = 3.5,
    minRange = 5,
    maxRange = 18,
    castTime = 0.65,
    castSpeed = 1.05,
    lockMovement = false,
    effects = {
        { type = "Slow", duration = 3 },
    },
    tags = { "Magic", "Progenitor", "Ranged", "Mobility" },

    accuracy = 0.87,
    mpCost = 12,
}

return WarpLance
