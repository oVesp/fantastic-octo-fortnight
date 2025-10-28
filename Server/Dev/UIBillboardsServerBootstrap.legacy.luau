-- ServerScriptService>UIBillboardsServerBootstrap.lua
local RS = game:GetService("ReplicatedStorage")
local UIB = require(RS.Modules.UIBillboards)

local function tryAttach(model)
	if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
		if not model:FindFirstChild("UIB_Hp") then
			UIB.AttachHpBar(model)
		end
	end
end

-- Attach to existing
for _, m in ipairs(workspace:GetChildren()) do
	tryAttach(m)
end

-- Attach to future
workspace.ChildAdded:Connect(tryAttach)
