-- Server: MonsterDataHandler
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Create RemoteEvents
local GetMonsterDataEvent = Instance.new("RemoteEvent")
GetMonsterDataEvent.Name = "GetMonsterData"
GetMonsterDataEvent.Parent = ReplicatedStorage


local function findMonsterByOwnerId(ownerId)
	for _, monster in pairs(workspace:GetChildren()) do
		if monster:IsA("Model") and monster:GetAttribute("OwnerId") == ownerId then
			return monster
		else
			return "No monster found"
		end
	end
	return nil
end

-- Handle data requests
local function DeepCopy(tbl)
	local copy = {}
	for k, v in (tbl) do
		if typeof(v) == "table" then
			copy[k] = DeepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

GetMonsterDataEvent.OnServerEvent:Connect(function(player)
	local data = _G.DATA:Get(player)

	local monster = DeepCopy(data.Monster)
	local model = findMonsterByOwnerId(data.Monster.OwnerId)
	
	GetMonsterDataEvent:FireClient(player, monster, model)
end)

