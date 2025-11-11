local utils = require("core.utils")
local TeamResource = require("core.team_resource")

local spGetTeamInfo = Spring.GetTeamInfo
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetTeamMaxUnits = Spring.GetTeamMaxUnits

local topics = {
	UnitFinished = "UnitFinished",
	UnitDestroyed = "UnitDestroyed",
}
local knownTopics = {}
for k, _ in pairs(topics) do
	table.insert(knownTopics, k)
end

---@alias RulesParam string|number

-- TeamContext provides access to team-specific data and resources.
--
---@class TeamContext
---@field id integer The team ID
---@field allyTeamId number
---@field leaderId number
---@field leaderName string
---@field color table<string, number>
---@field maxUnits integer
---@field unitCount integer
---@field unitCounts table<integer, integer>
--
---@field _logger Logger
---@field _resources table<string, TeamResource>
---@field _subscribers table<string, function[]> Table of event subscribers by event type
local TeamContext = {}
TeamContext.__index = TeamContext

---@param id number
---@param logger Logger
---@return TeamContext
function TeamContext.New(id, logger)
	---@type TeamContext
	local self = setmetatable({
		id = id,
		allyTeamId = 0,
		leaderId = 0,
		leaderName = "Unknown",
		color = {},
		maxUnits = 0,
		unitCount = 0,
		unitCounts = {},
		_logger = logger,
		_resources = {},
		_subscribers = {},
	}, TeamContext)

	local _, leaderId, _, _, _, allyTeamId = spGetTeamInfo(self.id, false)
	self.leaderId = leaderId
	self.allyTeamId = allyTeamId
	self.leaderName = (
		(WG and WG.playernames and WG.playernames.getPlayername)
		and WG.playernames.getPlayername(leaderId)
	)
		or spGetPlayerInfo(leaderId, false)
		or "Unknown"

	local r, g, b, a = Spring.GetTeamColor(self.id)
	self.color = { r = r or 0, g = g or 0, b = b or 0, a = a or 1 }

	local maxUnits, unitCount = spGetTeamMaxUnits(self.id)
	self.maxUnits = maxUnits
	self.unitCount = unitCount or 0

	return self
end

function TeamContext:Shutdown()
	for _, r in pairs(self._resources) do
		r:Shutdown()
	end

	self._subscribers = {}
end

---@return string
function TeamContext:__tostring()
	return utils.DumpClass(
		self,
		"TeamContext",
		{ "id", "leaderName", "maxUnits", "unitCount", "_resources" }
	)
end

-- Refreshes resources
function TeamContext:GameFrame()
	for _, r in pairs(self._resources) do
		r:GameFrame()
	end
end

---@private
---@param topic string
---@param data table<string, any>?
function TeamContext:publish(topic, data)
	if not self._subscribers[topic] then
		return
	end

	for _, cb in ipairs(self._subscribers[topic]) do
		cb(data)
	end
end

-- Subscribe to TeamContext events
--
---@param caller string Caller reference for debugging and logging.
---@param topic string The event type to subscribe to
---@param callback fun(data : table<string, any>?) The callback function to be called when the event occurs
---@return function? Unsubscribe function to remove this subscription, nil on failure
function TeamContext:Subscribe(caller, topic, callback)
	if not table.contains(knownTopics, topic) then
		self._logger:Warning("Unknown topic '%s' in a teamcontext for caller '%s'", topic, caller)
		return nil
	end

	if not self._subscribers[topic] then
		self._subscribers[topic] = {}
	end

	table.insert(self._subscribers[topic], callback)

	-- Return an unsubscribe function
	return function()
		-- safety
		if not self._subscribers[topic] then
			return
		end

		table.removeAll(self._subscribers[topic], callback)
	end
end

-- IsReal checks if the current team is real.
--.
---@return boolean
function TeamContext:IsReal()
	return utils.IsTeamReal(self.allyTeamId)
end

function TeamContext:updateUnitCount()
	local maxUnits, unitCount = spGetTeamMaxUnits(self.id)
	self.maxUnits = maxUnits
	self.unitCount = unitCount or 0
end

-- Called at the moment the team unit is completed.
--
---@param id integer unitID
---@param defID integer unitDefID
function TeamContext:UnitFinished(id, defID)
	self:updateUnitCount()

	if not self.unitCounts[defID] then
		self.unitCounts[defID] = 1
	else
		self.unitCounts[defID] = self.unitCounts[defID] + 1
	end

	-- Runs after unitCounts so rules have these updated.
	self:publish(topics.UnitFinished, { id = id, teamID = self.id, defID = defID })
end

-- Called when a team unit is destroyed.
--
---@param id integer unitID
---@param defID integer unitDefID
function TeamContext:UnitDestroyed(id, defID)
	self:updateUnitCount()

	if not self.unitCounts[defID] then
		return
	end

	if self.unitCounts[defID] > 0 then
		self.unitCounts[defID] = self.unitCounts[defID] - 1
	end

	-- Runs after unitCounts so rules have these updated.
	self:publish(topics.UnitDestroyed, { id = id, teamID = self.id, defID = defID })
end

-- Get team resources for a specific resource type
--
---@param resourceType ResourceType
function TeamContext:GetResource(resourceType)
	if not self._resources[resourceType] then
		self._resources[resourceType] = TeamResource.New(self, resourceType, self._logger)
	end

	return self._resources[resourceType]
end

-- Get team rules parameter
-- Returns a value from Spring.GetTeamRulesParam
--
---@param param string
---@return RulesParam?
function TeamContext:GetRulesParam(param)
	return spGetTeamRulesParam(self.id, param)
end

-- Same as GetRulesParam but makes sure to return a number, default is 0.
--
---@param param string
---@param default number?
---@return number
function TeamContext:GetRulesParamNum(param, default)
	local val = spGetTeamRulesParam(self.id, param)

	return tonumber(val) or (default and default or 0)
end

-- Get count of units by unit def name.
--
---@param unitName string
function TeamContext:GetUnitCountByDefName(unitName)
	local unitDefID = UnitDefNames[unitName].id
	return self.unitCounts[unitDefID] or 0
end

return TeamContext
