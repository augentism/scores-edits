local mod = get_mod("scores")

local UISettings = mod:original_require("scripts/settings/ui/ui_settings")
local ProfileSnapshot = mod:io_dofile("scores/scripts/mods/scores/profile_snapshot")

mod.pending_history_profile_snapshots = mod.pending_history_profile_snapshots or {}
local max_players = 7

mod.capture_history_profile_snapshot = function(self, player, profile)
	local account_id = self:account_id_from_player(player)
	if not account_id then return false end
	self.pending_history_profile_snapshots = self.pending_history_profile_snapshots or {}
	local key = tostring(account_id)
	if self.pending_history_profile_snapshots[key] then return true end
	local encoded = ProfileSnapshot.encode(profile)
	if not encoded then return false end
	self.pending_history_profile_snapshots[key] = encoded
	return true
end

local function snapshot_profile_for_player(self, player)
	local profile = self:safe_player_call(player, "profile")
	if profile then return profile end

	local account_id = self:account_id_from_player(player)
	local social = Managers.data_service and Managers.data_service.social
	local player_info = nil
	if social and social._get_player_info_for_player then
		local ok, info = pcall(social._get_player_info_for_player, social, player)
		player_info = ok and info or nil
	end
	player_info = player_info or (account_id and social and social:get_player_info_by_account_id(account_id))
	return self:safe_player_call(player_info, "profile")
end

mod.capture_history_profile_snapshots = function(self)
	if not self:history_capture_enabled() then
		return
	end

	local snapshots = self.pending_history_profile_snapshots or {}
	local players = self.player_manager and self.player_manager:players() or {}
	for _, player in pairs(players) do
		local account_id = self:account_id_from_player(player)
		local key = account_id and tostring(account_id)
		-- Once captured, polling only checks the small roster identity. Avoid
		-- repeatedly walking and encoding complete profile/loadout graphs.
		if key and not snapshots[key] then
			local profile = snapshot_profile_for_player(self, player)
			self:capture_history_profile_snapshot(player, profile)
		end
	end
	self.pending_history_profile_snapshots = snapshots
end

mod.clear_history_profile_snapshots = function(self)
	self.pending_history_profile_snapshots = {}
	self._history_profile_capture_timer = 0
end

mod.update_history_profile_snapshots = function(self, dt)
	if not self:history_capture_enabled() then
		self._history_profile_capture_timer = 0
		return
	end

	self._history_profile_capture_timer = (self._history_profile_capture_timer or 0) - (dt or 0)
	if self._history_profile_capture_timer > 0 then return end
	self._history_profile_capture_timer = 5
	self:capture_history_profile_snapshots()
end

local function as_text(value)
	return tostring(value)
end

local function split_record(line, separator)
	local fields = {}
	local start = 1
	separator = separator or ";"
	while true do
		local stop = string.find(line, separator, start, true)
		if not stop then
			fields[#fields+1] = string.sub(line, start)
			break
		end
		fields[#fields+1] = string.sub(line, start, stop - 1)
		start = stop + #separator
	end
	return fields
end

local function optional_field(value)
	if value == nil or value == "nil" then
		return nil
	end
	return value
end

local function optional_bool(value)
	if value == "true" then return true end
	if value == "false" then return false end
	return nil
end

local function write_record(file, fields)
	local field_count = fields.n or #fields
	for i = 1, field_count do
		if i > 1 then file:write(";") end
		file:write(as_text(fields[i]))
	end
	file:write("\n")
end

local function format_duration(seconds)
	seconds = tonumber(seconds)
	if not seconds then
		return ""
	end
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds / 60) % 60)
	seconds = seconds % 60
	return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

local function row_display_text(row)
	local text = row.mod:localize(row.text) or row.text
	return mod:row_setting_label(row, text)
end

local function row_value_count(row)
	local count = 0
	if type(row.data) == "table" then
		for _ in pairs(row.data) do
			count = count + 1
		end
	end
	return count
end

local function row_template(row_name)
	for _, template in pairs(mod.scoreboard_rows or {}) do
		if template.name == row_name then
			return template
		end
	end
end

local function copy_list(values)
	if type(values) ~= "table" then
		return nil
	end

	local copied = {}
	for i = 1, #values do
		copied[i] = values[i]
	end
	return copied
end

