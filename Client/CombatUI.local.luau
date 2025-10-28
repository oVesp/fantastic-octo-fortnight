-- LocalScript (starter somewhere)
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local UIB = require(RS.Modules.UIBillboards)
local UI = RS.Remotes.CombatUI
local AttackBanner = UI:WaitForChild("AttackBanner")

-- When a mob appears, attach HP/MP bar and team arrow
workspace.ChildAdded:Connect(function(obj)
	if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
		if obj.Parent == workspace then
			local isMine = obj:GetAttribute("OwnerId") == player.UserId
			if isMine or obj:GetAttribute("Team") then
				--UIB.AttachHpBar(obj)  -- This now includes both HP and MP bars
				UIB.AttachTeamArrow(obj, isMine)	
			end
		end
	end
end)

-- Attack banner + custom mob sound
AttackBanner.OnClientEvent:Connect(function(attackerModel, moveName, sfxName)
	UIB.SpawnAttackBanner(attackerModel, tostring(moveName or "ATTACK!"))
	if _G.EFFECTS and _G.EFFECTS.PlaySound then
		_G.EFFECTS.PlaySound(sfxName or "DefaultImpact", { Where = attackerModel })
	end
end)