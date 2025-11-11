local constants = require("core.constants")
local Rule = require("rule")
local RuleState = require("rule_state")

local utils = require("core.utils")
local Logger = require("core.logger")
local Config = require("core.config")
local GameContext = require("core.game_context")
local TeamContext = require("core.team_context")

local interpolate = require("i18n.interpolate")

---@type OverwatchUi
local ui = require("ui.rml_ui")

---@type Channel[]
local channels = {
	require("channels.command"),
	require("channels.console"),
	require("channels.uilog"),
	require("channels.marquee"),
	require("channels.ping"),
	require("channels.sound"),
}

---@type Blueprint[]
local builtinBlueprints = require("builtin_blueprints")

local defaultConfig = require("default_config")

local LogLevel = constants.LogLevel

-- Builtin configuration
local IS_RELEASE = constants.IS_RELEASE
local NAME = constants.NAME
local VERSION = constants.VERSION
local LOG_LEVEL = IS_RELEASE and LogLevel.INFO or LogLevel.TRACE
local LOG_ECHO = true

local BP_FILES_PATTERN = "OverwatchBlueprints*.lua"

-- Interval for cleanups triggered by GameContext
local CLEANUP_INTERVAL = IS_RELEASE and 15 or 5

-- Per rule required fields
local CONFIG_RULE_REQS = { id = "string", enabled = "boolean" } -- 'blueprint = "string"' will be checked as well
-- Per rule optional fields
local CONFIG_RULE_OPTS = {
	enabled = "boolean",
	ownTeam = "boolean",
	interval = "number",
	cooldown = "number",
	category = "string",
	priority = "number",
	icon = "string",
	template = "string",
	parameters = "table",
	channels = "table",
	tags = "table",
}

--Per rule defaults
local CONFIG_RULE_DEFAULTS = {
	cooldown = IS_RELEASE and 10 or 0,
	interval = IS_RELEASE and 60 or 1,
}

-- Forward declarations
local spGetTeamList = Spring.GetTeamList

-- Vars
local initialized = false
---@type table<string, Blueprint> Available rules indexed by rule ID
local blueprints
---@type Rule[] Array of rule instances with their configurations
local rules
---@type table<number, table<string, RuleState>> States indexed by [teamID][ruleID]
local ruleStates
---@type table<number, table<string, function[]>>
local ruleStoppers
---@type table<number, TeamContext>
local teamContexts

---@type Logger
local logger
---@type Config
local config
---@type GameContext
local gameContext

---@type Widget
local widget = widget

function widget:GetInfo()
	return {
		name = NAME,
		desc = "Configurable monitoring and notification engine, press Alt+p to toggle the panel.",
		author = "Fast",
		date = VERSION,
		license = "GNU GPL, v2 or later",
		layer = -5,
		enabled = true,
	}
end

-- Helpers
---@param level MyLogLevel|integer
local function hasMinLogLevel(level)
	return LOG_LEVEL <= level
end

---@return number[]
local function getTeamlist()
	local r = {}
	local t = spGetTeamList()
	for _, teamId in ipairs(t) do
		local allyId = select(6, Spring.GetTeamInfo(teamId))
		if utils.IsTeamReal(allyId) then
			table.insert(r, teamId)
		end
	end

	return r
end

--- @param n Notification
local function dispatch(n)
	if not n.config then
		logger:Warning("Bad rule not getting a config: %s", table.toString(n))
		return
	end

	if not n.team then
		logger:Warning("Bad rule not getting a team: %s", table.toString(n))
		return
	end

	local nconf = n.config

	-- Template/interpolate the message.
	n.message = n.message or interpolate(nconf.template, n.templateParams)

	-- Apply config if not overriden.
	n.seconds = n.seconds or gameContext.seconds
	n.channels = n.channels or nconf.channels
	n.priority = n.priority or nconf.priority
	n.category = n.category or nconf.category
	n.icon = n.icon or nconf.icon

	-- Distribute
	for _, c in ipairs(channels) do
		if c.IsEnabled() then
			-- Notify and stop distributing if channel wants it.
			if not c.Notify(n) then
				return
			end
		end
	end
end

