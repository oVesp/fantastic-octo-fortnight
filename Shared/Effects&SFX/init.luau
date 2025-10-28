-- effects.lua (optimized version)

local effects = {}

local RP = game:GetService('ReplicatedStorage')
local Assets = RP:WaitForChild('Assets')
local Modules = RP:WaitForChild('Modules')
local TweenService = game:GetService('TweenService')
local Debris = game:GetService('Debris')
local PhysicsService = game:GetService("PhysicsService")
local RS = game:GetService("RunService")

local plr = game.Players.LocalPlayer

local LightningBolt = require(script:WaitForChild('LightningBolt'))
local LightningSparks = require(script.LightningBolt:WaitForChild('LightningSparks'))
local bubbleModule = require(script:WaitForChild('BubbleModule'))
local EffectPool = require(script:WaitForChild('EffectPoolManager'))
local MoveVFX = require(RP.Modules:WaitForChild("MoveVFX"))

-- EmitterEffect com pooling
function effects.EmitterEffect(info)
	if not info or not info.Name then return end
	local duration = info.Duration or 2
	local effect = EffectPool:GetInstance(info.Name, "EmitterEffect");
	
	if not effect then warn('effect not found', info.Name) return end
	--print(effect:IsA("BasePart"), effect)

	local w;
	if effect:IsA("BasePart") then
		effect.Parent = workspace.Debris
		effect.CFrame = (typeof(info.Position) == "Instance" and info.Position.CFrame or info.Position) * (info.Offset or CFrame.new())
		
		if info.Weld then
			effect.Anchored = false
			w = Instance.new("WeldConstraint")
			w.Part0 = info.Weld
			w.Part1 = effect
			w.Parent = effect
		else
			effect.Anchored = true
		end

		for _, p in ipairs(effect:GetDescendants()) do
			if p:IsA("ParticleEmitter") and not p:HasTag("GK_PARTICLEBLACKLIST") then
				local count = p:GetAttribute("EmitCount")
				local emitduration = p:GetAttribute("EmitDuration")
				if count then
					task.delay(p:GetAttribute("EmitDelay") or 0, function()
						
						p:Emit(count)
					end)
				end

				if emitduration then
					p.Enabled = true
					task.delay(emitduration,function()
						p.Enabled = false
					end)
				end

			end
		end
		task.delay(duration, function()
			if w then w:Destroy() end
			EffectPool:ReturnInstance(info.Name, effect, "EmitterEffect")
		end)
	elseif effect:IsA("Folder") and info.Parts then
		for _, particle in ipairs(effect:GetChildren()) do
			if not particle:IsA("ParticleEmitter") then continue end
			for _, part in ipairs(info.Parts) do
				if not part:IsA("BasePart") then continue end
				local newParticle = particle:Clone()
				newParticle.Parent = part
				local count = newParticle:GetAttribute("EmitCount")
				if count then
					newParticle:Emit(count)
					Debris:AddItem(newParticle, duration)
				end
			end
		end
	end
	
	return effect
end

-- PlaySound com pooling
function effects.PlaySound(name, info)
	if not name or not info then return end
	local where = info.Where
	if not where and info.Position then
		local part = Instance.new("Part")
		part.Size = Vector3.new(1,1,1)
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 1
		part.CFrame = info.Position
		part.Parent = workspace.Debris
		where = part
		Debris:AddItem(part, (info.Duration or 3) + 5)
	end
	local sound = EffectPool:GetInstance(name, "SFX") or (tonumber(name))
	if not sound then return end
	if typeof(sound) ~= "Instance" and tonumber(sound) then
		sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://"..name
	end
	sound.Parent = where
	if info.Volume then sound.Volume = info.Volume end
	if info.RandomPitch then sound.PlaybackSpeed = math.random(90, 110) / 100 end
	sound:Play()
	task.spawn(function()
		if not sound.IsLoaded then
			repeat task.wait() until sound.IsLoaded
		end
		if info.Duration then
			task.delay(info.Duration, function()
				local fadeOut = TweenService:Create(sound, TweenInfo.new(info.FadeOutTime or 1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Volume = 0 })
				fadeOut:Play()
				task.delay((info.FadeOutTime or 1), function()
					EffectPool:ReturnInstance(name, sound, "SFX")
				end)
			end)
		else
			sound.Ended:Connect(function()
				EffectPool:ReturnInstance(name, sound, "SFX")
				if info.Position and where and where:IsA("Part") then where:Destroy() end
			end)
			task.delay(sound.TimeLength + 5, function()
				if sound.Parent then EffectPool:ReturnInstance(name, sound, "Sounds") end
				if info.Position and where and where:IsA("Part") then where:Destroy() end
			end)
		end
	end)
	return sound
end

