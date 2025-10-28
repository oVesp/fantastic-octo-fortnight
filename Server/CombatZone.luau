-- ServerScriptService>Main>CombatArena (REPLACE with this code)

-- This module defines a conceptual "soft boundary" for combat instead of a hard wall.
local CombatZone = {}

local activeZones = {} -- The radius of the combat area in studs
local DEFAULT_ZONE_RADIUS = 30      -- fixed max travel range (studs)
local DEFAULT_ZONE_HEIGHT = 128      -- cylinder height (adjust as needed)

local RUN_SERVICE = game:GetService("RunService")

local debugParts = {}

-- Folder to house all debug parts
local function _debugFolder()
	local f = workspace:FindFirstChild("CombatZonesDebug")
	if not f then
		f = Instance.new("Folder")
		f.Name = "CombatZonesDebug"
		f.Parent = workspace
	end
	return f
end

-- Keep a local map for quick access
local debugParts = debugParts or {}

local function _sweepOrphanDebug()
	-- Remove any ZoneDebug_* that doesn't correspond to an active zone id
	local df = workspace:FindFirstChild("CombatZonesDebug")
	if not df then return end
	for _, p in ipairs(df:GetChildren()) do
		if p:IsA("BasePart") and p.Name:match("^ZoneDebug_") then
			local id = p.Name:gsub("^ZoneDebug_", "")
			if not activeZones[id] then
				p:Destroy()
				debugParts[id] = nil
			end
		end
	end
end

-- NEW: find nearest BattleSpots/Spot
local function findNearestSpot(pos: Vector3): Vector3?
	local folder = workspace:FindFirstChild("BattleSpots")
	if not folder then return nil end
	local best, bestD = nil, math.huge
	for _, inst in ipairs(folder:GetChildren()) do
		if inst:IsA("BasePart") and inst.Name:lower() == "spot" then
			local d = (inst.Position - pos).Magnitude
			if d < bestD then best, bestD = inst, d end
		end
	end
	return best and best.Position or nil
end
--- Calculates the center point between all combatants.
local function calculateCenter(combatants)
	local totalPosition = Vector3.new(0, 0, 0)
	local count = 0
	for _, c in ipairs(combatants) do
		if c and c.PrimaryPart then
			totalPosition += c.PrimaryPart.Position
			count += 1
		end
	end
	return (count > 0) and (totalPosition / count) or Vector3.new(0, 0, 0)
end

local function createDebugCylinder(zone)
	if not RUN_SERVICE:IsStudio() then return end
	_sweepOrphanDebug()

	local part = debugParts[zone.id]
	if not part then
		part = Instance.new("Part")
		part.Name = "ZoneDebug_" .. tostring(zone.id)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = Enum.Material.ForceField
		part.Transparency = 0.85
		part.Color = Color3.fromRGB(0, 255, 0)
		part.Parent = _debugFolder()
		debugParts[zone.id] = part
	end

	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(zone.height or DEFAULT_ZONE_HEIGHT,
		(zone.radius or DEFAULT_ZONE_RADIUS) * 2,
		(zone.radius or DEFAULT_ZONE_RADIUS) * 2)

	-- Lay the cylinder on its side (your requested orientation)
	part.CFrame = CFrame.new(zone.center) * CFrame.Angles(0, 0, math.rad(90))
end

-- helper: destroy debug part
local function removeDebugCylinder(zoneId)
	local part = debugParts[zoneId]
	if part then
		part:Destroy()
		debugParts[zoneId] = nil
	end
end


--- Creates a new combat zone.
-- @param combatId A unique ID for the combat.
-- @param combatants A table of monster models.
-- @return The zone data table.
-- PATCHED Create function (add debug line at the end)
function CombatZone.Create(combatId, combatants, opts)
	if activeZones[combatId] then return activeZones[combatId] end

	opts = opts or {}
	local center = opts.center or calculateCenter(combatants)
	local zone = {
		id = combatId,
		center = center,
		radius = tonumber(opts.radius) or DEFAULT_ZONE_RADIUS,
		height = tonumber(opts.height) or DEFAULT_ZONE_HEIGHT,
	}

	activeZones[combatId] = zone
	print(("[CombatZone] Created zone %s at %s r=%.1f h=%.1f")
		:format(combatId, tostring(center), zone.radius, zone.height))

	createDebugCylinder(zone)
	_sweepOrphanDebug()
	return zone
	
end

-- PATCHED Remove to also destroy the debug part
function CombatZone.Remove(combatId)
	activeZones[combatId] = nil
	removeDebugCylinder(combatId) -- 🔰 cleanup
end
--- Clamps a position to the inside of a zone's radius.
-- This creates a "leashing" effect instead of a hard wall.
-- @param zone The zone data table.
-- @param position The Vector3 position to check.
-- @return The original position if inside, or the closest point on the edge if outside.
function CombatZone.ClampPositionToZone(zone, position)
	if not zone then return position end
	-- horizontal leash
	local horizontal = Vector3.new(position.X - zone.center.X, 0, position.Z - zone.center.Z)
	if horizontal.Magnitude > zone.radius then
		local dir = horizontal.Unit
		local clampedX = zone.center.X + dir.X * zone.radius * 0.98
		local clampedZ = zone.center.Z + dir.Z * zone.radius * 0.98
		position = Vector3.new(clampedX, position.Y, clampedZ)
	end
	-- vertical leash (cylinder)
	if zone.height then
		local half = zone.height * 0.5
		local y = math.clamp(position.Y, zone.center.Y - half, zone.center.Y + half)
		position = Vector3.new(position.X, y, position.Z)
	end
	return position
end

function CombatZone.FindNearestSpot(pos) return findNearestSpot(pos) end

--- Gets the data for an active zone.
function CombatZone.Get(combatId)
	return activeZones[combatId]
end

return CombatZone