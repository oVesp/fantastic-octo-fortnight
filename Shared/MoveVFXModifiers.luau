-- ModuleScript: ReplicatedStorage>Modules>MoveVFXModifiers
-- Provides a data-driven modifier system for move VFX stages (cast, travel, impact, end)
-- inspired by Path of Exile's support gems philosophy.

local Modifiers = {}

local registry = {}
local stageOrder = { "cast", "travel", "impact", "endcast" }

local function deepCopy(value)
        if typeof(value) ~= "table" then
                return value
        end
        local copy = {}
        for k, v in pairs(value) do
                copy[k] = deepCopy(v)
        end
        return copy
end

local function tableClone(value)
        if table.clone then
                return table.clone(value)
        end
        local result = {}
        for k, v in pairs(value) do
                result[k] = v
        end
        return result
end

local function isArray(tbl)
        local count = 0
        for k in pairs(tbl) do
                if typeof(k) ~= "number" then
                        return false
                end
                count += 1
        end
        return count > 0
end

local StageContext = {}
StageContext.__index = StageContext

function StageContext.new(stageName, stage, operations, baseContext)
        local self = setmetatable({}, StageContext)
        self.stageName = stageName
        self.stage = stage
        self.operations = operations
        self.baseContext = baseContext
        return self
end

function StageContext:addOperation(operation)
        local opCopy = deepCopy(operation)
        table.insert(self.operations, opCopy)
        return opCopy
end

function StageContext:findOperations(opType)
        local found = {}
        for _, op in ipairs(self.operations) do
                if op.type == opType then
                        table.insert(found, op)
                end
        end
        return found
end

function StageContext:findFirstOperation(opType)
        for _, op in ipairs(self.operations) do
                if op.type == opType then
                        return op
                end
        end
        return nil
end

function StageContext:ensureOperation(opType, defaults)
        local existing = self:findFirstOperation(opType)
        if existing then
                        return existing
        end
        defaults = defaults or {}
        defaults.type = opType
        return self:addOperation(defaults)
end

function StageContext:ensureProjectile(params)
        local existing = self:findFirstOperation("projectile")
        if existing then
                return existing
        end
        params = params or {}
        local baseName = self.stage.baseName or self.baseContext.baseName or ""
        local templateName = params.template or self.stage.projectileTemplate
        if not templateName and baseName ~= "" then
                templateName = "Projectile_" .. baseName
        end
        local projectile = {
                type = "projectile",
                template = templateName,
                speed = params.speed or self.stage.projectileSpeed or 80,
                count = params.count or params.projectiles or self.stage.projectileCount or 1,
                duration = params.duration or self.stage.projectileDuration,
                offset = params.offset or self.stage.projectileOffset,
                anchor = params.anchor or self.stage.projectileAnchor,
                easing = params.easing,
        }
        return self:addOperation(projectile)
end

function StageContext:ensureArena(params)
        local existing = self:findFirstOperation("arena")
        if existing then
                return existing
        end
        params = params or {}
        local baseName = self.stage.baseName or self.baseContext.baseName or "Arena"
        local arena = {
                type = "arena",
                radius = params.radius or self.stage.arenaRadius or 12,
                duration = params.duration or self.stage.arenaDuration or 1.5,
                effectName = params.effectName or self.stage.arenaEffect or ("Arena_" .. baseName),
                attach = params.attach or self.stage.arenaAttach,
                pulses = params.pulses,
                mode = params.mode or self.stage.arenaMode or "pulse",
        }
        return self:addOperation(arena)
end

local function register(def)
        registry[def.id] = def
end

local function modifierAllowsStage(def, stageName)
        if not def.stages then
                return true
        end
        if typeof(def.stages) == "string" then
                return def.stages == stageName
        end
        if typeof(def.stages) == "table" then
                if def.stages[stageName] then
                        return true
                end
                for _, value in ipairs(def.stages) do
                        if value == stageName then
                                return true
                        end
                end
        end
        return false
end

local function pushEntry(target, entry)
        if entry == nil then
                return
        end
        if typeof(entry) == "string" then
                table.insert(target, { id = entry })
                return
        end
        if typeof(entry) ~= "table" then
                return
        end
        if entry.id or entry.Id or entry.ID then
                local copy = deepCopy(entry)
                copy.id = copy.id or entry.Id or entry.ID
                table.insert(target, copy)
                return
        end
        if entry[1] and not isArray(entry) then
                local copy = deepCopy(entry)
                copy.id = copy.id or copy[1]
                copy[1] = nil
                table.insert(target, copy)
                return
        end
        if isArray(entry) then
                for _, child in ipairs(entry) do
                        pushEntry(target, child)
                end
                return
        end
        for _, stageName in ipairs(stageOrder) do
                if entry[stageName] then
                        pushEntry(target, entry[stageName])
                end
        end
        if entry.all then
                pushEntry(target, entry.all)
        end
        if entry.global then
                pushEntry(target, entry.global)
        end
