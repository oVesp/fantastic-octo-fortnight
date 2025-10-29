-- ModuleScript: ReplicatedStorage>Modules>MovesModules>VoidRay
local VoidRay = {
    id = "VoidRay",
    name = "Void Ray",
    rarity = "Advanced",
    power = 32,
    cooldown = 4.5,
    minRange = 6,
    maxRange = 18,
    castTime = 0.9,
    castSpeed = 0.9,
    lockMovement = true,
    effects = {
        { type = "DamageOverTime", duration = 8, status = "Burn", dps = 6 },
        { type = "Slow", duration = 4 },
    },
    tags = { "Magic", "Progenitor", "Ranged" },

    accuracy = 0.84,
    mpCost = 14,
}

function VoidRay.execute(attacker, target, combatManager)
    if combatManager and combatManager.ApplyMoveEffects then
        combatManager:ApplyMoveEffects(attacker, target, VoidRay)
    end
end

return VoidRay
