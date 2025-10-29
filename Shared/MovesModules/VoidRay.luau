-- ModuleScript: ReplicatedStorage>Modules>MovesModules>VoidRay
local VoidRay = {
    id = "VoidRay",
    name = "Void Ray",
    description = "Channel a beam of entropic energy that lingers as a burn.",
    rarity = "Advanced",
    power = 34,
    cooldown = 4.8,
    minRange = 6,
    maxRange = 20,
    castTime = 0.9,
    castSpeed = 0.9,
    lockMovement = true,
    tags = { "Magic", "Progenitor", "Ranged" },
    effects = {
        { type = "DamageOverTime", duration = 8, status = "Burn", dps = 7 },
        { type = "Slow", duration = 4 },
    },
    mpCost = 16,
}

function VoidRay.execute(attacker, target, combatManager)
    if combatManager and combatManager.ApplyMoveEffects then
        combatManager:ApplyMoveEffects(attacker, target, VoidRay)
    end
end

return VoidRay
