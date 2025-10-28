-- ModuleScript: ServerScriptService>Main>TrainingSystem>Main
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Utils = require(script.Parent.Utils)
local MoveUnlocks = require(RS.Modules.MoveUnlocks)
local TrainingsFolder = script.Parent.Trainings 
local TrainingCache = {}

-- Add BaseManager
local BaseManager = require(script.Parent.Parent.BaseManager)
local baseManager = BaseManager.new()


local Remotes = RS:FindFirstChild("Remotes") or Instance.new("Folder", RS)
Remotes.Name = "Remotes"
local EvFocus = Remotes:FindFirstChild("TrainingCameraFocus") or Instance.new("RemoteEvent", Remotes)
EvFocus.Name = "TrainingCameraFocus"
local EvRestore = Remotes:FindFirstChild("TrainingCameraRestore") or Instance.new("RemoteEvent", Remotes)
EvRestore.Name = "TrainingCameraRestore"
local StatUpdate = game.ReplicatedStorage.Remotes.StatUpdate


local TrainingSystem = {}
TrainingSystem.__index = TrainingSystem

function TrainingSystem:GetModule(name)
	if TrainingCache[name] then
		return TrainingCache[name]
	end
	local m = TrainingsFolder:FindFirstChild(name)
	assert(m, "Training module not found: " .. tostring(name))
	TrainingCache[name] = require(m)
	return TrainingCache[name]
end

local function resolvePlayerForMonster(fallbackPlayer, monster)
	if typeof(fallbackPlayer) == "Instance" and fallbackPlayer:IsA("Player") then
		return fallbackPlayer
	end
	local oid = monster and monster:GetAttribute("OwnerId")
	if oid then
		return Players:GetPlayerByUserId(tonumber(oid))
	end
	return nil
end

function TrainingSystem:Start(player, monster, trainingName, ctx)
	if monster:GetAttribute("InTraining") then return _G.EFFECTS.PlaySound("Fail", {Where = monster.HumanoidRootPart}) end
	assert(player and monster and trainingName, "missing args")
	-- Stop any existing movement
	if _G.MOVEMENT then
		_G.MOVEMENT.StopFollowing(monster)
	end

	local Mod = self:GetModule(trainingName)

	-- Get player's base training area with full context
	local trainingContext = baseManager:GetTrainingAreaContext(player, trainingName)
	if not trainingContext then
		warn("[TrainingSystem] Could not find training area for: " .. trainingName)
		return {success = false, reason = "training_area_not_found"}, {}
	end

	-- Build context with training area parts
	ctx = ctx or {}
	ctx.Start = trainingContext.Start
	ctx.Finish = trainingContext.Finish
	ctx.End = trainingContext.Finish -- Support both "Finish" and "End" naming
	ctx.Nodes = trainingContext.Nodes
	ctx.NodesFolder = trainingContext.Nodes -- Support both naming conventions
	ctx.Interactables = trainingContext.Interactables
	ctx.Base = trainingContext.Base

	

	monster:SetAttribute("InTraining", true)

	if _G.STATES then
		local st = _G.STATES:GetStorage(monster)
		if st and st.Following then
			_G.STATES:RemoveState(monster, "Following", st.Following.self_key)
		end
	end

	EvFocus:FireClient(player, monster, trainingName)

	local result
	local ok, err = pcall(function()
		result = Mod:Start(monster, player, ctx)
	end)

	if not ok then
		warn("Training error:", err)
		result = {success = false, reason = "error"}
	end

	local success, failReason = Utils.EvaluateSuccess(monster, player, trainingName, ctx, result)
	monster:SetAttribute("InTraining", nil)

	local targetPlayer = resolvePlayerForMonster(player, monster)
	if targetPlayer then
		EvRestore:FireClient(targetPlayer)
	end

	if monster:GetAttribute("OwnerId") and _G.STATES then
		_G.STATES:SetState(monster, "Following")
	end

	local gains = {}
	if result and result.success == true then
		local owner = monster:GetAttribute("OwnerId")
		if owner and _G.DATA then
			local data = _G.DATA:Get(owner).Monster
			data.MoveProgress = data.MoveProgress or {}
			data.MoveProgress[trainingName] = (data.MoveProgress[trainingName] or 0) + 1

			local gained = MoveUnlocks.ResolveUnlocks(data, "training", {training = trainingName})
		end

		if result.stat_override then
			gains = result.stat_override
			Utils.ApplyGains(monster, gains, player)
		else
			local baseBonus = Mod.BaseBonus
			gains = Utils.ComputeGains(monster, baseBonus)
			Utils.ApplyGains(monster, gains, player)
		end
		StatUpdate:FireClient(player, gains)

		_G.EFFECTS.PlaySound("Success", {Where = monster.HumanoidRootPart})

		if _G.MOVE_LEARNING then
			_G.MOVE_LEARNING.OnTrainingComplete(player, trainingName, true)
		end

		if _G.EVOLUTION and _G.EVOLUTION.CheckEvolutionTrigger then
			local owner = monster:GetAttribute("OwnerId")
			if owner then
				local ownerPlr = game.Players:GetPlayerByUserId(owner)
				if ownerPlr then
					task.delay(1, function()
						local ok, evoResult = pcall(function()
							return _G.EVOLUTION.CheckEvolutionTrigger(ownerPlr, "training", {
								trainingType = trainingName,
							})
						end)
						if not ok then
							warn("[TrainingSystem] Evolution check failed:", evoResult)
						end
					end)
				end
			end
		end
	else
		--_G.EFFECTS.PlaySound("Fail", {Where = targetPlayer.HumanoidRootPart})
	end

	return result, gains
end

-- Add method to get base manager for other modules
function TrainingSystem:GetBaseManager()
	return baseManager
end

return setmetatable({}, TrainingSystem)