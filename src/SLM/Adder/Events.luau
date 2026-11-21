local Signal = require(script.Parent.Parent.Signal)

return function ()
	local Events = {
		OnSessionStart = Signal.new(),
		OnSessionStop = Signal.new(),
		OnRefresh = Signal.new(),
		OnFailedRefresh = Signal.new()
	}
	
	return Events
end