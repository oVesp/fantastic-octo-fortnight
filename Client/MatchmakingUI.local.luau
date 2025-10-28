---- StarterPlayerScripts/MusicController.local.luau
---- LocalScript that wires MusicManager to the player's MONSTER states (InCombat, Training).
---- This version listens directly to the monster model's attributes for greater accuracy and robustness.

--local Players = game:GetService("Players")
--local ReplicatedStorage = game:GetService("ReplicatedStorage")
--local Workspace = game:GetService("Workspace")
--local player = Players.LocalPlayer

---- Load the MusicManager module
--local ok, MusicManager = pcall(function()
--	return require(ReplicatedStorage.Modules:WaitForChild("MusicManager"))
--end)
--if not ok or not MusicManager then
--	warn("[MusicController] Could not load MusicManager module. Music will be disabled.")
--	return
--end

---- Playlists using the asset names you provided.
---- The system will cycle through these tracks for each state.
--local playlists = {
--	Default = {
--		"AmbientLoop_1",
--		"AmbientLoop_2",
--		"AmbientPad_1",
--		"AmbientPad_2",
--	},
--	InCombat = {
--		"BattleLoop_1",
--		"BattleLoop_2",
--		"BattleDrum_1",
--		"BattleSpike_1",
--	},
--	Training = {
--		"TrainingLoop_1",
--		"TrainingLoop_2",
--		"TrainingFocus_1",
--		"TrainingMotif_1",
--	},
--}

---- Create a client-side instance of the music manager
--local manager = MusicManager.new({
--	playlists = playlists,
--	mode = "Default",
--	crossfade = 0.2 -- A short crossfade for smooth transitions
--})

---- --- Monster Tracking and State Handling ---

--local currentMonster = nil
--local attributeConnections = {}

---- Function to update music based on the monster's current state attributes.
---- Priority: InCombat > Training > Default
--local function updateMusicMode()
--	if not currentMonster or not currentMonster.Parent then
--		manager:SetMode("Default")
--		return
--	end

--	if currentMonster:GetAttribute("InCombat") then
--		manager:SetMode("InCombat")
--	elseif currentMonster:GetAttribute("InTraining") then
--		manager:SetMode("Training")
--	else
--		manager:SetMode("Default")
--	end
--end

---- Cleans up old connections to prevent memory leaks
--local function cleanupConnections()
--	for _, conn in ipairs(attributeConnections) do
--		pcall(function() conn:Disconnect() end)
--	end
--	table.clear(attributeConnections)
--end

---- Main function to find and begin tracking the player's monster
--local function findAndTrackMonster()
--	cleanupConnections()
--	currentMonster = nil

--	-- Search workspace for a model owned by the local player
--	for _, child in ipairs(Workspace:GetChildren()) do
--		if child:IsA("Model") and child:GetAttribute("OwnerId") == player.UserId then
--			currentMonster = child
--			break
--		end
--	end

--	if currentMonster then
--		print("[MusicController] Found monster:", currentMonster.Name)

--		-- Listen for attribute changes on the new monster
--		table.insert(attributeConnections, currentMonster.AttributeChanged:Connect(function(attribute)
--			if attribute == "InCombat" or attribute == "InTraining" then
--				updateMusicMode()
--			end
--		end))

--		-- Listen for the monster being destroyed (respawn, evolution, etc.)
--		table.insert(attributeConnections, currentMonster.Destroying:Connect(function()
--			print("[MusicController] Monster is being destroyed. Switching to default music and searching for a new one.")
--			currentMonster = nil
--			cleanupConnections()
--			manager:SetMode("Default")
--			-- Wait a moment before searching again to allow the new monster to spawn.
--			task.delay(1, findAndTrackMonster)
--		end))

--		-- Set the initial music mode based on the monster's current state
--		updateMusicMode()
--	else
--		-- No monster found, set to default and listen for one to be added
--		manager:SetMode("Default")
--		local conn
--		conn = Workspace.ChildAdded:Connect(function(child)
--			if child:IsA("Model") and child:GetAttribute("OwnerId") == player.UserId then
--				-- Found it! Stop listening for new children and start tracking.
--				conn:Disconnect()
--				findAndTrackMonster()
--			end
--		end)
--		table.insert(attributeConnections, conn)
--	end
--end


---- --- Initialization ---

---- Start the default music playlist initially
--manager:Start()

---- Begin the process of finding and tracking the player's monster
--findAndTrackMonster()

---- Expose the manager for debugging in the client console (optional)
--_G.ClientMusicManager = manager