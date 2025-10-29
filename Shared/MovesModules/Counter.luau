-- ModuleScript: ReplicatedStorage>Modules>MovesModules>VoidRay
local VoidRay = {
	id = "VoidRay",
	name = "Void Ray",
	rarity = "Amateur",
	power = 30,
	cooldown = 4.0,
	minRange = 6,
	maxRange = 18,
	castTime = 0.9,
	effects = {
		{ type = "DamageOverTime", duration = 8, dps = 6, stacks = 1, status = "Burn" },
		{ type = "Slow", duration = 4 },
	},
	tags = {"Magic", "Progenitor", "Ranged"},
}

-- Função de execução customizada para efeitos especiais
function VoidRay.execute(attacker, target, combatManager)
	-- Lógica customizada do Void Ray
	-- Exemplo: aplicar debuff de redução de defesa
	if combatManager and combatManager.ApplyMoveEffects then
		combatManager:ApplyMoveEffects(attacker, target, VoidRay)
	end
end

return VoidRay