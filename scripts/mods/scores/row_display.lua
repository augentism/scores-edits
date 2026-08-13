local mod = get_mod("scores")

local UISettings = mod:original_require("scripts/settings/ui/ui_settings")
local ViewSettings = mod:io_dofile("scores/scripts/mods/scores/views/scoreboard/scoreboard_view_settings")

local max_players = ViewSettings.scoreboard_max_players or 4

local function copy_data(data)
	local copied = {}
	for account_id, values in pairs(data or {}) do
		copied[account_id] = {
			score = values.score or 0,
			value = values.value or 0,
			text = values.text,
			text_data = values.text_data,
		}
	end
	return copied
end

local function copy_row(row)
	local copied = {}
	for key, value in pairs(row or {}) do
		copied[key] = key == "data" and copy_data(value) or value
	end
	return copied
end

local function row_lookup(sorted_rows)
	local index = {}
	for _, group in pairs(sorted_rows or {}) do
		for _, row in pairs(group) do
			index[row.name] = row
		end
	end
	return index
end

local function ensure_player_slots(row, players)
	row.data = row.data or {}
	for i = 1, math.min(#players, max_players) do
		local account_id = mod:account_id_from_player(players[i])
		if account_id and not row.data[account_id] then
			row.data[account_id] = {score = 0}
		end
	end
end

local function source_rows(row, indexed_rows)
	local rows = {}
	if row.summary then
		for i = 1, #row.summary do
			local source = indexed_rows[row.summary[i]]
			if source then
				rows[#rows + 1] = source
			end
		end
	else
		rows[1] = row
	end
	return rows
end

local function summary_data(row, players, indexed_rows)
	local data = {}
	for i = 1, math.min(#players, max_players) do
		local player = players[i]
		local account_id = mod:account_id_from_player(player)
		local score = 0
		if account_id then
			local rows = source_rows(row, indexed_rows)
			for j = 1, #rows do
				local source = rows[j]
				if source.data then
					local values = row.score and mod:normalize_values(players, source) or source.data
					local row_data = values and values[account_id]
					score = score + (row_data and row_data.score or 0)
				end
			end
			data[account_id] = {score = score}
		end
	end
	return data
end

local function apply_split_damage_text(display_row, players, indexed_rows)
	local actual_row = indexed_rows and indexed_rows["actual_damage_dealt"]
	local overkill_row = indexed_rows and indexed_rows["overkill_damage_dealt"]
	for i = 1, math.min(#players, max_players) do
		local player = players[i]
		local account_id = mod:account_id_from_player(player)
		if account_id and display_row.data and display_row.data[account_id] then
			local actual = 0
			local over = 0
			if actual_row and actual_row.data and actual_row.data[account_id] and actual_row.data[account_id].score then
				actual = actual_row.data[account_id].score
			end
			if overkill_row and overkill_row.data and overkill_row.data[account_id] and overkill_row.data[account_id].score then
				over = overkill_row.data[account_id].score
			end
			display_row.data[account_id].score = (actual or 0) + (over or 0)
			display_row.data[account_id].text_data = (mod:shorten_value(actual, 0) or "0").." / "..(mod:shorten_value(over, 0) or "0")
		end
	end
	display_row.text = "row_damage_dealt_1"
end

local function player_list(players)
	if not players then
		return {}
	end

	local list = {}
	if players[1] ~= nil then
		for i = 1, #players do
			list[#list + 1] = players[i]
		end
		return list
	end

	for _, player in pairs(players) do
		list[#list + 1] = player
	end
	return list
end

local function move_local_player_first(players, local_account_id)
	if not local_account_id then
		return players
	end

	for i = 1, #players do
		if mod:account_id_from_player(players[i]) == local_account_id then
			if i > 1 then
				local player = players[i]
				table.remove(players, i)
				table.insert(players, 1, player)
			end
			break
		end
	end

	return players
end

local function strip_rich_text_tags(text)
	if type(text) ~= "string" then
		return text
	end

	return text:gsub("{#[^}]*}", "")
end

local function is_bot_player(player)
	local is_bot = mod:safe_player_call(player, "is_bot")
	if is_bot ~= nil then
		return is_bot == true
	end

	local bot = mod:safe_player_call(player, "bot")
	return bot == true
end

mod.display_scoreboard_players = function(self, player_manager, loaded_players, static_players)
	local players
	if self.scoreboard_players then
		players = player_list(self:scoreboard_players(player_manager, loaded_players, static_players))
	else
		players = player_list(loaded_players)
	end

	if self:get("me_first") then
		return move_local_player_first(players, self:me())
	end

	return players
end

mod.player_display_pair = function(self, player)
	local player_name = strip_rich_text_tags(self:safe_player_call(player, "name")) or "Player"
	local profile = self:safe_player_call(player, "profile")
	local archetype = profile and profile.archetype and profile.archetype.name
	local symbol = player.string_symbol or (archetype and UISettings.archetype_font_icon[archetype]) or ""
	local account_name = self:player_account_name(player, player_name)
	return player_name, symbol, account_name
end

mod.player_account_name = function(self, player, player_name)
	if is_bot_player(player) then
		return nil
	end

	local account_name = self:safe_player_call(player, "account_name")
		or self:safe_player_call(player, "accountName")
		or self:safe_player_call(player, "account_username")
		or self:safe_player_call(player, "platform_user_name")
		or self:safe_player_call(player, "user_name")
		or self:safe_player_call(player, "username")
	local account_id = self:account_id_from_player(player)
	local social = Managers.data_service and Managers.data_service.social
	local player_info = nil
	if account_id and social and social.get_player_info_by_account_id then
		local ok, info = pcall(social.get_player_info_by_account_id, social, account_id)
		player_info = ok and info or nil
	end
	if not account_name and player_info and player_info.user_display_name then
		local ok, display_name = pcall(player_info.user_display_name, player_info)
		account_name = ok and display_name or nil
	end

	if type(account_name) == "table" then
		account_name = account_name.name or account_name.display_name or account_name.username
	end

	local profile = self:safe_player_call(player, "profile")
	local profile_name = profile and profile.name
	account_name = account_name and strip_rich_text_tags(tostring(account_name)) or nil
	profile_name = profile_name and strip_rich_text_tags(tostring(profile_name)) or nil
	if account_name == "" or account_name == "nil" or account_name == player_name or account_name == profile_name then
		return nil
	end

	return account_name
end

mod.row_label = function(self, row, groups, is_history)
	local localized = row.mod:localize(row.text)
	if localized == "<>" or localized == "<"..tostring(row.text)..">" then
		localized = nil
	end

	if is_history and not row.score then
		if row.section then
			return localized or row.text
		end
		return self:row_setting_label(row, localized or row.text)
	end

	local label = localized or row.text
	if groups and groups[row.text] then
		label = groups[row.text]
	end

	return self:row_setting_label(row, label)
end

mod.row_display_model = function(self, row, sorted_rows, groups, loaded_players, is_history, end_view)
	local players = self:display_scoreboard_players(Managers.player, loaded_players, is_history or end_view)
	local display_row = copy_row(row)
	local indexed_rows = row_lookup(sorted_rows)
	local children = self:get_row_children(row.name, nil, sorted_rows)

	if not row.player_header and row.name ~= "header" and not row.section then
		display_row.data = summary_data(row, players, indexed_rows)
	else
		ensure_player_slots(display_row, players)
	end

	-- Kept for a possible future actual / overkill split display.
	-- apply_split_damage_text(display_row, players, indexed_rows)

	local data = self:display_values(players, display_row)
	local validation = display_row.validation
	if data and validation then
		for account_id, row_data in pairs(data) do
			row_data.is_best = validation.is_best(data, account_id)
			row_data.is_worst = validation.is_worst(data, account_id)
		end
	end

	return {
		row = display_row,
		players = players,
		label = self:row_label(display_row, groups, is_history),
		children = children,
		display_data = data,
	}
end

return mod

