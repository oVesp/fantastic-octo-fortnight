-- ReplicatedStorage/Modules/EvolutionVFX.lua
-- Sequência de efeitos de evolução (client-side)

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local Camera = workspace.CurrentCamera
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Lighting = game:GetService("Lighting")


local Remotes = RS:WaitForChild("Remotes")
local EvolutionEffect = Remotes:WaitForChild("EvolutionEffect")
local EvolutionComplete = Remotes:WaitForChild("EvolutionComplete")


local Effects = require(RS.Modules["Effects&SFX"]) -- usa EmitterEffect, AuraEffect, PlaySound etc.

-- util: coleta partes "boas" para a aura
local function getAuraParts(model: Model)
	if not model or not model.Parent then return {} end
	local parts = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			table.insert(parts, p)
		end
	end
	-- fallback: se nada foi pego, usa HRP
	if #parts == 0 then
		local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		if hrp then table.insert(parts, hrp) end
	end
	return parts
end

local function playCinematicCamera(monster: Model, duration)
	if not monster or not monster:FindFirstChild("HumanoidRootPart") then return end
	local hrp = monster.HumanoidRootPart
	local startCF = Camera.CFrame
	local origin = hrp.Position
	local distance = 12
	local height = 4
	local angle = 0
	local rotationSpeed = math.pi / 6 -- 30°/s
	local zoomDistance = 6 -- how much closer camera moves
	local t = 0

	-- Define camera mode
	Camera.CameraType = Enum.CameraType.Scriptable

	-- Cria tween de zoom (aproximação gradual)
	local zoomTween = TweenService:Create(Camera, TweenInfo.new(duration * 0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(origin + Vector3.new(0, height, distance - zoomDistance), origin)
	})
	zoomTween:Play()

	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		t += dt
		angle += rotationSpeed * dt
		local offset = CFrame.new(math.cos(angle) * distance, height, math.sin(angle) * distance)
		local cf = CFrame.lookAt(origin + offset.Position, origin + Vector3.new(0, height * 0.5, 0))
		Camera.CFrame = cf
	end)

	task.delay(duration, function()
		if conn then conn:Disconnect()
		end
		-- restaura câmera ao player
		local char = player.Character
		if char and char:FindFirstChild("Humanoid") then
			Camera.CameraType = Enum.CameraType.Custom
			Camera.CameraSubject = char:FindFirstChild("Humanoid")
		else
			Camera.CameraType = Enum.CameraType.Custom
			Camera.CameraSubject = workspace
		end
	end)
end

local function playCameraShake(duration, opts)
	opts = opts or {}
	local amp = opts.amplitude or 0.25       -- deslocamento posicional (studs)
	local rAmp = opts.rotAmplitude or 0.5    -- rotação (graus)
	local freq = opts.frequency or 12        -- Hz
	local decay = opts.decay or 1.8          -- maior = some mais rápido

	local seed = math.random(1, 10_000)
	local t0 = time()
	local conn

	local function noise(n) return math.noise(n, seed) end

	conn = RunService.RenderStepped:Connect(function()
		local t = time() - t0
		if t >= duration then
			if conn then conn:Disconnect() end
			return
		end

		-- envelope de decaimento
		local env = math.exp(-decay * (t / duration))

		-- offsets em 3 eixos usando “ruído” para suavidade
		local offX = noise(t * freq) * amp * env
		local offY = noise((t + 37) * freq) * amp * env * 0.6
		local offZ = noise((t + 73) * freq) * amp * env * 0.4

		local rX = math.rad(noise((t + 11) * freq) * rAmp * env)
		local rY = math.rad(noise((t + 23) * freq) * rAmp * env * 0.6)
		local rZ = math.rad(noise((t + 47) * freq) * rAmp * env * 0.4)

		-- aplica apenas se estivermos em Scriptable
		if Camera.CameraType == Enum.CameraType.Scriptable then
			Camera.CFrame = Camera.CFrame * CFrame.new(offX, offY, offZ) * CFrame.Angles(rX, rY, rZ)
		end
	end)
end

