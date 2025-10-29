-- ModuleScript: ReplicatedStorage>Modules>MovesModules>PebbleShot
local PebbleShot = {
    id = "PebbleShot",
    name = "Pebble Shot",
    description = "Launch a cluster of stones that chip foes down at range.",
    rarity = "Amateur",
    power = 20,
    cooldown = 2.8,
    minRange = 5,
    maxRange = 18,
    castTime = 0.5,
    castSpeed = 1.0,
    lockMovement = true,
    tags = { "Ranged", "Construct" },
    effects = {
        { type = "Slow", duration = 3, chance = 0.7 },
    },
    mpCost = 7,
}

return PebbleShot
