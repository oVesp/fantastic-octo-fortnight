-- ModuleScript: ReplicatedStorage>Modules>MovesModules>RockFist
local RockFist = {
    id = "RockFist",
    name = "Rock Fist",
    rarity = "Amateur",
    power = 28,
    cooldown = 3.4,
    minRange = 0,
    maxRange = 6,
    castTime = 0.7,
    castSpeed = 0.9,
    lockMovement = true,
    effects = {
        { type = "Stun", duration = 1 },
    },
    tags = { "Melee", "Construct" },

    accuracy = 0.88,
    mpCost = 6,
}

return RockFist
