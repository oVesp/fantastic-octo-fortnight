-- DebugUIClient.luau
-- Client-side wiring for DebugUI (simple scrolling frame with buttons).
-- Place this LocalScript in StarterPlayerScripts or inside the DebugUI hierarchy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")

-- Wait for the Debug UI Frame (adjust path/names if your UI differs)
local debugUi = playerGui:WaitForChild("DebugUI")
if not debugUi then
	warn("[DebugUIClient] DebugUI not found in PlayerGui (expected a ScreenGui named DebugUI)")
	return
end

-- The original snippet referenced DebugUI.ScrollingFrame; adapt if necessary
local DebugUIFrame = debugUi:WaitForChild("ScrollingFrame", 5)
if not DebugUIFrame then
	warn("[DebugUIClient] ScrollingFrame not found inside DebugUI")
	return
end

-- Remote references (server script will create these if they don't exist)
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local MonsterSummon = remotesFolder:FindFirstChild("MonsterSummon")
local GenerateMonster = remotesFolder:FindFirstChild("GenerateMonster")
local EvolutionRequest = remotesFolder:FindFirstChild("EvolutionRequest")
local SpawnCombat = remotesFolder:FindFirstChild("SpawnCombat") -- optional/debug
-- Queue remotes: prefer FindFirstChild to avoid long WaitForChild stalls in debug, but check existence
local JoinQueue = remotesFolder:FindFirstChild("JoinQueue")
local LeaveQueue = remotesFolder:FindFirstChild("LeaveQueue")
local QueueStatusUpdate = remotesFolder:FindFirstChild("QueueStatusUpdate")
local joinRankedBtn = DebugUIFrame:FindFirstChild("JoinQueue")     -- optional debug button-- optional/debug
local CreateArena = remotesFolder:FindFirstChild("CreateArena") -- arena creation

-- Button wiring (assumes Buttons named exactly; change names as needed)
local createBtn = DebugUIFrame:FindFirstChild("CreateMonster")
local summonBtn = DebugUIFrame:FindFirstChild("SummonMonster")
local evolveBtn = DebugUIFrame:FindFirstChild("EvolveMonster")
local spawnCombatBtn = DebugUIFrame:FindFirstChild("SpawnCombat") -- optional debug button
local joinQueueBtn = DebugUIFrame:FindFirstChild("JoinQueue")     -- optional debug button

-- Arena creation buttons
local arena1v1Btn = DebugUIFrame:FindFirstChild("Arena1v1")
local arena2v2Btn = DebugUIFrame:FindFirstChild("Arena2v2")
local arena4v4Btn = DebugUIFrame:FindFirstChild("Arena4v4")
local arenaFFABtn = DebugUIFrame:FindFirstChild("ArenaFFA")

if createBtn and GenerateMonster then
	createBtn.Activated:Connect(function()
		GenerateMonster:FireServer()
		print("[DebugUIClient] Fired GenerateMonster")
	end)
end

if summonBtn and MonsterSummon then
	summonBtn.Activated:Connect(function()
		MonsterSummon:FireServer()
		print("[DebugUIClient] Fired MonsterSummon")
	end)
end

if evolveBtn and EvolutionRequest then

	-- Optional: listen to queue status updates and print them for debugging
	if QueueStatusUpdate then
		QueueStatusUpdate.OnClientEvent:Connect(function(payload)
			print("[DebugUIClient] QueueStatusUpdate:", payload and typeof(payload) == "table" and payload.status or tostring(payload))
		end)
	end
	evolveBtn.Activated:Connect(function()
		EvolutionRequest:FireServer()
		print("[DebugUIClient] Fired EvolutionRequest")
	end)
end

-- Optional debug buttons for spawning a combat or joining a queue (admin-only server checks apply)
if spawnCombatBtn and SpawnCombat then
	spawnCombatBtn.Activated:Connect(function()
		-- Example payload: server requires actual Instance references; client cannot send Instance to server
		-- Instead, for debug we can send a simple signal and server will use the player's monster + a nearby mob.
		SpawnCombat:FireServer({ instances = nil, options = { mode = "teams", teamSize = 1 } })
		print("[DebugUIClient] Fired SpawnCombat (payload nil instances -> server will decide)")
	end)
end

-- Debug helpers: map debug buttons to the new queue names
if joinQueueBtn and JoinQueue then
	joinQueueBtn.Activated:Connect(function()
		local ok, err = pcall(function()
			JoinQueue:FireServer("Main_Arena_8")
		end)
		if not ok then warn("[DebugUIClient] Failed JoinQueue Main_Arena_8:", err) end
		print("[DebugUIClient] Fired JoinQueue for Main_Arena_8")
	end)
end

if joinRankedBtn and JoinQueue then
	joinRankedBtn.Activated:Connect(function()
		local ok, err = pcall(function()
			JoinQueue:FireServer("Small_Arena_4")
		end)
		if not ok then warn("[DebugUIClient] Failed JoinQueue Small_Arena_4:", err) end
		print("[DebugUIClient] Fired JoinQueue for Small_Arena_4")
	end)
end

-- Optional quick join for duel via Arena1v1 button if present
if arena1v1Btn and JoinQueue then
	arena1v1Btn.Activated:Connect(function()
		local ok, err = pcall(function()
			JoinQueue:FireServer("Duel_1v1")
		end)
		if not ok then warn("[DebugUIClient] Failed JoinQueue Duel_1v1:", err) end
		print("[DebugUIClient] Fired JoinQueue for Duel_1v1")
	end)
end

-- Optional LeaveQueue wiring
local leaveBtn = DebugUIFrame:FindFirstChild("LeaveQueue")
if leaveBtn and LeaveQueue then
	leaveBtn.Activated:Connect(function()
		local ok, err = pcall(function()
			LeaveQueue:FireServer()
		end)
		if not ok then warn("[DebugUIClient] Failed LeaveQueue:", err) end
		print("[DebugUIClient] Fired LeaveQueue")
	end)
end

-- Arena creation button handlers
if arena1v1Btn and CreateArena then
	arena1v1Btn.Activated:Connect(function()
		CreateArena:FireServer({ mode = "1v1", autoStart = true })
		print("[DebugUIClient] Creating 1v1 arena")
	end)
end

if arena2v2Btn and CreateArena then
	arena2v2Btn.Activated:Connect(function()
		CreateArena:FireServer({ mode = "2v2", autoStart = true })
		print("[DebugUIClient] Creating 2v2 arena")
	end)
end

if arena4v4Btn and CreateArena then
	arena4v4Btn.Activated:Connect(function()
		CreateArena:FireServer({ mode = "4v4", autoStart = true })
		print("[DebugUIClient] Creating 4v4 arena")
	end)
end

if arenaFFABtn and CreateArena then
	arenaFFABtn.Activated:Connect(function()
		CreateArena:FireServer({ mode = "FFA", autoStart = true })
		print("[DebugUIClient] Creating FFA arena")
	end)
end

--joinQueueBtn.Activated:Connect(function()
--	JoinQueue:FireServer("casual")
--	print("[DebugUIClient] Joined casual queue")
--end)

--joinRankedBtn.Activated:Connect(function()
--	JoinQueue:FireServer("ranked")
--	print("[DebugUIClient] Joined ranked queue")
--end)