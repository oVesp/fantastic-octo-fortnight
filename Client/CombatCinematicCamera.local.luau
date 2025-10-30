-- LocalScript: StarterPlayerScripts>CombatCinematicCamera
-- Listens for combat camera toggle events and adjusts the current camera to frame combatants.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CombatCameraToggle = Remotes:WaitForChild("CombatCameraToggle")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local rng = Random.new()

local state = {
active = false,
connection = nil,
defaultType = nil,
defaultSubject = nil,
defaultFov = nil,
focusModels = {},
localFocus = nil,
modeIndex = 1,
modeStartTime = 0,
modeContext = nil,
}

type CameraContext = {
focus: Model,
focusPos: Vector3,
pivotCF: CFrame?,
lookVector: Vector3,
otherCenter: Vector3,
groupCenter: Vector3,
radius: number,
otherCount: number,
}

local CameraModes = {}

local function registerCameraMode(mode)
CameraModes[#CameraModes + 1] = mode
end

registerCameraMode({
name = "focus_follow",
duration = 6,
update = function(_, info: CameraContext)
local lookTarget = info.focusPos:Lerp(info.otherCenter, 0.35)

local direction = info.otherCenter - info.focusPos
if direction.Magnitude < 1 then
direction = info.lookVector
else
direction = direction.Unit
end

local right = direction:Cross(Vector3.new(0, 1, 0))
if right.Magnitude < 0.1 then
right = Vector3.new(1, 0, 0)
else
right = right.Unit
end

local distance = 14 + math.clamp(info.radius * 0.5, 0, 12)
local height = 6 + math.clamp(info.radius * 0.25, 0, 6)
local sideOffset = 3 + math.clamp(info.radius * 0.2, 0, 5)

local camOffset = (-direction * distance) + Vector3.new(0, height, 0) + right * sideOffset
local desiredCF = CFrame.new(info.focusPos + camOffset, lookTarget)
local desiredFov = math.clamp(68 + (info.otherCount * 3), 60, 80)

return desiredCF, desiredFov, 0.12
end,
})

registerCameraMode({
name = "top_down",
duration = 5,
update = function(_, info: CameraContext)
local lookTarget = info.groupCenter
local height = math.max(18, info.radius * 2)
local forward = info.lookVector.Unit * math.min(info.radius * 0.25, 8)
local position = lookTarget + Vector3.new(0, height, 0) + forward
local desiredCF = CFrame.new(position, lookTarget)
local desiredFov = math.clamp(72 + info.radius * 0.1, 62, 85)

return desiredCF, desiredFov, 0.18
end,
})

registerCameraMode({
name = "center_orbit",
duration = 7,
enter = function(context)
context.angle = rng:NextNumber(0, math.pi * 2)
context.direction = rng:NextNumber(0, 1) > 0.5 and 1 or -1
context.speed = math.rad(rng:NextInteger(18, 32))
end,
update = function(context, info: CameraContext, dt: number)
local angle = context.angle or 0
local speed = context.speed or math.rad(24)
local direction = context.direction or 1
context.angle = angle + speed * direction * (dt or 0)

local orbitRadius = math.max(16, info.radius * 1.4)
local height = 8 + info.radius * 0.3
local offset = Vector3.new(math.cos(context.angle) * orbitRadius, height, math.sin(context.angle) * orbitRadius)
local desiredCF = CFrame.new(info.groupCenter + offset, info.groupCenter)
local desiredFov = math.clamp(70 + info.otherCount * 2, 62, 78)

return desiredCF, desiredFov, 0.1
end,
})

registerCameraMode({
name = "wide_center",
duration = 6,
update = function(_, info: CameraContext)
local toCenter = info.groupCenter - info.focusPos
if toCenter.Magnitude < 2 then
toCenter = info.lookVector
else
toCenter = toCenter.Unit
end

local distance = 12 + info.radius
local height = 5 + info.radius * 0.2
local desiredPosition = info.groupCenter - toCenter * distance + Vector3.new(0, height, 0)
local desiredCF = CFrame.new(desiredPosition, info.groupCenter)
local desiredFov = math.clamp(66 + info.radius * 0.4, 60, 82)

return desiredCF, desiredFov, 0.14
end,
})

local function getRoot(model: Model?)
        if not model then
                return nil
        end

        if model.PrimaryPart then
                return model.PrimaryPart
        end

        local humanoidRoot = model:FindFirstChild("HumanoidRootPart")
        if humanoidRoot and humanoidRoot:IsA("BasePart") then
                return humanoidRoot
        end

        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.RootPart then
                return humanoid.RootPart
        end

        for _, child in ipairs(model:GetChildren()) do
                if child:IsA("BasePart") then
                        return child
                end
        end

        return nil
end

local function modelPosition(model: Model?)
        if not model or not model.Parent then
                return nil
        end

        local root = getRoot(model)
        if root then
                return root.Position
        end

        local ok, pivot = pcall(function()
                return model:GetPivot()
        end)

        if ok then
                return pivot.Position
        end

        return nil
end

local function getOwnerId(model: Model?)
        if not model then
                return nil
        end

        local ownerId = model:GetAttribute("OwnerId")
        if typeof(ownerId) == "number" then
                return ownerId
        end

        return nil
end

local function determineLocalFocus(models: {Model})
local localUserId = player.UserId

for _, model in ipairs(models) do
if getOwnerId(model) == localUserId then
                        return model
                end
        end

        for _, model in ipairs(models) do
                if model == player.Character then
                        return model
                end
        end

        return models[1]
end

local function stopCameraControl()
        if state.connection then
                state.connection:Disconnect()
                state.connection = nil
        end

        if state.defaultType then
                camera.CameraType = state.defaultType
        else
                camera.CameraType = Enum.CameraType.Custom
        end

        if state.defaultSubject and state.defaultSubject.Parent then
                camera.CameraSubject = state.defaultSubject
        end

        if state.defaultFov then
                camera.FieldOfView = state.defaultFov
        end

        state.active = false
state.focusModels = {}
state.localFocus = nil
state.modeContext = nil
end

local function startCameraControl(models: {Model})
if #models == 0 then
return
        end

        if state.active then
                stopCameraControl()
        end

        state.defaultType = camera.CameraType
        state.defaultSubject = camera.CameraSubject
        state.defaultFov = camera.FieldOfView

state.focusModels = models
state.localFocus = determineLocalFocus(models)
state.active = true
state.modeContext = nil

camera.CameraType = Enum.CameraType.Scriptable

local targetFov = 68

local function setMode(index: number)
state.modeIndex = index
state.modeStartTime = os.clock()
state.modeContext = {}
local mode = CameraModes[index]
if mode and mode.enter then
mode.enter(state.modeContext)
end
end

if #CameraModes > 0 then
setMode(rng:NextInteger(1, #CameraModes))
end

state.connection = RunService.RenderStepped:Connect(function(dt)
if not state.active then
return
end

local validModels = table.create(#state.focusModels)
                for _, model in ipairs(state.focusModels) do
                        if model and model.Parent then
                                table.insert(validModels, model)
                        end
                end

                if #validModels == 0 then
                        stopCameraControl()
                        return
                end

                if not state.localFocus or not state.localFocus.Parent then
                        state.localFocus = determineLocalFocus(validModels)
                end

local focus = state.localFocus
if not focus or not focus.Parent then
stopCameraControl()
return
end

local focusPos = modelPosition(focus)
if not focusPos then
stopCameraControl()
return
end

local pivotCF
do
local ok, cf = pcall(function()
return focus:GetPivot()
end)
if ok then
pivotCF = cf
end
end

local sum = Vector3.zero
local count = 0
local otherSum = Vector3.zero
local otherCount = 0
local radius = 0
for _, model in ipairs(validModels) do
local pos = modelPosition(model)
if pos then
sum += pos
count += 1
if model ~= focus then
otherSum += pos
otherCount += 1
local dist = (pos - focusPos).Magnitude
if dist > radius then
radius = dist
end
end
end
end

if count == 0 then
stopCameraControl()
return
end

radius = math.max(radius, 6)

local lookVector = pivotCF and pivotCF.LookVector or Vector3.new(0, 0, -1)
local groupCenter = sum / count
local otherCenter
if otherCount > 0 then
otherCenter = otherSum / otherCount
else
otherCenter = focusPos + lookVector * 12
end

local frameContext: CameraContext = {
focus = focus,
focusPos = focusPos,
pivotCF = pivotCF,
lookVector = lookVector,
otherCenter = otherCenter,
groupCenter = groupCenter,
radius = radius,
otherCount = otherCount,
}

if #CameraModes == 0 then
return
end

local mode = CameraModes[state.modeIndex]
if not mode then
setMode(1)
mode = CameraModes[state.modeIndex]
end

if not mode then
return
end

local elapsed = os.clock() - state.modeStartTime
if mode.duration and elapsed >= mode.duration then
local nextIndex = (state.modeIndex % #CameraModes) + 1
setMode(nextIndex)
mode = CameraModes[state.modeIndex]
end

if not mode then
return
end

local desiredCF, desiredFov, lerpAlpha = mode.update(state.modeContext, frameContext, dt)
if desiredCF then
local alpha = math.clamp(lerpAlpha or 0.12, 0.02, 0.5)
camera.CFrame = camera.CFrame:Lerp(desiredCF, alpha)
end

local fov = desiredFov or targetFov
camera.FieldOfView += (fov - camera.FieldOfView) * 0.1
end)
end

CombatCameraToggle.OnClientEvent:Connect(function(isActive: boolean?, models)
        if isActive then
                        local parsed = {}
                        if typeof(models) == "Instance" then
                                if models:IsA("Model") then
                                        table.insert(parsed, models)
                                end
                        elseif typeof(models) == "table" then
                                for _, value in pairs(models) do
                                        if typeof(value) == "Instance" and value:IsA("Model") then
                                                table.insert(parsed, value)
                                        end
                                end
                        end

                        if #parsed == 0 then
                                return
                        end

                        startCameraControl(parsed)
        else
                stopCameraControl()
        end
end)

player.CharacterRemoving:Connect(function()
        if state.active then
                stopCameraControl()
        end
end)