-- Helper to run a rule on interval.
--
---@param rule Rule
---@param teamId number
---@private
local function triggerRule(rule, teamId)
	-- No interval given = no run
	if not rule.config.interval or rule.config.interval < 0 then
		return
	end

	local now = gameContext.seconds
	local teamContext = teamContexts[teamId]
	local ruleConfig = rule.config
	local state = ruleStates[teamId][ruleConfig.id] or table.copy(rule.state)
	ruleStates[teamId][ruleConfig.id] = state

	local lastTriggered = state.lastTriggered or 0
	local cooldown = ruleConfig.cooldown or 0
	local interval = ruleConfig.interval

	-- Initialize lastTriggered and skip if wasn't initialized (first run)
	if lastTriggered < 1 then
		state.lastTriggered = now
		return
	end

	-- Skip if cooldown hasn't elapsed
	if cooldown > 0 and now - lastTriggered < cooldown then
		return
	end

	-- Skip if interval hasn't elapsed or interval-based monitoring is disabled for this rule.
	-- it's disabled when interval is < 0.
	if interval > 0 and now - lastTriggered < interval then
		return
	end

	-- Generate alert
	local triggered = rule.bp.Trigger(gameContext, teamContext, ruleConfig, state, dispatch)
	if triggered then
		-- Update state
		state.lastTriggered = now

		if hasMinLogLevel(LogLevel.TRACE2) then
			logger:Trace2("Rule: %s triggered", rule.config.id)
		end
	end
end

---@return Rule?
local function createRule(rConfig)
	if type(rConfig.blueprint) ~= "string" then
		logger:Warning(
			"Invalid rule config '%s', missing: 'blueprint', skipping it",
			table.toString(rConfig)
		)
		return
	end

	local bp = blueprints[rConfig.blueprint]
	if not bp then
		logger:Warning(
			"Blueprint '%s' for rule '%s' not found, skippping it",
			rConfig.blueprint,
			rConfig.id
		)
		return
	end

	local merged = table.copy(bp.defaultConfig)
	local missing = utils.MergeValidate(
		merged,
		rConfig,
		CONFIG_RULE_REQS,
		CONFIG_RULE_OPTS,
		CONFIG_RULE_DEFAULTS
	)
	if missing and table.count(missing) > 0 then
		logger:Warning(
			"Invalid rule config '%s', missing: '%s', skipping it",
			table.toString(rConfig),
			table.toString(missing)
		)
		return
	end

	-- -- Write back into users config
	-- if config.data and config.data.rules then
	-- 	config.data.rules[rConfig.id] = merged
	-- end

	if hasMinLogLevel(LogLevel.TRACE3) then
		logger:Trace3("Rule %s: merged config: %s", rConfig.id, table.toString(merged))
	end

	---@type Rule
	local ruleInstance = Rule.New(bp, merged, {
		lastTriggered = 0,
		lastChecked = 0,
		notified = false,
		data = {},
	})

	return ruleInstance
end

-- Loads a single rule file from VFS.
--
---@param path string
---@param env table
---@return number the number of rules loaded.
local function loadBlueprint(path, env)
	logger:Debug("Processing blueprint file: %s", path)

	local loaded = 0

	-- Load the file
	local r = VFS.Include(path, env)

	if type(r) ~= "table" then
		logger:Error("Loading blueprint file: %s", path)
		return 0
	end

	-- Register each blueprint
	for _, bp in ipairs(r) do
		if bp.id then
			if hasMinLogLevel(LogLevel.TRACE) then
				logger:Trace("Blueprint: %s", bp.id)
			end
			blueprints[bp.id] = bp
			loaded = loaded + 1
		end
	end
	logger:Debug("Loaded %d blueprints from %s", loaded, path)

	return loaded
end

