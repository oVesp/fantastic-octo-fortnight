-- ModuleScript: ReplicatedStorage>Modules>MovesModules>BasicAttack
local RockFist = {
	id = "RockFist",
	name = "RockFist",
	rarity = "Amateur",
	power = 0,
	cooldown = 1.2,
	minRange = 0,
	maxRange = 6,
	castTime = 0.4,
	castSpeed = 1.0,
	lockMovement = true,
	effects = {},
	tags = {"Melee", "Universal"},

	-- Overrides específicos para este movimento
	accuracy = 0.96,
	mpCost = 0,
}

-- Função de execução customizada (opcional)
-- function RockFist.execute(attacker, target)
--     -- Lógica customizada do movimento
--     -- Para RockFist, usar lógica genérica de dano
-- end

return RockFist