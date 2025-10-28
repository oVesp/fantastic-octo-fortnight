local PL = game:GetService('Players');

local DataStorage = require(script:WaitForChild('DataStorage'));

return {
	new = function(module)
		local module = module or {}

		module.DotENV = require(script:WaitForChild('.ENV'));
		module.Template = require(script:WaitForChild('Template'));

		do -- setup
			local StateChanged = function(state, ds: DataStorage.DataStore, player : Player)
				while ds.State == false and player:IsDescendantOf(game) do
					if ds:Open(module.Template) ~= DataStorage.Response.Success then task.wait(6) end
				end
			end

			local setup = function(plr : Player)
				local dataStore = DataStorage.new(module.DotENV.MainDataKey, plr.UserId);

				if not plr or not plr:IsDescendantOf(game) then print(plr.Name.." not found while processing DATA") return end

				print(plr.Name.. ' DATA LOADING');

				local conns = {};

				conns.state_changed = dataStore.StateChanged:Connect(StateChanged);

				StateChanged(dataStore.State, dataStore, plr);

				if not plr or not plr:IsDescendantOf(game) then print(plr.Name.." not found while processing DATA") return end

				if module.OnJoining then
					for i, fun in ipairs(module.OnJoining) do
						xpcall(fun, warn, plr, dataStore)
					end
				end

				plr:SetAttribute('DataLoaded', true);

				print(plr.Name.. ' DATA LOADED');

				conns.disconnect = PL.ChildRemoved:Connect(function(this_plr: Player) if this_plr ~= plr then return end
					for k, v in pairs(conns) do v:Disconnect() end; table.clear(conns);

					if module.OnLeaving then
						for i, fun in ipairs(module.OnLeaving) do
							xpcall(fun, warn, plr, dataStore)
						end
					end

					if dataStore then dataStore:Destroy(); dataStore = nil end
				end)
			end

			for _, plr in ipairs(PL:GetPlayers()) do
				task.spawn(setup, plr)
			end

			PL.PlayerAdded:Connect(setup)
		end

		local target_normalizer = {
			Instance = function(target: Instance & Player)
				assert(target:IsA('Player'), 'Target type not supported');

				if not target:GetAttribute('DataLoaded') then target:GetAttributeChangedSignal('DataLoaded'):Wait() end

				return target.UserId
			end,

			number = function(target: number)
				return target
			end,
		}

		function module:Get(target: number | Player)
			assert(target, 'No target provided')

			target = target_normalizer[typeof(target)](target)

			local ds = DataStorage.find(module.DotENV.MainDataKey, target)

			if not ds then task.wait(1) return module:Get(target) end

			return ds.Value
		end

		function module:ForcedUpdate(target: number, success_callback: (prev) -> (), queue_content: {key: string, info: any})
			local ds = DataStorage.find(module.DotENV.MainDataKey, target) or DataStorage.hidden(module.DotENV.MainDataKey, target)

			local res = ds:Open()

			if res == 'Success' then
				xpcall(function()
					success_callback(ds.Value)
				end, function()
					if ds:Queue(queue_content) ~= 'Success' then error('Failed to force data saving') end
				end)
			elseif res == 'Locked' then
				if ds:Queue(queue_content) ~= 'Success' then error('Failed to force data saving') end
			else
				error('Failed to force data saving')
			end

			if ds.Hidden == true then ds:Destroy() end

			return true
		end
		
		return module
	end,
}
