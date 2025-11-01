-- ModuleScript: ReplicatedStorage>Modules>MoveVFXModules>VoidRayVFX
local VoidRayVFX = {
        moveId = "VoidRay"
}

VoidRayVFX.blueprint = {
        cast = {
                effect = "Cast_VoidRay",
                sfxStart = "Cast_VoidRay",
        },
        travel = {
                trail = "Travel_VoidRay",
                sfxLoop = "Travel_VoidRay",
                projectile = {
                        template = "Projectile_VoidRay",
                        speed = 120,
                        duration = 0.65,
                        offset = CFrame.new(0, 1.5, 0),
                },
                modifiers = {
                        { id = "MultiProjectile", count = 3, spread = 18, spawnRadius = 0.4 },
                        { id = "SpeedSupport", multiplier = 1.15 },
                        { id = "CurveSupport", amplitude = 2.5, frequency = 1.2 },
                        { id = "Homing", turnRate = 20, duration = 1.0 },
                        { id = "MultiTarget", targets = "all" },
                },
        },
        impact = {
                effect = "Impact_VoidRay",
                sfxHit = "Impact_VoidRay",
        },
        endcast = {
                sfxEnd = "End_VoidRay",
        },
}

VoidRayVFX.modifiers = {
        impact = {
                { id = "ArenaPulse", radius = 14, duration = 1.2, effectName = "VoidRay_ArenaPulse", sfx = "VoidRay_ArenaPulse" },
        },
}

function VoidRayVFX.getPack()
        local pack = {}
        for stageName, stage in pairs(VoidRayVFX.blueprint) do
                if typeof(stage) == "table" then
                        pack[stageName] = {}
                        for key, value in pairs(stage) do
                                if key ~= "modifiers" then
                                        pack[stageName][key] = value
                                end
                        end
                end
        end
        return pack
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
