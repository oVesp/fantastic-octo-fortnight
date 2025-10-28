assert(game:GetService("RunService"):IsClient(), "Crater should only be ran client-side to save on server performance. Try :FireAllClients() if you need to activate this from the server.")
local Crater = {}
--------------------
local TweenService = game:GetService("TweenService")
local partCacheModule = require(script.PartCache)
--------------------
Crater.Settings = {
	useGroundMaterial = true; --Determines whether the crater will use the ground below it as a base for material, color, and transparency.
	debrisColor = Color3.new(0.6,0.6,0.6); --Color for debris. Only used if useGroundMaterial is set to false.
	debrisMaterial = Enum.Material.Slate; --Material for debris. Only used if useGroundMaterial is set to false.
	timeBeforeRemoval = 5; --The time it takes for craters and debris to disappear.
	doFlyingDebris = true; --Determines whether or not debris will fly out of the crater.
	FlyingRocks = 0,
	centerFlyingDebris = false; --Determines whether or not the debris will come from the center of the crater or all around the crater's radius.
	hasDust = true; --Toggles dust emissions on crater creation.
	rockSkipInterval = 7; --Inversely proportional to the number of rocks which will be skipped when making the crater. Creates a sort of "jagged" effect on your craters. Set to 0 to disable.
	debrisFolder = game.Workspace.Debris; --Recommended to create a folder named "Debris" or something of the like for this. This folder will house all of your PartCache instances and debris.
	FilterDescendantsInstances = { --Used for raycasting. Add anything which you would not like to be recognized as ground.
		game.Players.LocalPlayer.Character;
	};
	fadeInTime = 0.05; --Determines how fast your craters come out of the ground.
	fadeOutTime = 2; --Determines how fast your craters sink back into the ground after timeBeforeRemoval has passed.
	forceNumberDebris = 0; --Forces a number of debris to be used per-crater. Set to 0 to disable.
}
local function getAllChrs() local t = {}; for _,v in ipairs(game.Players:GetChildren()) do table.insert(t, v.Character) return t end end 
table.insert(Crater.Settings.FilterDescendantsInstances,Crater.Settings.debrisFolder)
game.Players.LocalPlayer.CharacterAdded:Connect(function()
	table.insert(Crater.Settings.FilterDescendantsInstances,game.Players.LocalPlayer.Character)
end)
local gfxlvl: Enum.SavedQualitySetting = UserSettings().GameSettings.SavedQualityLevel
local currentQuality = 0
function doGFXLevel()
	if gfxlvl == Enum.SavedQualitySetting.Automatic then
		currentQuality = 0.5
	elseif gfxlvl == Enum.SavedQualitySetting.QualityLevel10 then
		currentQuality = 1
	else
		currentQuality = tonumber("0."..string.sub(gfxlvl.Name,13))
	end
end
doGFXLevel()
UserSettings().GameSettings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(function()
	gfxlvl = UserSettings().GameSettings.SavedQualityLevel
	doGFXLevel()
end)

--------------------
--[[
	Use example:
	This module should only be used on the client.
	----------------
	local Crater = require(game:GetService("ReplicatedStorage").Crater)
	local chr = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()
	
	while wait(5) do
		Crater.formCrater({
			Position = chr.HumanoidRootPart.Position;
			Radius = 10;
			rockSize = 2.5;
		})
	end
]]

