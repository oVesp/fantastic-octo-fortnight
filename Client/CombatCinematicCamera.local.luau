-- LocalScript: StarterPlayerScripts>CombatCinematicCamera
-- Listens for combat camera toggle events and adjusts the current camera to frame combatants.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CombatCameraToggle = Remotes:WaitForChild("CombatCameraToggle")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local state = {
	active = false,
	connection = nil,
	defaultType = nil,
	defaultSubject = nil,
	defaultFov = nil,
	focusModels = {},
	localFocus = nil,
	lastModels = nil,
	spectateButton = nil,
	spectateButtonConnection = nil,
}

local function copyModels(models: {Model})
	local copy = table.create and table.create(#models) or {}
	for _, model in ipairs(models) do
		table.insert(copy, model)
	end
	return copy
end

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

local function stopCameraControl(clearLastModels: boolean?)
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

        if clearLastModels ~= false then
                state.lastModels = nil
        end
end

local function startCameraControl(models: {Model})
        if #models == 0 then
                return
        end

        if state.active then
                stopCameraControl(false)
        end

        state.defaultType = camera.CameraType
        state.defaultSubject = camera.CameraSubject
        state.defaultFov = camera.FieldOfView

        state.focusModels = copyModels(models)
        state.localFocus = determineLocalFocus(models)
        state.lastModels = copyModels(models)
        state.active = true

        camera.CameraType = Enum.CameraType.Scriptable

        local targetFov = 68

        state.connection = RunService.RenderStepped:Connect(function()
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

                local aggregate = Vector3.zero
                local count = 0
                for _, model in ipairs(validModels) do
                        if model ~= focus then
                                local pos = modelPosition(model)
                                if pos then
                                        aggregate += pos
                                        count += 1
                                end
                        end
                end

                local otherCenter
                if count > 0 then
                        otherCenter = aggregate / count
                else
                        local look = pivotCF and pivotCF.LookVector or Vector3.new(0, 0, -1)
                        otherCenter = focusPos + look * 12
                end

                local lookTarget = focusPos:Lerp(otherCenter, 0.35)

                local direction = otherCenter - focusPos
                if direction.Magnitude < 1 then
                        direction = pivotCF and pivotCF.LookVector or Vector3.new(0, 0, -1)
                else
                        direction = direction.Unit
                end

                local right = direction:Cross(Vector3.new(0, 1, 0))
                if right.Magnitude < 0.1 then
                        right = Vector3.new(1, 0, 0)
                else
                        right = right.Unit
                end

                local camOffset = (-direction * 16) + Vector3.new(0, 6, 0) + right * 4
                local desiredCF = CFrame.new(focusPos + camOffset, lookTarget)
                camera.CFrame = camera.CFrame:Lerp(desiredCF, 0.12)

                local fov = math.clamp(targetFov + (count * 3), 62, 78)
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
                stopCameraControl(true)
        end
end)

player.CharacterRemoving:Connect(function()
        if state.active then
                stopCameraControl(true)
        end
end)

local function detachSpectateButton()
        if state.spectateButtonConnection then
                state.spectateButtonConnection:Disconnect()
                state.spectateButtonConnection = nil
        end
        state.spectateButton = nil
end

local function handleSpectateButton(button)
        if state.spectateButton == button then
                return
        end

        detachSpectateButton()
        state.spectateButton = button

        if not button or not button.Parent then
                return
        end

        state.spectateButtonConnection = button.MouseButton1Click:Connect(function()
                if state.active then
                        stopCameraControl(false)
                        return
                end

                local models = state.lastModels
                if not models then
                        return
                end

                local valid = {}
                for _, model in ipairs(models) do
                        if typeof(model) == "Instance" and model:IsA("Model") and model.Parent then
                                table.insert(valid, model)
                        end
                end

                if #valid > 0 then
                        startCameraControl(valid)
                end
        end)
end

local function findSpectateButton()
        local playerGui = player:FindFirstChildOfClass("PlayerGui")
        if not playerGui then
                return nil
        end

        local interfaceGui = playerGui:FindFirstChild("Interface")
        if not interfaceGui then
                return nil
        end

        local frame = interfaceGui:FindFirstChild("Frame")
        if not frame then
                return nil
        end

        local button = frame:FindFirstChild("Spectate")
        if button and button:IsA("GuiButton") then
                return button
        end

        return nil
end

local function tryBindSpectateButton()
        local button = findSpectateButton()
        if button then
                handleSpectateButton(button)
        end
end

tryBindSpectateButton()

local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 5)
if playerGui then
        playerGui.DescendantAdded:Connect(function(descendant)
                if descendant.Name == "Spectate" and descendant:IsA("GuiButton") then
                        handleSpectateButton(descendant)
                end
        end)

        playerGui.DescendantRemoving:Connect(function(descendant)
                if descendant == state.spectateButton then
                        detachSpectateButton()
                end
        end)
else
        player.ChildAdded:Connect(function(child)
                if child:IsA("PlayerGui") then
                        playerGui = child
                        tryBindSpectateButton()
                        child.DescendantAdded:Connect(function(descendant)
                                if descendant.Name == "Spectate" and descendant:IsA("GuiButton") then
                                        handleSpectateButton(descendant)
                                end
                        end)

                        child.DescendantRemoving:Connect(function(descendant)
                                if descendant == state.spectateButton then
                                        detachSpectateButton()
                                end
                        end)
                end
        end)
end
