-- Client Script
local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local EvSpawnMonster = Remotes:WaitForChild("SpawnMonster")

-- Trigger spawn when a button is pressed or condition is met
local function spawnMonster(nurseModel)
	EvSpawnMonster:FireServer(nurseModel)
end