--------------------
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = Crater.Settings.FilterDescendantsInstances
local partCache = partCacheModule.new(Instance.new("Part"), 1000, Crater.Settings.debrisFolder)
--------------------
function Crater.formCrater(craterProperties)
	local self = Crater
	local random = Random.new()
	local radius: number = craterProperties.Radius
	local Position: Vector3 = craterProperties.Position
	local rockSize: Vector3 = Vector3.new(craterProperties.rockSize,craterProperties.rockSize,craterProperties.rockSize)
	local useGroundMaterial: boolean = craterProperties.useGroundMaterial ~= nil and craterProperties.useGroundMaterial or self.Settings.useGroundMaterial
	local debrisColor: Color3 = craterProperties.debrisColor or self.Settings.debrisColor
	local debrisMaterial: Enum = craterProperties.debrisMaterial or self.Settings.debrisMaterial
	local timeBeforeRemoval: number = craterProperties.timeBeforeRemoval or self.Settings.timeBeforeRemoval
	local doFlyingDebris: boolean = craterProperties.doFlyingDebris ~= nil and craterProperties.doFlyingDebris or self.Settings.doFlyingDebris
	local FlyingRocks: number = craterProperties["FlyingRocks"]
	local centerFlyingDebris: boolean = craterProperties.centerFlyingDebris ~= nil and craterProperties.centerFlyingDebris or self.Settings.centerFlyingDebris
	local hasDust: boolean = craterProperties.hasDust ~= nil and craterProperties.hasDust or self.Settings.hasDust
	local rockSkipInterval: number = craterProperties.rockSkipInterval or self.Settings.rockSkipInterval
	local fadeInTime: number = craterProperties.fadeInTime or self.Settings.fadeInTime
	local fadeOutTime: number = craterProperties.fadeOutTime or self.Settings.fadeOutTime
	local forceNumberDebris: number = craterProperties.forceNumberDebris or self.Settings.forceNumberDebris
	local Material
	local Transparency 
	local Color
	local raycast = workspace:Raycast(Position,Vector3.new(0,-25,0),params)
	if raycast and raycast.Instance then
		Position = raycast.Position + Vector3.new(0,1,0)
	end
	if hasDust == true then
		local dust = script.VFX.CraterDust:Clone()
		dust.Parent = self.Settings.debrisFolder
		dust.Position = Position
		dust.Size = Vector3.new(radius,2,radius)
		dust.Smoke.Size = NumberSequence.new(radius * 0.5)
		dust.Smoke.Speed = NumberRange.new(radius * 1.5,radius * 3)
		local dustEmitCount = math.floor(radius * 1.5) + math.floor(craterProperties.rockSize * 1.5)
		if dustEmitCount > 75 then
			dustEmitCount = 75
		end
		dust.Smoke:Emit(dustEmitCount * currentQuality)
		game.Debris:AddItem(dust,10)
		if raycast and raycast.Instance then
			dust.Smoke.Color = ColorSequence.new(raycast.Instance.Color)
		end
	end
	local parts = 0
	if forceNumberDebris > 0 then
		parts = forceNumberDebris
		rockSkipInterval = 0
	else
		for i = 0,radius * 8,craterProperties.rockSize do
			parts += 1
		end

	end
	local function getXAndZPositions(angle)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		return x, z
	end
	local angle = 30
	local otherAngle = 360/parts
	local noPartInterval = math.random(rockSkipInterval - 1,rockSkipInterval + 1)
	local lastSkipped = 0
	for i = 1, parts do
		local cf = CFrame.new(Position)
		local newCF = cf * CFrame.fromEulerAnglesXYZ(0, math.rad(angle), 0) * CFrame.new(radius/2 + radius/15, 10, 0)
		local ray = game.Workspace:Raycast(newCF.Position, Vector3.new(0, -15, 0), params)
		angle += otherAngle
		--chance to not make rocks
		if i - lastSkipped < 3  and lastSkipped > 0 then continue end
		if i % noPartInterval == 0 and rockSkipInterval > 0 then
			lastSkipped = i
			noPartInterval = math.random(rockSkipInterval - 1,rockSkipInterval + 1)
			continue;
		end
		if ray then
			local part = partCache:GetPart()
			TweenService:Create(part,TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),{Size = Vector3.new(rockSize.X * math.random(1150,1500) / 1000, rockSize.Y * math.random(725,900) / 1000, rockSize.Z * math.random(1150,1500) / 1000) * random:NextNumber(1, 1.5)}):Play()
			--part.Size = Vector3.new(rockSize.X * math.random(1150,1500) / 1000, rockSize.Y * math.random(725,900) / 1000, rockSize.Z * math.random(1150,1500) / 1000) * random:NextNumber(1, 1.5)
			if fadeInTime > 0.036 then
				part.CFrame = CFrame.new(ray.Position - Vector3.new(0, (rockSize.Y * 0.4) + rockSize.Y * 1.5, 0), Position) * CFrame.fromEulerAnglesXYZ(random:NextNumber(-1,-0.3),random:NextNumber(-0.15,0.15),random:NextNumber(-.15,.15))
				TweenService:Create(part,TweenInfo.new(fadeInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),{CFrame = CFrame.new(ray.Position - Vector3.new(0, rockSize.Y * math.random(325,450) / 1000, 0), Position) * CFrame.fromEulerAnglesXYZ(random:NextNumber(-1,-0.3),random:NextNumber(-0.15,0.15),random:NextNumber(-.15,.15))}):Play()
			else
				part.CFrame = CFrame.new(ray.Position - Vector3.new(0, rockSize.Y * math.random(325,450) / 1000, 0), Position) * CFrame.fromEulerAnglesXYZ(random:NextNumber(-1,-0.3),random:NextNumber(-0.15,0.15),random:NextNumber(-.15,.15))
			end
			part.Parent = self.Settings.debrisFolder
			if useGroundMaterial == true and ray.Instance ~= nil then
				part.Material = ray.Instance.Material;
				part.Transparency = ray.Instance.Transparency;
				part.Color = ray.Instance.Color;
				if ray.Instance.Material == Enum.Material.Grass then
					part.Color = Color3.fromRGB(86, 66, 54)
					part.Material = Enum.Material.Slate
				end
			elseif useGroundMaterial == false then
				part.Material = debrisMaterial;
				part.Color = debrisColor;
				part.Transparency = 0;
			elseif ray.Instance == nil then
				continue;
			end
			Material = ray.Instance.Material
			Color = ray.Instance.Color
			Transparency = ray.Instance.Transparency
			
			part.Anchored = true
			part.CanTouch = false
			part.CanCollide = false
			
			task.delay(timeBeforeRemoval + math.random(-600,600) / 1000, function()
				TweenService:Create(part,TweenInfo.new(fadeOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),{Transparency = 1; CFrame = part.CFrame * CFrame.new(0,-craterProperties.rockSize * 2,0)}):Play()
				task.delay(fadeOutTime, function()
					partCache:ReturnPart(part)
				end)
			end)
		end
	end
	local numOfRocks = math.round(radius / 5)
	if numOfRocks > 8 then
		numOfRocks = 8
	end
	if FlyingRocks then numOfRocks = FlyingRocks end
	if doFlyingDebris == true then
		for i = 0,numOfRocks do
			local part = partCache:GetPart()
			part.Transparency = 0
			part.CanCollide = true
			part.Anchored = false;
			part.CollisionGroup = "rocks"
			part.Size = Vector3.new(0,0,0)
			part.Massless = true
			part.Name = "Debris"
			TweenService:Create(part,TweenInfo.new(0.2),{Size = Vector3.new(math.random(100,craterProperties.rockSize * 100) / 100,math.random(100,craterProperties.rockSize * 100) / 100,math.random(100,craterProperties.rockSize * 100) / 100)}):Play()
			if centerFlyingDebris == true then
				part.Position = Position
			else
				part.Position = Position + Vector3.new(math.random(-radius,radius),rockSize,math.random(-radius,radius))
			end
			local raycast = workspace:Raycast(part.Position + Vector3.new(0,7.5,0),Vector3.new(0,-15,0),params)
			if raycast == nil then partCache:ReturnPart(part) continue end
			if useGroundMaterial == true and raycast.Instance ~= nil then
				part.Material = raycast.Instance.Material
				part.Transparency = raycast.Instance.Transparency
				part.Color = raycast.Instance.Color
				if raycast.Instance.Material == Enum.Material.Grass then
					part.Color = Color3.fromRGB(86, 66, 54)
					part.Material = Enum.Material.Slate
				end
			elseif useGroundMaterial == false then
				part.Material = debrisMaterial
				part.Transparency = 0
				part.Color = debrisColor
			elseif raycast.Instance == nil then
				partCache:ReturnPart(part)
				return;
			end
			local v = Instance.new("BodyVelocity")
			v.Parent = part
			v.MaxForce = Vector3.new(math.huge,math.huge,math.huge)
			v.Velocity = Vector3.new(math.random(-craterProperties.rockSize * 10,craterProperties.rockSize * 10),math.random(craterProperties.rockSize * 15,craterProperties.rockSize * 25),math.random(-craterProperties.rockSize * 10,craterProperties.rockSize * 10))
			game.Debris:AddItem(v,0.2)
			part.AssemblyAngularVelocity = Vector3.new(math.random(-45,45),math.random(-45,45),math.random(-45,45))
			task.spawn(function()
				task.wait(timeBeforeRemoval)
				TweenService:Create(part,TweenInfo.new(fadeOutTime,Enum.EasingStyle.Cubic),{Size = Vector3.new(0,0,0)}):Play()
				task.delay(fadeOutTime,function()
					partCache:ReturnPart(part)
				end)
			end)
		end
	end
	return
