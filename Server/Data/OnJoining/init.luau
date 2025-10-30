local RP = game:GetService('ReplicatedStorage');

local queue_functions = require(script:WaitForChild('QueueFunctions'));

local CURRENT_UPDATE = 1

local module = {

	--function(plr, data) -- initial values
	--	if not data.Value.NewPlayer then return end

	--	data.Value.NewPlayer = false;
	--end,

	function(plr, data)

		-- Only create a new monster if there's no monster id present or the player is flagged as NewPlayer.
                if data.Value.Monster and data.Value.Monster.id then return end
                local monster = _G.MONSTERGENERATOR.RollMonster(plr.UserId)
                -- Merge generated monster data into the player's Monster table without overwriting full tables
                data.Value.Monster = data.Value.Monster or {}
                data.Value.Monster.Stats = data.Value.Monster.Stats or {}
                data.Value.Monster.Moves = data.Value.Monster.Moves or {}
                for k, v in pairs(monster) do
                        if k == "Stats" then
                                for sk, sv in pairs(v) do
                                        data.Value.Monster.Stats[sk] = sv
                                end
                        elseif k == "Moves" then
                                -- Ensure moves table exists and copy entries
                                for i, mv in ipairs(v) do
                                        data.Value.Monster.Moves[i] = mv
                                end
                        else
                                data.Value.Monster[k] = v
                        end
                end
		-- mark as initialized
		data.Value.NewPlayer = false

	end,

	function(plr, data) -- update versioning: game version is now up-to-date
		local last_played = data.Value.LastUpdatePlayed;

		if last_played and tonumber(last_played) >= CURRENT_UPDATE then return end



		data.Value.LastUpdatePlayed = tostring(CURRENT_UPDATE)
	end,

	function(plr, data) -- data versioning: data is now up-to-date
		while not _G.DATA do task.wait(1) end

		data.Value.Version = _G.DATA.Template.Version
	end,

	function(plr, data) -- process_queue
		data.ProcessQueue:Connect(function(id, values_array) data:Remove(id)
			for _, pack in ipairs(values_array) do
				if not queue_functions[pack.key] then continue end

				for k, v in pairs(pack) do
					print(k, v)
				end

				queue_functions[pack.key](plr, pack.info)
			end
		end);
	end,
}

return module
