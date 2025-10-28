-- ModuleScript: ReplicatedStorage>Modules>MovesModules>WeavePulse
local WeavePulse = {
	id = "WeavePulse",
	name = "Weave Pulse",
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
-- function WeavePulse.execute(attacker, target)
--     -- Lógica customizada do movimento
--     -- Para WeavePulse, usar lógica genérica de dano
-- end

return WeavePulse