end



function Crater:UpdateSettings(settingsTable)
	if settingsTable.useGroundMaterial ~= nil then
		self.Settings.useGroundMaterial = settingsTable.useGroundMaterial
	end
	if settingsTable.debrisColor ~= nil then
		self.Settings.debrisColor = settingsTable.debrisColor
	end
	if settingsTable.debrisMaterial ~= nil then
		self.Settings.debrisMaterial = settingsTable.debrisMaterial
	end
	if settingsTable.timeBeforeRemoval ~= nil then
		self.Settings.timeBeforeRemoval = settingsTable.timeBeforeRemoval
	end
	if settingsTable.doFlyingDebris ~= nil then
		self.Settings.doFlyingDebris = settingsTable.doFlyingDebris
	end
	if settingsTable.centerFlyingDebris ~= nil then
		self.Settings.centerFlyingDebris = settingsTable.centerFlyingDebris
	end
	if settingsTable.hasDust ~= nil then
		self.Settings.hasDust = settingsTable.hasDust
	end
	if settingsTable.rockSkipInterval ~= nil then
		self.Settings.rockSkipInterval = settingsTable.rockSkipInterval
	end
	if settingsTable.debrisFolder ~= nil then
		self.Settings.debrisFolder = settingsTable.debrisFolder
		partCacheModule:SetCacheParent(settingsTable.debrisFolder)
	end
	if settingsTable.FilterDescendantsInstances ~= nil then
		params.FilterDescendantsInstances = settingsTable.FilterDescendantsInstances
	end
	if settingsTable.fadeInTime ~= nil then
		self.Settings.fadeInTime = settingsTable.fadeInTime
	end
	if settingsTable.fadeOutTime ~= nil then
		self.Settings.fadeOutTime = settingsTable.fadeOutTime
	end
	if settingsTable.forceNumberDebris ~= nil then
		self.Settings.forceNumberDebris = settingsTable.forceNumberDebris
	end
end

return Crater