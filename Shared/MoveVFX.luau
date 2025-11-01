-- ModuleScript: ReplicatedStorage>Modules>MoveVFX
-- Resolves move VFX packages with support-style modifiers that can customize
-- each stage (cast, travel, impact, end) similar to Path of Exile support gems.

local M = {}

local Modifiers = require(script.Parent:WaitForChild("MoveVFXModifiers"))

local NAME = {
        BasicAttack = "BasicAttack",
        VoidRay = "VoidRay",
        CosmicThread = "CosmicThread",
        WeavePulse = "WeavePulse",
        -- ... outros movimentos
}


local STAGES = { "cast", "travel", "impact", "endcast" }

local function deepCopy(value)
        return Modifiers.deepCopy(value)
end

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

local function buildDefaultBlueprint(baseName)
        local pack = {
                cast = {
                        effect = "Cast_" .. baseName,
                        sfxStart = "Cast_" .. baseName,
                },
                travel = {
                        trail = "Travel_" .. baseName,
                        sfxLoop = "Travel_" .. baseName,
                },
                impact = {
                        effect = "Impact_" .. baseName,
                        sfxHit = "Impact_" .. baseName,
                },
                endcast = {
                        sfxEnd = "End_" .. baseName,
                },
        }
        for _, stageName in ipairs(STAGES) do
                if pack[stageName] then
                        pack[stageName].baseName = baseName
                end
        end
        return pack
end

local function convertToBlueprint(raw, baseName)
        if not raw then
                return buildDefaultBlueprint(baseName)
        end
        local blueprint = {}
        for _, stageName in ipairs(STAGES) do
                local info = raw[stageName]
                if info then
                        blueprint[stageName] = deepCopy(info)
                        blueprint[stageName].baseName = blueprint[stageName].baseName or baseName
                end
        end
        if raw.modifiers then
                blueprint.modifiers = deepCopy(raw.modifiers)
        end
        return blueprint
end

local function resolveStage(stageName, blueprintStage, context)
        if not blueprintStage then
                return nil
        end
        return Modifiers.ResolveStage(stageName, blueprintStage, context)
end

function M.Resolve(moveId, runtimeModifiers)
        local baseName = NAME[moveId] or moveId
        local module = VFX_MODULES[moveId]

        local rawBlueprint
        if module then
                if typeof(module.blueprint) == "function" then
                        rawBlueprint = module.blueprint(moveId)
                elseif module.blueprint then
                        rawBlueprint = module.blueprint
                end
        end

        if not rawBlueprint and module and typeof(module.getPack) == "function" then
                rawBlueprint = module.getPack(moveId)
        end

        if not rawBlueprint then
                rawBlueprint = buildDefaultBlueprint(baseName)
        end

        -- Allow legacy modules that only return strings (no stage tables)
        if typeof(rawBlueprint) ~= "table" then
                rawBlueprint = buildDefaultBlueprint(baseName)
        end

        local blueprint = convertToBlueprint(rawBlueprint, baseName)

        local resolved = {}
        for _, stageName in ipairs(STAGES) do
                local stageBlueprint = blueprint[stageName]
                if stageBlueprint then
                        resolved[stageName] = resolveStage(stageName, stageBlueprint, {
                                moveId = moveId,
                                baseName = baseName,
                                blueprintModifiers = blueprint.modifiers,
                                moduleModifiers = module and module.modifiers,
                                runtimeModifiers = runtimeModifiers,
                        })
                end
        end

        resolved.metadata = {
                moveId = moveId,
                baseName = baseName,
        }

        return resolved, module
end

return M
