-- ModuleScript: ReplicatedStorage>Modules>MovesModules>QuickHook
local QuickHook = {
    id = "QuickHook",
    name = "Quick Hook",
    description = "Step in with a looping hook that speeds the user up on hit.",
    rarity = "Amateur",
    power = 24,
    cooldown = 3.0,
    minRange = 1,
    maxRange = 5,
    castTime = 0.4,
    castSpeed = 1.1,
    lockMovement = false,
    tags = { "Melee", "Mobility", "Universal" },
    effects = {
        { type = "Haste", duration = 3 },
    },
    mpCost = 6,
}

function QuickHook.execute(attacker, target, combatManager)
    if combatManager and combatManager.ApplyMoveEffects then
        combatManager:ApplyMoveEffects(attacker, target, QuickHook)
    end
end

return QuickHook
