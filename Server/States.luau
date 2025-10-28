local HTTP=game:GetService('HttpService');
local PL=game:GetService('Players');
local module={}
local Storage=setmetatable({},{
	__index={
		get_storage=function(self,plr: Player)
			self[plr]=self[plr]or{}
			return self[plr]
		end,
		cleanup=function(self)
			for plr: Player,obj in pairs(self)do
				for k,v in obj do
					module:RemoveState(plr,k,v.self_key)
				end
			end
			table.clear(self);
		end,
	}
});

local HealingLoops={}
local BoostActivated={}
local MovementLoops={}
-- O CombatLoop foi movido para o CombatManager para centralizar a lógica.
local RespawnLoops={}

local function _resolve(source: Model | Player)
	-- Returns: storageKey(any), model(Model), isPlayer(boolean)
	if source:IsA("Player") then
		return source, source.Character, true
	end
	-- source is Model
	local plr = PL:GetPlayerFromCharacter(source)
	-- Use Player as storage key if available; otherwise fall back to the model itself
	return (plr or source), source, false
end

local states={
	["Disabled"]={
		Activated=function(chr: Model)
		end,
		Deactivated=function(chr: Model)
		end,
		Replicated=true
	},
	["Ragdoll"]={
		Activated=function(chr: Model)
			_G.RAGDOLL:Ragdoll(chr);
		end,
		Linked={"Disabled","CatchImmune"},
		Deactivated=function(chr: Model)
			_G.RAGDOLL:Recover(chr);
		end,
		Replicated=true
	},
	["Infected"]={
		Activated=function(chr: Model)
		end,
	},
	["Healing"]={
		Activated=function(chr: Model,amount: number)
			_G.EFFECTS.PlaySound("Heal",{Where=chr})
			print('start')
			HealingLoops[chr]=task.defer(function()
				while HealingLoops[chr]do
					_G.DAMAGE:Heal(chr,1,"Healing")
					task.wait(.2)
				end
			end)
		end,
		Deactivated=function(chr)
			if HealingLoops[chr]then
				pcall(task.cancel,HealingLoops[chr]);
				HealingLoops[chr]=nil
			end
			print('stopped')
		end
	},
	["Bleeding"]={
		Activated=function(chr: Model)
		end,
		Deactivated=function(chr)
		end
	},
	["Inactive"]={
		Activated=function(chr: Model)
		end,
		Deactivated=function(chr)
		end
	},
	["Idle"]={
		Activated=function(chr: Model)
			print('Idle activated')
		end,
		Deactivated=function(chr)
			print('Idle deactivated')
		end,
		Replicated=true
	},
	["Following"] = {
		Activated = function(chr)
			--print("Following activated for:", chr and chr.Name)
			local ownerKey = chr:GetAttribute("OwnerId") or chr:GetAttribute("Userid")
			if not ownerKey then return end

			local ownerPlayer = PL:GetPlayerByUserId(tonumber(ownerKey))
			if ownerPlayer and ownerPlayer.Character then
				-- Apenas inicia o sistema. O loop contínuo agora está no módulo Movement.
				_G.MOVEMENT.StartFollowing(chr, ownerPlayer.Character)
			else
				warn("Não foi possível encontrar o personagem do dono para seguir.")
			end
			task.spawn(function()
				local hum = chr.Humanoid
				while hum.Health < hum.MaxHealth do
					hum.Health += 1
					wait(0.2)
				end
			end
			)
		end,
		Deactivated = function(chr)
			--print("Following deactivated for", chr and chr.Name)
			-- Para o movimento contínuo da Parte Guia
			_G.MOVEMENT.StopFollowing(chr)
		end,
		Replicated = true
	},
	["InCombat"] = {
		Activated = function(chr: Model)
			-- NOTE: Logic to remove "Following" state moved to CombatManager.StartCombat

			if _G.MOVEMENT then
				_G.MOVEMENT.StopFollowing(chr)
				if _G.MOVEMENT.StopFacing then
					_G.MOVEMENT.StopFacing(chr)
				end
			end

			-- Cancel any immediate motion
			local hum = chr:FindFirstChildOfClass("Humanoid")
			if hum and chr.PrimaryPart then
				hum:MoveTo(chr.PrimaryPart.Position)
				hum.AutoRotate = false
			end
		end,

		-- When InCombat ends → go back to Following (if owned & alive) else Idle.
		Deactivated = function(chr: Model)
			-- This function now ONLY cleans up combat-related movement/state.
			-- It no longer decides the *next* state (CombatManager does that).
			if _G.MOVEMENT and _G.MOVEMENT.StopFacing then
				_G.MOVEMENT.StopFacing(chr)
			end

			local hum = chr:FindFirstChildOfClass("Humanoid")
			--local prevSpeed = hum.WalkSpeed
			--if hum then
			--	hum.AutoRotate = true
			--	if hum.WalkSpeed <= 0 then hum.WalkSpeed = prevSpeed end
			--end

			

			-- Clear transient states that can block follow
			local st = _G.STATES and _G.STATES:GetStorage(chr)
			if st then
				if st.Attacking then _G.STATES:RemoveState(chr, "Attacking", st.Attacking.self_key) end
				if st.Casting   then _G.STATES:RemoveState(chr, "Casting",   st.Casting.self_key)   end
			end
		end,
		Replicated = true
	},

	["Training"] = {
		Activated = function(chr: Model)
			-- Se estiver seguindo, desligar
			if _G.STATES and _G.STATES:IsInState(chr, "Following") then
				local st = _G.STATES:GetStorage(chr)
				if st and st.Following then
					_G.STATES:RemoveState(chr, "Following", st.Following.self_key)
				end
			end
			if _G.MOVEMENT then
				_G.MOVEMENT.StopFollowing(chr)
			end

			-- Cancela movimento atual
			local hum = chr:FindFirstChildOfClass("Humanoid")
			if hum and chr.PrimaryPart then
				hum:MoveTo(chr.PrimaryPart.Position)
			end

			chr:SetAttribute("IsTraining", true)
		end,

		Deactivated = function(chr: Model)
			chr:SetAttribute("IsTraining", nil)
		end,

		Replicated = true,
	},
	
	["Attacking"]={
		
		Activated=function(chr: Model)
			-- print(chr.Name .. " started attacking") -- Comentado para reduzir spam no console
			--chr:SetAttribute("IsAttacking",true)
			chr.Humanoid.WalkSpeed = 0
		end,
		Deactivated = function(chr: Model)
			if _G.MOVEMENT and _G.MOVEMENT.StopFacing then
				_G.MOVEMENT.StopFacing(chr)
			end
		end,
		Replicated=true
	},
	["Casting"]={
		Activated=function(chr: Model)
			print(chr.Name .. " is casting")
			chr:SetAttribute("IsCasting",true)
			chr.Humanoid.WalkSpeed = 0
		end,
		Deactivated=function(chr: Model)
			print(chr.Name .. " finished casting")
			chr:SetAttribute("IsCasting",false)
			chr.Humanoid.WalkSpeed = 16
		end,
		Replicated=true
	},
	["DECIDING"] = {
		Activated = function(chr: Model)
			chr:SetAttribute("IsDeciding", true)
			local hum = chr:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = 0 end
		end,
		Deactivated = function(chr: Model)
			chr:SetAttribute("IsDeciding", nil)
			local hum = chr:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = 16 end
		end,
		Replicated = true
	},
	["POSITIONING"] = {
		Activated = function(chr: Model)
			chr:SetAttribute("IsPositioning", true)
			local hum = chr:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = 16 end
		end,
		Deactivated = function(chr: Model)
			chr:SetAttribute("IsPositioning", nil)
		end,
		Replicated = true
	},
	["REPOSITIONING"] = {
		Activated = function(chr: Model)
			chr:SetAttribute("IsRepositioning", true)
			local hum = chr:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = 16 end
		end,
		Deactivated = function(chr: Model)
			chr:SetAttribute("IsRepositioning", nil)
		end,
		Replicated = true
	},
	["RESTING"] = {
		Activated = function(chr: Model)
			chr:SetAttribute("IsResting", true)
			local hum = chr:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = 0 end
		end,
		Deactivated = function(chr: Model)
			chr:SetAttribute("IsResting", nil)
			local hum = chr:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = 16 end
		end,
		Replicated = true
	},
	["REACTING"] = {
		Activated = function(chr: Model)
			chr:SetAttribute("IsReacting", true)
			local hum = chr:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = 0 end
		end,
		Deactivated = function(chr: Model)
			chr:SetAttribute("IsReacting", nil)
			local hum = chr:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = 16 end
		end,
		Replicated = true
	},
	["DEFENDING"] = {
		Activated = function(chr: Model)
			chr:SetAttribute("IsDefending", true)
			local hum = chr:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = 0 end
			if _G.MOVEMENT and _G.MOVEMENT.StopFacing then
				_G.MOVEMENT.StopFacing(chr)
			end
		end,
		Deactivated = function(chr: Model)
			chr:SetAttribute("IsDefending", nil)
			local hum = chr:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = 16 end
		end,
		Replicated = true
	},
	["Stunned"]={
		Activated=function(chr: Model)
			print(chr.Name .. " is stunned")
			chr:SetAttribute("IsStunned",true)
		end,
		Deactivated=function(chr: Model)
			print(chr.Name .. " is no longer stunned")
			chr:SetAttribute("IsStunned",false)
		end,
		Replicated=true,
		Linked={"Disabled"}
	},
	["Dead"]={
		Activated=function(chr: Model)
			print(chr.Name .. " died")
			chr:SetAttribute("IsDead",true)
			local ownerId=chr:GetAttribute("OwnerId")
			if ownerId then
				local player=PL:GetPlayerByUserId(ownerId)
				if player then
					RespawnLoops[chr]=task.delay(3,function()
						if RespawnLoops[chr]then
							module:RespawnPlayerMonster(player)
							RespawnLoops[chr]=nil
						end
					end)
				end
			end
		end,
		Deactivated=function(chr: Model)
			print(chr.Name .. " revived")
			chr:SetAttribute("IsDead",false)
			if RespawnLoops[chr]then
				pcall(task.cancel,RespawnLoops[chr])
				RespawnLoops[chr]=nil
			end
			chr:Destroy()
		end,
		Replicated=true,
		Linked={"Disabled"}
	},
	["Respawning"]={
		Activated=function(chr: Model)
			print(chr.Name .. " is respawning")
			chr:SetAttribute("IsRespawning",true)
		end,
		Deactivated=function(chr: Model)
			print(chr.Name .. " finished respawning")
			chr:SetAttribute("IsRespawning",false)
		end,
		Replicated=true
	},
	["Insane"]={
		Activated=function(plr: Player)
			print("playerInsanity: ",plr)
		end,
	}
}

