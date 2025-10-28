-- Updated Data Structure (Template)
return {
	id = nil,

	Level = 1,  	

	NewPlayer = true,

	--to be decided: Multiple Monsters?
	Monster = {
		id = nil,
		Name = nil,
		Race = nil,
		Stage = nil,
		Level = nil,
		Bond = nil,
		Wins = nil,
		Age = nil,
		SessionTime = nil,
		CareMistakes = nil,
		Personality = nil,
		Stats = {},      -- keep as empty table to indicate structure
		Moves = {},
		History = {},
		Appearance = {},
		BaseRaceFamily = nil,
		isNPC = false,
		GeneratedWithLevel = nil,
		Element = nil,
		OwnerId = nil,
	},
	Version = 1.0, 
}