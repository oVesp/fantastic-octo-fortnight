-- ModuleScript: ReplicatedStorage>Modules>MoveVFXModules>FortifyVFX
local FortifyVFX = {
        moveId = "Fortify"
}

FortifyVFX.blueprint = {
        cast = {
                effect = "Cast_Fortify",
                sfxStart = "Cast_Fortify",
        },
        travel = {
                trail = "Travel_Fortify",
                sfxLoop = "Travel_Fortify",
        },
        impact = {
                effect = "Impact_Fortify",
                sfxHit = "Impact_Fortify",
        },
        endcast = {
                sfxEnd = "End_Fortify",
        },
}

FortifyVFX.modifiers = {
        cast = {
                { id = "ArenaPulse", radius = 8, duration = 8, effectName = "FortifyAura", attach = "caster", mode = "aura" },
        },
}

function FortifyVFX.getPack(moveId)
        local pack = {}
        for stageName, stage in pairs(FortifyVFX.blueprint) do
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
function FortifyVFX.cast(moveId, where, opts)
        if not (_G.EFFECTS and _G.EFFECTS.AuraEffect) then
                return
        end

        local rootPart = where
        if where and where:IsA("Model") then
                rootPart = where.PrimaryPart or where:FindFirstChildWhichIsA("BasePart")
        end
        if not (rootPart and rootPart:IsA("BasePart")) then
                return
        end
        local bodyParts = {}
        for _, part in ipairs(where.Parent:GetChildren()) do
                if part:IsA("BasePart") then
                        table.insert(bodyParts, part)
                end
        end
        _G.EFFECTS.AuraEffect({
                Name = "FortifyAura",
                LocationParts = bodyParts,
                Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(160, 215, 255)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 140, 255)),
                }),
                Duration = opts and opts.Duration or 8,
                AuraReference = "Fortify",
        })
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