-- Bloom temporário com fade-in/out
local function playPeakBloom(totalDuration, cfg)
	cfg = cfg or {}
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0
	bloom.Size = cfg.Size or 56
	bloom.Threshold = cfg.Threshold or 1.0
	bloom.Name = "EvolutionPeakBloom"
	bloom.Parent = Lighting

	local TweenService = game:GetService("TweenService")
	local inTime = math.clamp((cfg.InTime or 0.18), 0.05, totalDuration * 0.4)
	local outTime = math.clamp((cfg.OutTime or 0.35), 0.1, totalDuration * 0.6)
	local peak = cfg.Peak or 1.8

	local twIn = TweenService:Create(bloom, TweenInfo.new(inTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Intensity = peak })
	local twOut = TweenService:Create(bloom, TweenInfo.new(outTime, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Intensity = 0 })

	twIn:Play()
	task.delay(inTime + math.max(0, totalDuration - (inTime + outTime)), function()
		twOut:Play()
		twOut.Completed:Once(function()
			if bloom then bloom:Destroy() end
		end)
	end)
end

-- tier pode ser: "Basic" | "Mythic" | "Divine" ou nil (auto)
local function playEvolutionSequence(monster: Model, originCf: CFrame, opts)
	opts = opts or {}
	local tier = opts.tier or "Basic"
	local duration = opts.duration or 3.5
	
	task.spawn(function()
		playCinematicCamera(monster, duration + 2)
	end)
	
	-- âncora para sons/luzes
	local where = Instance.new("Part")
	where.Name = "EvolutionAnchor"
	where.Anchored = true
	where.CanCollide = false
	where.Transparency = 1
	where.CFrame = originCf
	where.Parent = workspace.Debris
	Debris:AddItem(where, duration + 6)

	local hrp = monster and (monster:FindFirstChild("HumanoidRootPart") or monster.PrimaryPart)
	local weldTo = hrp or where
	local auraParts = monster and getAuraParts(monster) or {}

	----------------------------------------------------------------
	-- 0) Preparação: leve correção de cor + fov + som de início
	----------------------------------------------------------------
	Effects.ColorCorrection({
		Brightness = 0.05, Saturation = -0.1, Contrast = 0.15,
		TintColor = Color3.fromRGB(255, 245, 242),
		InTime = 0.15, Duration = duration - 0.3, OutTime = 0.25
	})
	Effects.FovEffect({ Start = 0.25, Duration = duration - 0.4, End = 0.2, Fov = 62 })

	Effects.PlaySound("EvolutionStart", { Where = where, Volume = 0.85, RandomPitch = true })

	----------------------------------------------------------------
	-- 1) EvolutionSparks — dourado, burst, subindo (início instantâneo)
	----------------------------------------------------------------
	Effects.EmitterEffect({
		Name = "EvolutionSparks",
		Position = weldTo.CFrame,
		Weld = weldTo, -- gruda no alvo
		Duration = 1.2, -- bursts curtos
		Offset = CFrame.new(0, 1.2, 0)
	})

	----------------------------------------------------------------
	-- 2) EvolutionEnergy — roxo/azul em vórtice, build-up (0.15s)
	----------------------------------------------------------------
	task.delay(0.15, function()
		Effects.EmitterEffect({
			Name = "EvolutionEnergy",
			Position = weldTo.CFrame,
			Weld = weldTo,
			Duration = duration - 0.6,
			Offset = CFrame.new(0, 1.0, 0)
		})
		Effects.PlaySound("EvolutionRumble", { Where = where, Volume = 0.55, RandomPitch = false, Duration = duration - 0.6, FadeOutTime = 0.25 })
	end)

	----------------------------------------------------------------
	-- 3) EvolutionAura (básica) — laranja, pulsando, colada nas partes (0.25s)
	----------------------------------------------------------------
	task.delay(0.25, function()
		if #auraParts > 0 then
			Effects.AuraEffect({
				Name = "EvolutionAura",
				LocationParts = auraParts,
				Duration = duration - 0.8,
				AuraReference = "EvolutionAura"
			})
		end
	end)

	----------------------------------------------------------------
	-- 4) CosmicParticles — espiral cósmica (0.6s)
	----------------------------------------------------------------
	task.delay(0.6, function()
		Effects.EmitterEffect({
			Name = "CosmicParticles",
			Position = weldTo.CFrame,
			Weld = weldTo,
			Duration = math.max(1.0, duration - 1.0),
			Offset = CFrame.new()
		})
		Effects.PlaySound("CosmicEvolution", { Where = where, Volume = 0.7, RandomPitch = true })
	end)

	-- 5) Pico (clímax) — flash + aura avançada + som de transformação (~dur/2)
	task.delay(duration * 0.55, function()
		-- flash de luz (corona/divine feel)
		Effects.LightEffect({
			Name = "EvolutionFlash",
			Where = where,
			Range = (tier == "Divine" and 22) or (tier == "Mythic" and 16) or 12,
			Brightness = (tier == "Divine" and 12) or (tier == "Mythic" and 8) or 6,
			Color = (tier == "Divine" and Color3.fromRGB(255, 233, 127))
				or (tier == "Mythic" and Color3.fromRGB(160, 100, 255))
				or Color3.fromRGB(255, 170, 70),
			Duration = 0.35, Delay = 0, Shadows = false
		})

		Effects.PlaySound("EvolutionTransform", { Where = where, Volume = 0.9, RandomPitch = true })

		-- 🔸 NEW: shake + bloom durante o pico
		-- shake curto (0.6~0.9s), amplitude modesta, com decaimento
		local shakeDur = (tier == "Divine" and 0.9) or (tier == "Mythic" and 0.75) or 0.6
		playCameraShake(shakeDur, {
			amplitude = (tier == "Divine" and 0.35) or (tier == "Mythic" and 0.3) or 0.25,
			rotAmplitude = (tier == "Divine" and 0.9) or (tier == "Mythic" and 0.7) or 0.5,
			frequency = 12,
			decay = 2.2
		})

		-- bloom com pico e fade out
		playPeakBloom(shakeDur + 0.15, {
			Peak = (tier == "Divine" and 2.4) or (tier == "Mythic" and 2.0) or 1.8,
			Size = (tier == "Divine" and 64) or (tier == "Mythic" and 60) or 56,
			Threshold = 1.0,
			InTime = 0.18,
			OutTime = 0.35
			
		})
	end)
	----------------------------------------------------------------
	-- 6) Aura final conforme tier (Mythic/Divine) + limpeza da aura básica
	----------------------------------------------------------------
	task.delay(duration * 0.65, function()
		if #auraParts > 0 then
			if tier == "Mythic" then
				Effects.AuraEffect({
					Name = "MythicAura",
					LocationParts = auraParts,
					Duration = 2.5,
					AuraReference = "EvolutionAura"
				})
			elseif tier == "Divine" then
				Effects.AuraEffect({
					Name = "DivineAura",
					LocationParts = auraParts,
					Duration = 2.8,
					AuraReference = "EvolutionAura"
				})
			end

			-- limpa a aura de evolução básica para não acumular
			Effects.CleanAura({ Name = "EvolutionAura", Target = monster })
		end
	end)

	----------------------------------------------------------------
	-- 7) Fechamento — fanfarra / complete
	----------------------------------------------------------------
	task.delay(duration, function()
		local completeSfx = (tier == "Divine") and "AscensionComplete" or "EvolutionComplete"
		Effects.PlaySound(completeSfx, { Where = where, Volume = 1.0 })
		playPeakBloom(0.45, { Peak = 1.3, Size = 52, Threshold = 1.05, InTime = 0.12, OutTime = 0.28 })

		-- toque final cósmico curto
		Effects.EmitterEffect({
			Name = "CosmicParticles",
			Position = weldTo.CFrame,
			Weld = weldTo,
			Duration = 0.8
		})
	end)
end

----------------------------------------------------------------
-- Escuta o remoto do servidor para tocar VFX no cliente local
-- Server chama EvolutionEffect:FireClient(player, monsterPosition, targetRaceString)
----------------------------------------------------------------
EvolutionEffect.OnClientEvent:Connect(function(worldPos: Vector3, targetRace: string)
	local plr = Players.LocalPlayer
	-- tenta achar o monstro do player em cena (seguindo o padrão OwnerId)
	local best
	for _, m in ipairs(workspace:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("OwnerId") == plr.UserId then
			best = m; break
		end
	end
	-- origem visual (se não achou o modelo, usa a posição enviada)
	local origin = (best and (best:GetPivot())) or CFrame.new(worldPos)
	playEvolutionSequence(best, origin, {
		-- regra simples: Divine para evoluções de tier alto, Mythic para médias
		tier = (targetRace and targetRace:find("Prime") or targetRace == "CosmicWeaver") and "Mythic" or "Basic",
		duration = 3.5
	})
end)

return {
	PlaySequence = playEvolutionSequence
}