end

local function gatherModifiers(stageName, stage, context)
        local combined = {}
        local function absorb(source)
                if not source then
                        return
                end
                if typeof(source) ~= "table" then
                        pushEntry(combined, source)
                        return
                end
                if source.id or source.Id or source.ID then
                        pushEntry(combined, source)
                        return
                end
                if source[1] and not isArray(source) then
                        pushEntry(combined, source)
                        return
                end
                if isArray(source) then
                        for _, child in ipairs(source) do
                                pushEntry(combined, child)
                        end
                        return
                end
                if source.all then
                        pushEntry(combined, source.all)
                end
                if source.global then
                        pushEntry(combined, source.global)
                end
                if source[stageName] then
                        pushEntry(combined, source[stageName])
                end
        end

        absorb(stage.modifiers)
        absorb(context.blueprintModifiers)
        absorb(context.moduleModifiers)
        absorb(context.runtimeModifiers)

        return combined
end

local function applyModifiers(contextObj, entries)
        for _, entry in ipairs(entries) do
                if entry and entry.id then
                        local modifier = registry[entry.id]
                        if modifier and modifierAllowsStage(modifier, contextObj.stageName) then
                                local params = entry.options or entry.config or entry.settings or entry
                                if params == entry then
                                        params = tableClone(params)
                                        params.id = nil
                                        params.options = nil
                                        params.config = nil
                                        params.settings = nil
                                else
                                        params = deepCopy(params)
                                end
                                if modifier.apply then
                                        modifier.apply(contextObj, params)
                                end
                        end
                end
        end
end

function Modifiers.ResolveStage(stageName, blueprintStage, context)
        local stage = deepCopy(blueprintStage or {})
        stage.stageName = stageName
        stage.baseName = stage.baseName or context.baseName
        stage.moveId = stage.moveId or context.moveId

        local operations = {}
        local existingOps = stage.operations
        if typeof(existingOps) == "table" then
                for _, op in ipairs(existingOps) do
                        local copy = deepCopy(op)
                        if copy.type then
                                table.insert(operations, copy)
                        end
                end
        end

        local contextObj = StageContext.new(stageName, stage, operations, context)

        local function ensureDefault(opType, default)
                if contextObj:findFirstOperation(opType) then
                        return
                end
                if default then
                        contextObj:addOperation(default)
                end
        end

        if stage.effect then
                ensureDefault("emitter", {
                        type = "emitter",
                        name = stage.effect,
                        duration = stage.duration,
                        offset = stage.offset,
                        attach = stage.attach,
                        weld = stage.weld,
                })
        end
        if stage.trail then
                ensureDefault("trail", {
                        type = "trail",
                        name = stage.trail,
                        duration = stage.trailDuration or stage.duration,
                        attach = stage.attachTrail,
                        offset = stage.trailOffset,
                })
        end
        if stage.sfxStart then
                ensureDefault("sound:start", {
                        type = "sound",
                        cue = "start",
                        name = stage.sfxStart,
                        volume = stage.sfxVolume,
                        loop = false,
                })
        end
        if stage.sfxLoop then
                ensureDefault("sound:loop", {
                        type = "sound",
                        cue = "loop",
                        name = stage.sfxLoop,
                        volume = stage.sfxVolume,
                        loop = true,
                })
        end
        if stage.sfxHit then
                ensureDefault("sound:hit", {
                        type = "sound",
                        cue = "hit",
                        name = stage.sfxHit,
                        volume = stage.sfxVolume,
                        loop = false,
                })
        end
        if stage.sfxEnd then
                ensureDefault("sound:end", {
                        type = "sound",
                        cue = "end",
                        name = stage.sfxEnd,
                        volume = stage.sfxVolume,
                        loop = false,
                })
        end
        if stage.projectile then
                local projectile = deepCopy(stage.projectile)
                projectile.type = "projectile"
                contextObj:addOperation(projectile)
        end
        if stage.arena then
                local arena = deepCopy(stage.arena)
                arena.type = "arena"
                contextObj:addOperation(arena)
        end

        local entries = gatherModifiers(stageName, stage, context)
        applyModifiers(contextObj, entries)

        stage.operations = operations
        stage.appliedModifiers = entries
        return stage
end

Modifiers.StageContext = StageContext
Modifiers.deepCopy = deepCopy
Modifiers.register = register

--[[
        Built-in modifiers
]]--

