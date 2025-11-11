local utils = require("core.utils")

local topics = {
	Cleanup = "Cleanup",
	UnitFinished = "UnitFinished",
	UnitDestroyed = "UnitDestroyed",
	PlayerChanged = "PlayerChanged",
}
local knownTopics = {}
for k, _ in pairs(topics) do
	table.insert(knownTopics, k)
end

local spGetGameFrame = Spring.GetGameFrame
local spGetGameSeconds = Spring.GetGameSeconds
local spGetGameRulesParam = Spring.GetGameRulesParam

-- Global game state and context information
--
-- GameContext tracks game-wide state like time, PVE mode, boss status,
-- and provides utility methods for checking game conditions.
--
---@class GameContext
---@field myTeamID integer
---@field myAllyTeamID integer
---@field myPlayerID integer
---@field inSpecMode boolean
---@field modOptions table<string, string>
---@field maxUnits integer
---@field maxUnitsPerPlayer integer
---@field frame number Current game frame
---@field time number Current game time
---@field startupSeconds number Game time at startup
---@field seconds number Current game time in seconds
---@field pveMode string The PVE mode, currently one of: "raptors", "scavengers", or "none"
---@field bossAnger number Queen/Boss anger level (0-100)
---@field bossHealth number Queen/Boss health percentage (0-100)
---@field evolution number Queen/Tech evolution level
---@field gracePeriod number Grace period timestamp
---@field graceRemaining number? Remaining grace period in seconds
---@field unitCount integer
---@field unitCounts table<integer, integer>
--
---@field _logger Logger
---@field _subscribers table<string, function[]> Table of event subscribers by event type
---@field _cleanupInterval integer
---@field _lastCleanup number
local GameContext = {}
GameContext.__index = GameContext

---@return GameContext
function GameContext.New(cleanUpInterval, logger)
	---@type GameContext
	local self = setmetatable({
		myTeamID = 0,
		myAllyTeamID = 0,
		myPlayerID = 0,
		inSpecMode = false,
		modOptions = Spring.GetModOptions(),
		maxUnits = Game.maxUnits,
		frame = 0,
		startupSeconds = spGetGameSeconds() or 0,
		seconds = 0,
		bossAnger = 0,
		bossHealth = 0,
		evolution = 0,
		gracePeriod = 0,
		graceRemaining = 0,
		unitCount = 0,
		unitCounts = {},

		_logger = logger,
		_subscribers = {},
		_cleanupInterval = cleanUpInterval,
		_lastCleanup = 0,
	}, GameContext)

	-- Do not cleanup on start / recreation of widget
	self._lastCleanup = self.startupSeconds + cleanUpInterval

	return self
end

function GameContext:Shutdown()
	self._subscribers = {}
end

---@return string
function GameContext:__tostring()
	return utils.DumpClass(self, "GameContext", {
		"myTeamID",
		"myAllyTeamID",
		"myPlayerID",
		"inSpecMode",
		"frame",
		"seconds",
		"pveMode",
		"bossAnger",
		"bossHealth",
		"evolution",
		"gracePeriod",
		"graceRemaining",
	})
end

---@return boolean
function GameContext:Init()
	self.myTeamID = Spring.GetMyTeamID()
	self.myPlayerID = Spring.GetMyPlayerID()
	self.myAllyTeamID = Spring.GetMyAllyTeamID()
	self.inSpecMode = Spring.IsReplay() or Spring.GetSpectatingState()

	self.pveMode = "none"
	if Spring.Utilities.Gametype.IsRaptors() then
		self.pveMode = "raptors"
	elseif Spring.Utilities.Gametype.IsScavengers() then
		self.pveMode = "scavengers"
	end

	self:GameFrame()

	return true
end

