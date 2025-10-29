-- ModuleScript: ReplicatedStorage>Modules>MovesModules>CosmicThread
local CosmicThread = {
    id = "CosmicThread",
    name = "Cosmic Thread",
    rarity = "Advanced",
    power = 20,
    cooldown = 3.0,
    minRange = 4,
    maxRange = 14,
    castTime = 0.75,
    castSpeed = 0.95,
    lockMovement = false,
    effects = {
        { type = "Slow", duration = 6 },
    },
    tags = { "Magic", "Progenitor", "Ranged" },

    accuracy = 0.88,
    mpCost = 10,
}

return CosmicThread
