-- ModuleScript: ReplicatedStorage>Modules>MovesModules>Harden
local Harden = {
    id = "Harden",
    name = "Harden",
    description = "Briefly reinforce your plating for a modest guard boost.",
    rarity = "Amateur",
    power = 0,
    cooldown = 3.0,
    minRange = 0,
    maxRange = 6,
    castTime = 0.4,
    castSpeed = 1.05,
    lockMovement = true,
    tags = { "Buff", "Defensive", "Construct" },
    effects = {
        { type = "BuffSelf", status = "GuardUp", duration = 6, power = 0.15 },
    },
    mpCost = 6,
}

return Harden
