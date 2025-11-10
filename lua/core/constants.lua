local IS_RELEASE = false

local NAME = "Overwatch"
local VERSION = "2025-11-08"

---@see https://github.com/beyond-all-reason/RecoilEngine/blob/master/rts/System/Log/Level.h
---@enum MyLogLevel
local LogLevel = {
	ALL = 0,
	TRACE3 = 17, -- extra
	TRACE2 = 18, -- extra
	TRACE = 19, -- extra
	DEBUG = 20,
	INFO = 30,
	NOTICE = 35,
	DEPRECATED = 37,
	WARNING = 40,
	ERROR = 50,
	FATAL = 60,
	NONE = 255,
}

---@diagnostic disable-next-line: duplicate-doc-alias
---@enum NotifyPriority
local NotifyPriority = {
	TRACE = 1,
	DEBUG = 16,
	INFO = 256, -- 2^8
	WARNING = 4096, -- 2^12
	ERROR = 65536, -- 2^16
	CRITICAL = 1048576, -- 2^20
	NONE = 16777216, -- 2^24
}

local NOTIFY_PRIORITY_NAMES = {
	[NotifyPriority.TRACE] = "TRACE",
	[NotifyPriority.DEBUG] = "DEBUG",
	[NotifyPriority.INFO] = "INFO",
	[NotifyPriority.WARNING] = "WARNING",
	[NotifyPriority.ERROR] = "ERROR",
	[NotifyPriority.CRITICAL] = "CRITICAL",
	[NotifyPriority.NONE] = "NONE",
}

---@diagnostic disable-next-line: duplicate-doc-alias
---@enum ResourceType
local ResourceType = {
	METAL = "metal",
	ENERGY = "energy",
} ---@type ResourceType

return {
	CONFIG_DIR = "LuaUI/Config/",
	CONFIG_FILES_PATTERN = "OverwatchConfig*.lua",
	CONFIG_FILE = "OverwatchConfig.lua", -- Will be loaded after the above and we write to it
	IS_RELEASE = IS_RELEASE,
	NAME = NAME,
	VERSION = VERSION,
	LogLevel = LogLevel,
	ResourceType = ResourceType,
	NOTIFY_PRIORITY = NotifyPriority,
	NOTIFY_PRIORITY_NAMES = NOTIFY_PRIORITY_NAMES,
}
