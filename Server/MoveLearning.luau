-- ServerScriptService.Main.MoveLearning.lua
local MoveLearning = {}
MoveLearning.__index = MoveLearning

local RS = game:GetService("ReplicatedStorage")
local MoveUnlocks = require(RS.Modules.MoveUnlocks)

function MoveLearning.Init()
	-- Register with global systems
	_G.MOVE_LEARNING = MoveLearning
end

-- Basic move learning trigger
function MoveLearning.TryLearnMove(player, trigger, opts)
	local data = _G.DATA:Get(player).Monster
	if not data then return false end

	local unlockedMoves = MoveUnlocks.ResolveUnlocks(data, trigger, opts or {})

	if #unlockedMoves > 0 then
		-- Notify player about new moves
		print(unlockedMoves)
		return true, unlockedMoves
	end

	return false, "No moves unlocked"
end

-- Combat-triggered move learning
function MoveLearning.OnCombatEnd(player, combatResult)
	local data = _G.DATA:Get(player)
	if not data then return end

	-- Increment wins if victorious
	if combatResult.won then
		data.Wins = (data.Wins or 0) + 1
	end

	-- Try to learn moves from combat
	MoveLearning.TryLearnMove(player, "combat", {
		damageDealt = combatResult.damageDealt or 0,
		survived = combatResult.survived or false
	})
end

-- Training-triggered move learning
function MoveLearning.OnTrainingComplete(player, trainingType, success)
	if not success then return end

	local data = _G.DATA:Get(player)
	if not data then return end

	-- Update move progress for this training type
	data.MoveProgress = data.MoveProgress or {}
	data.MoveProgress[trainingType] = (data.MoveProgress[trainingType] or 0) + 1

	-- Try to learn moves from training
	MoveLearning.TryLearnMove(player, "training", {
		trainingType = trainingType,
		progress = data.MoveProgress[trainingType]
	})
end

-- Evolution-triggered move learning
function MoveLearning.OnEvolution(player, oldRace, newRace, previousMoves)
	local data = _G.DATA:Get(player)
	if not data then return end

	-- Update race and stage
	data.Race = newRace
	data.Stage = require(RS.Modules.Races):GetStage(newRace)

	-- Learn moves from evolution
	MoveLearning.TryLearnMove(player, "evolution", {
		from = oldRace,
		to = newRace,
		previousMoves = previousMoves
	})
end

-- Manual move management
function MoveLearning.ReplaceMove(player, moveToRemove, moveToAdd)
	local data = _G.DATA:Get(player)
	if not data or not data.Moves then return false end

	-- Find and remove the specified move
	for i, moveData in ipairs(data.Moves) do
		local moveId = moveData.move and moveData.move.id or moveData.id
		if moveId == moveToRemove then
			table.remove(data.Moves, i)

			-- Add new move
			local Moves = require(RS.Modules.Moves)
			local newMove = Moves:GetMove(data.Race, moveToAdd) or Moves:GetMove(nil, moveToAdd)
			if newMove then
				table.insert(data.Moves, { move = newMove, rarity = newMove.rarity })

				-- Trim to max 4 moves if needed
				if #data.Moves > 4 then
					MoveLearning.TrimMoves(data)
				end

				return true
			end
			break
		end
	end

	return false
end

-- Ensure only 4 moves are kept (priority system)
function MoveLearning.TrimMoves(data)
	if not data.Moves or #data.Moves <= 4 then return end

	local RARITY_ORDER = { Amateur = 1, Advanced = 2, Specialist = 3, Ascended = 4, Primordial = 5 }

	-- Sort by priority: BasicAttack always kept, then by rarity
	table.sort(data.Moves, function(a, b)
		local aId = a.move and a.move.id or a.id
		local bId = b.move and b.move.id or b.id

		-- BasicAttack has highest priority
		if aId == "BasicAttack" then return true end
		if bId == "BasicAttack" then return false end

		-- Then sort by rarity
		local aRarity = a.rarity or (a.move and a.move.rarity) or "Amateur"
		local bRarity = b.rarity or (b.move and b.move.rarity) or "Amateur"

		return (RARITY_ORDER[aRarity] or 1) > (RARITY_ORDER[bRarity] or 1)
	end)

	-- Remove excess moves (keep only first 4)
	while #data.Moves > 4 do
		table.remove(data.Moves)
	end
end

-- Get current moves in standardized format
function MoveLearning.GetCurrentMoves(data)
	local moves = {}
	for _, moveData in ipairs(data.Moves or {}) do
		local moveId = moveData.move and moveData.move.id or moveData.id
		if moveId then
			table.insert(moves, moveId)
		end
	end
	return moves
end

return MoveLearning