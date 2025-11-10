local constants = require("core.constants")
local utils = require("core.utils")

local spGetTeamResources = Spring.GetTeamResources

local RT_ENERGY = constants.ResourceType.ENERGY

local topics = {
	IsBetween = "IsBetween",
	IsBelow = "IsBelow",
	IsAbove = "IsAbove",
	IsFull = "IsFull",
	IsLow = "IsLow",
	HasExcess = "HasExcess",
}
local knownTopics = {}
for k, _ in pairs(topics) do
	table.insert(knownTopics, k)
end

---@alias teamResourceTopicsFilter fun(resource: TeamResource, options: table): boolean

---@type table<string, teamResourceTopicsFilter>
local topicsFilter = {
	IsBelow = function(resource, options)
		return resource:IsBelow(options.threshold)
	end,
	IsAbove = function(resource, options)
		return resource:IsAbove(options.threshold)
	end,
	IsBetween = function(resource, options)
		if not options.min or not options.max then
			return false
		end

		return resource:IsBetween(options.min, options.max)
	end,
	IsFull = function(resource, options)
		return resource:IsAbove()
	end,
	IsLow = function(resource, options)
		return resource:IsBelow()
	end,
	HasExcess = function(resource, options)
		return resource:HasExcess(options.threshold)
	end,
}

-- Resource information for a specific team
--
-- A wrapper for Spring.GetTeamResources
--
---@class TeamResource
---@field teamCtx TeamContext
---@field teamId number
---@field resourceType ResourceType
---@field current number
---@field storage number
---@field pull number
---@field income number
---@field expense number
---@field share number
---@field sent number
---@field received number
---@field excess number
---@field _logger Logger
---@field _subscribers table<string, table> Table of event subscribers by event type
local TeamResource = {}
TeamResource.__index = TeamResource

---@param team TeamContext
---@param resourceType ResourceType
---@param logger Logger
---@return TeamResource
function TeamResource.New(team, resourceType, logger)
	---@type TeamResource
	local self = setmetatable({
		teamCtx = team,
		teamId = team.id,
		resourceType = resourceType,
		current = 0,
		storage = 0,
		pull = 0,
		income = 0,
		expense = 0,
		share = 0,
		sent = 0,
		received = 0,
		excess = 0,
		_logger = logger,
		_subscribers = {},
	}, TeamResource)

	self:GameFrame()

	return self
end

---@return string
function TeamResource:__tostring()
	return utils.DumpClass(self, "TeamResource", {
		"teamId",
		"resourceType",
		"current",
		"storage",
		"pull",
		"income",
		"expense",
		"share",
		"sent",
		"received",
		"excess",
	})
end

function TeamResource:GameFrame()
	local current, storage, pull, income, expense, share, sent, received, excess =
		spGetTeamResources(self.teamId, tostring(self.resourceType))

	self.current = current or 0
	self.storage = storage or 1
	self.pull = pull or 0
	self.income = income or 0
	self.expense = expense or 0
	self.share = share or 0
	self.sent = sent or 0
	self.received = received or 0
	self.excess = excess or 0

	if self.current > 0 then
		self:publish(topics.IsBelow)
		self:publish(topics.IsAbove)
		self:publish(topics.IsBetween)
		self:publish(topics.IsFull)
		self:publish(topics.IsLow)
		self:publish(topics.HasExcess)
	end
end

---@private
---@param topic string
function TeamResource:publish(topic)
	if not self._subscribers[topic] then
		return
	end

	local topicFilter = topicsFilter[topic]

	if topicFilter then
		for _, options in pairs(self._subscribers[topic]) do
			if topicFilter(self, options) then
				options._callback()
			end
		end
	else
		for _, options in pairs(self._subscribers[topic]) do
			options._callback()
		end
	end
end

-- Subscribe to TeamResource events
--
---@param caller string Caller reference for debugging and logging.
---@param topic string The event type to subscribe to
---@param options table
---@param callback fun() The callback function to be called when the event occurs
---@return function? Unsubscribe function to remove this subscription, nil on failure
function TeamResource:Subscribe(caller, topic, options, callback)
	if not table.contains(knownTopics, topic) then
		self._logger:Warning("Unknown topic '%s' in a teamcontext for caller '%s'", topic, caller)
		return nil
	end

	if not self._subscribers[topic] then
		self._subscribers[topic] = {}
	end

	options._callback = callback

	table.insert(self._subscribers[topic], options)

	-- Return an unsubscribe function
	return function()
		-- safety
		if not self._subscribers[topic] then
			return
		end

		table.removeAll(self._subscribers[topic], options)
	end
end

-- Get resource storage ratio
-- Returns the ratio of current amount to total storage (0-1)
function TeamResource:GetRatio()
	if self.resourceType == RT_ENERGY then
		local mmUse = self.teamCtx:GetRulesParamNum("mmUse", 0)
		return (self.current + mmUse) / self.storage
	end

	return self.current / self.storage
end

-- Get net resource income
-- Returns the difference between income and expense rates
function TeamResource:GetNetResource()
	return self.income - self.expense
end

-- Check if resource storage is nearly full
-- Returns true if storage ratio is above the threshold
--
---@param threshold number? (default 0.9)
function TeamResource:IsAbove(threshold)
	threshold = threshold or 0.9
	return self:GetRatio() >= threshold
end

-- Check if resource is below threshold
-- Returns true if storage ratio is below the threshold
--
---@param threshold number? (default 0.2)
function TeamResource:IsBelow(threshold)
	threshold = threshold or 0.2
	return self:GetRatio() <= threshold
end

-- Returns whether the resource between min and max
--
---@param min integer
---@param max integer
---@return boolean
function TeamResource:IsBetween(min, max)
	return self:GetRatio() <= min and self:GetRatio() >= max
end

-- Check if excess is above threshold.
---@param threshold number? (default 0.1)
function TeamResource:HasExcess(threshold)
	threshold = threshold or 0.1
	return self.excess >= (self.storage * threshold)
end

return TeamResource
