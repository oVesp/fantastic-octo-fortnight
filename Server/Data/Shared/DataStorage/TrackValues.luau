
local module = {}

local function custom_print(t, l, seen)
	l = l or 0
	seen = seen or {}

	if seen[t] then
		return '"*** cycle table reference detected ***"'
	end
	seen[t] = true

	local indent = string.rep("  ", l)
	local inner_indent = string.rep("  ", l + 1)

	local entries = {}

	local function format_value(v)
		if type(v) == "string" then
			return '"' .. v .. '"'
		elseif type(v) == "table" then
			return custom_print(v, l + 1, seen)
		end
		return tostring(v)
	end

	for k, v in pairs(t) do
		local key_str = type(k) == "string" and '["'..k..'"]' or "["..tostring(k).."]"
		local value_str = format_value(v)
		table.insert(entries, inner_indent .. key_str .. " = " .. value_str)
	end

	if #entries == 0 then
		return "{}"
	end
	return "{\n" .. table.concat(entries, "\n") .. "\n" .. indent .. "}"
end

local type_to_class = {
	boolean = 'BoolValue',
	string = 'StringValue',
	number = 'NumberValue',
}

function set_value(target: Instance, key: string, value: any)
	if not value then	
		local prev_replicated = target:FindFirstChild(key); if prev_replicated then
			prev_replicated:Destroy()
		end
		
		return
	end

	local instance_class = type_to_class[typeof(value)]

	if not instance_class then return end

	local prev_replicated = target:FindFirstChild(key);

	if prev_replicated and prev_replicated.ClassName ~= instance_class then prev_replicated:Destroy() end

	local new_value = prev_replicated or Instance.new(instance_class)
	new_value.Name = key
	new_value.Value = value
	new_value.Parent = target
end

function replicate(t: {any}, target: Instance, folder_name: string)
	local folder = Instance.new('Folder');
	folder.Name = folder_name;
	folder.Parent = target;

	for k, v in pairs(t) do
		if typeof(v) ~= 'table' then
			set_value(folder, k, v)
		end
	end

	return folder
end

function convert_to_proxy(source: {any}, target: Instance?, folder_name: string)
	local folder = replicate(source, target, folder_name)

	local proxy = setmetatable({}, {
		__stg = source,

		__index = function(self, k)
			return source[k]
		end,
		__newindex = function(self, k, v)
			if typeof(v) ~= 'table' then
				set_value(folder, k, v)

				source[k] = v
			else
				if folder:FindFirstChild(k) then folder[k]:Destroy() end

				source[k] = convert_to_proxy(v, folder, k)
			end
		end,
		__iter = function(self)
			return next, source
		end,
		__tostring = function(self)
			return custom_print(source)
		end,
	})

	for k, v in pairs(source) do if typeof(v) ~= 'table' then continue end
		source[k] = convert_to_proxy(v, folder, k)
	end

	return proxy
end

module.track = function(storage: {any}, replication_target: Instance)
	return convert_to_proxy(storage, replication_target, 'Data')
end

module.normalize = function(tracked: {any})
	if not getmetatable(tracked) then return end

	local t = table.clone(getmetatable(tracked).__stg)

	for k, v in pairs(t) do
		rawset(t, k, if typeof(v) ~= 'table' then v else module.normalize(v))
	end

	return t
end

return module
	