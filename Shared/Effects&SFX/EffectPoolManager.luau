local DEBUG = false

local EffectPool = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage:WaitForChild("Assets")

local CachedAssets = {}
local Pools = {}
local EffectAliases = {}

local WatchedFolders = {
	EmitterEffect = true,
	AuraEffects = true,
	SFX = true,
	Trail = true,
	Misc = true,
	Lights = true,
}

local function getFullPath(obj)
	local path = {}
	while obj and obj ~= Assets do
		table.insert(path, 1, obj.Name)
		obj = obj.Parent
	end
	return table.concat(path, ".")
end

local function isValid(obj)
	return obj:IsA("BasePart") or obj:IsA("Folder") or obj:IsA("Sound")
end

local function registerAlias(key, name, fullPath)
	EffectAliases[key] = EffectAliases[key] or {}
	if not EffectAliases[key][name] then
		EffectAliases[key][name] = fullPath
		if DEBUG then
			print("[EffectPool] Alias registered:", key, name, "->", fullPath)
		end
	elseif EffectAliases[key][name] ~= fullPath and DEBUG then
		warn("[EffectPool] Duplicate alias name:", name, "under key:", key)
	end
end

local function handleEmitterFolder(folder)
	local children = folder:GetDescendants()
	local hasBasePart = false
	local validParts = {}

	for _, obj in ipairs(children) do
		if obj:IsA("BasePart") then
			hasBasePart = true
			table.insert(validParts, obj)
		end
	end

	if not hasBasePart then
		local path = getFullPath(folder)
		CachedAssets[path] = folder
		registerAlias("EmitterEffects", folder.Name, path)
	else
		for _, part in ipairs(validParts) do
			local path = getFullPath(part)
			CachedAssets[path] = part
			registerAlias("EmitterEffects", part.Name, path)
		end
	end
end

local function cacheAsset(obj)
	local fullPath = getFullPath(obj)

	local parentFolder = fullPath:split(".")[1]
	if not WatchedFolders[parentFolder] then return end

	if parentFolder == "EmitterEffects" and obj:IsA("Folder") then
		handleEmitterFolder(obj)
		return
	end

	if not isValid(obj) then return end

	CachedAssets[fullPath] = obj
	registerAlias(parentFolder, obj.Name, fullPath)
end

for _, obj in ipairs(Assets:GetDescendants()) do
	cacheAsset(obj)
end

local function monitorFolder(folder)
	folder.ChildAdded:Connect(function(child)
		cacheAsset(child)
	end)
	for _, sub in ipairs(folder:GetChildren()) do
		if sub:IsA("Folder") then
			monitorFolder(sub)
		end
	end
end

monitorFolder(Assets)

local function getBase(path)
	return CachedAssets[path]
end

function EffectPool:GetInstance(name, key)
	local path = EffectAliases[key] and EffectAliases[key][name]
	if not path then
		if DEBUG then warn("[EffectPool] No valid path for:", name, "under key:", key) end
		return nil
	end

	Pools[key] = Pools[key] or {}
	Pools[key][path] = Pools[key][path] or {}
	local pool = Pools[key][path]

	for i = #pool, 1, -1 do
		if typeof(pool[i]) ~= "Instance" or (pool[i].Parent == nil and not pool[i]:IsDescendantOf(game)) then
			table.remove(pool, i)
		end
	end

	if #pool > 0 then
		local instance = table.remove(pool)
		instance.Parent = nil
		if DEBUG then print("[EffectPool] Reused from pool:", path) end
		return instance
	else
		local base = getBase(path)
		if base and base:IsDescendantOf(game) then
			local clone = base:Clone()
			if clone:IsA("BasePart") then clone.Massless = true end
			
			clone:SetAttribute("__EffectPoolName", name)
			clone:SetAttribute("__EffectPoolKey", key)
			if DEBUG then print("[EffectPool] Cloned new instance of:", path) end
			return clone
		else
			if DEBUG then warn("[EffectPool] Base not found or invalid for path:", path) end
		end
	end

	return nil
end

function EffectPool:ReturnInstance(name, instance, key)
	if not instance or typeof(instance) ~= "Instance" then return end

	name = name or instance:GetAttribute("__EffectPoolName")
	key = key or instance:GetAttribute("__EffectPoolKey")

	if not name or not key then
		if DEBUG then warn("[EffectPool] Missing name or key for return.") end
		return
	end

	local path = EffectAliases[key] and EffectAliases[key][name]
	if not path then
		if DEBUG then warn("[EffectPool] Could not resolve path for return of:", name, "under key:", key) end
		return
	end

	instance.Parent = nil
	Pools[key] = Pools[key] or {}
	Pools[key][path] = Pools[key][path] or {}
	table.insert(Pools[key][path], instance)

	if DEBUG then print("[EffectPool] Returned instance to pool:", path) end
end

function EffectPool:Dump()
	print("=== CachedAssets ===")
	for k in pairs(CachedAssets) do
		print("•", k)
	end

	print("=== EffectAliases ===")
	for key, group in pairs(EffectAliases) do
		print("==", key, "==")
		for k, v in pairs(group) do
			print("•", k, "→", v)
		end
	end

	print("=== Pools ===")
	for key, group in pairs(Pools) do
		print("==", key, "==")
		for k, v in pairs(group) do
			print("•", k, "#", #v)
		end
	end
end

return EffectPool
