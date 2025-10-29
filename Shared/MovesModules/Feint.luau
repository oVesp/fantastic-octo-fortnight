-- ModuleScript: ReplicatedStorage>Modules>MovesModules>Feint
local Feint = {
    id = "Feint",
    name = "Feint",
    description = "Quick jab that throws opponents off-balance.",
    rarity = "Amateur",
    power = 10,
    cooldown = 2.4,
    minRange = 0,
    maxRange = 5,
    castTime = 0.3,
    castSpeed = 1.15,
    lockMovement = false,
    tags = { "Melee", "Debuff", "Universal" },
    effects = {
        { type = "Disarm", duration = 3, chance = 0.6 },
    },
    mpCost = 4,
}

return Feint
