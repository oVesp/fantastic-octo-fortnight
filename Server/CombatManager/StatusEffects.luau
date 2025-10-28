-- ServerScriptService/Main/Game/StatusEffects.luau
-- Sistema leve de efeitos com stacking controlado e modificadores de stats.
-- Server-autoritative; client só visual (via _G.EFFECTS, se quiser).

local RunService = game:GetService("RunService")

local SE = {}

-- Definições canônicas: como cada efeito impacta stats/estados
-- type = "Buff" | "Debuff" | "CC" | "Shield" | "State"
SE.DEFS = {
	Haste        = { type="Buff",   maxStacks=1,  pri=20,  mods={ Speed = {mult=1.20} } },
	Berserk      = { type="Buff",   maxStacks=1,  pri=10,  mods={ Strength = {mult=1.25}, Defense = {mult=0.9} } },
	GuardUp      = { type="Buff",   maxStacks=1,  pri=18,  mods={ Defense = {mult=1.25} } },
	Focus        = { type="Buff",   maxStacks=3,  pri=12,  mods={ Skill = {add=5} } },
	ArcaneMind   = { type="Buff",   maxStacks=1,  pri=12,  mods={ Intelligence = {mult=1.20} } },

	Slow         = { type="Debuff", maxStacks=2,  pri=15,  mods={ Speed = {mult=0.8} } },
	Weaken       = { type="Debuff", maxStacks=2,  pri=14,  mods={ Strength = {mult=0.85} } },
	Silence      = { type="Debuff", maxStacks=1,  pri=30,  flags={ NoCast=true } },
	Burn         = { type="Debuff", maxStacks=3,  pri=10,  dot={ dps=4 }, mods={} },
	Poison       = { type="Debuff", maxStacks=3,  pri=10,  dot={ dps=3 }, mods={} },
	Stun         = { type="CC",     maxStacks=1,  pri=100, flags={ Stunned=true, NoMove=true, NoCast=true } },
	Root         = { type="CC",     maxStacks=1,  pri=80,  flags={ NoMove=true } },

	Shield       = { type="Shield", maxStacks=1,  pri=50,  shield=true }, -- valor definido na aplicação
	Invulnerability = { type="State", maxStacks=1, pri=200, flags={ Invuln=true } },
}

-- Armazena estados por Instance
-- Map<Instance, { active = { [name] = { stacks, expiresAt, power, source, lastTickHpDot } }, sumMods = {} , flags = {} , shieldHp = number }>
local STORE: {[Instance]: any} = {}

local function now() return os.clock() end

local function ensure(obj)
	local rec = STORE[obj]
	if rec then return rec end
	rec = { active = {}, sumMods = {}, flags = {}, shieldHp = 0 }
	STORE[obj] = rec
	return rec
end

-- Aplica/tenta empilhar um efeito
-- info = { name, dur, stacks?, power? }
function SE.Apply(target: Instance, info, source: Instance?)
	if not target or not info or not info.name then return false, "bad_args" end
	local def = SE.DEFS[info.name]
	if not def then return false, "unknown_effect" end

	local R = ensure(target)
	local slot = R.active[info.name]
	local maxStacks = def.maxStacks or 1
	local stacks = math.max(1, math.min(maxStacks, (info.stacks or 1)))

	if not slot then
		slot = { stacks = 0, expiresAt = 0, power = 0, source = source }
		R.active[info.name] = slot
	end

	-- renovar duração e ajustar stacks
	slot.expiresAt = now() + math.max(0.1, info.dur or 0)
	slot.stacks = math.max(1, math.min(maxStacks, stacks))
	slot.power = info.power or slot.power
	slot.source = source or slot.source

	-- Se for Shield, define HP da barreira proporcional ao power
	if def.shield then
		-- Se power não vier, define um default
		local val = info.power or 20
		R.shieldHp = math.max(R.shieldHp, val)
	end

	return true
end

function SE.Remove(target: Instance, name: string)
	local R = STORE[target]
	if not R or not R.active[name] then return end
	R.active[name] = nil
end

function SE.Has(target: Instance, name: string)
	local R = STORE[target]
	return R and R.active[name] ~= nil
end

-- Consulta agregada de modificadores (para multiplicar stats na leitura)
-- Retorna tabela com { add = {Stat->sum}, mult = {Stat->product}}
function SE.GetStatModifiers(target: Instance)
	local R = STORE[target]
	if not R then return { add = {}, mult = {} }, {} end
	local add, mult, flags = {}, {}, {}
	for name, slot in pairs(R.active) do
		local def = SE.DEFS[name]
		if def and def.flags then
			for k, v in pairs(def.flags) do
				flags[k] = v or flags[k]
			end
		end
		if def and def.mods then
			for stat, mod in pairs(def.mods) do
				if mod.add then
					add[stat] = (add[stat] or 0) + (mod.add * (slot.stacks or 1))
				end
				if mod.mult then
					mult[stat] = (mult[stat] or 1.0) * (mod.mult ^ (slot.stacks or 1))
				end
			end
		end
	end
	return { add = add, mult = mult }, flags
end

-- Aplica dano antes de HP: consome Shield se existir
function SE.AbsorbWithShield(target: Instance, dmg: number): (number, number)
	local R = STORE[target]
	if not R or (R.shieldHp or 0) <= 0 then return dmg, 0 end
	local shield = R.shieldHp
	local absorb = math.min(dmg, shield)
	R.shieldHp -= absorb
	if R.shieldHp <= 0 then R.shieldHp = 0 end
	return (dmg - absorb), absorb
end

-- Tick: expira efeitos e aplica DoTs
-- callbackDamage(target, amount, source, tag) é usado para aplicar DoT (server authority)
function SE.Tick(dt: number, callbackDamage)
	-- Limpeza & DoTs
	for target, R in pairs(STORE) do
		for name, slot in pairs(R.active) do
			if slot.expiresAt <= now() then
				R.active[name] = nil
			else
				local def = SE.DEFS[name]
				if def and def.dot and callbackDamage then
					local dps = def.dot.dps * (slot.stacks or 1)
					if dps > 0 then
						callbackDamage(target, dps * dt, slot.source, name)
					end
				end
			end
		end
	end
end

-- Loop de tick básico (opcional; ou chame SE.Tick do teu CombatManager)
local ACC = 0
RunService.Heartbeat:Connect(function(dt)
	ACC += dt
	if ACC >= 0.1 then -- 10 Hz
		local cdt = ACC; ACC = 0
		SE.Tick(cdt, nil) -- sem callback padrão; CombatManager pode setar o dele
	end
end)

return SE
