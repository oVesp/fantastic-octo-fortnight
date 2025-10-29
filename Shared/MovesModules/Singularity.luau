-- ModuleScript: ReplicatedStorage>Modules>MovesModules>Singularity
local Singularity = {
    id = "Singularity",
    name = "Singularity",
    description = "Collapse space into a miniature singularity that drags everything inward.",
    rarity = "Specialist",
    power = 40,
    cooldown = 6.5,
    minRange = 2,
    maxRange = 18,
    castTime = 1.15,
    castSpeed = 0.85,
    lockMovement = true,
    tags = { "Magic", "Progenitor", "Ranged", "AoE" },
    effects = {
        { type = "Pull", duration = 1.2 },
        { type = "Slow", duration = 4 },
        { type = "DamageOverTime", duration = 4, dps = 8 },
    },
    mpCost = 22,
}

return Singularity
