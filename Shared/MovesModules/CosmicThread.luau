-- ModuleScript: ReplicatedStorage>Modules>MovesModules>CosmicThread
local CosmicThread = {
	id = "CosmicThread",
	name = "Cosmic Thread",
	rarity = "Amateur",
	power = 10,
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
-- function CosmicThread.execute(attacker, target)
--     -- Lógica customizada do movimento
--     -- Para CosmicThread, usar lógica genérica de dano
-- end

return CosmicThread