function module:SetState(source: Model | Player, state: string, duration: number?, ...)
	if not states[state] then return end

	local storageKey, model, isPlayer = _resolve(source)
	if not model or not model.Parent then return end

	local st = Storage:get_storage(storageKey)
	local unique_key = HTTP:GenerateGUID(false)

	-- Call Activated with the MODEL
	if states[state].Activated then
		states[state].Activated(model, ...)
	end

	-- Linked states (also keyed on the same storageKey)
	local linked_keys = (function()
		if not states[state].Linked then return end
		local t = {}
		for _, linked_state in ipairs(states[state].Linked) do
			t[linked_state] = module:SetState(source, linked_state)
		end
		return t
	end)()

	st[state] = { self_key = unique_key, linked_keys = linked_keys }

	-- Replicate attribute on the MODEL (or Player if you truly intend that)
	if states[state].Replicated then
		(model or source):SetAttribute(state, true)
	end

	if duration then
		task.delay(duration, function()
			module:RemoveState(source, state, unique_key)
		end)
	end
	return unique_key
end

function module:RemoveState(source: Model | Player, state: string, unique_key: string, ...)
	if not states[state] then return end

	local storageKey, model, isPlayer = _resolve(source)
	if not model then return end

	local st = Storage:get_storage(storageKey)
	if not st[state] or st[state].self_key ~= unique_key then return end

	-- Call Deactivated with the MODEL
	if states[state].Deactivated then
		states[state].Deactivated(model, ...)
	end

	-- Remove linked states
	if st[state].linked_keys then
		for linked_state, linked_key in pairs(st[state].linked_keys) do
			module:RemoveState(source, linked_state, linked_key)
		end
	end

	-- Clear replicated attribute on the MODEL (or Player if you truly intend that)
	if states[state].Replicated then
		(model or source):SetAttribute(state, nil)
	end

	st[state] = nil
