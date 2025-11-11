local constants = require("core.constants")

local spEcho = Spring.Echo
local spLog = Spring.Log

local LogLevel = constants.LogLevel

local levelNames = {
	[LogLevel.ALL] = "ALL",
	[LogLevel.TRACE3] = "TRACE3",
	[LogLevel.TRACE2] = "TRACE2",
	[LogLevel.TRACE] = "TRACE",
	[LogLevel.DEBUG] = "DEBUG",
	[LogLevel.INFO] = "INFO",
	[LogLevel.NOTICE] = "NOTICE",
	[LogLevel.DEPRECATED] = "DEPRECATED",
	[LogLevel.WARNING] = "WARNING",
	[LogLevel.ERROR] = "ERROR",
	[LogLevel.FATAL] = "FATAL",
	[LogLevel.NONE] = "NONE",
}

---@param level MyLogLevel
---@return string
local function levelName(level)
	-- Direct mapping
	if levelNames[level] then
		return levelNames[level]
	end

	-- Overflow.
	if level <= LogLevel.ALL then
		return "ALL"
	elseif level >= LogLevel.NONE then
		return "NONE"
	end

	-- Inbetween.
	if level > LogLevel.FATAL then
		return "FATAL+" .. (level - LogLevel.FATAL)
	end

	if level < LogLevel.DEBUG then
		return "DEBUG-" .. (LogLevel.DEBUG - level)
	end

	-- Unknown / unexpected value
	return "UNKN(" .. tostring(level) .. ")"
end

-- Logger
--
-- Example:
--
-- ```lua
-- local Logger = require("lib.logger")
-- local logger = Logger("MyWidget", LogLevel.ALL, true)
-- logger.Trace3("Trace me: %s", type(toTrace))
-- ```
--
---@class Logger
---@field section string
---@field level MyLogLevel
---@field useEcho boolean Use Spring.Echo instead of Spring.Log
local Logger = {}
Logger.__index = Logger

---@param section string
---@param level MyLogLevel
---@param useEcho boolean
---@return Logger
function Logger.New(section, level, useEcho)
	---@type Logger
	local self =
		setmetatable({ section = section, level = level, useEcho = useEcho or false }, Logger)

	return self
end

-- Creates a new logger with the given section and same level/useEcho as current.
--
---@param section string
---@return Logger
function Logger:WithSection(section)
	return Logger.New(section, self.level, self.useEcho)
end

-- Log a message auto switches to "Spring.Echo" when you specify a level < INFO as releases are limited to INFO.
--
---@param level MyLogLevel|integer
---@param msg string
function Logger:Log(level, msg, ...)
	-- This is first so developers get a info early.
	if type(msg) ~= "string" then
		spEcho("Error: got an invalid message", msg)
	end

	if not (self.level <= level) then
		return
	end

	if self.useEcho or (self.level < LogLevel.INFO) then
		if select("#", ...) > 0 then
			local status, msg2 = pcall(string.format, msg, ...)
			if status then
				msg = msg2
			else
				msg = msg .. ", failed to format!"
				level = LogLevel.ERROR
			end
		end

		msg = string.format("[%s::%s] ", self.section, levelName(level)) .. msg

		spEcho(msg)
	else
		if select("#", ...) > 0 then
			local status, msg2 = pcall(string.format, msg, ...)
			if status then
				msg = msg2
			else
				msg = msg .. ", failed to format!"
				level = LogLevel.ERROR
			end
		end

		spLog(self.section, level, msg)
	end
end

-- Helpers that wrap the above Log method

---@param msg string
function Logger:Info(msg, ...)
	self:Log(LogLevel.INFO, msg, ...)
end

---@param msg string
function Logger:Warning(msg, ...)
	self:Log(LogLevel.WARNING, msg, ...)
end

---@param msg string
function Logger:Error(msg, ...)
	self:Log(LogLevel.ERROR, msg, ...)
end

---@param msg string
function Logger:Fatal(msg, ...)
	self:Log(LogLevel.FATAL, msg, ...)
end

---@param msg string
function Logger:Debug(msg, ...)
	self:Log(LogLevel.DEBUG, msg, ...)
end

---@param msg string
function Logger:Trace(msg, ...)
	self:Log(LogLevel.TRACE, msg, ...)
end

function Logger:Trace2(msg, ...)
	self:Log(LogLevel.TRACE2, msg, ...)
end

function Logger:Trace3(msg, ...)
	self:Log(LogLevel.TRACE3, msg, ...)
end

---@return Logger
return Logger
