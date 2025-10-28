-- ModuleScript: ReplicatedStorage>Modules>MoveVFXModules>VoidRayVFX
local VoidRayVFX = {
	moveId = "VoidRay"
}

function VoidRayVFX.getPack(moveId)
	return {
		cast = {
			effect = "Cast_VoidRay",
			sfxStart = "Cast_VoidRay"
		},
		travel = {
			trail = "Travel_VoidRay", 
			sfxLoop = "Travel_VoidRay"
		},
		impact = {
			effect = "Impact_VoidRay",
			sfxHit = "Impact_VoidRay"
		},
		endcast = {
			sfxEnd = "End_VoidRay"
		}
	}
end

-- Handler avançado para VFX customizado
function VoidRayVFX.impact(moveId, where, opts)
	-- Implementação customizada de efeitos de impacto
	if _G.EFFECTS and _G.EFFECTS.EmitterEffect then
		_G.EFFECTS.EmitterEffect({
			Name = "Impact_VoidRay",
			Where = where,
			Duration = 0.25
		})
	end
end

return VoidRayVFX