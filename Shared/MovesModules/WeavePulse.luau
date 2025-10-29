-- ModuleScript: ReplicatedStorage>Modules>MovesModules>WeavePulse
local WeavePulse = {
    id = "WeavePulse",
    name = "Weave Pulse",
    description = "Emit a pulse of cosmic thread energy that weakens foes.",
    rarity = "Amateur",
    power = 18,
    cooldown = 2.2,
    minRange = 3,
    maxRange = 14,
    castTime = 0.55,
    castSpeed = 1.0,
    lockMovement = true,
    tags = { "Magic", "Progenitor", "Ranged" },
    effects = {
        { type = "Disarm", duration = 2, chance = 0.4 },
    },
    mpCost = 8,
}

return WeavePulse
