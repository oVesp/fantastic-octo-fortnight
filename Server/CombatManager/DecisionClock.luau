-- ServerScriptService/Main/Game/Combat/DecisionClock.lua
local DecisionClock = {}

function DecisionClock.init(agent)
	agent._thinkAt = 5
	agent._thinkRate = math.random(5, 25) / 100 -- 0.25s a 0.55s
end

function DecisionClock.ready(agent, now)
	if now >= (agent._thinkAt or 0) then
		agent._thinkAt = now + (agent._thinkRate or 0.4)
		return true
	end
	return false
end

return DecisionClock
