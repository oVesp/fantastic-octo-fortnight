-- ModuleScript: ReplicatedStorage>Modules>MovesModules>WarpLance
local WarpLance = {
    id = "WarpLance",
    name = "Warp Lance",
    description = "Blink-step forward and skewer the target with a threaded lance.",
    rarity = "Advanced",
    power = 28,
    cooldown = 3.4,
    minRange = 4,
    maxRange = 20,
    castTime = 0.6,
    castSpeed = 1.1,
    lockMovement = false,
    tags = { "Magic", "Progenitor", "Ranged", "Mobility" },
    effects = {
        { type = "Slow", duration = 3, chance = 0.6 },
        { type = "Haste", duration = 2 },
    },
    mpCost = 14,
}

return WarpLance
