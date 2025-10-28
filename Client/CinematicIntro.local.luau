-- ClientScripts/CinematicCamera.lua

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local remote = game.ReplicatedStorage.Remotes:WaitForChild("CinematicCamera")

remote.OnClientEvent:Connect(function(boss, duration)
	if not boss or not boss.PrimaryPart then return end
	local originalType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable

	local pos = boss.PrimaryPart.Position
	local startCFrame = CFrame.new(pos + Vector3.new(0, 10, 25), pos)
	local endCFrame = CFrame.new(pos + Vector3.new(15, 8, 5), pos)

	camera.CFrame = startCFrame
	TweenService:Create(camera, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ CFrame = endCFrame }):Play()

	task.delay(duration, function()
		camera.CameraType = originalType
	end)
end)
