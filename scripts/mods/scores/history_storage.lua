local mod = get_mod("scores")
local DMF = get_mod("DMF")

local _io = DMF:persistent_table("_io")
_io.initialized = _io.initialized or false
if not _io.initialized then _io = DMF.deepcopy(Mods.lua.io) end

local _os = DMF:persistent_table("_os")
_os.initialized = _os.initialized or false
if not _os.initialized then _os = DMF.deepcopy(Mods.lua.os) end

local HISTORY_CACHE_VERSION = 3
local HISTORY_FOLDER = "Fatshark/Darktide/scores_history/v1/"

mod.scoreboard_history_io = _io
mod.scoreboard_history_os = _os
mod.checked_history_files = nil
mod.scoreboard_history_cache_version = HISTORY_CACHE_VERSION

mod.scoreboard_history_file_exists = function(self, path)
	local file = _io.open(path, "r")
	if file then
		file:close()
		return true
	end
	return false
end

local function directory_exists(path)
	if not path then
		return false
	end
	local ok, _, code = _os.rename(path.."/", path.."/")
	return ok or code == 13
end

local function quote_path(path)
	return '"'..string.gsub(path or "", '"', '\\"')..'"'
end

local function is_windows_path(path)
	return type(path) == "string" and string.match(path, "^%a:[/\\]")
end

local function shell_path(path)
	if is_windows_path(path) then
		return string.gsub(path, "/", "\\")
	end
	return path
end

local function list_directory_commands(path)
	local path_for_shell = shell_path(path)
	if is_windows_path(path) then
		return {
			'dir '..quote_path(path_for_shell)..' /b',
			'ls -1 '..quote_path(path),
		}
	end

	return {
		'ls -1 '..quote_path(path_for_shell),
		'dir '..quote_path(path_for_shell)..' /b',
	}
end

local function command_succeeded(handle)
	local close_ok, result, _, code = pcall(handle.close, handle)
	if not close_ok then
		return false
	end

	-- Lua versions disagree here: close() may return true, an exit code, or
	-- nil plus an exit code. In all supported forms, zero means success.
	return result == true or result == 0 or code == 0
end

local function execute_succeeded(command)
	local execute_ok, result, _, code = pcall(_os.execute, command)
	if not execute_ok then
		return false
	end

	return result == true or result == 0 or code == 0
end

local function scan_directory(path)
	local popen = _io and _io.popen
	if not popen or not path then
		return nil
	end

	local commands = list_directory_commands(path)

	for i = 1, #commands do
		local ok, handle = pcall(popen, commands[i])
		if ok and handle then
			local files = {}
			local lines_ok = pcall(function()
				for file_name in handle:lines() do
					files[#files+1] = file_name
				end
			end)
			local close_ok = command_succeeded(handle)
			if lines_ok and close_ok then
				return files
			end
		end
	end
end

local function add_history_file(entries, base_path, file_name)
	if type(file_name) ~= "string" or not string.match(file_name, "^%d+%.lua$") then
		return true
	end

	local timestamp = string.sub(file_name, 1, string.len(file_name) - 4)
	local path = base_path..file_name
	if not mod:scoreboard_history_file_exists(path) then
		return false
	end

	local entry = mod:load_scoreboard_history_entry(path, timestamp, true)
	if not entry then
		return true
	end
	entry.file = file_name
	entry.date = _os.date("%Y-%m-%d %H:%M:%S", tonumber(timestamp))
	entries[#entries+1] = entry
	return true
end

local function appdata_root()
	local base_path = _os.getenv("APPDATA")
		or _os.getenv("XDG_DATA_HOME")
		or (_os.getenv("HOME") and _os.getenv("HOME").."/.local/share")

	return base_path
end

mod.appdata_path = function(self, folder)
	local base_path = appdata_root()
	return base_path and base_path.."/"..(folder or HISTORY_FOLDER) or nil
end

mod.create_scoreboard_history_directory = function(self)
	local path = self:appdata_path()
	if not path then
		return false
	end

	if not directory_exists(path) then
		if is_windows_path(path) then
			local current_path = string.match(shell_path(path), "^%a:[/\\]") or ""
			local rest = string.sub(shell_path(path), #current_path + 1)
			for directory_name in string.gmatch(rest, "[^/\\]+") do
				current_path = current_path..directory_name
				if not directory_exists(current_path) then
					local ok = execute_succeeded('mkdir '..quote_path(current_path))
					if not ok and not directory_exists(current_path) then
						return false
					end
				end
				current_path = current_path.."\\"
			end
		else
			local ok = execute_succeeded('mkdir -p '..quote_path(path))
			if not ok and not directory_exists(path) then
				return false
			end
		end
	end

	return directory_exists(path)
end

mod.current_date = function(self)
	return _os.time(_os.date("*t"))
end

mod.create_scoreboard_history_entry_path = function(self)
	local base_path = self:appdata_path()
	if not base_path then
		return nil, nil
	end

	local file_name = tostring(self:current_date())..".lua"
	return base_path..file_name, file_name
end

mod.get_scoreboard_history_entries_cache = function(self)
	if self:get("scoreboard_history_cache_version") ~= HISTORY_CACHE_VERSION then
		self:set("scoreboard_history_entries", {})
		self:set("scoreboard_history_cache_version", HISTORY_CACHE_VERSION)
		return nil
	end
	return self:get("scoreboard_history_entries")
end

mod.set_scoreboard_history_entries_cache = function(self, entries)
	self:set("scoreboard_history_cache_version", HISTORY_CACHE_VERSION)
	self:set("scoreboard_history_entries", entries)
end

local function cached_file_names(self, base_path, cached_files, scan_dir)
	if scan_dir then
		local scanned_files = scan_directory(base_path)
		if scanned_files then
			self:set_scoreboard_history_entries_cache(scanned_files)
			return scanned_files
		else
			-- Shell-backed directory scans may be unavailable under Proton or a
			-- sandboxed Steam installation. Preserve filenames recorded on save
			-- instead of replacing a usable cache with an empty list.
			return cached_files or {}
		end
	end

	return cached_files or {}
end

mod.get_scoreboard_history_entries = function(self, scan_dir)
	local base_path = self:appdata_path()
	if not base_path then
		return {}
	end

	local cached_files = self:get_scoreboard_history_entries_cache()
	local files = cached_file_names(self, base_path, cached_files, scan_dir)

	if scan_dir or not self.checked_history_files or #(cached_files or {}) ~= #(files or {}) then
		local entries = {}
		local stale_cache = false
		local valid_files = {}
		for _, file_name in pairs(files or {}) do
			if add_history_file(entries, base_path, file_name) then
				valid_files[#valid_files+1] = file_name
			else
				stale_cache = true
			end
		end

		if stale_cache then
			-- Remove missing files directly. Retrying a shell scan here can recurse
			-- forever when directory listing is unavailable under Proton.
			self:set_scoreboard_history_entries_cache(valid_files)
		end
		self.checked_history_files = entries
	end

	return self.checked_history_files
end

mod.delete_scoreboard_history_entry = function(self, file_name)
	local base_path = self:appdata_path()
	if not base_path then
		return false
	end

	local file_path = base_path..file_name
	if not self:scoreboard_history_file_exists(file_path) or not _os.remove(file_path) then
		return false
	end

	local cache = self:get_scoreboard_history_entries_cache() or {}
	local updated = {}
	for _, cached_file in pairs(cache) do
		if cached_file ~= file_name then
			updated[#updated+1] = cached_file
		end
	end
	self:set_scoreboard_history_entries_cache(updated)
	self.checked_history_files = nil
	return true
end

return mod
