return {
	-- teamSize: tamanho do time. Para FFA use teamSize=1 e minPlayers > teamSize.
	MODES = {
		["1v1"] = { teamSize = 1, teams = 2, minPlayers = 2, maxPlayers = 2 },
		["2v2"] = { teamSize = 2, teams = 2, minPlayers = 4, maxPlayers = 4 },
		["4v4"] = { teamSize = 4, teams = 2, minPlayers = 8, maxPlayers = 8 },
		["FFA"] = { teamSize = 1, teams = 8, minPlayers = 3, maxPlayers = 8 },
	},
	Timeouts = {
		ReserveSeconds = 15,   -- tempo para carregar players/arena antes de cancelar a reserva
		MatchBuildSeconds = 20 -- se arena não iniciar nesse tempo, aborta e refile
	},
	CrossServer = {
		Enabled = false,           -- ligue para matchmaking global
		QueueKeysPrefix = "mmq:",  -- prefixo das filas no MemoryStore
		MapKey = "mmq:reservations"
	}
}