-- ServerScriptService/Main/TrainingUIFromPrompt.server.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
-- ADICIONE no ReplicatedStorage/Remotes um RemoteEvent chamado "RequestOpenTrainingUI"
local RequestOpenTrainingUI = Remotes:FindFirstChild("RequestOpenTrainingUI")
if not RequestOpenTrainingUI then
	RequestOpenTrainingUI = Instance.new("RemoteEvent")
	RequestOpenTrainingUI.Name = "RequestOpenTrainingUI"
	RequestOpenTrainingUI.Parent = Remotes
end

-- Já existente no seu projeto e usado pelo ZoneUISystem para abrir a UI no client:
local OpenTrainingUIEvent = Remotes:WaitForChild("OpenTrainingUIEvent")

-- Utilitário: preenche stats a partir do monstro do player (OwnerId == player.UserId)
local function prefillStatsFor(player: Player)
	local uid = player.UserId
	local monster

	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("Model") and tonumber(inst:GetAttribute("OwnerId") or 0) == uid then
			monster = inst
			break
		end
	end

	local stats = {}
	for _, name in ipairs({ "Strength", "Defense", "Skill", "Speed", "Intelligence", "Luck" }) do
		stats[name] = monster and (monster:GetAttribute(name) or 0) or 0
	end
	return stats
end

-- Segurança: valida o modelo enviado pelo cliente e o BaseOwnerId no servidor
local function modelBelongsToPlayer(model: Instance, player: Player): boolean
	if not model or not model.Parent then return false end
	if not model:IsA("Model") then return false end

	local baseOwnerId = tonumber(model:GetAttribute("BaseOwnerId"))
	if baseOwnerId == nil then
		-- fallback opcional para compat:
		baseOwnerId = tonumber(model:GetAttribute("OwnerId"))
	end
	return baseOwnerId ~= nil and baseOwnerId == player.UserId
end

RequestOpenTrainingUI.OnServerEvent:Connect(function(player, modelRef)
	-- Revalida tudo no servidor
	if typeof(modelRef) ~= "Instance" or not modelBelongsToPlayer(modelRef, player) then
		-- Rejeita silenciosamente; opcional: enviar feedback de "não autorizado"
		return
	end
	print("request")
	-- Ok, é o dono. Abre UI igual ao ZoneUISystem (com stats preenchidos).
	local payload = { stats = prefillStatsFor(player) }
	OpenTrainingUIEvent:FireClient(player, payload)
end)
