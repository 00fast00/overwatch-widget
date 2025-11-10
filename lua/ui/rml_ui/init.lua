-- RmlUi UI Rendering
local utils = require("core.utils")
local constants = require("core.constants")
local controls = require("ui.rml_ui.controls")

local RCSS_CHUNK = require("ui.rml_ui.overwatch-rcss")
local RML_CHUNK = require("ui.rml_ui.overwatch-rml")

local LogLevel = constants.LogLevel

local spGetViewGeometry = Spring.GetViewGeometry
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers

-- Constants
local DEFAULT_TEXT_COLOR = "#ffffffff"
local DEFAULT_BG_COLOR = "#4a4a4a00"

local CONFIG_SECTION = "rmlUi"
local CONFIG_DEFAULTS = {
	show = true,
	teamColoring = true,
	prioColoring = true,

	columns = {
		time = { visible = true },
		playerName = { visible = true },
		priority = { visible = false },
		category = { visible = true },
		rule = { visible = false },
		icon = { visible = false },
		message = { visible = true },
	},
}

local MARQUEE_NCID = "marquee"

local MODEL_NAME = "overwatch_model"
local RML_PATH = "LuaUI/Widgets/overwatch.rml"
local RCSS_PATH = "LuaUI/Widgets/overwatch.rcss"

-- Vars
local logger ---@type Logger
local gameContext ---@type GameContext
local teamContexts ---@type TeamContext[]
local config ---@type Config

local uiConfig = {}

local logs = {} ---@type table[]

local viewSizeX, viewSizeY
local widgetScale
local font2
local marqueeMessage ---@type Notification?
local marqueeStartTime

local NOTIFY_PRIORITY = constants.NOTIFY_PRIORITY
local NOTIFY_PRIORITY_BACKGROUND_COLORS = {
	[NOTIFY_PRIORITY.TRACE] = "#4a4a4a00",
	[NOTIFY_PRIORITY.DEBUG] = "",
	[NOTIFY_PRIORITY.INFO] = "#4a4a4a00",
	[NOTIFY_PRIORITY.WARNING] = "#00FF48AA",
	[NOTIFY_PRIORITY.ERROR] = "#4a4a4a00",
	[NOTIFY_PRIORITY.CRITICAL] = "#4a4a4a00",
	[NOTIFY_PRIORITY.NONE] = "#4a4a4a00",
}

---@param r number
---@param g number
---@param b number
---@param a number
---@returns string
local function rgbaToHex(r, g, b, a)
	return string.format(
		"#%02x%02x%02x%02x",
		math.floor(r * 255),
		math.floor(g * 255),
		math.floor(b * 255),
		math.floor(a * 255)
	)
end

---@class (exact) OverwatchUiModel
---@field isDev boolean
---@field debugging boolean
---@field panel string
---@field columns any
---@field logs table[]
---@field logCount integer
---@field logMax integer
local initModel = {
	isDev = not constants.IS_RELEASE,
	debugging = false,

	panel = "log",

	columns = {
		[1] = { label = "Time", width = "3.5rem", visible = true, teamColor = false },
		[2] = { label = "Player Name", width = "14rem", visible = true, teamColor = true },
		[3] = { label = "Priority", width = "5rem", visible = true, teamColor = false },
		[4] = { label = "Category", width = "5rem", visible = true, teamColor = false },
		[5] = { label = "Rule", width = "17rem", visible = true, teamColor = false },
		[6] = { label = "Icon", width = "2rem", visible = false, teamColor = false },
		[7] = { label = "Message", width = "100%", visible = true, teamColor = false },
	},

	logs = {},
	logCount = 0,
	logMax = constants.IS_RELEASE and 5000 or 100000,
}
local rmlContext ---@type RmlUi.Context?
local dmHandle ---@type RmlUi.SolLuaDataModel<OverwatchUiModel>?
local document ---@type RmlUi.Document?

-- Helper to check if file contents and chunk are the same.
--
---@param chunk string
---@param path string
---@return boolean tmp false if not else true
local function checkFile(chunk, path)
	local file = io.open(path, "r")
	if not file then
		return false
	end

	local fileChunk = file:read("*a")
	file:close()

	if chunk ~= fileChunk then
		return false
	end

	return true
end

-- Helper to overwrite file contents with the given chunk.
--
---@param chunk string
---@param path string
local function overwriteFile(chunk, path)
	local file = io.open(path, "w")

	if not file then
		logger:Error("unable to save file %s", path)
		return
	end

	if not file:write(chunk) then
		logger:Error("failed to write to file %s", path)
		file:close()
		return
	end

	file:close()
end

