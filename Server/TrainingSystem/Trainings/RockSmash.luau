--RockSmash.lua

local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Utils = require(script.Parent.Parent.Utils)
local AnimationHandler = require(game.ServerScriptService.Main:WaitForChild("AnimationHandler"))

-- Remotes do TrainingSystem
local Remotes = RS:WaitForChild("Remotes")
local EvFocus   = Remotes:WaitForChild("TrainingCameraFocus")
local EvRestore = Remotes:WaitForChild("TrainingCameraRestore")

local Training = {}
Training.Name = "RockSmash"
Training.Duration = 10
Training.BaseBonus = { Strength = 20} -- ganhos aplicados pelo Main.lua quando success == true

-- === Helpers ===

local function getDeathAnimationId(monster: Model)
	local race = monster:GetAttribute("Race")
	if not race then return nil end
	local animRoot = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("Animations")
	if not animRoot then return nil end

	local folder = animRoot:FindFirstChild(race)
	if not folder then
		for _, f in ipairs(animRoot:GetChildren()) do
			if f:IsA("Folder") and f.Name:lower() == tostring(race):lower() then folder = f; break end
		end
	end
	if not folder then return nil end
	for _, a in ipairs(folder:GetChildren()) do
		if a:IsA("Animation") and a.Name:lower():find("death") then
			return a.AnimationId
		end
	end
	return nil
end

local function stopAll(model: Model)
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
		pcall(function() t:Stop(0.05) end)
	end
end

local function playDeathFrozen(monster: Model)
	local hum = monster:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local deathId = getDeathAnimationId(monster)
	if not deathId then return nil end

	local anim = Instance.new("Animation")
	anim.AnimationId = deathId
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0.15)
	task.delay(0.20, function()
		if track and track.IsPlaying then pcall(function() track:AdjustSpeed(0) end) end -- congela
	end)
	return track
end

local function collectParts(root: Instance): {BasePart}
	local out = {}
	if not root then return out end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(out, d) end
	end
	return out
end

