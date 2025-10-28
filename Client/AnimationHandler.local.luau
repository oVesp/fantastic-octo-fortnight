local AnimationRemoteEvent = game.ReplicatedStorage.Remotes:WaitForChild("AnimationRemoteEvent")
local AnimationManager = require(game.ReplicatedStorage.Modules.AnimationManager)


local function PlayCastAnimation(monster, animationId)
	if not monster or not monster.Parent then return end

	local humanoid = monster:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	-- Load and play animation
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId

	local animationTrack = animator:LoadAnimation(animation)
	animationTrack:Play()

	-- Clean up when animation ends or monster is destroyed
	monster.Destroying:Connect(function()
		if animationTrack then
			animationTrack:Stop()
		end
	end)
end

AnimationRemoteEvent.OnClientEvent:Connect(function(action, monster, animationId)
	if action == "PlayCastAnimation" then
		PlayCastAnimation(monster, animationId)
	end
end)
