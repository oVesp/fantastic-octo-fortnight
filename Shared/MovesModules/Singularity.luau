-- ModuleScript: ReplicatedStorage>Modules>MovesModules>Singularity
local Singularity = {
    id = "Singularity",
    name = "Singularity",
    rarity = "Specialist",
    power = 36,
    cooldown = 5.5,
    minRange = 2,
    maxRange = 16,
    castTime = 1.1,
    castSpeed = 0.85,
    lockMovement = true,
    effects = {
        { type = "Pull", duration = 1 },
        { type = "Slow", duration = 4 },
    },
    tags = { "Magic", "Progenitor", "Ranged", "AoE" },

    accuracy = 0.86,
    mpCost = 18,
}

return Singularity