local function shakeParts(parts: {BasePart}, totalTime: number?)
	totalTime = totalTime or 0.75
	_G.EFFECTS.PlaySound("Fail", {Where = parts[1]})
	for _, p in ipairs(parts) do
		if not p:IsA("BasePart") then continue end
		local c0 = p.CFrame
		local goal = { CFrame = c0 * CFrame.Angles(0, 0, math.rad(2 + math.random()*4)) }
		local tw1 = TweenService:Create(p, TweenInfo.new(totalTime*0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		local tw2 = TweenService:Create(p, TweenInfo.new(totalTime*0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = c0 })
		tw1:Play()
		tw1.Completed:Connect(function() tw2:Play() end)
	end
end

local function explode(parts: {BasePart})
	for _, bp in ipairs(parts) do
		if not bp:IsA("BasePart") then continue end
		bp.Anchored = false
		local dir = (bp.Position + Vector3.new(math.random()-0.5, math.random(), math.random()-0.5)).Unit
		bp.AssemblyLinearVelocity = dir * (10 + math.random()*14)
		bp.AssemblyAngularVelocity = Vector3.new(math.random(), math.random(), math.random()) * 6
	end
	if _G.EFFECTS and parts[1] then
		_G.EFFECTS.EmitterEffect({
			Name = "DefaultImpact", Duration = 1.25,
			Position = CFrame.new(parts[1].Position)
		})
		_G.EFFECTS.PlaySound("RockImpact", {Where = parts[1]})
		--_G.EFFECTS.PlaySound("DefaultImpact", { Where = parts[1] })
	end
end

local function castOnce(monster: Model, castAnimId: string?, fallback: number?)
	if castAnimId then
		local ok = pcall(function()
			AnimationHandler:PlayCastOnce(monster, castAnimId, { fallback = fallback or 0.7, replace = false })
		end)
		if ok then return end
	end
	task.wait(fallback or 0.6)
end

local function pickCastAnimation(monster: Model)
	local race = monster:GetAttribute("Race")
	if not race then return nil end
	local animRoot = RS.Assets and RS.Assets:FindFirstChild("Animations")
	if not animRoot then return nil end
	local folder = animRoot:FindFirstChild(race)
	if not folder then return nil end
	for _, a in ipairs(folder:GetChildren()) do
		if a:IsA("Animation") and (a.Name:lower():find("cast") or a.Name:lower():find("attack")) then
			return a.AnimationId
		end
	end
	return nil
end

local function withHumanoidFrozen(monster: Model, fn)
	local hum = monster:FindFirstChildOfClass("Humanoid")
	local root = monster:FindFirstChild("HumanoidRootPart") or monster.PrimaryPart
	local prevWS, prevAuto
	if hum and root then
		prevWS, prevAuto = hum.WalkSpeed, hum.AutoRotate
		hum:MoveTo(root.Position)
		hum.WalkSpeed = 0
		hum.AutoRotate = false
	end

	local ok, err = pcall(fn)
	if not ok then warn("[RockSmash] error:", err) end

	if hum then
		hum.WalkSpeed = prevWS or 16
		hum.AutoRotate = (prevAuto == nil) and true or prevAuto
	end
	return ok
end

-- === START ===
function Training:Start(monster: Model, player: Player, ctx)
	assert(monster and player, "RockSmash: missing monster/player")

	-- Spawn do asset: ReplicatedStorage/Assets/TrainingAssets/RockSmash/Rock
	local assetsRoot = RS:WaitForChild("Assets"):WaitForChild("TrainingAssets")
	local myRoot = assetsRoot:FindFirstChild("RockSmash")
	assert(myRoot, "RockSmash asset folder not found in ReplicatedStorage/Assets/TrainingAssets/RockSmash")
	local rockTemplate = myRoot:FindFirstChild("Rock") or myRoot:FindFirstChildWhichIsA("Model")
	assert(rockTemplate, "RockSmash: 'Rock' model not found inside TrainingAssets/RockSmash")

	-- Clona pro Workspace em um folder temporário
	local sessionFolder = Instance.new("Folder")
	sessionFolder.Name = "RockSmash_Session"
	sessionFolder.Parent = Workspace

	local rockClone = rockTemplate:Clone()
	rockClone.Name = "Rock"
	rockClone.Parent = sessionFolder

	-- Posição base
	local baseCF = (ctx.Start and ctx.Start.CFrame or monster:GetPivot())
	local spawnOffset = CFrame.new(0, 0, -8)
	rockClone:PivotTo(baseCF * spawnOffset)

	-- Garante ancoragem inicial das peças
	local rockParts = collectParts(rockClone)
	for _, p in ipairs(rockParts) do
		p.Anchored = true
		p.AssemblyLinearVelocity = Vector3.zero
		p.AssemblyAngularVelocity = Vector3.zero
	end

	-- Teleporta o monstro no Start
	if ctx.Start and monster.PrimaryPart then
		monster:PivotTo(ctx.Start.CFrame + Vector3.new(0, 2, 0))
	end

	-- 3 casts — câmera diferente a cada cast
	local camPresets = {
		{ radius = 11.5, height = 4.2, yaw = -30, fov = 68 },
		{ radius =  8.8, height = 5.8, yaw = 35, fov = 64 },
		{ radius =  7.0, height = 5.0, yaw = 10, fov = 60 },
	}
	local castAnimId = pickCastAnimation(monster)

	withHumanoidFrozen(monster, function()
		for i = 1, 3 do
			EvFocus:FireClient(player, monster, Training.Name, {
				mode = "orbit",
				duration = 0.85,
				radius = camPresets[i].radius,
				height = camPresets[i].height,
				yawOffsetDeg = camPresets[i].yaw,
				fov = camPresets[i].fov,
				target = "monster",
			})
			
			castOnce(monster, castAnimId, 0.7)
			if _G.EFFECTS then
				_G.EFFECTS.PlaySound("DefaultImpact", { Where = monster })
				_G.EFFECTS.FovEffect({ Fov = 62, Start = 0.12, Duration = 0.10 })
			end
			task.wait(0.15)
		end
	end)

	-- Decide sucesso (STR dá identidade ao treino)
	local strength = monster:GetAttribute("Strength") or 0
	local successChance = math.clamp(0.45 + (strength * 0.01), 0.25, 0.90)
	local success = math.random() < successChance

	if success then
		-- Explode (unanchor + impulso) e finaliza
		explode(rockParts)
		-- pequeno delay só pra “mostrar”
		task.wait(0.8)
		-- RESET: destrói clone e recria no mesmo pivot original, ancorado
		rockClone:Destroy()
		local fresh = rockTemplate:Clone()
		fresh.Name = "Rock"
		fresh.Parent = sessionFolder
		fresh:PivotTo(baseCF)
		for _, p in ipairs(collectParts(fresh)) do p.Anchored = true end

		-- opcionalmente envia para End
		if ctx.End and monster.PrimaryPart then
			monster:PivotTo(ctx.End.CFrame + Vector3.new(0, 2, 0))
		end

		-- cleanup de sessão (o Main vai restaurar câmera e estado)
		task.delay(1.0, function() if sessionFolder and sessionFolder.Parent then sessionFolder:Destroy() end end)
		return { success = true, reason = "rock_break" }
	else
		-- Falha: tremedeira
		shakeParts(rockParts, 0.8)

		-- congela movimento / autorotate
		local hum = monster:FindFirstChildOfClass("Humanoid")
		local root = monster:FindFirstChild("HumanoidRootPart") or monster.PrimaryPart
		local prevWS, prevAuto = nil, nil
		if hum and root then
			prevWS, prevAuto = hum.WalkSpeed, hum.AutoRotate
			hum:MoveTo(root.Position)
			hum.WalkSpeed = 0
			hum.AutoRotate = false
		end

		-- som de falha
		if _G.EFFECTS and root then
			pcall(function() _G.EFFECTS.PlaySound("Fail", {Where = root}) end)
		end

		-- duração da câmera de falha (controla o congelamento)
		local camFailDuration = 1.6

		-- dispara câmera de falha
		local ownerId = monster:GetAttribute("OwnerId")
		local plr = ownerId and game:GetService("Players"):GetPlayerByUserId(tonumber(ownerId)) or nil
		if plr then
			local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
			local EvFail = Remotes:WaitForChild("TrainingCameraFail")
			EvFail:FireClient(plr, monster, {
				mode = "death",
				duration = camFailDuration,
				radiusStart = 12, radiusEnd = 9,
				heightStart = 6, heightEnd = 7.5,
				angularSpeedDeg = 55,
				fovStart = 70, fovEnd = 62,
				easeTime = 0.25,
			})
		end

		-- toca a death e congela A PARTIR de 60% da anima
		_G.FUNCTIONS.playDeathFrozen(monster, 0.6, camFailDuration, { fallbackLen = 1.2, block = false })

		-- ==================================================================
		--  THIS IS THE FIX: Wait for the duration of the failure sequence.
		--  This pauses the script here, keeping WalkSpeed at 0 until the
		--  camera effect is over.
		-- ==================================================================
		task.wait(camFailDuration)

		-- reset da rocha pro pivot-base (ancora e zera velocidades)
		for _, p in ipairs(rockParts) do
			p.Anchored = true
			p.AssemblyLinearVelocity = Vector3.zero
			p.AssemblyAngularVelocity = Vector3.zero
		end
		rockClone:PivotTo(baseCF)

		-- restaura movimento APÓS a espera
		if hum then
			hum.WalkSpeed = prevWS or 16
			hum.AutoRotate = (prevAuto == nil) and true or prevAuto
		end

		-- Limpa a sessão
		task.delay(0.5, function() if sessionFolder and sessionFolder.Parent then sessionFolder:Destroy() end end)

		return { success = false, reason = "rock_intact" }
	end
end


return Training
