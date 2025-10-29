-- ModuleScript: ReplicatedStorage>Modules>MovesModules>QuickHook
local QuickHook = {
    id = "QuickHook",
    name = "Quick Hook",
    rarity = "Amateur",
    power = 20,
    cooldown = 2.8,
    minRange = 1,
    maxRange = 5,
    castTime = 0.45,
    castSpeed = 1.1,
    lockMovement = false,
    effects = {
        { type = "Haste", duration = 4 },
    },
    tags = { "Melee", "Mobility", "Universal" },

    accuracy = 0.92,
    mpCost = 5,
}

function QuickHook.execute(attacker, target, combatManager)
    if combatManager and combatManager.ApplyMoveEffects then
        combatManager:ApplyMoveEffects(attacker, target, QuickHook)
    end
end

return QuickHook
