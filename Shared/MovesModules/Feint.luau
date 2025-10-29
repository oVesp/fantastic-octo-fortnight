-- ModuleScript: ReplicatedStorage>Modules>MovesModules>Feint
local Feint = {
    id = "Feint",
    name = "Feint",
    rarity = "Amateur",
    power = 12,
    cooldown = 2.2,
    minRange = 0,
    maxRange = 5,
    castTime = 0.35,
    castSpeed = 1.1,
    lockMovement = false,
    effects = {
        { type = "Disarm", duration = 3 },
    },
    tags = { "Melee", "Debuff", "Universal" },

    accuracy = 0.93,
    mpCost = 3,
}

return Feint
