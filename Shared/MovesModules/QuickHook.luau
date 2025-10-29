-- ModuleScript: ReplicatedStorage>Modules>MovesModules>QuickHook
local QuickHook = {
	id = "QuickHook",
	name = "QuickHook",
	rarity = "Amateur",
	power = 15,
	cooldown = 4.0,
	minRange = 1,
	maxRange = 5,
	castTime = 2.0,
	effects = {
		{ type = "Haste", duration = 8 },
	},
	tags = {"Physical", "Progenitor", "Ranged"},
}

-- Função de execução customizada para efeitos especiais
function QuickHook.execute(attacker, target, combatManager)
	-- Lógica customizada do Void Ray
	-- Exemplo: aplicar debuff de redução de defesa
	if combatManager and combatManager.ApplyMoveEffects then
		combatManager:ApplyMoveEffects(attacker, target, QuickHook)
	end
end

return QuickHook