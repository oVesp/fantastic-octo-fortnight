-- ModuleScript: ReplicatedStorage>Modules>MovesModules>Fortify
local Fortify = {
    id = "Fortify",
    name = "Fortify",
    rarity = "Amateur",
    power = 0,
    cooldown = 5.0,
    minRange = 0,
    maxRange = 8,
    castTime = 0.6,
    castSpeed = 1.0,
    lockMovement = true,
    effects = {
        { type = "BuffSelf", status = "GuardUp", duration = 8 },
        { type = "FortifyAura", duration = 8, refreshDuration = 4 },
    },
    tags = { "Buff", "Defensive", "Construct" },

    accuracy = 0.98,
    mpCost = 8,
}

return Fortify
