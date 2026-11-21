local MemoryStoreService = game:GetService("MemoryStoreService")
local MemoryClass ={}
MemoryClass.__index = MemoryClass

type self = typeof(setmetatable({
	SortedMap = MemoryStoreService:GetSortedMap()
}, MemoryClass))

local cache : {[string] : self} = {}

local function UPcall (callback:()->(), ...)
	local success, result =nil,nil
	for i = 1, 5 do
		success, result = pcall(callback, ...)
		if success then
			return success, result
		end

		warn("Pcall failed, retrying. \n|[error]: "..result)
		task.wait(1)
	end	

	return success, result
end



function MemoryClass.new(SortedMap : string)
	if cache[SortedMap] then
		return cache[SortedMap]
	end
	
	local self = setmetatable({}, MemoryClass)
	self.SortedMap = MemoryStoreService:GetSortedMap(SortedMap)
	cache[SortedMap] = self
	
	return self
end


function MemoryClass.Read(self : self, Key : string) : (boolean, any)
	local success, result = UPcall(function()
		return self.SortedMap:GetAsync(Key)
	end)
	
	return success, result
end

function MemoryClass.Write (self : self, Key : string, Value : any, Expiry : number, SortKey : number | string) : (boolean, any)
	local success, result = UPcall(function()
		return self.SortedMap:SetAsync(Key, Value, Expiry, SortKey)
	end)
	
	return success, result
end


-- Automatically convert to a list of keys
function MemoryClass.GetRangeAsync (self : self, Direction : Enum.SortDirection, Amount : number, LowerBound : {}, UpperBound : {}) : any
	local success, result = UPcall(function()
		return self.SortedMap:GetRangeAsync(Direction, Amount, LowerBound, UpperBound)
	end)
	
	if success then
		local LastKey,LastSortKey
		if #result > 0 then
			local Value = result[#result]
			LastKey = Value.key
			LastSortKey = Value.sortKey
		end
		
		return success, result, LastKey, LastSortKey
	else
		return success, result
	end
end


function MemoryClass.Remove (self : self, Key : string) : (boolean, any)
	local success, result = UPcall(function()
		return self.SortedMap:RemoveAsync(Key)
	end)
	
	return success, result
end




return MemoryClass