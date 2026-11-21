local Events = require(script.Events)
local MSC = require(script.Parent.MemoryStoreClass)
local ServerLifetime = os.time()
local Players = game:GetService("Players")
local Adder = {}
local AdderCache = {}
Adder.__index = Adder

type self = typeof(setmetatable({
	__RenewTime = 0,
	__Group = "",
	__Active = false,
	__LatestShard = "",
	__Key = "",
	__Thread = nil,
	__Event = nil :: typeof(Events()),
	__Metadata = {}
},Adder))

local function InfoClass ()
	return {
		JoinId = game.JobId,
		Metadata = {},
	}
end

function Adder.new(RenewTime : number, Group : string, Key : string) 
	local self = setmetatable({}, Adder)
	self.__RenewTime = RenewTime or 30
	self.__Group = Group or "V"
	self.__Active = false
	self.__LatestShard = ""
	self.__Thread = nil
	self.__Key = Key or game.JobId
	self.__Metadata = {}	
	self.__Event = Events()


	table.insert(AdderCache, self)
	
	return self
end

function Adder.SetGroup(self : self, Group : string)
	if typeof(Group) ~= "string" then
		return error("Group must be a string!")
	end
	
	if string.len(Group) > 15 then
		return warn("Group Name cannot be longer than 15 characters!")
	end
	
	self.__Group = Group
end

function Adder.SetRenewTime(self : self, RenewTime : number)
	if typeof(RenewTime) ~= "number" then
		return error("RenewTime must be a number!")
	end
	
	if RenewTime < 30 or RenewTime > 90 then
		return warn("RenewTime must be in 30 to 90 seconds range.")
	end
	
	self.__RenewTime = RenewTime
end

function Adder.SetMetadata(self : self, MetaData : {})
	if typeof(MetaData) ~= "table" then
		return error("MetaData must be a table!")
	end
	
	-- check if the metadata is valid
	
	self.__Metadata = MetaData
end

function Adder.SetServerKey (self : self, ID : string)
	if typeof(ID) ~= "string" then
		return error("ID must be a string!")
	end
	
	if string.len(ID) > 15 then
		return warn("ID cannot be longer than 15 characters!")
	end
	
	self.__Key = ID
end

function Adder.GetMetadata(self : self)
	return self.__Metadata
end

function Adder.GetEvents(self : self)
	return self.__Event
end


--- Adder Functions
function Adder.StartSession (self : self)
	if self.__Active then	
		return warn("Session is already active!")
	end
	
	self.__Active = true
	self.__Thread = task.spawn(function()
		while self.__Active do
			self:Refresh()
			task.wait(self.__RenewTime)
		end
	end)
	
	self:GetEvents().OnSessionStart:Fire()
end

function Adder.Refresh(self : self)
	local GetPlayer = #Players:GetPlayers()
	if GetPlayer == 0 then
		GetPlayer +=1
	end
	
	local Shard = self.__Group.."."..GetPlayer % 15 

	-- Get Memory Store Class
	local MemoryStore = MSC.new(Shard)

	
	local NewInfo = InfoClass()
	NewInfo.Metadata = self:GetMetadata()
	-- Update Key Async
	local success, result = MemoryStore:Write(self.__Key, NewInfo, self.__RenewTime, GetPlayer)
	
	if not success then
		self:GetEvents().OnFailedRefresh:Fire()
		warn("Failed to update key: "..result)
		return false
	end
	
	self.__LatestShard = Shard

	self:GetEvents().OnRefresh:Fire()
end

function Adder.StopSession(self : self)
	if not self.__Active then
		return
	end
	
	self.__Active = false
	
	--- Cleanup Thread and Key
	if self.__Thread then
		task.cancel(self.__Thread)
	end
	
	
	local MemoryStore = MSC.new(self.__LatestShard)
	local success,result = MemoryStore:Remove(self.__Key)
	
	if not success then
		warn(result)
	end
	
	self:GetEvents().OnSessionStop:Fire()
end


game:BindToClose(function(Reason : Enum.CloseReason)
	for _, Adder in AdderCache do
		Adder:StopSession()
	end
end)

return Adder