local function updateView()
	viewSizeX, viewSizeY = spGetViewGeometry()
	widgetScale = (0.75 + (viewSizeX * viewSizeY / 10000000))

	if WG and WG["fonts"] then
		-- font = WG["fonts"].getFont()
		font2 = WG["fonts"].getFont(nil, 1.5)
	end
end

local function drawMarqueeMessage()
	if not marqueeMessage or not marqueeStartTime or not font2 then
		return
	end

	local currentTimer = spGetTimer()
	local elapsed = spDiffTimers(currentTimer, marqueeStartTime)

	-- Check if message should be dismissed.
	if elapsed > uiConfig.marqueeDuration then
		marqueeMessage = nil
		marqueeStartTime = nil
		return
	end

	local params = marqueeMessage.config.parameters["channels"][MARQUEE_NCID]
	local fc = params.fontColor
	local foc = params.fontOutlineColor

	-- Calculate vertical position (scroll up from bottom).
	local marqueeY = viewSizeY - (elapsed * params.speed * viewSizeY)

	if marqueeY > 0 then
		font2:Begin()
		font2:SetTextColor(fc.r, fc.g, fc.b, fc.a)
		font2:SetOutlineColor(foc.r, foc.g, foc.b, foc.a)
		font2:Print(
			marqueeMessage.message,
			viewSizeX / 2,
			marqueeY,
			params.font_size * widgetScale,
			"co"
		)
		font2:End()
	else
		-- Message scrolled off screen.
		marqueeMessage = nil
		marqueeStartTime = nil
	end
end

