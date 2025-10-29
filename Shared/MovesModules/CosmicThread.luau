-- ModuleScript: ReplicatedStorage>Modules>MovesModules>CosmicThread
local CosmicThread = {
    id = "CosmicThread",
    name = "Cosmic Thread",
    description = "Snare the target in astral filaments, sapping their speed.",
    rarity = "Advanced",
    power = 22,
    cooldown = 3.2,
    minRange = 5,
    maxRange = 16,
    castTime = 0.7,
    castSpeed = 0.95,
    lockMovement = false,
    tags = { "Magic", "Progenitor", "Ranged" },
    effects = {
        { type = "Slow", duration = 5, chance = 0.8 },
        { type = "DamageOverTime", duration = 4, dps = 5 },
    },
    mpCost = 12,
}

return CosmicThread
