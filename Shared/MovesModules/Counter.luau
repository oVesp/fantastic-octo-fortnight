-- ModuleScript: ReplicatedStorage>Modules>MovesModules>Counter
local Counter = {
    id = "Counter",
    name = "Counter",
    description = "Brace and retaliate with a heavy swing after blocking.",
    rarity = "Amateur",
    power = 22,
    cooldown = 3.5,
    minRange = 0,
    maxRange = 5,
    castTime = 0.55,
    castSpeed = 1.05,
    lockMovement = false,
    tags = { "Melee", "Defensive", "Universal" },
    effects = {
        { type = "BuffSelf", status = "GuardUp", duration = 5 },
        { type = "Haste", duration = 2 },
    },
    mpCost = 6,
}

return Counter
