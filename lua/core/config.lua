-- Configuration helper and store.
--
---@class Config
---@field data table
---@field _logger Logger
local Config = {}
Config.__index = Config

---@param logger Logger
---@return Config
function Config.New(logger)
	---@type Config
	local self = setmetatable(
		{ data = {}, _logger = logger:WithSection(logger.section .. "::config") },
		Config
	)

	return self
end

-- Load config file using VFS.Include
--
-- Will return false only if no config has been found and no defaults have been specified.
--
---@param path string Path to the config file
---@param defaultConfig table? Default configuration if no config has been found
---@return boolean success Whether loading was successful
function Config:Load(path, defaultConfig)
	self._logger:Debug("Loading")

	if not VFS.FileExists(path) then
		if defaultConfig then
			self._logger:Info("Config not found, will create on first save")
			self.data = defaultConfig or {}
			return true
		end

		self._logger:Error("No config in '%s' found and no defaults", path)
		return false
	end

	local result = VFS.Include(path)
	if type(result) ~= "table" then
		return false
	end

	self.data = result

	self._logger:Debug("Loaded config successfully")
	return true
end

---@param path string
---@param previous table
---@return table
local function loadOne(path, previous)
	local new = VFS.Include(path)
	if type(new) ~= "table" then
		return {}
	end

	return table.merge(previous, new)
end

-- Load config files using VFS.Include
--
-- Will return false only if no config has been found and no defaults have been specified.
--
---@param dir string Config directory to look for "pattern"
---@param pattern string Pattern of config files to load "last" will be excluded from that list
---@param last string Last config file to load
---@param defaultConfig table? Default configuration if no config has been found
---@return boolean success Whether loading was successful
function Config:LoadMany(dir, pattern, last, defaultConfig)
	local cFiles = VFS.DirList(dir, pattern)

	self._logger:Debug("Loading")

	if #cFiles == 0 then
		if defaultConfig then
			self._logger:Info("Config not found, will create on first save")
			self.data = defaultConfig or {}
			return true
		end

		self._logger:Error(
			"No config in '%s' found with pattern '%s' and no defaults",
			dir,
			pattern
		)
		return false
	end

	local lastPath = ""
	for _, p in ipairs(cFiles) do
		local filename = p:match("([^/]+)$")
		if filename ~= last then
			self._logger:Trace("Loading config %s", p)
			self.data = loadOne(p, self.data)
		else
			lastPath = p
		end
	end

	if #lastPath > 0 then
		self._logger:Trace("Loading last config %s", lastPath)
		self.data = loadOne(lastPath, self.data)
	end

	return true
end

-- Save config file using table.save
---@param path string Path to save the config file
---@param header string? Optional header comment
---@param removeRules boolean? should we remove rules from the output?
---@return boolean success Whether saving was successful
function Config:Save(path, header, removeRules)
	if not self.data then
		self._logger:Debug("Trying to save a nil config to %s", path)
		return false
	end

	if removeRules and self.data["rules"] then
		local data = table.copy(self.data)
		data["rules"] = nil
		table.save(data, path, header)
		return true
	end

	-- Save using table.save.
	table.save(self.data, path, header)

	return true
end

return Config