-- Loads all rules from VFS.
--
---@param env table
---@return number the number of rules loaded.
local function loadBlueprints(env)
	logger:Debug("Loading rules from VFS")

	-- Find all rule files in LuaUI/Config directory
	local bpFiles = VFS.DirList(constants.CONFIG_DIR, BP_FILES_PATTERN)

	if #bpFiles == 0 then
		logger:Debug("No blueprint files found in %s", constants.CONFIG_DIR)
		return 0
	end

	logger:Debug("Found %d blueprint files", #bpFiles)

	-- Process each file
	local bpLoaded = 0
	for _, path in ipairs(bpFiles) do
		bpLoaded = bpLoaded + loadBlueprint(path, env)
	end

	return bpLoaded
end

---@param team TeamContext
local function cleanupTeam(team)
	if not team then
		return
	end

	local id = team.id

	-- Stop all rules listening.
	if ruleStoppers[id] then
		for _, trs in pairs(ruleStoppers[id]) do
			for _, rs in pairs(trs) do
				rs()
			end
		end
		ruleStoppers[id] = nil
	end

	-- Cleanup states
	ruleStates[id] = nil

	-- Stop contexts
	team:Shutdown()
	teamContexts[id] = nil
end

---@param msg string
local function fatalRemoveMe(msg, ...)
	logger:Fatal(msg, ...)
	widgetHandler:RemoveWidget()
end

-- Widget callins

function widget:Initialize()
	logger = Logger.New(NAME, LOG_LEVEL, LOG_ECHO)
	config = Config.New(logger)

	-- Load Config
	if
		not config:LoadMany(
			constants.CONFIG_DIR,
			constants.CONFIG_FILES_PATTERN,
			constants.CONFIG_FILE,
			defaultConfig
		)
	then
		fatalRemoveMe(
			"Loading config: %s/%s and %s/%s",
			constants.CONFIG_DIR,
			constants.CONFIG_FILE,
			constants.CONFIG_DIR,
			constants.CONFIG_FILES_PATTERN
		)
		return
	end

	if hasMinLogLevel(LogLevel.TRACE2) then
		logger:Trace2("Config: %s", table.toString(config.data))
	end

	-- Add internal blueprints.
	blueprints = {}

	for _, bp in ipairs(builtinBlueprints) do
		logger:Trace3("Blueprint: %s", bp.id)
		blueprints[bp.id] = table.copy(bp)
	end

	-- Load external blueprints.
	local blueprintsEnv = getfenv() --TODO(fast): Seems to be a big security risk, revisit this soon.
	blueprintsEnv.logger = logger:WithSection(NAME .. "::rules")
	blueprintsEnv.NotifyPriority = constants.NOTIFY_PRIORITY
	blueprintsEnv.ResourceType = constants.ResourceType

	local loaded = loadBlueprints(blueprintsEnv)
	logger:Debug("Blueprints: %d, loaded %d external blueprints", table.count(blueprints), loaded)

	if hasMinLogLevel(LogLevel.TRACE3) then
		logger:Trace3("Blueprints: %s", table.toString(blueprints))
	end

	-- Create and init the GameContext.
	gameContext = GameContext.New(CLEANUP_INTERVAL, logger)
	if not gameContext:Init() then
		fatalRemoveMe("While initializing GameContext")
		return
	end

	-- Initialize team context(s).
	teamContexts = {}
	ruleStates = {}
	local allTeams = getTeamlist()
	for _, teamID in ipairs(allTeams) do
		teamContexts[teamID] = TeamContext.New(teamID, logger)
		ruleStates[teamID] = RuleState.New()
	end

	-- Create rules from config.
	ruleStoppers = {}

	rules = {}
	if not config.data["rules"] then
		fatalRemoveMe("Invalid config: no rule config section")
		return
	end

	local myTeamID = gameContext.myTeamID

	logger:Trace("=== Creating rules ===")
	for id, rc in pairs(config.data["rules"]) do
		local rcfg = table.copy(rc)
		rcfg.id = id
		local rule = createRule(rcfg)

		if rule then
			table.insert(rules, rule)
			if logger.level > LogLevel.TRACE3 and logger.level <= LogLevel.TRACE then
				logger:Trace("Rule: %s, bp=%s", rule.config.id, rule.bp.id)
			end

			local rconf = rule.config

			-- Start the rule for all teams
			if rconf.enabled and rule.bp.Start then
				for _, team in pairs(teamContexts) do
					if not rconf.ownTeam or team.id == myTeamID then
						if not ruleStoppers[team.id] then
							ruleStoppers[team.id] = {}
						end

						ruleStoppers[team.id][rule.config.id] =
							rule.bp.Start(gameContext, team, rconf, dispatch)
					end
				end
			end
		end
	end
	logger:Trace("=== Total: %d rules ===", #rules)

	-- Initialize the UI.
	ui.Init(logger, gameContext, config)

	-- Initialize channels.
	for _, c in ipairs(channels) do
		if not c.Init(logger, gameContext, config, ui) then
			fatalRemoveMe("While initializing channel '%s'", c.id)
			return
		end

		logger:Debug("created channel: %s", c.id)
	end

	-- We have fresh TeamContext's add units to them.
	local allUnits = Spring.GetAllUnits()
	for _, unitID in ipairs(allUnits) do
		local teamID = Spring.GetUnitTeam(unitID)
		local unitDefID = Spring.GetUnitDefID(unitID)

		if teamID and unitDefID then
			gameContext:UnitFinished(unitID, unitDefID, teamID)

			if teamContexts[teamID] then
				teamContexts[teamID]:UnitFinished(unitID, unitDefID)
			end
		end
	end

	initialized = true
end

function widget:Shutdown()
	ui.Shutdown()

	for _, team in pairs(teamContexts) do
		cleanupTeam(team)
	end

	gameContext:Shutdown()

	initialized = false
end

function widget:GameFrame(n)
	if not initialized then
		return
	end

	-- Update game context
	gameContext:GameFrame()

	-- Cleanup teamcontexts
	for _, team in pairs(teamContexts) do
		if team then
			if not team:IsReal() then
				logger:Debug("Removing team %d it's not real anymore", team.id)

				cleanupTeam(team)
			end
		end
	end

	-- Process all rules for all teams
	local myTeamID = gameContext.myTeamID
	for id, team in pairs(teamContexts) do
		-- Update team context
		team:GameFrame()

		-- Process each rule instance
		for _, ruleInstance in ipairs(rules) do
			local rconf = ruleInstance.config
			if
				ruleInstance.bp.Trigger
				and rconf.enabled
				and (not rconf.ownTeam or id == myTeamID)
			then
				triggerRule(ruleInstance, id)
			end
		end
	end
end

function widget:PlayerChanged(playerID)
	if not gameContext:HasPlayerChanged() then
		return
	end

	gameContext:Init()

	-- Reinitialize team contexts for all teams
	local allTeams = spGetTeamList()
	for _, teamID in ipairs(allTeams) do
		teamContexts[teamID] = TeamContext.New(teamID, logger)
		ruleStates[teamID] = {}
	end

	ui.PlayerHasChanged()
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if not unitID or not unitDefID or not unitTeam then
		return
	end

	gameContext:UnitFinished(unitID, unitDefID, unitTeam)

	if teamContexts[unitTeam] then
		teamContexts[unitTeam]:UnitFinished(unitID, unitDefID)
	end
end

function widget:UnitDestroyed(
	unitID,
	unitDefID,
	unitTeam,
	attackerID,
	attackerDefID,
	attackerTeam,
	weaponDefID
)
	if not unitID or not unitDefID or not unitTeam then
		return
	end

	gameContext:UnitDestroyed(unitID, unitDefID, unitTeam)

	if teamContexts[unitTeam] then
		teamContexts[unitTeam]:UnitDestroyed(unitID, unitDefID)
	end
end

-- UI Callins
function widget:DrawScreen(viewSizeX, viewSizeY)
	return ui.DrawScreen(viewSizeX, viewSizeY)
end

function widget:ViewResize(viewSizeX, viewSizeY)
	return ui.ViewResize(viewSizeX, viewSizeY)
end

function widget:KeyPress(keyCode, mods, isRepeat, label, utf32char, scanCode, actionList)
	return ui.KeyPress(keyCode, mods, isRepeat, label, utf32char, scanCode, actionList)
end

function widget:KeyRelease(keyCode, mods, label, utf32char, scanCode, actionList)
	return ui.KeyRelease(keyCode, mods, label, utf32char, scanCode, actionList)
end

function widget:MousePress(x, y, button)
	return ui.MousePress(x, y, button)
end

function widget:MouseRelease(x, y, button)
	return ui.MouseRelease(x, y, button)
end

function widget:MouseMove(x, y, dx, dy, button)
	return ui.MouseMove(x, y, dx, dy, button)
end

function widget:MouseWheel(up, value)
	return ui.MouseWheel(up, value)
end
