-- ModuleScript: ReplicatedStorage>Modules>MovesModules>BasicAttack
local BasicAttack = {
    id = "BasicAttack",
    name = "Basic Attack",
    description = "Reliable strike with no MP cost.",
    rarity = "Amateur",
    power = 14,
    cooldown = 1.6,
    minRange = 0,
    maxRange = 6,
    castTime = 0.45,
    castSpeed = 1.0,
    lockMovement = true,
    effects = {},
    tags = { "Melee", "Universal" },
    mpCost = 0,
}

return BasicAttack
