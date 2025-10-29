-- ModuleScript: ReplicatedStorage>Modules>MovesModules>Fortify
local Fortify = {
    id = "Fortify",
    name = "Fortify",
    description = "Anchor in place, raising defenses and sharing the guard with allies.",
    rarity = "Amateur",
    power = 0,
    cooldown = 6.0,
    minRange = 0,
    maxRange = 8,
    castTime = 0.7,
    castSpeed = 0.95,
    lockMovement = true,
    tags = { "Buff", "Defensive", "Construct" },
    effects = {
        { type = "BuffSelf", status = "GuardUp", duration = 8 },
        { type = "FortifyAura", duration = 8, refreshDuration = 4 },
        { type = "Shield", duration = 6, power = 35 },
    },
    mpCost = 10,
}

return Fortify
