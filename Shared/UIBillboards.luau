-- ReplicatedStorage/Modules/UIBillboards.lua
local UIB = {}
local Teams = {
	[1] = Color3.fromRGB(60, 160, 255), -- azul
	[2] = Color3.fromRGB(255, 90, 90),  -- vermelho
	[0] = Color3.fromRGB(180, 180, 180),-- cinza (FFA)
	me = Color3.fromRGB(255, 220, 90),  -- amarelo (mob do player)
}

local function resolveAdornee(model: Model): BasePart?
	if not model or not model:IsA("Model") then return nil end
	-- 1) PrimaryPart, se já existir
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end
	-- 2) HumanoidRootPart (ou RootPart)
	local hrp = model:FindFirstChild("HumanoidRootPart", true)
	if hrp and hrp:IsA("BasePart") then return hrp end
	-- 3) Head
	local head = model:FindFirstChild("Head", true)
	if head and head:IsA("BasePart") then return head end
	-- 4) primeira BasePart do modelo
	for _,d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then return d end
	end
	return nil
end

local function mkBillboard(adorn: BasePart, size, offset, alwaysOnTop)
	local bb = Instance.new("BillboardGui")
	bb.Size = size or UDim2.new(0, 160, 0, 20)
	bb.StudsOffset = offset or Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = (alwaysOnTop ~= false)
	bb.Adornee = adorn
	bb.Name = "UIB_Billboard"
	bb.ResetOnSpawn = false
	bb.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	return bb
end

-- Barra de HP (em cima do mob)
function UIB.AttachHpBar(model: Model)
	if not model or not model:IsA("Model") then return end
	if model:FindFirstChild("UIB_Hp") then return end

	local adorn = resolveAdornee(model)
	if not adorn then
		-- espera aparecer uma parte válida (spawn assíncrono)
		local conn; conn = model.DescendantAdded:Connect(function(obj)
			if obj:IsA("BasePart") and not model:FindFirstChild("UIB_Hp") then
				local okAdorn = resolveAdornee(model)
				if okAdorn then
					conn:Disconnect()
					UIB.AttachHpBar(model) -- chama de novo agora que existe
				end
			end
		end)
		return
	end

	local bb = mkBillboard(adorn, UDim2.new(0, 180, 0, 28), Vector3.new(0, 5.2, 0), true)
	bb.Name = "UIB_Hp"
	bb.Parent = model

	local frame = Instance.new("Frame", bb)
	frame.Size = UDim2.fromScale(1,1)
	frame.BackgroundColor3 = Color3.fromRGB(40,40,40)
	frame.BorderSizePixel = 0

	local fill = Instance.new("Frame", frame)
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0,0.5)
	fill.Position = UDim2.new(0, 2, .5, 0)
	fill.Size = UDim2.new(1, -4, .8, 0)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 120)
	fill.BorderSizePixel = 0

	local name = Instance.new("TextLabel", frame)
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, -6, 1, 0)
	name.Position = UDim2.new(0, 3, 0, 0)
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextColor3 = Color3.new(1,1,1)
	name.TextStrokeTransparency = 0.7
	name.Text = (model:GetAttribute("Name") or model.Name)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local maxHp = (humanoid and humanoid.MaxHealth) or (model:GetAttribute("Hp") or 100)

	local function set(v, mx)
		mx = mx or maxHp
		local p = math.clamp((v or mx)/math.max(1,mx), 0, 1)
		fill.Size = UDim2.new(p, -4, .8, 0)
	end

	if humanoid then
		set(humanoid.Health, humanoid.MaxHealth)
		humanoid.HealthChanged:Connect(function(h) set(h, humanoid.MaxHealth) end)
	else
		set(model:GetAttribute("Hp") or maxHp, maxHp)
		model:GetAttributeChangedSignal("Hp"):Connect(function()
			set(model:GetAttribute("Hp"))
		end)
	end

	-- se PrimaryPart for definido depois, re-ancora o billboard
	model:GetPropertyChangedSignal("PrimaryPart"):Connect(function()
		local newAdorn = resolveAdornee(model)
		if newAdorn and bb then bb.Adornee = newAdorn end
	end)

	return bb
end

function UIB.AttachTeamArrow(model: Model, isMyMonster: boolean?)
	if not model or not model:IsA("Model") then return end
	if model:FindFirstChild("UIB_Arrow") then return end

	local adorn = resolveAdornee(model)
	if not adorn then
		local conn; conn = model.DescendantAdded:Connect(function(obj)
			if obj:IsA("BasePart") and not model:FindFirstChild("UIB_Arrow") then
				local okAdorn = resolveAdornee(model)
				if okAdorn then
					conn:Disconnect()
					UIB.AttachTeamArrow(model, isMyMonster)
				end
			end
		end)
		return
	end

	local teamId = model:GetAttribute("Team") or 0
	local color = isMyMonster and Color3.fromRGB(255,220,90)
		or (teamId==1 and Color3.fromRGB(60,160,255))
		or (teamId==2 and Color3.fromRGB(255,90,90))
		or Color3.fromRGB(180,180,180)

	local bb = mkBillboard(adorn, UDim2.new(0, 36, 0, 36), Vector3.new(0, 7.2, 0), true)
	bb.Name = "UIB_Arrow"
	bb.Parent = model

	local tri = Instance.new("ImageLabel", bb)
	tri.AnchorPoint = Vector2.new(.5,.5)
	tri.Position = UDim2.fromScale(.5,.5)
	tri.Size = UDim2.fromScale(1,1)
	tri.BackgroundTransparency = 1
	tri.Image = "rbxassetid://13199052680"
	tri.ImageColor3 = color

	model:GetAttributeChangedSignal("Team"):Connect(function()
		local t = model:GetAttribute("Team") or 0
		tri.ImageColor3 = isMyMonster and Color3.fromRGB(255,220,90)
			or (t==1 and Color3.fromRGB(60,160,255))
			or (t==2 and Color3.fromRGB(255,90,90))
			or Color3.fromRGB(180,180,180)
	end)

	model:GetPropertyChangedSignal("PrimaryPart"):Connect(function()
		local newAdorn = resolveAdornee(model)
		if newAdorn and bb then bb.Adornee = newAdorn end
	end)

	return bb
end

-- Banner "Hyper Beam!" sobre o personagem
function UIB.SpawnAttackBanner(model, text)
	if not model or not model.PrimaryPart then return end
	local bb = mkBillboard(model.PrimaryPart, UDim2.new(0, 220, 0, 36), Vector3.new(0, 8.5, 0), true)
	bb.Name = "UIB_Banner"
	bb.Parent = model
	local lbl = Instance.new("TextLabel", bb)
	lbl.Size = UDim2.fromScale(1,1)
	lbl.BackgroundTransparency = 0.25
	lbl.BackgroundColor3 = Color3.fromRGB(30,30,30)
	lbl.TextColor3 = Color3.new(1,1,1)
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextScaled = true
	lbl.Text = text
	lbl.TextStrokeTransparency = 0.7
	lbl.AutoLocalize = false

	game:GetService("TweenService"):Create(lbl, TweenInfo.new(.2), {BackgroundTransparency = .1}):Play()
	task.delay(1.1, function()
		if bb then bb:Destroy() end
	end)
end

return UIB