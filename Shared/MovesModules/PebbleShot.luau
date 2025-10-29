-- ModuleScript: ReplicatedStorage>Modules>MovesModules>PebbleShot
local PebbleShot = {
    id = "PebbleShot",
    name = "Pebble Shot",
    rarity = "Amateur",
    power = 18,
    cooldown = 2.6,
    minRange = 4,
    maxRange = 16,
    castTime = 0.55,
    castSpeed = 1.0,
    lockMovement = true,
    effects = {
        { type = "Slow", duration = 3 },
    },
    tags = { "Ranged", "Construct" },

    accuracy = 0.9,
    mpCost = 4,
}

return PebbleShot
