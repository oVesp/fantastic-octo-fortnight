-- ModuleScript: ReplicatedStorage>Modules>MovesInitializer
local MovesInitializer = {}

function MovesInitializer.Init()
	-- Garantir que todos os módulos sejam carregados
	local Moves = require(script.Parent.Moves)
	local MoveVFX = require(script.Parent.MoveVFX)

	-- Registrar globalmente se necessário
	_G.MovesSystem = Moves
	_G.MoveVFXSystem = MoveVFX

	print("[MovesSystem] Sistema de movimentos modularizado carregado com sucesso")
end

return MovesInitializer