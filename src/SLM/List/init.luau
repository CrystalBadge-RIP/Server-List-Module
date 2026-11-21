local Events = require(script.Events)
local MSC = require(script.Parent.MemoryStoreClass)
local List = {}
List.__index = List

type self = typeof(setmetatable({
	__Cursor = {},
	__IterAmount = 10,
	__LastRequest = 0,
	__Group = nil,
	__Level = 0,	
	__Sort = Enum.SortDirection.Ascending,
	__Event = nil :: typeof(Events()), 
	__CurrentList = {},
	__CacheList = {},
	__UseIter = {},
}, List))


function List.new (Group : string, IterAmount : number, Sort : Enum.SortDirection) : self
	local self : self = setmetatable({}, List)
	self.__Cursor = nil
	self.__IterAmount = 10
	self.__LastRequest = 0
	self.__Group = nil
	self.__Level = 1
	self.__Sort = Enum.SortDirection.Ascending
	self.__CurrentList = {}
	self.__CacheList = {}
	self.__Event = Events()
	self.__UseIter = 0
	
	if Group then
		self:SetGroup(Group)
	end
	
	if IterAmount then
		self:SetIterAmount(IterAmount)
	end
	
	if Sort then
		self:SetSortDirection(Sort)
	end
	
	self:Refresh()
	
	return self
end

------------------------------------
function List.ReadNext (self : self)
	if os.time() - self.__LastRequest < 5 then
		warn("Request too fast")
		return
	end
	
	local GetMemory = MSC.new(self.__Group.."."..self.__Level)
	local Lower,Upper = nil,nil
	
	if self.__Sort == Enum.SortDirection.Ascending then
		Lower = self.__Cursor
	else
		Upper = self.__Cursor
	end
	
	
	local Success, Result, LastKey, LastSortKey = GetMemory:GetRangeAsync(self.__Sort, self.__IterAmount-self.__UseIter, Lower, Upper)
	if not Success then
		self:GetEvents().OnRequestFailed:Fire()
		return
	end

	
	local R_Length = #Result

	self:_AddCache(Result)
	
	-- Basically:
	-- If it ascending it will check if it less than 15
	-- If it descending it will check if it more than 1
	local IsAscending = (
		self.__Sort == Enum.SortDirection.Ascending and 
			self.__Level < 15 or (
				self.__Sort == Enum.SortDirection.Descending and 
				self.__Level > 1
			)
	)
	

	if R_Length < self.__IterAmount and IsAscending then
		self:_SetCursor(nil)
		self:_MoveLevel()
		self:_AddIter(R_Length)
	
		if self:_GetDifIter() > 0 then
			return self:ReadNext()
		end
	end
	
	if R_Length > 0 then
		self:_SetCursor({
			key = LastKey,
			sortKey = LastSortKey,
		})
	end
	
	local CacheResult = self.__CacheList
	
	self:_UpdateCurrentList()
	self:_ResetLastRequest(os.time())
	self:_ResetIter()
	self:_ResetCache()
	
	self:GetEvents().OnRead:Fire(CacheResult)
	
	return CacheResult
end
------------------------------------
------- Utility Functions -----------
function List.SetIterAmount (self : self, Amount : number)
	if Amount < 1 or Amount > 30 then
		warn("Amount must be between 1 and 30")
		return
	end
	
	self.__IterAmount = Amount
end

function List.Refresh (self : self)
	self:_SetCursor(nil)
	self:_SetLevel((self.__Sort == Enum.SortDirection.Ascending) and 1 or 15)	
	self.__CurrentList = {}
	
	self:GetEvents().OnRefresh:Fire()
end

function List.GetCurrentList (self : self)
	return self.__CurrentList
end

function List.SetGroup (self : self, Group : string)
	if typeof(Group) ~= "string" or string.len(Group) > 40 then
		warn("Group must be a string and less than 40 characters")
		return
	end
	
	self.__Group = Group
	self:Refresh()
end

function List.SetSortDirection (self : self, SortDirection : Enum.SortDirection)
	if SortDirection.EnumType ~= Enum.SortDirection then
		warn("SortDirection must be a SortDirection")
		return
	end
	
	self.__Sort = SortDirection
	self:Refresh()
end

function List.GetEvents (self : self)
	return self.__Event
end


------------------------------------
----- Functions that shouldn't be used.-----
function List._SetLevel (self : self, Level : number)
	if typeof(Level) ~= "number" or Level < 1 or Level > 15 then
		warn("Level must be a number between 1 and 15")
		return
	end
	
	self.__Level = Level
end

function List._MoveLevel (self: self)
	if self.__Sort == Enum.SortDirection.Ascending then
		self.__Level += 1
	else
		self.__Level -= 1
	end
end

function List._SetCursor(self : self, Cursor : {any})
	self.__Cursor = Cursor
end

function List._ResetLastRequest (self : self)
	self.__LastRequest = os.time()	
end

function List._UpdateCurrentList (self : self)
	for Key, Data in self.__CacheList do
		table.insert(self.__CurrentList, Data)
	end
end

function List._GetDifIter (self : self)
	return self.__IterAmount - self.__UseIter
end

function List._ResetIter (self : self)
	self.__UseIter = 0
end

function List._ResetCache (self : self)
	self.__CacheList = {}
end

function List._AddIter (self : self, Length : number)
	self.__UseIter += Length
end

function List._AddCache (self : self, FetchResult : {any})
	for Key, Data in FetchResult do
		table.insert(self.__CacheList, Data)
	end
end

return List