register({
        id = "MultiProjectile",
        stages = { travel = true, impact = true },
        apply = function(contextObj, params)
                local projectile = contextObj:ensureProjectile(params)
                projectile.count = math.max(1, params.count or params.projectiles or projectile.count or 1)
                projectile.spreadAngle = params.spread or params.spreadAngle or projectile.spreadAngle or 0
                projectile.pattern = params.pattern or projectile.pattern or "cone"
                projectile.fireDelay = params.fireDelay or projectile.fireDelay
                projectile.randomize = params.randomize or projectile.randomize
                if params.spawnRadius then
                        projectile.spawnRadius = params.spawnRadius
                end
                if params.offset then
                        projectile.offset = params.offset
                end
                if params.template then
                        projectile.template = params.template
                end
        end,
})

register({
        id = "SpeedSupport",
        stages = { cast = true, travel = true, impact = true },
        apply = function(contextObj, params)
                local multiplier = params.multiplier or params.speedMultiplier or 1
                for _, op in ipairs(contextObj:findOperations("projectile")) do
                        if params.speed then
                                op.speed = params.speed
                        else
                                op.speed = (op.speed or params.baseSpeed or 60) * multiplier
                        end
                        if params.duration then
                                op.duration = params.duration
                        end
                        if params.acceleration then
                                op.acceleration = params.acceleration
                        end
                end
                if params.duration then
                        for _, op in ipairs(contextObj.operations) do
                                if op.type == "emitter" or op.type == "trail" then
                                        op.duration = params.duration
                                end
                        end
                end
        end,
})

register({
        id = "CurveSupport",
        stages = { travel = true },
        apply = function(contextObj, params)
                local projectile = contextObj:ensureProjectile(params)
                projectile.curve = projectile.curve or {}
                projectile.curve.amplitude = params.amplitude or params.height or projectile.curve.amplitude or 0
                projectile.curve.axis = params.axis or projectile.curve.axis or Vector3.new(0, 1, 0)
                projectile.curve.frequency = params.frequency or projectile.curve.frequency or 1
                projectile.curve.style = params.style or projectile.curve.style or "sine"
        end,
})

register({
        id = "OffsetSupport",
        stages = { cast = true, travel = true, impact = true, endcast = true },
        apply = function(contextObj, params)
                local offset = params.offset or params.cframe or params.vector
                if not offset and typeof(params) == "Vector3" then
                        offset = params
                end
                if not offset then
                        return
                end
                if params.applyTo == "projectile" then
                        for _, op in ipairs(contextObj:findOperations("projectile")) do
                                op.offset = offset
                        end
                        return
                end
                if params.applyTo == "arena" then
                        for _, op in ipairs(contextObj:findOperations("arena")) do
                                op.offset = offset
                        end
                        return
                end
                for _, op in ipairs(contextObj.operations) do
                        op.offset = offset
                end
        end,
})

register({
        id = "MultiTarget",
        stages = { travel = true, impact = true },
        apply = function(contextObj, params)
                local projectile = contextObj:ensureProjectile(params)
                projectile.targets = params.targets or params.mode or projectile.targets or "all"
                projectile.splitCount = params.split or projectile.splitCount
                projectile.chaining = params.chaining or projectile.chaining
        end,
})

register({
        id = "Homing",
        stages = { travel = true },
        apply = function(contextObj, params)
                local projectile = contextObj:ensureProjectile(params)
                projectile.homing = projectile.homing or {}
                projectile.homing.turnRate = params.turnRate or params.speed or projectile.homing.turnRate or 12
                projectile.homing.seekDuration = params.duration or projectile.homing.seekDuration
                projectile.homing.maxAngle = params.maxAngle or projectile.homing.maxAngle
                projectile.homing.allowRetarget = params.allowRetarget
        end,
})

register({
        id = "ArenaPulse",
        stages = { cast = true, impact = true, endcast = true },
        apply = function(contextObj, params)
                local arena = contextObj:ensureArena(params)
                arena.radius = params.radius or arena.radius
                arena.duration = params.duration or arena.duration
                arena.effectName = params.effectName or params.effect or arena.effectName
                arena.sfx = params.sfx or arena.sfx
                arena.interval = params.interval or arena.interval
                arena.mode = params.mode or arena.mode
                arena.attach = params.attach or arena.attach
                arena.pulses = params.pulses or arena.pulses
        end,
})

register({
        id = "CustomOperation",
        stages = { cast = true, travel = true, impact = true, endcast = true },
        apply = function(contextObj, params)
                if typeof(params) ~= "table" then
                        return
                end
                if not params.type then
                        return
                end
                contextObj:addOperation(params)
        end,
})

return Modifiers
