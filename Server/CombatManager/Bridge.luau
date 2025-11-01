-- ReplicatedStorage/Modules/EffectsMoveBridge.lua (or merge into your Effects module)
local RP = game:GetService("ReplicatedStorage")
local MoveVFX = require(RP.Modules:WaitForChild("MoveVFX"))

local Bridge = {}

local function getRoot(model: Instance)
        if not model then return nil end
        if model.PrimaryPart then return model.PrimaryPart end
        local hrp = model:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp end
        for _, ch in ipairs(model:GetChildren()) do
                if ch:IsA("BasePart") then return ch end
        end
        return model
end

-- Internal: use your EffectsSystem with correct parameters
local function playStage(stage, moveId, where, opts)
        opts = opts or {}
        local pack, adv = MoveVFX.Resolve(moveId, opts.Modifiers)

        -- Advanced hook first (if present for this stage)
        if adv and type(adv[stage]) == "function" then
                local ok = pcall(adv[stage], moveId, where, opts)
                if ok then return end
        end

        local info = pack[stage]
        if not info then return end

        local casterModel = opts.CasterModel
        local targetModel = opts.TargetModel
        local casterRoot = opts.CasterRoot or (casterModel and getRoot(casterModel))
        local targetRoot = opts.TargetRoot or (targetModel and getRoot(targetModel))
        local originPart = where or casterRoot

        if info.operations and _G.EFFECTS and _G.EFFECTS.ExecuteStageOperations then
                local context = {
                        StageName = stage,
                        MoveId = moveId,
                        OriginPart = originPart,
                        CasterModel = casterModel,
                        TargetModel = targetModel,
                        CasterRoot = casterRoot,
                        TargetRoot = targetRoot,
                        Duration = opts.Duration,
                        Volume = opts.Volume,
                        Options = opts,
                        TargetList = opts.TargetList,
                }
                _G.EFFECTS.ExecuteStageOperations(info.operations, context)
                return
        end

        -- Fallback legacy behavior if ExecuteStageOperations is unavailable
        if info.effect and _G.EFFECTS and _G.EFFECTS.EmitterEffect then
                local posCFrame
                if originPart and originPart.CFrame then
                        posCFrame = originPart.CFrame
                elseif typeof(opts.Position) == "CFrame" then
                        posCFrame = opts.Position
                end
                _G.EFFECTS.EmitterEffect({
                        Name = info.effect,
                        Position = posCFrame,
                        Offset = opts.Offset,
                        Duration = opts.Duration or 0.5,
                        Weld = originPart,
                })
        end

        if info.trail and stage == "travel" and _G.EFFECTS and _G.EFFECTS.TrailEffect then
                _G.EFFECTS.TrailEffect({
                        Name = info.trail,
                        Part = originPart,
                        Duration = opts.Duration or 0.4,
                        Offset = opts.Offset,
                })
        end

        local function sfx(name, defaultWhere)
                if name and _G.EFFECTS and _G.EFFECTS.PlaySound then
                        _G.EFFECTS.PlaySound(name, {
                                Where = defaultWhere or originPart,
                                Volume = opts.Volume,
                                Duration = opts.SfxDuration,
                                FadeOutTime = opts.FadeOutTime,
                                RandomPitch = opts.RandomPitch,
                        })
                end
        end

        sfx(info.sfxStart, originPart)
        sfx(info.sfxLoop, originPart)
        sfx(info.sfxHit, targetRoot or originPart)
        sfx(info.sfxEnd, casterRoot or originPart)
end

-- Public API (called by CombatManager)
function Bridge.PlayCast(casterModel, moveId, castTime)
        local casterRoot = getRoot(casterModel)
        playStage("cast", moveId, casterRoot, {
                Duration = castTime or 1.0,
                CasterModel = casterModel,
                CasterRoot = casterRoot,
        })
end

function Bridge.PlayTravel(casterModel, moveId, travelRef, travelTime, opts)
        local casterRoot = getRoot(casterModel)
        opts = opts or {}
        opts.Duration = opts.Duration or travelTime or 0.5
        opts.CasterModel = casterModel
        opts.CasterRoot = casterRoot
        playStage("travel", moveId, travelRef or casterRoot, opts)
end

function Bridge.PlayImpact(casterModel, targetModel, moveId)
        local casterRoot = getRoot(casterModel)
        local targetRoot = getRoot(targetModel) or casterRoot
        playStage("impact", moveId, targetRoot, {
                CasterModel = casterModel,
                CasterRoot = casterRoot,
                TargetModel = targetModel,
                TargetRoot = targetRoot,
        })
end

function Bridge.PlayEnd(casterModel, moveId)
        local casterRoot = getRoot(casterModel)
        playStage("endcast", moveId, casterRoot, {
                CasterModel = casterModel,
                CasterRoot = casterRoot,
        })
end

return Bridge
