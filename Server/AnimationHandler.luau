-- ServerScriptService/Main/Game/AnimationHandler.server.lua
local AnimationHandler = {}

local ContentProvider = game:GetService("ContentProvider")
local ACP = game:GetService("AnimationClipProvider")

-- map fraco: Model -> track atual (lock)
local activeCast = setmetatable({}, { __mode = "k" })

local function ensureAnimator(model: Model)
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	return animator
end

local function normalizeId(id: string?)
	if not id or id == "" then return nil end
	local num = tostring(id):match("(%d+)$")
	return num and ("rbxassetid://" .. num) or nil
end

local function extractLength(obj: Instance?)
	-- Tenta acessar .Length
	if obj then
		local okLen, len = pcall(function() return (obj :: any).Length end)
		if okLen and type(len) == "number" and len > 0 then
			return len
		end
	end
	-- Se for KeyframeSequence, calcula pelo último keyframe
	if obj and obj.ClassName == "KeyframeSequence" then
		local okKF, keyframes = pcall(function()
			if (obj :: any).GetKeyframes then
				return (obj :: any):GetKeyframes()
			end
			return (obj :: any).Keyframes
		end)
		if okKF and keyframes then
			local maxT = 0
			for _, kf in ipairs(keyframes) do
				local okT, t = pcall(function() return (kf :: any).Time end)
				if okT and type(t) == "number" and t > maxT then
					maxT = t
				end
			end
			return maxT
		end
	end
	return 0
end

local function getAssetLength(animationId: string?)
	local norm = normalizeId(animationId)
	if not norm then return 0 end

	-- 1) AnimationClipProvider (pode devolver Clip ou KeyframeSequence dependendo do asset)
	local ok, clipOrSeq = pcall(function()
		return ACP:GetAnimationClipAsync(norm)
	end)
	if ok and clipOrSeq then
		local len = extractLength(clipOrSeq)
		if len > 0 then return len end
	end

	-- 2) Fallback opcional via KeyframeSequenceProvider (se quiser habilitar)
	-- local KSP = game:GetService("KeyframeSequenceProvider")
	-- local ok2, kfs = pcall(function() return KSP:GetKeyframeSequenceAsync(norm) end)
	-- if ok2 and kfs then
	-- 	return extractLength(kfs)
	-- end

	return 0
end

-- Toca uma animação de cast e ESPERA terminar (sem reentrar).
-- Retorna: length (segundos) e o track (ou nil).
function AnimationHandler:PlayCastOnce(model: Model, animationId: string, opts)
	opts = opts or {}
	if not model or not animationId or animationId == "" then return 0 end

	-- Evita reentrada
	local startWait = os.clock()
	while activeCast[model] do
		if opts.replace then
			local t = activeCast[model]
			if t and t.Destroy then
				pcall(function() t:Stop(0.05) end)
				pcall(function() t:Destroy() end)
			end
			activeCast[model] = nil
			break
		end
		if os.clock() - startWait > (opts.timeout or 6) then break end
		task.wait(0.03)
	end

	local animator = ensureAnimator(model)
	if not animator then return 0 end

	-- pega o comprimento real com o método robusto
	local baseLen = getAssetLength(animationId)
	if baseLen <= 0 then
		baseLen = opts.fallback or 1.0
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = normalizeId(animationId)
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = false

	local speed = (opts.speed and opts.speed > 0) and opts.speed or 1.0
	local effectiveLen = baseLen / speed

	activeCast[model] = track
	track:Play(0.05, 1.0, speed)

	local finished = false
	local conn; conn = track.Stopped:Connect(function()
		finished = true
		if conn then conn:Disconnect() end
	end)

	local deadline = os.clock() + effectiveLen + (opts.tail or 0.06)
	while not finished and os.clock() < deadline do
		task.wait(0.03)
	end

	if track.IsPlaying then pcall(function() track:Stop(0.05) end) end
	activeCast[model] = nil

	return effectiveLen, track
end

function AnimationHandler:IsCasting(model: Model)
	return activeCast[model] ~= nil
end

-- Pré-carrega todas as animações e seus clips para evitar “short length” no 1º play
function AnimationHandler:PreloadAll()
	local RS = game:GetService("ReplicatedStorage")
	local assets = RS:FindFirstChild("Assets")
	if not assets then
		warn("[AnimationHandler] Assets not found")
		return 0, 0
	end
	local animationsRoot = assets:FindFirstChild("Animations")
	if not animationsRoot then
		warn("[AnimationHandler] Assets/Animations not found")
		return 0, 0
	end

	local animInstances = {}
	local clips = {}
	local races, total = 0, 0

	for _, raceFolder in ipairs(animationsRoot:GetChildren()) do
		if raceFolder:IsA("Folder") then
			races += 1
			for _, item in ipairs(raceFolder:GetChildren()) do
				if item:IsA("Animation") then
					table.insert(animInstances, item)
					total += 1
					local norm = normalizeId(item.AnimationId)
					if norm then
						local ok, clip = pcall(function()
							return ACP:GetAnimationClipAsync(norm)
						end)
						if ok and clip then
							table.insert(clips, clip)
						end
					end
				end
			end
		end
	end

	-- Preload dos assets (Animation e AnimationClip)
	if #animInstances > 0 then
		pcall(function() ContentProvider:PreloadAsync(animInstances) end)
	end
	if #clips > 0 then
		pcall(function() ContentProvider:PreloadAsync(clips) end)
	end

	print(string.format(
		"[AnimationHandler] Preloaded %d races / %d animations (clips: %d).",
		races, total, #clips
		))
	return races, total
end

return AnimationHandler