-- Refreshes all game state information
function GameContext:GameFrame()
	-- Update game time
	self.frame = spGetGameFrame() or 0
	self.seconds = spGetGameSeconds() or 0

	-- Update boss/queen info if available
	if self.pveMode == "raptors" then
		self.bossAnger = spGetGameRulesParam("raptorQueenAnger") or 0
		self.bossHealth = spGetGameRulesParam("raptorQueenHealth") or 100
		self.evolution = spGetGameRulesParam("raptorTechAnger") or 0
		self.gracePeriod = spGetGameRulesParam("raptorGracePeriod") or 0
	elseif self.pveMode == "scavengers" then
		self.bossAnger = spGetGameRulesParam("scavBossAnger") or 0
		self.bossHealth = spGetGameRulesParam("scavBossHealth") or 100
		self.evolution = spGetGameRulesParam("scavTechAnger") or 0
		self.gracePeriod = spGetGameRulesParam("scavGracePeriod") or 0
	end

	-- Update grace period
	-- https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/gui_raptorStatsPanel.lua#L212
	if self.pveMode ~= "none" and self.gracePeriod > 0 then
		self.graceRemaining = math.ceil(((self.seconds - self.gracePeriod) * -1) - 0.5)
	end

	if self.seconds - self._lastCleanup < self._cleanupInterval then
		self:publish(topics.Cleanup)
		self._lastCleanup = self.seconds
	end
end

---@private
---@param topic string
---@param data table<string, any>?
function GameContext:publish(topic, data)
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
function GameContext:Subscribe(caller, topic, callback)
	if not table.contains(knownTopics, topic) then
		self._logger:Warning("Unknown topic '%s' in a gamecontext for caller '%s'", topic, caller)
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

-- Whetever the player changed spec mode or ally team.
--
---@return boolean
function GameContext:HasPlayerChanged()
	local currentspec = Spring.GetSpectatingState()
	local currentAllyTeamID = Spring.GetMyAllyTeamID()

	if (currentspec ~= self.inSpecMode) or (currentAllyTeamID ~= self.myAllyTeamID) then
		self:publish(topics.PlayerChanged)
		return true
	end

	return false
end

-- Called at the moment the team unit is completed.
--
---@param id integer unitID
---@param defID integer unitDefID
---@param teamID integer unitTeamID
function GameContext:UnitFinished(id, defID, teamID)
	self.unitCount = self.unitCount + 1

	if not self.unitCounts[defID] then
		self.unitCounts[defID] = 1
	else
		self.unitCounts[defID] = self.unitCounts[defID] + 1
	end

	-- Runs after unitCounts so rules have these updated.
	self:publish(topics.UnitFinished, { id = id, teamID = teamID, defID = defID })
end

-- Called when a team unit is destroyed.
--
---@param id integer unitID
---@param defID integer unitDefID
---@param teamID integer unitTeamID
function GameContext:UnitDestroyed(id, defID, teamID)
	if self.unitCount > 0 then
		self.unitCount = self.unitCount - 1
	end

	if not self.unitCounts[defID] then
		return
	end

	if self.unitCounts[defID] > 0 then
		self.unitCounts[defID] = self.unitCounts[defID] - 1
	end

	-- Runs after unitCounts so rules have these updated.
	self:publish(topics.UnitDestroyed, { id = id, teamID = teamID, defID = defID })
end

-- Check if evolution is within range
--
---@param min number?
---@param max number?
---@return boolean
function GameContext:IsEvolutionInRange(min, max)
	min = min or 0
	max = max or 100
	return self.evolution >= min and self.evolution <= max
end

-- Check if boss anger is within range
--
---@param min number
---@param max number
---@return boolean
function GameContext:IsBossAngerInRange(min, max)
	min = min or 0
	max = max or 100
	return self.bossAnger >= min and self.bossAnger <= max
end

-- Check if grace period is within range
--
---@param min number
---@param max number
---@return boolean
function GameContext:IsGraceInRange(min, max)
	if not self.graceRemaining or self.graceRemaining <= 0 then
		return false
	end

	min = min or 0
	max = max or math.huge
	return self.graceRemaining >= min and self.graceRemaining <= max
end

return GameContext