-- API
---@type OverwatchUi
local ui = {
	Init = function(l, gctx, cfg)
		if l then
			logger = l:WithSection(l.section .. "::RmlUi")
		end

		if gctx then
			gameContext = gctx
			teamContexts = {}
		end

		if cfg then
			config = cfg
		end

		if not RmlUi then
			-- RmLUI not found, head out.
			logger:Warning("RmlUi not found, won't have an UI")
			return false
		end

		if not logger or not gameContext or not config then
			logger:Warning(
				"logger/gameContext/config not given, won't have an UI. logger=%s, gameContext=%s, config=%s",
				type(logger),
				type(gameContext),
				type(config)
			)
			return false
		end

		-- Our own section in the config
		if not config.data[CONFIG_SECTION] then
			config.data[CONFIG_SECTION] = {}
		end
		uiConfig = config.data[CONFIG_SECTION]

		-- Apply defaults
		utils.ApplyDefaults(uiConfig, CONFIG_DEFAULTS)

		initModel.columns[1].visible = uiConfig.columns.time.visible
		initModel.columns[2].visible = uiConfig.columns.playerName.visible
		initModel.columns[3].visible = uiConfig.columns.priority.visible
		initModel.columns[4].visible = uiConfig.columns.category.visible
		initModel.columns[5].visible = uiConfig.columns.rule.visible
		initModel.columns[6].visible = uiConfig.columns.icon.visible
		initModel.columns[7].visible = uiConfig.columns.message.visible

		-- Set Player Name column visibility
		-- initModel.columns[1].visible = false -- gameContext.inSpecMode

		rmlContext = RmlUi.GetContext("shared")
		if not rmlContext then
			logger:Error("failed to get RmlUi context")
			return false
		end

		updateView()

		controls.Init(logger, rmlContext)
		---@diagnostic disable-next-line: missing-parameter
		dmHandle = rmlContext:OpenDataModel(MODEL_NAME, initModel)
		controls.SetDmHandle(dmHandle)

		-- Write .rml and .rcss if needed
		if constants.IS_RELEASE then
			if not checkFile(RML_CHUNK, RML_PATH) then
				logger:Debug("Writing .rml: %s", RML_PATH)
				overwriteFile(RML_CHUNK, RML_PATH)
			end

			if not checkFile(RCSS_CHUNK, RCSS_PATH) then
				logger:Debug("Writing .rcss: %s", RCSS_PATH)
				overwriteFile(RCSS_CHUNK, RCSS_PATH)
			end
		end

		---@diagnostic disable-next-line: redundant-parameter
		document = rmlContext:LoadDocument(RML_PATH, controls)
		document:ReloadStyleSheet()
		if uiConfig.show then
			document:Show()
		end

		return true
	end,

	Shutdown = function()
		if not rmlContext then
			logger:Warning("shutdown has no rmlContext")
			return false
		end

		if dmHandle then
			rmlContext:RemoveDataModel(MODEL_NAME)
			dmHandle = nil
		end

		if document then
			document:Close()
			document = nil
		end

		rmlContext = nil

		return true
	end,

	SetTeamContext = function(team)
		teamContexts[team.id] = team
	end,

	GetTeamContext = function(team_id)
		return teamContexts[team_id]
	end,

	Log = function(n)
		if not dmHandle then
			logger:Warning("adding a log without a handle")
			return
		end

		local logMax = dmHandle.logMax

		local teamColor = n.team.color
		local teamColorHex = rgbaToHex(teamColor.a, teamColor.g, teamColor.b, teamColor.a)
		local prioBgColor = NOTIFY_PRIORITY_BACKGROUND_COLORS[n.priority] or DEFAULT_BG_COLOR

		-- need to be aligned with the columns in init_model above.
		table.insert(logs, 1, {
			[1] = {
				value = string.formatTime(n.seconds),
				color = DEFAULT_TEXT_COLOR,
				bgColor = DEFAULT_BG_COLOR,
			},
			[2] = {
				value = n.team.leaderName,
				color = uiConfig.teamColoring and teamColorHex or DEFAULT_TEXT_COLOR,
				bgColor = DEFAULT_BG_COLOR,
			},
			[3] = {
				value = constants.NOTIFY_PRIORITY_NAMES[n.priority],
				color = DEFAULT_TEXT_COLOR,
				bgColor = uiConfig.prio_coloring and prioBgColor or DEFAULT_BG_COLOR,
			},
			[4] = {
				value = n.category or "",
				color = DEFAULT_TEXT_COLOR,
				bgColor = DEFAULT_BG_COLOR,
			},
			[5] = {
				value = n.config.id or "",
				color = DEFAULT_TEXT_COLOR,
				bgColor = DEFAULT_BG_COLOR,
			},
			[6] = { value = n.icon or "", color = DEFAULT_TEXT_COLOR, bgColor = DEFAULT_BG_COLOR },
			[7] = {
				value = n.message or "",
				color = DEFAULT_TEXT_COLOR,
				bgColor = DEFAULT_BG_COLOR,
			},
		})

		while #logs > logMax do
			table.remove(logs)
		end

		dmHandle.logs = logs
		dmHandle.logCount = #logs

		-- if not document then
		-- 	return
		-- end

		-- document:UpdateDocument()

		-- ---@param element RmlUi.Element
		-- ---@return fun()
		-- local say_click = function(element)
		-- 	return function()
		-- 		local leader_name = element:GetAttribute("data-leader_name")
		-- 		local message = element:GetAttribute("data-message")

		-- 		Spring.Echo(
		-- 			"say: " .. leader_name .. ": " .. message .. " (by " .. constants.NAME .. ")"
		-- 		)
		-- 		-- sp_send_commands("say: " .. playerName .. ": " .. message)
		-- 	end
		-- end

		-- local buttons = document:GetElementsByClassName("saybutton")
		-- Spring.Echo("Found: ", #buttons)
		-- for _, v in pairs(buttons) do
		-- 	Spring.Echo("Found button")
		-- 	if v:GetAttribute("data-listener") ~= "true" then
		-- 		v:AddEventListener("click", say_click(v), true)
		-- 		v:SetAttribute("data-listener", "true")
		-- 	end
		-- end
	end,

	Marquee = function(n)
		if marqueeMessage or marqueeStartTime or not font2 then
			if logger.level >= LogLevel.TRACE2 then
				logger:Trace2("Marquee message: %s", n.message)
			end

			return
		end

		if logger.level >= LogLevel.TRACE then
			logger:Trace("Marquee message: %s", n.message)
		end

		marqueeMessage = n
		marqueeStartTime = spGetTimer()
	end,

	PlayerHasChanged = function() end,

	-- Forwarded widget callins

	DrawScreen = function(viewSizeX, viewSizeY)
		drawMarqueeMessage()
	end,

	ViewResize = function()
		updateView()
	end,

	KeyPress = function(keyCode, mods, isRepeat, label, utf32char, scanCode, actionList)
		if not document then
			return false
		end

		if keyCode == 0x70 and mods.alt and not mods.ctrl and not mods.shift then -- Alt+'p' key
			if uiConfig.show then
				document:Hide()
				uiConfig.show = false
			else
				document:Show()
				uiConfig.show = true
			end

			-- Save
			if constants.IS_RELEASE then
				config:Save(constants.CONFIG_DIR .. constants.CONFIG_FILE)
			else
				config:Save(
					constants.CONFIG_DIR .. constants.CONFIG_FILE,
					"-- DEBUG (no rules) CONFIG --\n",
					true
				)
			end
		end

		return false
	end,

	KeyRelease = function(keyCode, mods, label, utf32char, scanCode, actionList)
		return false
	end,

	MousePress = function(x, y, button)
		return false
	end,

	MouseRelease = function(x, y, button)
		return false
	end,

	MouseMove = function(x, y, dx, dy, button) end,

	MouseWheel = function(up, value) end,
}
controls.SetUi(ui)

return ui
