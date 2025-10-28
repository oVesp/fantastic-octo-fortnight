-- ModuleScript: ReplicatedStorage>Modules>MoveVFX
local M = {}
local NAME = {
	BasicAttack = "BasicAttack",
	VoidRay = "VoidRay",
	CosmicThread = "CosmicThread",
	WeavePulse = "WeavePulse",
	-- ... outros movimentos
}

local DEFAULTS = {
	castEffect = "Cast_Default",
	impactEffect = "Impact_Default",
	sfxCast = "Cast_Default",
	sfxImpact = "Impact_Default",
	sfxEnd = "End_Default",
}

-- Carregar módulos VFX individuais
local function loadVFXModules()
	local vfxMap = {}
	local vfxFolder = script.Parent:WaitForChild("MoveVFXModules")

	if vfxFolder then
		for _, moduleScript in ipairs(vfxFolder:GetChildren()) do
			if moduleScript:IsA("ModuleScript") then
				local success, vfxData = pcall(require, moduleScript)
				if success and vfxData and vfxData.moveId then
					vfxMap[vfxData.moveId] = vfxData
				end
			end
		end
	end

	return vfxMap
end

local VFX_MODULES = loadVFXModules()

function M.Resolve(moveId)
	local baseName = NAME[moveId] or moveId

	-- Tentar carregar do módulo VFX específico
	local vfxModule = VFX_MODULES[moveId]
	if vfxModule then
		return vfxModule.getPack(moveId), vfxModule
	end

	-- Fallback para configuração padrão
	local pack = {
		cast = {effect = "Cast_" .. baseName, sfxStart = "Cast_" .. baseName},
		travel = {trail = "Travel_" .. baseName, sfxLoop = "Travel_" .. baseName},
		impact = {effect = "Impact_" .. baseName, sfxHit = "Impact_" .. baseName},
		endcast = {sfxEnd = "End_" .. baseName},
	}

	return pack, nil
end

return M