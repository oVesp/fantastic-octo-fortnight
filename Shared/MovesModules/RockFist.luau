-- ModuleScript: ReplicatedStorage>Modules>MovesModules>RockFist
local RockFist = {
    id = "RockFist",
    name = "Rock Fist",
    description = "Drive a stone-coated fist into the foe for burst damage.",
    rarity = "Amateur",
    power = 32,
    cooldown = 3.6,
    minRange = 0,
    maxRange = 6,
    castTime = 0.6,
    castSpeed = 0.95,
    lockMovement = true,
    tags = { "Melee", "Construct" },
    effects = {
        { type = "Stun", duration = 1.2, chance = 0.5 },
    },
    mpCost = 9,
}

return RockFist
