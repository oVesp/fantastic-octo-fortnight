-- ModuleScript: ReplicatedStorage>Modules>MovesModules>BasicAttack
local BasicAttack = {
    id = "BasicAttack",
    name = "Basic Attack",
    rarity = "Amateur",
    power = 12,
    cooldown = 1.4,
    minRange = 0,
    maxRange = 6,
    castTime = 0.4,
    castSpeed = 1.0,
    lockMovement = true,
    effects = {},
    tags = { "Melee", "Universal" },

    accuracy = 0.95,
    mpCost = 0,
}

return BasicAttack