local function backfill_row_metadata(row)
	if row and row.name == "player_header" then
		row.player_header = true
	end

	local template = row and row_template(row.name)
	if template then
		row.saved_text = row.text
		row.text = template.text or row.text
		if not row.summary then
			row.summary = copy_list(template.summary)
		end
		if not row.validation then
			row.validation = template.validation or "ASC"
			row.validation_type = row.validation
		end
		if not row.iteration then
			row.iteration = template.iteration or "ADD"
			row.iteration_type = row.iteration
		end
		if row.decimals == nil then
			row.decimals = template.decimals
		end
		if row.suffix == nil then
			row.suffix = template.suffix
		end
	else
		row.validation = row.validation or "ASC"
		row.validation_type = row.validation_type or row.validation
		row.iteration = row.iteration or "ADD"
		row.iteration_type = row.iteration_type or row.iteration
	end
end

mod.save_scoreboard_history_entry = function(self, sorted_rows)
	-- Directory detection via os.rename is not reliable across Windows, Wine,
	-- and native Linux. Try to create it, then let io.open below be the
	-- authoritative check that the history path is writable.
	self:create_scoreboard_history_directory()
	if self.capture_mission_metadata then
		-- Expedition transitions can reach the results view without carrying the
		-- usual StateGameplay parameters. Refresh any missing mission fields from
		-- the mechanism's canonical live data before persisting the entry.
		self:capture_mission_metadata(nil, nil, false)
	end

	local _io = self.scoreboard_history_io
	local _os = self.scoreboard_history_os
	local path, file_name = self:create_scoreboard_history_entry_path()
	if not path then
		return false
	end

	local temporary_path = path..".tmp"
	local file = _io.open(temporary_path, "w+")
	if not file then
		return false
	end
	local players = self.player_manager:players()
	local timer = (_os.time() or 0) - (self.timer or 0)

	local write_ok = pcall(function()
	write_record(file, {
		"#mission",
		self.mission_name,
		self.mission_resistance,
		self.mission_circumstance,
		self.victory_defeat,
		timer,
		self.mission_challenge,
		self.mission_havoc_rank,
		n = 8,
	})

	local player_count = 0
	for _ in pairs(players) do
		player_count = player_count + 1
	end
	write_record(file, {"#players", math.min(player_count, max_players)})

	local player_index = 0
	local profile_snapshots = {}
	for _, player in pairs(players) do
		player_index = player_index + 1
		if player_index <= max_players then
			-- Preserve the same complete profiles used by the working end screen.
			-- They are promoted only after this entry is successfully published and
			-- replace, rather than accumulate with, the previous match's cache.
			if self.cache_live_player_profile then
				self:cache_live_player_profile(player)
			end
			local profile = snapshot_profile_for_player(self, player)
			local archetype_name = profile and profile.archetype and profile.archetype.name
			local symbol = archetype_name and UISettings.archetype_font_icon[archetype_name]
			local player_name = self:safe_player_call(player, "name")
			write_record(file, {player_index, self:account_id_from_player(player), player_name, symbol, self:player_account_name(player, player_name), n = 5})
			local account_id = self:account_id_from_player(player)
			local encoded = ProfileSnapshot.encode(profile)
				or (account_id and self.pending_history_profile_snapshots[tostring(account_id)])
			profile_snapshots[#profile_snapshots+1] = {player_index, encoded}
		end
	end

	-- This marker is deliberately distinct from the legacy player records. Old
	-- releases ignore it after consuming the declared player count, while new
	-- releases can validate the snapshot schema version before decoding it.
	for i = 1, #profile_snapshots do
		local snapshot = profile_snapshots[i]
		local encoded = snapshot[2]
		if encoded then
			write_record(file, {"#profile_v1", snapshot[1], encoded})
		end
	end

	local row_index = 1
	for group_index = 1, #(sorted_rows or {}) do
		for row_position = 1, #sorted_rows[group_index] do
			local row = sorted_rows[group_index][row_position]
			if row.name ~= "header" and not row.score then
				write_record(file, {
					"#row",
					row.name,
					row_index,
					row_value_count(row),
					row_display_text(row),
					row.validation_type,
					row.iteration_type,
					row.visible,
					row.group,
					row.setting,
					row.parent,
					row.is_time,
					row.summary and table.concat(row.summary, ":") or "nil",
					row.normalize,
					row.icon,
					row.icon_package,
					row.icon_width,
					n = 17,
				})
				if type(row.data) == "table" then
					for account_id, data in pairs(row.data) do
						write_record(file, {
							account_id,
							data.score,
							data.is_best and "1" or "0",
							data.is_worst and "1" or "0",
							data.text,
						})
					end
				end
				row_index = row_index + 1
			elseif row.score then
				write_record(file, {"#group", row.text, row.mod:localize(row.text) or row.text})
			end
		end
	end
	end)

	local close_call_ok, close_result = pcall(file.close, file)
	if not write_ok or not close_call_ok or close_result == nil then
		_os.remove(temporary_path)
		return false
	end

	-- Publish only a complete, closed file. A failed rename leaves no partial
	-- history entry for the scanner to consume.
	if not _os.rename(temporary_path, path) then
		_os.remove(temporary_path)
		return false
	end

	local cache = self:get_scoreboard_history_entries_cache()
	if type(cache) ~= "table" then cache = {} end
	cache[#cache+1] = file_name
	self:set_scoreboard_history_entries_cache(cache)
	self.checked_history_files = nil
	if self.promote_live_profiles_to_history then
		self:promote_live_profiles_to_history(file_name)
	end
	self:clear_history_profile_snapshots()
	return true
end

mod.load_scoreboard_history_entry = function(self, path, date, only_head)
	local _io = self.scoreboard_history_io
	local _os = self.scoreboard_history_os
	local file = _io.open(path, "r")
	if not file then
		return nil, {}
	end

	local entry = {
		name = date,
		date = _os.date(nil, tonumber(date)),
	}
	local groups = {}
	local mode = nil
	local remaining = 0
	local active_row = nil

	for line in file:lines() do
		local fields = split_record(line, ";")
		local marker = fields[1]

		if marker == "#mission" then
			entry.mission_name = fields[2]
			entry.mission_resistance = fields[3] or ""
			entry.mission_circumstance = fields[4] or ""
			entry.victory_defeat = fields[5] or ""
			entry.timer = format_duration(fields[6])
			entry.mission_challenge = fields[7] or ""
			entry.mission_havoc_rank = optional_field(fields[8])
			mode = nil

		elseif marker == "#players" then
			entry.players = {}
			mode = "players"
			remaining = tonumber(fields[2]) or 0
			if remaining <= 0 and only_head then break end

		elseif marker == "#profile_v1" and not only_head then
			local player_entry = entry.players and entry.players[fields[2]]
			if player_entry then
				player_entry.profile = ProfileSnapshot.decode(fields[3])
			end
			mode = nil

		elseif mode == "players" and remaining > 0 then
			entry.players = entry.players or {}
			entry.players[fields[1]] = {
				index = fields[1],
				account_id = fields[2],
				name = fields[3],
				string_symbol = fields[4],
				account_name = optional_field(fields[5]),
			}
			remaining = remaining - 1
			if remaining <= 0 then
				mode = nil
				if only_head then break end
			end

		elseif marker == "#group" and not only_head then
			groups[fields[2]] = fields[3]
			mode = nil

		elseif marker == "#row" and not only_head then
			entry.rows = entry.rows or {}
			active_row = {
				name = fields[2],
				text = as_text(fields[5]),
				validation = optional_field(fields[6]),
				validation_type = optional_field(fields[6]),
				iteration = optional_field(fields[7]),
				iteration_type = optional_field(fields[7]),
				visible = optional_bool(fields[8]),
				group = optional_field(fields[9]),
				setting = optional_field(fields[10]),
				parent = optional_field(fields[11]),
				is_time = optional_bool(fields[12]),
				summary = optional_field(fields[13]) and split_record(fields[13], ":") or nil,
				normalize = optional_bool(fields[14]),
				icon = optional_field(fields[15]),
				icon_package = optional_field(fields[16]),
				icon_width = optional_field(fields[17]),
				data = {},
			}
			backfill_row_metadata(active_row)
			entry.rows[#entry.rows+1] = active_row
			mode = "row"
			remaining = tonumber(fields[4]) or 0
			if remaining <= 0 then mode = nil end

		elseif mode == "row" and active_row and remaining > 0 and not only_head then
			active_row.data[fields[1]] = {
				score = tonumber(fields[2]),
				value = tonumber(fields[2]),
				text_data = fields[5],
			}
			remaining = remaining - 1
			if remaining <= 0 then
				active_row = nil
				mode = nil
			end
		end
	end

	file:close()
	return entry, groups
end

return mod