-- PartEffect com pooling
function effects.PartEffect(info)
	if not info or not info.Name then return end
	local duration = info.Duration or 2
	local effect = EffectPool:GetInstance(info.Name, "Parts")
	if not effect then return end
	effect.Parent = workspace.Debris
	local offset = info.Offset or CFrame.new()
	effect.CFrame = (typeof(info.Position) == "Instance" and info.Position.CFrame or info.Position) * offset
	Debris:AddItem(effect, duration + 4)
	for _, e in ipairs(effect:GetDescendants()) do
		if e:IsA("ParticleEmitter") then
			e.Enabled = false
			if not e:GetAttribute("EmitCount") then
				e.Enabled = true
				task.delay(duration, function()
					e.Enabled = false
				end)
			else
				task.delay(e:GetAttribute("EmitDelay") or 0, function()
					e:Emit(e:GetAttribute("EmitCount"))
				end)
			end
		elseif e:IsA("Decal") then
			if info.StartFade then
				e.Transparency = 1
				TweenService:Create(e, TweenInfo.new(info.StartFade), { Transparency = 0 }):Play()
			end
			if info.ImageFade then
				task.delay(duration, function()
					TweenService:Create(e, TweenInfo.new(info.ImageFade, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
				end)
			end
		end
	end
end

-- TrailEffect com pooling
function effects.TrailEffect(info)
	if not info or not info.Name then return end
	local trailPart = EffectPool:GetInstance(info.Name, "Trail")
	if not trailPart or not info.Part then return end
	trailPart.Parent = info.Part
	trailPart.CFrame = info.Part.CFrame * (info.Offset or CFrame.new())
	trailPart.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = info.Part
	weld.Part1 = trailPart
	weld.Parent = trailPart
	if info.Duration then
		task.delay(info.Duration, function()
			--for _, v in ipairs(trailPart:GetDescendants()) do
			--	if v:IsA("Trail") then v.Enabled = false end
			--end
			weld:Destroy()
			EffectPool:ReturnInstance(info.Name, trailPart, "Trail")
		end)
	end
end

-- AuraEffect com pooling
function effects.AuraEffect(info)
	if not info or not info.Name or not info.LocationParts then return end

	local asset = EffectPool:GetInstance(info.Name, "AuraEffects")
	if not asset then
		warn("AuraEffect: Asset not found:", info.Name)
		return
	end

	for _, particle in ipairs(asset:GetDescendants()) do
		if not particle:IsA("ParticleEmitter") then continue end

		for _, part in ipairs(info.LocationParts) do
			if not part:IsA("BasePart") then continue end

			local newP = particle:Clone()
			newP.Parent = part

			if info.Color then newP.Color = info.Color end

			if newP:GetAttribute("EmitCount") then
				newP:Emit(newP:GetAttribute("EmitCount"))
			else
				newP.Enabled = true
			end

			if info.Duration then
				task.delay(info.Duration, function()
					newP.Enabled = false
					Debris:AddItem(newP, newP.Lifetime.Max)
				end)
			end

			if info.AuraReference then
				newP:SetAttribute('AuraName', info.AuraReference);
				newP:AddTag('AuraEmitter');
			end
		end
	end

	task.defer(function()
		EffectPool:ReturnInstance(info.Name, asset, "AuraEffects")
	end)
end

function effects.CleanAura(info)
	if not info or not info.Name or not info.Target then return end

	for _, particle: ParticleEmitter in ipairs(info.Target:GetDescendants()) do
		if not particle:IsA("ParticleEmitter") then continue end
		if not particle:HasTag('AuraEmitter') then continue end
		if info.Name and particle:GetAttribute('AuraName') ~= info.Name then continue end

		particle:Destroy();		
	end
end

function effects.LightEffect(info)
	if not info or not info.Name or not info.Where then return end
	local light = EffectPool:GetInstance(info.Name, "Lights")
	if not light then
		light = Instance.new("PointLight")
		light.Name = info.Name
	end
	light.Parent = info.Where
	light.Range = info.Range or 8
	light.Brightness = info.Brightness or 1
	light.Color = info.Color or Color3.new(1, 1, 1)
	light.Shadows = info.Shadows or false
	local duration = info.Duration or 1
	task.delay(info.Delay or 0, function()
		local fadeOut = TweenService:Create(light, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Range = 0, Brightness = 0 })
		fadeOut:Play()
		task.delay(duration, function()
			EffectPool:ReturnInstance(info.Name, light, "Lights")
		end)
	end)
end

function effects.ConstantEffect(info)
	if not info or not info.Name then return end

	local effect = EffectPool:GetInstance(info.Name, "ConstantEffects")
	if not effect then return end

	effect.Parent = workspace.Debris
	local offset = info.Offset or CFrame.new()
	effect.CFrame = (typeof(info.Position) == "CFrame" and info.Position or info.Position.CFrame) * offset

	if info.Weld then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = info.Weld
		weld.Part1 = effect
		weld.Parent = effect
	end

	for _, v in ipairs(effect:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			v.Enabled = true
			task.delay(info.Time or 1, function()
				v.Enabled = false
			end)
		end
	end

	task.delay(info.Duration or 2, function()
		EffectPool:ReturnInstance(info.Name, effect, "ConstantEffects")
	end)
end

function effects.HitGlow(info)
	if not info or not info.Where then return end

	local where = info.Where
	local glowDuration = info.GlowDuration or 0.5
	local fillColor = info.FillColor or Color3.new(1, 1, 1)
	local outlineColor = info.OutlineColor
	local type = info.Type or "Fill"

	local highlight = EffectPool:GetInstance("HitGlow", "Misc")
	
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "HitGlow"
	end

	highlight.Parent = where
	highlight.Adornee = where
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = fillColor
	highlight.OutlineColor = outlineColor or fillColor

	if type == "Fill" then
		highlight.FillTransparency = 0
		highlight.OutlineTransparency = 1
	elseif type == "Outline" then
		highlight.FillTransparency = 1
		highlight.OutlineTransparency = 0
	elseif type == "Full" then
		highlight.FillTransparency = 0
		highlight.OutlineTransparency = 0
	end

	local tween = TweenService:Create(highlight, TweenInfo.new(glowDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FillTransparency = 1,
		OutlineTransparency = 1
	})
	tween:Play()

	task.delay(glowDuration,function()
		highlight:Destroy()
		--EffectPool:ReturnInstance("HitGlow", highlight, "Misc")
	end)

end

function effects.FovEffect(info)
	local Start = info.Start or 0.6
	local End = info.End or 0.1
	local Fov = info.Fov or 60
	local Duration = info.Duration or 0.6
	local EasingStyle = info.EasingStyle or Enum.EasingStyle.Cubic
	local EasingDirection = info.EasingDirection or Enum.EasingDirection.Out

	local Camera = workspace.CurrentCamera
	local Default = 70

	TweenService:Create(Camera, TweenInfo.new(Start, EasingStyle, EasingDirection), {FieldOfView = Fov}):Play()
	
	task.delay(Duration, function()
		TweenService:Create(Camera, TweenInfo.new(End, EasingStyle, EasingDirection), {FieldOfView = Default}):Play()
	end)
end

function effects.Billboard(info)
	if not info or not info.Where then return end

	local where = info.Where
	local text = info.Text or "!"
	local duration = info.Duration or 2
	local fadeTime = info.FadeTime or 0.5
	local offset = info.Offset or Vector3.new(0, 3, 0)
	local color = info.Color or Color3.new(1, 1, 1)
	local size = info.Size or 30
	local font = info.Font or Enum.Font.GothamBold
	local outline = info.Outline or true
	local outlineColor = info.OutlineColor or Color3.new(0, 0, 0)
	local riseHeight = info.RiseHeight or 2
	local tweenStyle = info.TweenStyle or Enum.EasingStyle.Quad
	local tweenDirection = info.TweenDirection or Enum.EasingDirection.Out

	-- Create BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EffectBillboard"
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.AlwaysOnTop = true
	billboard.Enabled = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 100
	billboard.SizeOffset = Vector2.new(0, 0.5)

	-- Create TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextSize = size
	label.Font = font
	label.TextScaled = false
	label.TextWrapped = false
	label.TextStrokeTransparency = outline and 0 or 1
	label.TextStrokeColor3 = outlineColor

	-- Position the billboard
	if where:IsA("BasePart") then
		billboard.Adornee = where
		billboard.StudsOffset = offset
	else
		-- If it's a model, try to find a primary part
		if where:IsA("Model") and where.PrimaryPart then
			billboard.Adornee = where.PrimaryPart
			billboard.StudsOffset = offset
		else
			-- Fallback: create a temporary part at the position
			local tempPart = Instance.new("Part")
			tempPart.Size = Vector3.new(1, 1, 1)
			tempPart.Transparency = 1
			tempPart.CanCollide = false
			tempPart.Anchored = true
			tempPart.CFrame = typeof(where) == "CFrame" and where or CFrame.new(where)
			tempPart.Parent = workspace.Debris
			billboard.Adornee = tempPart
			billboard.StudsOffset = offset
			Debris:AddItem(tempPart, duration + fadeTime + 1)
		end
	end

	label.Parent = billboard
	billboard.Parent = where:IsA("BasePart") and where or (where:FindFirstChildOfClass("BasePart") or workspace.Debris)

	-- Animation: Float up and fade out
	local startPosition = billboard.StudsOffset
	local endPosition = startPosition + Vector3.new(0, riseHeight, 0)

	-- Tween position
	local positionTween = TweenService:Create(
		billboard,
		TweenInfo.new(duration, tweenStyle, tweenDirection),
		{StudsOffset = endPosition}
	)

	-- Tween transparency (start fading near the end)
	task.delay(duration - fadeTime, function()
		if label and label.Parent then
			local fadeTween = TweenService:Create(
				label,
				TweenInfo.new(fadeTime, tweenStyle, tweenDirection),
				{
					TextTransparency = 1,
					TextStrokeTransparency = 1
				}
			)
			fadeTween:Play()
		end
	end)

	positionTween:Play()

	-- Cleanup
	task.delay(duration + fadeTime, function()
		if billboard and billboard.Parent then
			billboard:Destroy()
		end
	end)

	return billboard
end

function effects.ThornTrap(info)
	local char = info.Character
	if not char then return end
	local humanoidRootPart = char:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	local Victim = info.Victim
	local VictimDirection = (Victim.Position - humanoidRootPart.Position).Unit

	local distance = (Victim.Position - humanoidRootPart.Position).Magnitude

	local segmentCount = distance / 2 
	local segmentLength = 3
	local maxAngleDeviation = 30
	local animationSpeed = 0.05

	local startPosition = humanoidRootPart.Position - Vector3.new(0, 3, 0)
	local direction = humanoidRootPart.CFrame.LookVector

	local forwardVector = VictimDirection * distance
	local endPosition = humanoidRootPart.Position - Vector3.new(0, 3, 0) + forwardVector
	local totalDistance = (endPosition - startPosition).Magnitude
	local stepDistance = totalDistance / segmentCount

	local function createSegment(index, lastPosition, lastDirection)
		local segment = Instance.new("Part")
		segment.Size = Vector3.new(1.5, 0.5, 1)
		segment.Anchored = true
		segment.CanCollide = false
		segment.Material = Enum.Material.Grass
		segment.Color = Color3.fromRGB(5, 108, 3)
		segment.Parent = workspace.Debris
		segment.Name = "Segment"..index

		local angle = math.rad(math.random(-maxAngleDeviation, maxAngleDeviation))
		local newDirection = (CFrame.Angles(0, angle, 0) * lastDirection).LookVector

		local segmentStart = lastPosition
		local segmentEnd = segmentStart + (newDirection * segmentLength)

		segment.CFrame = CFrame.new(segmentStart, segmentEnd)

		local sizeTween = TweenService:Create(segment, TweenInfo.new(animationSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(1, 0.5, segmentLength)})
		local positionTween = TweenService:Create(segment, TweenInfo.new(animationSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = CFrame.new(segmentEnd - (newDirection * (segmentLength / 2)), segmentEnd + newDirection)})

		sizeTween:Play()
		positionTween:Play()

		positionTween.Completed:Connect(function()
			local finalDirection = (endPosition - segmentEnd).unit

			task.spawn(function()
				task.wait(0.5)
				TweenService:Create(segment, TweenInfo.new(0.5), {Size = Vector3.new(0,0,0)}):Play()
				task.wait(0.5)

				segment:Destroy()
			end)

			if index >= segmentCount then
				local Grass = Instance.new("Part")
				Grass.Size = Vector3.new(0,0,0)
				Grass.Anchored = true
				Grass.CanCollide = false
				Grass.Material = Enum.Material.Grass
				Grass.Color = Color3.fromRGB(5, 108, 3)
				Grass.Parent = workspace.Debris
				Grass.Name = "Grass"
				Grass.CFrame = Victim.CFrame * CFrame.new(0,-1,0)

				TweenService:Create(Grass, TweenInfo.new(0.5, Enum.EasingStyle.Cubic), {Size = Vector3.new(4.5, 4.1, 1.5)}):Play()
				task.wait(info.Duration)
				local disappear = TweenService:Create(Grass, TweenInfo.new(0.5, Enum.EasingStyle.Cubic), {Size = Vector3.new(0,0,0)})
				disappear:Play()
				disappear.Completed:Connect(function()
					Grass:Destroy()
				end)
			else
				createSegment(index + 1, segmentEnd, CFrame.new(Vector3.zero, finalDirection))
			end


		end)
	end

	createSegment(1, startPosition, CFrame.new(Vector3.zero, direction))

end

function effects.Invisible(info)
	local Victim = info.Victim
	local Transparency = info.Transparency
	local face = info.face

	Victim:FindFirstChild("face", true).Transparency = Transparency

	for i, v in pairs(Victim:GetDescendants()) do
		if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
			if Transparency == 1 and v.Transparency == 1 then 
				v:SetAttribute("Transparency", true)
				continue 
			end
			if v:GetAttribute("Transparency") then continue end
			v.Transparency = Transparency
		end
	end
end

function effects.ShadowClone(info)
	local char = info.Character
	if not char then return end

	local amount = info.Amount or 3
	local duration = info.Duration or 1
	local interval = (duration / amount)
	local ShadowDuration = info.ShadowDuration or 0.5
	
	local this_plr = game.Players:GetPlayerFromCharacter(char)
	
	for i = 1, amount do
		task.delay((i - 1) * interval, function()
			if not char then return end

			local clone = script:WaitForChild('ShadowClone'):Clone()
			clone:PivotTo(char:GetPivot())
			clone:WaitForChild("HumanoidRootPart").Anchored = true
			
			clone.Parent = workspace.Debris
			
			for _, part in ipairs(clone:GetDescendants()) do
				if part:IsA("BasePart") and part.Transparency == 0 then
					part.Anchored = true
					part.CanCollide = false
					part.Material = Enum.Material.Neon
					part.Color = info.Color or Color3.fromRGB(0,0,0)
					part.Transparency = info.StartTransparency or 0.2

					part.CollisionGroup = "NoCollide"	
					
					if char:FindFirstChild(part.Name) then
						part.CFrame = char:FindFirstChild(part.Name).CFrame
					end
 				elseif part:HasTag('SoccerBall') or part:IsA("Motor6D") or part:IsA("Decal") then
					part:Destroy()
				end
			end

			for _, part in ipairs(clone:GetDescendants()) do
				if part:IsA("BasePart") then
					local fadeTween = TweenService:Create(part, TweenInfo.new(ShadowDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Transparency = 1
					})
					fadeTween:Play()
				end
			end

			task.delay(duration, function()
				if clone then clone:Destroy() end
			end)
		end)
	end
end

function effects.ColorCorrection(info)
	local duration = info.Duration or 1
	local brightness = info.Brightness or 0
	local saturation = info.Saturation or 0
	local contrast = info.Contrast or 0
	local tintColor = info.TintColor or Color3.fromRGB(255, 255, 255)
	local inTime = info.InTime or .2
	local outTime = info.OutTime or .3

	-- Cria o efeito
	local cc = game.Lighting:WaitForChild('VisualEffect')
	-- Tween de entrada
	local tweenIn = TweenService:Create(cc, TweenInfo.new(inTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Brightness = brightness,
		Saturation = saturation,
		Contrast = contrast,
		TintColor = tintColor
	})
	tweenIn:Play()

	-- Tween de saída após `duration`
	task.delay(duration, function()
		local tweenOut = TweenService:Create(cc, TweenInfo.new(outTime, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Brightness = 0,
			Saturation = 0,
			Contrast = 0,
			TintColor = Color3.new(1, 1, 1)
		})
		tweenOut:Play()
	end)
end

function effects.PlaceEffectPart(info)
	if not info or not info.Name or not info.Position then return end

	local effect = EffectPool:GetInstance(info.Name, "Misc")
	if not effect then
		warn("[EffectModule] Efeito não encontrado:", info.Name)
		return
	end

	local cframe = typeof(info.Position) == "CFrame" and info.Position or info.Position.CFrame
	local offset = info.Offset or CFrame.new()
	effect.CFrame = cframe * offset

	effect.Parent = info.Parent or workspace.Debris

	local duration = info.Duration or 2
	task.delay(duration, function()
		EffectPool:ReturnInstance(info.Name, effect, "Misc")
	end)

	return effect
end

function effects.SlashCameraTransition(info)
	local duration = info.Duration or 3
	local speed = info.Speed or 15
	local color = info.Color or Color3.new(1, 1, 1)

	local camera = workspace.CurrentCamera
	local partTemplate = Assets:WaitForChild("Misc"):WaitForChild("SlashTransition")
	local part = partTemplate:Clone()

	part.Anchored = true
	part.CanCollide = false
	part.Parent = workspace.Debris

	local connection
	connection = game:GetService("RunService").RenderStepped:Connect(function()
		if camera then
			part.CFrame = camera.CFrame * CFrame.new(0, 0, -2.5)
		end
	end)

	for _, particle in ipairs(part:GetDescendants()) do
		if particle:IsA("ParticleEmitter") then
			if particle.Name == "ColorParticle" then
				particle.Color = ColorSequence.new(color)
				particle.Speed = NumberRange.new(speed)
			end

			local emitCount = particle:GetAttribute("EmitCount") or 1
			particle:Emit(emitCount)
		end
	end
	
	task.delay(duration, function()
		if connection then
			connection:Disconnect()
		end
		part:Destroy()
	end)
end

function effects.SpeedLines(info)
	local duration = info.Duration or 3
	local Size = info.Size or 0.4
	local color = info.Color or Color3.new(1, 1, 1)

	local camera = workspace.CurrentCamera
	local partTemplate = Assets:WaitForChild("Misc"):WaitForChild(info['Type'] or "SpeedLines")
	local part = partTemplate:Clone()

	part.Anchored = true
	part.CanCollide = false
	part.Parent = workspace.Debris
	
	local fun = function()
		part.CFrame = camera.CFrame * CFrame.new(0, 0, -1)
	end
	
	game:GetService('RunService'):UnbindFromRenderStep('SpeedLinesConnection')

	game:GetService('RunService'):BindToRenderStep('SpeedLinesConnection',Enum.RenderPriority.Camera.Value, fun)

	for _, Beam in ipairs(part:GetDescendants()) do
		if Beam:IsA("Beam") and Beam.Name == "ColorBeam" then
			Beam.Color = ColorSequence.new(color)
			Beam.Width0 = Size
			Beam.Width1 = Size
		end
	end

	task.delay(duration, function()
		game:GetService('RunService'):UnbindFromRenderStep('SpeedLinesConnection')
		
		part:Destroy()
	end)
end

function effects.CloneBeamPart(info)
	if not info or not info.Name then return end

	-- Find template in ReplicatedStorage
	local template = Assets:WaitForChild("Misc"):WaitForChild(info.Name)
	if not template then return end

	-- Clone
	local clone = template:Clone()

	-- Parent to Debris folder in workspace
	local debrisFolder = workspace:FindFirstChild("Debris")
	clone.Parent = debrisFolder

	-- Set position
	local cf = info.Position

	-- If Model, pivot; if Part, set CFrame
	if clone:IsA("Model") then
		clone:PivotTo(cf)
	else
		if clone:IsA("BasePart") then
			clone.CFrame = cf
		end
	end

	-- Optional weld
	if info.Weld and info.WeldTo and info.WeldTo:IsA("BasePart") then
		local root
		if clone:IsA("Model") then
			root = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
			if root then
				for _, part in ipairs(clone:GetDescendants()) do
					if part:IsA("BasePart") and part ~= root then
						part.Anchored = false
						local wc = Instance.new("WeldConstraint")
						wc.Part0 = root
						wc.Part1 = part
						wc.Parent = root
					end
				end
				local wc = Instance.new("WeldConstraint")
				wc.Part0 = info.WeldTo
				wc.Part1 = root
				wc.Parent = info.WeldTo
				root.Anchored = false
			end
		else
			clone.Anchored = false
			local wc = Instance.new("WeldConstraint")
			wc.Part0 = info.WeldTo
			wc.Part1 = clone
			wc.Parent = info.WeldTo
		end
	else
		-- Anchor if no weld
		local base = clone:IsA("Model") and clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
		if base then base.Anchored = true end
	end

	-- Get beams
	local beams = {}
	for _, obj in ipairs(clone:GetDescendants()) do
		if obj:IsA("Beam") then
			table.insert(beams, obj)
		end
	end

	local duration = info.Duration or 1
	local fadeTime = info.Fade or 0.5

	-- If no beams, just remove after duration
	if #beams == 0 then
		Debris:AddItem(clone, duration)
		return
	end
	
	local original = {} -- [beam] = { {t, v, e}, ... }
	for _, beam in ipairs(beams) do
		if beam and beam.Parent then
			local kpList = {}
			for _, kp in ipairs(beam.Transparency.Keypoints) do
				table.insert(kpList, {kp.Time, kp.Value, kp.Envelope})
			end
			original[beam] = kpList
		end
	end

	task.delay(duration, function()
		local fadeValue = Instance.new("NumberValue")
		fadeValue.Value = 0
		fadeValue.Parent = clone

		local tween = TweenService:Create(
			fadeValue,
			TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Value = 1 }
		)

		-- lerp helpers
		local function lerp(a, b, t) return a + (b - a) * t end

		fadeValue.Changed:Connect(function(progress)
			-- Rebuild NumberSequence preserving original shape, fading each keypoint value → 1
			for beam, kpList in pairs(original) do
				if beam and beam.Parent then
					local newKp = table.create(#kpList)
					for i, kp in ipairs(kpList) do
						local time, startV, startE = kp[1], kp[2], kp[3]
						local v = lerp(startV, 1, progress)        -- value fades toward 1
						local e = lerp(startE or 0, 0, progress)   -- envelope fades toward 0
						newKp[i] = NumberSequenceKeypoint.new(time, v, e)
					end
					beam.Transparency = NumberSequence.new(newKp)
				end
			end
		end)

		tween:Play()
		tween.Completed:Connect(function()
			fadeValue:Destroy()
			Debris:AddItem(clone, 0.05)
		end)
	end)

	return clone
end

function effects.CleanEffect(info)
	if not info or not info.Target then return end
	
	local Target = workspace.Debris:FindFirstChild(info.Target)
	
	for _, particle: ParticleEmitter in ipairs(Target:GetDescendants()) do
		if not particle:IsA("ParticleEmitter") then continue end
		particle:Clear()
		
		particle:Destroy();		
	end
end


function effects.Bubble(Info)
	bubbleModule.CreateBubble(
		Info.CF,
		Info.StartSize,
		Info.StartTr,
		Info.EndSize,
		Info.Time
	)
end

local function screenShake(intensity, duration)
	local camera = workspace.CurrentCamera
	local originalPosition = camera.CFrame.Position

	local startTime = tick()
	local endTime = startTime + duration

	local connection
	connection = RS.Heartbeat:Connect(function()
		local currentTime = tick()
		if currentTime >= endTime then
			connection:Disconnect()
			camera.CFrame = CFrame.new(originalPosition) * camera.CFrame.Rotation
			return
		end

		local progress = (currentTime - startTime) / duration
		local currentIntensity = intensity * (1 - progress)

		local shakeOffset = Vector3.new(
			(math.random() - 0.5) * 2 * currentIntensity,
			(math.random() - 0.5) * 2 * currentIntensity,
			(math.random() - 0.5) * 2 * currentIntensity
		)

		camera.CFrame = CFrame.new(originalPosition + shakeOffset) * camera.CFrame.Rotation
	end)
end

local function safeEffect(name, where, opts)
	if not name or name == "" then return end
	if _G.EFFECTS and typeof(_G.EFFECTS.EmitterEffect) == "function" then
		_G.EFFECTS.EmitterEffect({ Name = name, Where = where, Duration = opts and opts.Duration, OffsetCFrame = opts and opts.OffsetCFrame })
	end
end

local function safeTrail(name, where, opts)
	if not name or name == "" then return end
	if _G.EFFECTS and typeof(_G.EFFECTS.AttachTrail) == "function" then
		_G.EFFECTS.AttachTrail(name, where, opts)
	else
		safeEffect(name, where, opts) -- fallback
	end
end

local function safeSfx(name, where)
	if not name or name == "" then return end
	if _G.EFFECTS and typeof(_G.EFFECTS.PlaySound) == "function" then
		_G.EFFECTS:PlaySound(name, where)
	end
end

function effects.PlayMovePackage(stage: "cast"|"travel"|"impact"|"endcast", moveId: string, where: Instance?, opts: table?)
	local pack, handler = MoveVFX.Resolve(moveId)

	-- Advanced stage hook (if present) gets first shot
	if handler and type(handler[stage]) == "function" then
		local ok = pcall(handler[stage], moveId, where, opts or {})
		if ok then return end -- advanced handled it
	end

	-- Default/template behavior
	local info = pack and pack[stage]
	if not info then return end
	if info.effect then safeEffect(info.effect, where, opts) end
	if info.trail  then safeTrail(info.trail, where, opts) end
	if info.sfxStart then safeSfx(info.sfxStart, where) end
	if info.sfxLoop  then safeSfx(info.sfxLoop,  where) end
	if info.sfxHit   then safeSfx(info.sfxHit,   where) end
	if info.sfxEnd   then safeSfx(info.sfxEnd,   where) end
end


-- Small util: count active billboards so we can stack vertically
local function _stackOffset(where: Instance, baseOffsetY: number, gap: number)
	local adornee = where
	if where:IsA("Model") then
		adornee = where.PrimaryPart or where:FindFirstChildWhichIsA("BasePart")
	end
	if not adornee then return Vector3.new(0, baseOffsetY, 0) end

	local count = 0
	for _, gui in ipairs(adornee:GetChildren()) do
		if gui:IsA("BillboardGui") and gui.Name == "EffectBillboard" then
			count += 1
		end
	end
	return Vector3.new(0, baseOffsetY + (gap * count), 0)
end

-- Optional micro-anim to add a bit of *pop* to the text (scale punch)
local function _punchScale(billboard: BillboardGui)
	local text = billboard:FindFirstChild("Text")
	if not text or not text:IsA("TextLabel") then return end
	text.TextScaled = false
	local origSize = text.TextSize
	text.TextSize = math.floor(origSize * 1.3)
	task.delay(0.06, function()
		if text and text.Parent then
			text.TextSize = origSize
		end
	end)
end

-- Optional micro-anim to shake (for damage / crit)
local function _shake(billboard: BillboardGui, intensity: number, timeSec: number)
	task.spawn(function()
		local start = os.clock()
		while billboard.Parent and (os.clock() - start) < timeSec do
			task.wait(0.03)
			local x = (math.random() - 0.5) * 2 * intensity
			local y = (math.random() - 0.5) * 1 * (intensity * 0.5)
			billboard.SizeOffset = Vector2.new(x * 0.02, 0.5 + y * 0.02)
		end
		if billboard and billboard.Parent then
			billboard.SizeOffset = Vector2.new(0, 0.5)
		end
	end)
end

-- Core spawner with sane defaults + stacking
local function _spawn(where, text, opts)
	opts = opts or {}
	local baseY = opts.BaseY or 3
	local gapY  = opts.StackGap or 0.4
	local color = opts.Color or Color3.fromRGB(255, 255, 255)
	local size  = opts.Size or 30

	-- stack Y to avoid overlap when multiple appear at once
	local stacked = _stackOffset(where, baseY, gapY)

	local b = _G.EFFECTS.Billboard({
		Where = where,
		Text = text,
		Duration = opts.Duration or 1.2,
		FadeTime = opts.FadeTime or 0.4,
		Offset = Vector3.new(0, stacked.Y, 0),
		Color = color,
		Size = size,
		Font = opts.Font or Enum.Font.GothamBold,
		Outline = opts.Outline ~= false,
		OutlineColor = opts.OutlineColor or Color3.new(0,0,0),
		RiseHeight = opts.RiseHeight or 2,
		TweenStyle = Enum.EasingStyle.Quad,
		TweenDirection = Enum.EasingDirection.Out,
	})

	if not b then return end
	if opts.Punch then _punchScale(b) end
	if opts.Shake then _shake(b, opts.ShakeIntensity or 1.5, opts.ShakeTime or 0.25) end
	return b
end

local DAMAGE_RED   = Color3.fromRGB(255, 95, 95)
local CRIT_YELLOW  = Color3.fromRGB(255, 230, 120)
local HEAL_GREEN   = Color3.fromRGB(110, 220, 110)
local MANA_BLUE    = Color3.fromRGB(120, 170, 255)
local MISS_GRAY    = Color3.fromRGB(200, 200, 200)
local BUFF_CYAN    = Color3.fromRGB(120, 240, 240)
local DEBUFF_PURP  = Color3.fromRGB(190, 120, 255)
local BLOCK_ORANGE = Color3.fromRGB(255, 180, 120)

-- Public helpers:

function effects.ShowDamage(where: Instance, amount: number, isCrit: boolean?)
	local t = string.format("-%d HP", math.max(0, math.floor(amount or 0)))
	return _spawn(where, t, {
		Color = isCrit and CRIT_YELLOW or DAMAGE_RED,
		Size = isCrit and 36 or 30,
		Punch = true,
		Shake = true,
		ShakeIntensity = isCrit and 2.5 or 1.2,
		ShakeTime = isCrit and 0.35 or 0.2,
		RiseHeight = isCrit and 2.8 or 2.0,
		Duration = isCrit and 1.5 or 1.2,
	})
end

function effects.ShowHeal(where: Instance, amount: number)
	local t = string.format("+%d HP", math.max(0, math.floor(amount or 0)))
	return _spawn(where, t, {
		Color = HEAL_GREEN,
		Size = 28,
		Punch = true,
		RiseHeight = 2.0,
	})
end

function effects.ShowMana(where: Instance, amount: number)
	local sign = amount >= 0 and "+" or ""
	local t = string.format("%s%d MP", sign, math.floor(amount))
	return _spawn(where, t, {
		Color = MANA_BLUE,
		Size = 26,
		RiseHeight = 1.8,
	})
end

function effects.ShowMiss(where: Instance)
	return _spawn(where, "Miss!", {
		Color = MISS_GRAY,
		Size = 28,
		Punch = true,
	})
end

function effects.ShowDodge(where: Instance)
	return _spawn(where, "Dodge!", {
		Color = MISS_GRAY,
		Size = 28,
		Punch = true,
	})
end

function effects.ShowBlock(where: Instance)
	return _spawn(where, "Block!", {
		Color = BLOCK_ORANGE,
		Size = 28,
		Punch = true,
	})
end

function effects.ShowCrit(where: Instance, amount: number?)
	if amount then
		return effects.ShowDamage(where, amount, true)
	end
	return _spawn(where, "CRIT!", {
		Color = CRIT_YELLOW,
		Size = 34,
		Punch = true,
		Shake = true,
		ShakeIntensity = 2.3,
		ShakeTime = 0.3,
	})
end

-- Generic status tags: “Poisoned”, “Burning”, “Stunned”, etc.
function effects.ShowStatus(where: Instance, label: string, isBuff: boolean?)
	return _spawn(where, label or "Status", {
		Color = isBuff and BUFF_CYAN or DEBUFF_PURP,
		Size = 24,
	})
end

return effects