end

function module:IsInState(source: Model & Player,state: string)
	if not states[state]then return end
	source=(source:IsA('Player')and source or PL:GetPlayerFromCharacter(source))or source
	local st=Storage:get_storage(source);
	return st[state]~=nil
end

-- Adicionado para facilitar o acesso externo ao storage de um monstro
function module:GetStorage(source)
	source=(source:IsA('Player')and source or PL:GetPlayerFromCharacter(source))or source
	return Storage:get_storage(source)
end

function module:ClearStorage(source)
	Storage:cleanup();
end
function module:IsInCombat(character)
	return self:IsInState(character,"InCombat")
end
function module:IsStunned(character)
	return self:IsInState(character,"Stunned")
end
function module:IsDead(character)
	return self:IsInState(character,"Dead")
end
function module:IsAttacking(character)
	return self:IsInState(character,"Attacking")
end
function module:IsRespawning(character)
	return self:IsInState(character,"Respawning")
end

function module:RespawnPlayerMonster(player)
	local playerId = tostring(player.UserId)
	print("Respawning monster for player: " .. player.Name)

	-- Unregister current monster first
	if _G.MONSTERGENERATOR and _G.MONSTERGENERATOR.UnregisterPlayerMonster then
		_G.MONSTERGENERATOR.UnregisterPlayerMonster(player.UserId)
	end

	-- Find and cleanup current monster in workspace
	local currentMonster = nil

	-- Method 1: Check PlayerMonsters table
	if _G.MONSTERGENERATOR and _G.MONSTERGENERATOR.GetPlayerMonster then
		currentMonster = _G.MONSTERGENERATOR.GetPlayerMonster(player.UserId)
	end

	-- Method 2: Search by OwnerId
	if not currentMonster then
		for _, obj in pairs(workspace:GetChildren()) do
			if obj:IsA("Model") then
				local ownerId = obj:GetAttribute("OwnerId")
				if ownerId and tonumber(ownerId) == player.UserId then
					currentMonster = obj
					break
				end
			end
		end
	end

	-- Cleanup current monster
	if currentMonster and currentMonster.Parent then
		print("Cleaning up old monster: " .. currentMonster.Name)
		currentMonster:Destroy()
		self:RemoveState(currentMonster, "Dead")
		print(typeof(currentMonster))
		--currentMonster.Parent:Destroy()

		-- Remove states
		if self:IsInState(currentMonster, "InCombat") then
			local st = self:GetStorage(currentMonster)
			if st and st.InCombat then
				self:RemoveState(currentMonster, "InCombat", st.InCombat.self_key)
			end
		end

		if self:IsInState(currentMonster, "Dead") then
			local st = self:GetStorage(currentMonster)
			if st and st.Dead then
				self:RemoveState(currentMonster, "Dead", st.Dead.self_key)
			end
		end

		-- Stop movement
		if _G.MOVEMENT then
			_G.MOVEMENT.StopFollowing(currentMonster)
		end

		-- Destroy the model
	end

	-- Get player data and create new monster
	local playerData = _G.DATA and _G.DATA:Get(player.UserId)
	if not playerData then
		-- Create default data if DATA system doesn't exist
		playerData = nil
	end

	-- Create new monster
	local newMonster, monsterData
	if _G.MONSTERGENERATOR and _G.MONSTERGENERATOR.BuildMonster then
		newMonster, monsterData = _G.MONSTERGENERATOR.BuildMonster(playerData.Monster, player.UserId)
	else
		warn("MONSTERGENERATOR not available for respawn")
		return nil
	end

	if newMonster then
		-- Position near player
		local character = player.Character
		if character and character.PrimaryPart then
			local spawnPos = character.PrimaryPart.Position + Vector3.new(5, 0, 5)
			if newMonster.PrimaryPart then
				newMonster:SetPrimaryPartCFrame(CFrame.new(spawnPos))
			end
		end

		-- Set respawning state briefly
		self:SetState(newMonster, "Respawning", 2)

		task.delay(2.1, function()
			if newMonster and newMonster.Parent then
				self:SetState(newMonster, "Following")
				print("Monster respawned and following: " .. player.Name)

				-- Verify registration
				if _G.MONSTERGENERATOR and _G.MONSTERGENERATOR.GetPlayerMonster then
					local registeredMonster = _G.MONSTERGENERATOR.GetPlayerMonster(player.UserId)
					if registeredMonster == newMonster then
						print("Monster properly registered for player: " .. player.Name)
					else
						warn("Monster registration failed for player: " .. player.Name)
					end
				end
			end
		end)

		return newMonster
	end

	return nil
end

function module:ForceRespawn(player)
	return self:RespawnPlayerMonster(player)
end

return module
