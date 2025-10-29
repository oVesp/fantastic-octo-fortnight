-- ModuleScript: ReplicatedStorage>Modules>MovesModules>Counter
local Counter = {
    id = "Counter",
    name = "Counter",
    rarity = "Amateur",
    power = 18,
    cooldown = 3.2,
    minRange = 0,
    maxRange = 5,
    castTime = 0.5,
    castSpeed = 1.05,
    lockMovement = false,
    effects = {
        { type = "BuffSelf", status = "GuardUp", duration = 4 },
        { type = "Haste", duration = 2 },
    },
    tags = { "Melee", "Defensive", "Universal" },

    accuracy = 0.97,
    mpCost = 4,
}

return Counter
