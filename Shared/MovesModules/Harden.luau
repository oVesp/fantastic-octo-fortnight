-- ModuleScript: ReplicatedStorage>Modules>MovesModules>Harden
local Harden = {
    id = "Harden",
    name = "Harden",
    rarity = "Amateur",
    power = 0,
    cooldown = 3.5,
    minRange = 0,
    maxRange = 6,
    castTime = 0.5,
    castSpeed = 1.0,
    lockMovement = true,
    effects = {
        { type = "BuffSelf", status = "GuardUp", duration = 6 },
    },
    tags = { "Buff", "Defensive", "Construct" },

    accuracy = 0.98,
    mpCost = 5,
}

return Harden
