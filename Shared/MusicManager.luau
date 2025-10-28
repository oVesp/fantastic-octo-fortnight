-- ReplicatedStorage/Modules/MusicManager.luau
-- Client-side Module: manages playlists by "mode" and cycles tracks using Effects.PlaySound
-- Designed to be required from a LocalScript (one instance per player).

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MusicManager = {}
MusicManager.__index = MusicManager

-- Example modes: "Default", "InCombat", "Training"
-- Playlist items can be:
--  - a string: interpreted as the Effects.PlaySound Name (e.g. "BattleLoop1")
--  - a table: { name = "BattleLoop1", volume = 0.8, loop = false, params = {...} }
-- Effects.PlaySound is called as: Effects.PlaySound(name, params)
local Effects = nil
pcall(function()
	Effects = require(RS.Modules["Effects&SFX"])
end)

-- Helper to call Effects.PlaySound safely
local function safePlaySound(name, params)
	if not Effects or typeof(Effects.PlaySound) ~= "function" then
		warn("[MusicManager] Effects.PlaySound not available, cannot play:", tostring(name))
		return nil
	end
	local ok, res = pcall(function()
		return Effects.PlaySound(name, params or {})
	end)
	if not ok then
		warn("[MusicManager] Effects.PlaySound error:", tostring(res))
		return nil
	end
	return res
end

function MusicManager.new(opts)
	local self = setmetatable({}, MusicManager)
	self.playlists = opts and opts.playlists or {} -- { Default = { ... }, InCombat = {...}, Training = {...} }
	self.mode = opts and opts.mode or "Default"
	self.currentIndex = 0
	self.currentSound = nil
	self.isPlaying = false
	self._stopRequested = false
	self.crossfade = opts and opts.crossfade or 0.15 -- seconds, if supported by Effects
	return self
end

-- Replace or add playlist for a mode
function MusicManager:SetPlaylist(mode, list)
	self.playlists[mode] = list or {}
end

function MusicManager:GetPlaylist(mode)
	return self.playlists[mode] or {}
end

-- Force switch mode (stops current track and starts mode playlist)
function MusicManager:SetMode(mode)
	if not mode then return end
	if self.mode == mode then return end
	self.mode = mode
	self.currentIndex = 0
	self:Stop(true)
	self:Start()
end

-- Stop playback. immediate true -> stop and don't wait for fade/ended.
function MusicManager:Stop(immediate)
	self._stopRequested = true
	self.isPlaying = false
	if self.currentSound then
		pcall(function()
			-- If Effects.PlaySound returned a Sound instance, stop it gracefully if possible
			if typeof(self.currentSound) == "Instance" and self.currentSound:IsA("Sound") then
				if immediate then
					self.currentSound:Stop()
				else
					-- Try fade out via Effects if available (Effects may expose FadeOut through params)
					if Effects and typeof(Effects.FadeSound) == "function" then
						pcall(function() Effects.FadeSound(self.currentSound, self.crossfade) end)
					else
						self.currentSound:Stop()
					end
				end
			end
		end)
	end
	self.currentSound = nil
end

-- Internal: advance index and play next track for current mode
function MusicManager:PlayNext()
	-- guard
	if self._stopRequested then return end
	local list = self:GetPlaylist(self.mode)
	if not list or #list == 0 then
		-- nothing to play; stop
		self.isPlaying = false
		return
	end

	-- pick next index (cycle)
	self.currentIndex = (self.currentIndex % #list) + 1
	local entry = list[self.currentIndex]

	-- normalize entry
	local name, params = nil, {}
	if type(entry) == "string" then
		name = entry
	elseif type(entry) == "table" then
		name = entry.name or entry[1]
		params = entry.params or {}
		if entry.volume then params.Volume = entry.volume end
		if entry.loop ~= nil then params.Loop = entry.loop end
	else
		-- invalid entry: skip to next
		warn("[MusicManager] invalid playlist entry for mode", self.mode, "index", self.currentIndex)
		-- schedule next short delay
		task.delay(0.5, function()
			if not self._stopRequested then self:PlayNext() end
		end)
		return
	end

	-- Attach default params and non-loop behavior: we handle cycling so Loop=false unless user explicitly set
	if params.Loop == nil then params.Loop = false end
	-- Prefer placing sound on Camera for 3D safety
	local camera = workspace.CurrentCamera
	if camera then params.Where = camera end

	-- Play using Effects
	local soundObj = safePlaySound(name, params)
	self.currentSound = soundObj
	self.isPlaying = true

	-- Attempt to detect when the sound ends.
	-- If Effects.PlaySound returns a Sound instance, connect Ended event.
	-- Otherwise, if it returned a table with Duration, use that. Fallback to a guess of 120s.
	if soundObj and typeof(soundObj) == "Instance" and soundObj:IsA("Sound") then
		-- If the played Sound is looped (user requested), we won't auto-advance; but the idea is to cycle, so treat Loop=false by default.
		local conn
		conn = soundObj.Ended:Connect(function()
			-- disconnect to avoid double-calls
			if conn then
				pcall(function() conn:Disconnect() end)
				conn = nil
			end
			-- if stop requested, end
			if self._stopRequested then
				self.isPlaying = false
				self.currentSound = nil
				return
			end
			-- play next
			task.wait(0.07) -- tiny gap between tracks
			if not self._stopRequested then
				self:PlayNext()
			end
		end)
	elseif type(soundObj) == "table" and soundObj.Duration then
		task.delay(soundObj.Duration or 10, function()
			if self._stopRequested then return end
			self:PlayNext()
		end)
	else
		-- Unknown return: fallback wait (default track length)
		local fallback = 120
		task.delay(fallback, function()
			if self._stopRequested then return end
			self:PlayNext()
		end)
	end
end

-- Start (or resume) cycling the current mode playlist
function MusicManager:Start()
	self._stopRequested = false
	if self.isPlaying then return end
	-- start from next track
	task.spawn(function()
		-- slight delay to ensure everything is ready on client
		task.wait(0.02)
		if not self._stopRequested then
			self:PlayNext()
		end
	end)
end

-- Utility: immediately play a specific index in current mode
function MusicManager:PlayIndex(index)
	local list = self:GetPlaylist(self.mode)
	if not list or #list == 0 then return end
	index = math.clamp(index or 1, 1, #list)
	self.currentIndex = index - 1 -- PlayNext increments
	self:Stop(true)
	self._stopRequested = false
	self:Start()
end

return MusicManager