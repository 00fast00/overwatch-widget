-- Controls available from RML.

local spSendCommands = Spring.SendCommands

local logger ---@type Logger
-- local rmlContext ---@type RmlUi.Context
local ui ---@type OverwatchUi
local dmHandle

local controls = {}

-- checkHandle is a safety helper to check we have required locals.
--
---@return boolean
local function checkHandle()
	if not ui or not dmHandle then
		logger:Warning("ui controls have no ui set, they won't work")
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

function controls:Reload()
	if not ui then
		logger:Warning("ui controls have no ui set, reload won't work")
		return
	end

	ui.Shutdown()
	ui.Init()
end

function controls:ToggleDebugger()
	if not checkHandle() then
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

---@param mode string
function controls:SetPanelMode(mode)
	if not checkHandle() then
		return
	end

	dmHandle.panelMode = mode
end

---@param event RmlUi.Event
---@param global boolean
function controls:Say(event, global)
	if not checkHandle() then
		return
	end

	local player = event.parameters["player"]
	local message = event.parameters["message"]

	if global then
		spSendCommands(string.format("say %s: %s", player, message))
	else
		spSendCommands(string.format("say a: %s: %s", player, message))
	end
end

function controls:AtEnd(it_index, list)
	return it_index > #list
end

return controls
