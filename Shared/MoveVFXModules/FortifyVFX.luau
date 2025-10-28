-- ModuleScript: ReplicatedStorage>Modules>MoveVFXModules>FortifyVFX
local FortifyVFX = {
	moveId = "Fortify"
}

function FortifyVFX.getPack(moveId)
	return {
		cast = {
			effect = "Cast_Fortify",
			sfxStart = "Cast_Fortify"
		},
		travel = {
			trail = "Travel_Fortify", 
			sfxLoop = "Travel_Fortify"
		},
		impact = {
			effect = "Impact_Fortify",
			sfxHit = "Impact_Fortify"
		},
		endcast = {
			sfxEnd = "End_Fortify"
		}
	}
end

-- Handler avançado para VFX customizado
function FortifyVFX.cast(moveId, where, opts)
	-- Implementação customizada de efeitos de lançamento
	--_G.EFFECTS.AuraEffect
	if _G.EFFECTS and _G.EFFECTS.AuraEffect then
		_G.EFFECTS.AuraEffect({
			Name = "FortifyAura",
			Where = where,
			Duration = 1
		})
	end
end

function FortifyVFX.impact(moveId, where, opts)
	-- Implementação customizada de efeitos de impacto
	if _G.EFFECTS and _G.EFFECTS.EmitterEffect then
		_G.EFFECTS.EmitterEffect({
			Name = "Impact_Fortify",
			Where = where,
			Duration = 0.25
		})
	end
end

return FortifyVFX
