-- Controls available from RML.

local logger ---@type Logger
-- local rmlContext ---@type RmlUi.Context
local ui ---@type OverwatchUi
local dmHandle

local controls = {}

-- checkHandle is a safety helper to check we have required locals.
--
---@param callee string
---@return boolean
local function checkHandle(callee)
	if not ui or not dmHandle then
		logger:Warning("ui controls have no ui set, %s won't work", callee)
		return false
	end

	return true
end

---@param l Logger
---@param rmlCtx RmlUi.Context
function controls.Init(l, rmlCtx)
	logger = l
	-- rmlContext = rmlCtx
end

function controls.SetUi(u)
	ui = u
end

function controls.SetDmHandle(h)
	dmHandle = h
end

function controls.Reload()
	if not ui then
		logger:Warning("ui controls have no ui set, reload won't work")
		return
	end

	ui.Shutdown()
	ui.Init()
end

function controls.ToggleDebugger(_)
	if not checkHandle("ToggleDebugger") then
		return
	end

	dmHandle.debugging = not dmHandle.debugging
	if dmHandle.debugging then
		RmlUi.SetDebugContext("shared")
	else
		---@diagnostic disable-next-line: param-type-mismatch
		RmlUi.SetDebugContext(nil)
	end
end

---@param panel string
function controls.SetPanel(_, panel)
	if not checkHandle("SetPanel") then
		return
	end

	logger:Debug("setting panel to %s", panel)

	dmHandle.panel = panel
end

return controls
