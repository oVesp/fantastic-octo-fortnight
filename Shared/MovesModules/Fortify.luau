-- ModuleScript: ReplicatedStorage>Modules>MovesModules>BasicAttack
local Fortify = {
	id = "Fortify",
	name = "Fortify",
	rarity = "Amateur",
	power = 0,
	cooldown = 1.2,
	minRange = 0,
	maxRange = 6,
	castTime = 0.4,
	castSpeed = 1.0,
	lockMovement = true,
        effects = {"BuffSelf", "FortifyAura"},
        tags = {"Buff", "Defensive", "Construct"},

	-- Overrides específicos para este movimento
	accuracy = 0.96,
	mpCost = 0,
}

-- Função de execução customizada (opcional)
-- function Fortify.execute(attacker, target)
--     -- Lógica customizada do movimento
--     -- Para Fortify, usar lógica genérica de dano
-- end

return Fortify