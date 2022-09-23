-- // Variables \\ --
local tween = {}
local functions = {}
local active = {}

local uniqueID = 0

-- // Functions \\ --

-- other functions
local function lerp(a, b, t)
	return a + (b - a) * t
end

-- easing functions
functions["easeOutQuad"] = function(x)
	return 1 - (1 - x) * (1 - x);
end

-- main functions
tween.create = function(initialValue, finalValue, tweenInfo, customID) -- tweenInfo: {time, style, repeatCount, delay}
	uniqueID = uniqueID + 1

	active[customID or tostring(uniqueID)] = {
		value = initialValue;
		finalValue = finalValue;
		totalTime = tweenInfo.time;
		elapsedTime = 0;
		info = tweenInfo;
		style = tweenInfo.style or "linear";
		repeatCount = tweenInfo.repeatCount or 0;
		repeatDelay = tweenInfo.delay or 0;
		isFinished = false;
		direction = 1;
		reverse = tweenInfo.reverse or false
	}

	return customID or tostring(uniqueID)
end

tween.update = function(dt)
	for id, data in pairs(active) do
		data.elapsedTime = data.elapsedTime + dt

		if data.elapsedTime > data.totalTime then
			data.isFinished = true
		end
	end
end

tween.value = function(id)
	if not active[id] then return nil end

	local data = active[id]

	if not data.isFinished then
		return lerp(data.value, data.finalValue, functions[data.style](data.elapsedTime/data.totalTime))
	else
		return data.finalValue
	end
end

tween.getDebugData = function(id)
	return active[id]
end

return tween