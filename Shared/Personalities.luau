-- ModuleScript: ReplicatedStorage>Modules>Personalities
local module = {}

module.Personalities = {
	Aggressive = {
		weights = {
			engage = 25, 
			retreat = 2, 
			attack = 45, 
			reposition = 8, 
			defend = 5, 
			retarget = 5,
			buffSelf = 0, 
			debuff = 5, 
			taunt = 5,
			kite = 0, 
			orbit = 0
		},
		movementStyle = {
			jitterRange = {0.3, 0.8},        -- Decisões mais rápidas
			intentionDuration = 1.2,         -- Intenções mais curtas
			personalSpace = 6,               -- Espaço pessoal menor
			preferCloseRange = true,
			aggressionMultiplier = 1.3,
			retreatThreshold = 0.1           -- Só recua com menos de 10% de vida
		},
		trainingMultipliers = {
			Strength = 1.3, Speed = 1.1, Intelligence = 0.8, 
			Defense = 1.2, Luck = 0.9, Skill = 1.0
		}
	},

	Unpredictable = {
		weights = {
			engage = 10, 
			retreat = 10, 
			attack = 15, 
			reposition = 10, 
			defend = 10, 
			retarget = 10,
			buffSelf = 10, 
			debuff = 10, 
			taunt = 10,
			kite = 10, 
			orbit = 10
		},
		movementStyle = {
			jitterRange = {0.5, 1.5},        -- Variação grande no tempo de decisão
			intentionDuration = 1.8,         -- Intenções de duração média
			personalSpace = 8,               -- Espaço pessoal médio
			preferCloseRange = false,
			aggressionMultiplier = 1.0,
			retreatThreshold = 0.3
		},
		trainingMultipliers = {
			Strength = 1.0, Speed = 1.4, Intelligence = 1.1, 
			Defense = 0.9, Luck = 0.8, Skill = 1.0
		}
	},

	--Defensive = {
	--	weights = {
	--		engage = 5, 
	--		retreat = 20, 
	--		attack = 15, 
	--		reposition = 25, 
	--		defend = 30, 
	--		retarget = 10,
	--		buffSelf = 10, 
	--		debuff = 0, 
	--		taunt = 2,
	--		kite = 25, 
	--		orbit = 18
	--	},
	--	movementStyle = {
	--		jitterRange = {0.8, 1.8},        -- Decisões mais lentas e cuidadosas
	--		intentionDuration = 2.5,         -- Intenções mais longas
	--		personalSpace = 12,              -- Espaço pessoal maior
	--		preferCloseRange = false,
	--		aggressionMultiplier = 0.7,
	--		retreatThreshold = 0.5           -- Recua com 50% de vida
	--	},
	--	trainingMultipliers = {
	--		Strength = 0.9, Speed = 1.0, Intelligence = 1.1, 
	--		Defense = 1.4, Luck = 1.3, Skill = 1.0
	--	}
	--},

	Strategist = {
		weights = {
			engage = 10, 
			retreat = 15, 
			attack = 20, 
			reposition = 15, 
			defend = 10, 
			retarget = 15,
			buffSelf = 25, 
			debuff = 15, 
			taunt = 5,
			kite = 20, 
			orbit = 15
		},
		movementStyle = {
			jitterRange = {0.7, 1.3},        -- Decisões ponderadas
			intentionDuration = 2.0,         -- Intenções médias
			personalSpace = 9,               -- Espaço pessoal balanceado
			preferCloseRange = false,
			aggressionMultiplier = 0.9,
			retreatThreshold = 0.4
		},
		trainingMultipliers = {
			Strength = 0.8, Speed = 0.9, Intelligence = 1.5, 
			Defense = 1.0, Luck = 1.2, Skill = 1.0
		}
	},

	Reckless = {
		weights = {
			engage = 35, 
			retreat = 0, 
			attack = 40, 
			reposition = 10, 
			defend = 0, 
			retarget = 10,
			buffSelf = 0, 
			debuff = 5, 
			taunt = 5,
			kite = 0, 
			orbit = 0
		},
		movementStyle = {
			jitterRange = {0.2, 0.6},        -- Decisões muito rápidas
			intentionDuration = 0.8,         -- Intenções muito curtas
			personalSpace = 4,               -- Espaço pessoal mínimo
			preferCloseRange = true,
			aggressionMultiplier = 1.6,
			retreatThreshold = 0.05          -- Quase nunca recua
		},
		trainingMultipliers = {
			Strength = 1.4, Speed = 1.3, Intelligence = 0.7, 
			Defense = 0.8, Luck = 0.6, Skill = 1.0
		}
	},

	--Supportive = {
	--	weights = {
	--		engage = 5, 
	--		retreat = 25, 
	--		attack = 5, 
	--		reposition = 15, 
	--		defend = 30, 
	--		retarget = 5,
	--		buffSelf = 20, 
	--		debuff = 10, 
	--		taunt = 5,
	--		kite = 25, 
	--		orbit = 20
	--	},
	--	movementStyle = {
	--		jitterRange = {0.9, 1.6},        -- Decisões lentas
	--		intentionDuration = 2.2,         -- Intenções longas
	--		personalSpace = 11,              -- Mantém distância
	--		preferCloseRange = false,
	--		aggressionMultiplier = 0.6,
	--		retreatThreshold = 0.6
	--	},
	--	trainingMultipliers = {
	--		Strength = 0.9, Speed = 1.0, Intelligence = 1.3, 
	--		Defense = 1.2, Luck = 1.4, Skill = 1.0
	--	}
	--},

	Trickster = {
		weights = {
			engage = 5, 
			retreat = 15, 
			attack = 15, 
			reposition = 30, 
			defend = 5, 
			retarget = 25,
			buffSelf = 10, 
			debuff = 15, 
			taunt = 10,
			kite = 20, 
			orbit = 25
		},
		movementStyle = {
			jitterRange = {0.4, 1.2},        -- Variação média
			intentionDuration = 1.5,         -- Intenções de duração variada
			personalSpace = 7,               -- Espaço pessoal menor
			preferCloseRange = false,
			aggressionMultiplier = 0.8,
			retreatThreshold = 0.35
		},
		trainingMultipliers = {
			Strength = 0.8, Speed = 1.5, Intelligence = 1.2, 
			Defense = 0.9, Luck = 1.0, Skill = 1.0
		}
	},

	--Cautious = {
	--	weights = {
	--		engage = 8, 
	--		retreat = 20, 
	--		attack = 12, 
	--		reposition = 25, 
	--		defend = 20, 
	--		retarget = 8,
	--		buffSelf = 15, 
	--		debuff = 5, 
	--		taunt = 2,
	--		kite = 30, 
	--		orbit = 25
	--	},
	--	movementStyle = {
	--		jitterRange = {1.0, 2.0},        -- Decisões muito lentas
	--		intentionDuration = 3.0,         -- Intenções muito longas
	--		personalSpace = 14,              -- Espaço pessoal máximo
	--		preferCloseRange = false,
	--		aggressionMultiplier = 0.5,
	--		retreatThreshold = 0.7           -- Recua facilmente
	--	},
	--	trainingMultipliers = {
	--		Strength = 0.7, Speed = 1.2, Intelligence = 1.1, 
	--		Defense = 1.3, Luck = 1.5, Skill = 1.0
	--	}
	--}
}

function module:RollPersonality()
	local personalities = {}
	for name, data in pairs(module.Personalities) do
		table.insert(personalities, name)
	end
	return personalities[math.random(1, #personalities)]
end

function module.GetDefault()
	return module.Personalities.Cautious
end

function module.GetMovementStyle(personalityName)
	local personality = module.Personalities[personalityName]
	if personality and personality.movementStyle then
		return personality.movementStyle
	end
	return module.Personalities.Cautious.movementStyle
end

function module.GetJitterForPersonality(personalityName)
	local movementStyle = module.GetMovementStyle(personalityName)
	local minJitter = movementStyle.jitterRange[1] or 0.5
	local maxJitter = movementStyle.jitterRange[2] or 1.5
	return math.random(minJitter * 100, maxJitter * 100) / 100
end

return module