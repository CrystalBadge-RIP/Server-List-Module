local Signal = require(script.Parent.Parent.Signal)

return function ()
	local Events = {
		OnRead = Signal.new(),
		OnRefresh = Signal.new(),
		OnRequestFailed = Signal.new()
	}

	return Events
end