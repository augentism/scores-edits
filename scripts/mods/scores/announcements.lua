local mod = get_mod("scores")

local Managers = Managers
local ChatManagerConstants = mod:original_require("scripts/foundation/managers/chat/chat_manager_constants")
local math_floor = math.floor
local string_format = string.format
local table_concat = table.concat
local table_sort = table.sort
local tostring = tostring

local send_retry_delay = 5
local max_send_attempts = 4
local max_no_channel_attempts = 2
-- Brag/top-score chat announcements are intentionally disabled and hidden from
-- options. To re-enable, set this true and restore the announce_top_scores
-- widget in scores_data.lua; the existing setting id and strings remain.
local top_score_announcements_enabled = false

local tracked_rows = {
	{
		row_name = "damage_dealt",
		label = "top_score_announcement_damage",
		direction = "highest",
		require_positive = true,
	},
	{
		row_name = "damage_taken",
		label = "top_score_announcement_damage_taken",
		direction = "lowest",
	},
	{
		row_name = "operated",
		label = "top_score_announcement_objectives",
		direction = "highest",
		require_positive = true,
	},
}

local function row_lookup(sorted_rows)
	local rows = {}
	for _, group in pairs(sorted_rows or {}) do
		for _, row in pairs(group) do
			rows[row.name] = row
		end
	end
	return rows
end

local function rounded_score(score)
	return tostring(math_floor((score or 0) + 0.5))
end

local function better_score(score, best_score, direction)
	if best_score == nil then
		return true
	end
	if direction == "lowest" then
		return score < best_score
	end
	return best_score < score
end

local function same_score(score, best_score)
	return score == best_score
end

local function unique_winner(model, direction)
	local best_account_id
	local best_player
	local best_score
	local winner_count = 0

	for i = 1, math.min(#(model.players or {}), 4) do
		local player = model.players[i]
		local account_id = mod:account_id_from_player(player)
		local row_data = account_id and model.display_data and model.display_data[account_id]
		local score = row_data and row_data.score
		if score ~= nil then
			if better_score(score, best_score, direction) then
				best_account_id = account_id
				best_player = player
				best_score = score
				winner_count = 1
			elseif same_score(score, best_score) then
				winner_count = winner_count + 1
			end
		end
	end

	return best_account_id, best_player, best_score, winner_count == 1
end

local function connected_chat_channels(chat_manager)
	if type(chat_manager.connected_chat_channels) ~= "function" then
		return nil
	end

	local ok, channels = pcall(chat_manager.connected_chat_channels, chat_manager)
	if ok then
		return channels
	end
end

local function tagged_channel_handle(chat_manager, tag)
	for channel_handle, channel in pairs(connected_chat_channels(chat_manager) or {}) do
		if channel.tag == tag then
			return channel_handle
		end
	end
end

local function chat_channel_handle(chat_manager)
	local channel_tags = ChatManagerConstants and ChatManagerConstants.ChannelTag
	local mission_handle = channel_tags and tagged_channel_handle(chat_manager, channel_tags.MISSION)
	if mission_handle then
		return mission_handle
	end

	local party_handle = channel_tags and tagged_channel_handle(chat_manager, channel_tags.PARTY)
	if party_handle then
		return party_handle
	end

	for channel_handle in pairs(connected_chat_channels(chat_manager) or {}) do
		return channel_handle
	end
end

mod.send_top_score_chat_message = function(self, message)
	local chat_manager = Managers and Managers.chat
	if not chat_manager or type(chat_manager.send_channel_message) ~= "function" or not message or message == "" then
		return false, "no_channel"
	end

	local channel_handle = chat_channel_handle(chat_manager)
	if not channel_handle then
		if self:get("dev_mode") then
			self:echo("Scores chat announcement skipped: no connected chat channel.")
		end
		return false, "no_channel"
	end

	local ok, err = pcall(chat_manager.send_channel_message, chat_manager, channel_handle, message)
	if not ok and self:get("dev_mode") then
		self:echo("Scores chat announcement failed: "..tostring(err))
	end
	if ok then
		return true
	end
	return false, "send_failed"
end

mod.clear_top_score_announcements = function(self)
	self.top_score_announcement_sent = nil
	self.top_score_announcement_pending = nil
	self.top_score_announcement_retry_timer = nil
end

mod.top_score_announcement_parts = function(self, sorted_rows, groups, loaded_players)
	local local_account_id = self:me()
	if not local_account_id then
		return {}
	end

	local rows = row_lookup(sorted_rows)
	local parts = {}
	for i = 1, #tracked_rows do
		local tracked = tracked_rows[i]
		local row = rows[tracked.row_name]
		if row then
			local model = self:row_display_model(row, sorted_rows, groups, loaded_players, false, true)
			local winner_account_id, winner_player, score, is_unique = unique_winner(model, tracked.direction)
			if is_unique and winner_account_id == local_account_id and (not tracked.require_positive or score > 0) then
				local player_name = self:safe_player_call(winner_player, "name") or "Player"
				parts[#parts + 1] = string_format(self:localize(tracked.label), player_name, rounded_score(score))
			end
		end
	end

	return parts
end

mod.announce_top_scores = function(self, sorted_rows, groups, loaded_players, is_history, end_view)
	if not end_view
		or is_history
		or self.top_score_announcement_sent
		or self.top_score_announcement_pending
		or not top_score_announcements_enabled
		or not self:get("announce_top_scores") then
		return
	end

	local parts = self:top_score_announcement_parts(sorted_rows, groups, loaded_players)
	if #parts == 0 then
		self.top_score_announcement_sent = true
		return
	end

	local message = self:localize("top_score_announcement_prefix").." "..table_concat(parts, " ")
	self.top_score_announcement_pending = {
		message = message,
		attempts = 0,
	}
	self.top_score_announcement_retry_timer = 0
	self:flush_top_score_announcement()
end

mod.announce_end_view_scoreboard_fallback = function(self)
	if not self.get_rows_in_groups or not self.get_scoreboard_groups then
		return
	end

	local rows = self.registered_scoreboard_rows or {}
	local sorted_rows = self:get_rows_in_groups(rows)
	local groups = self:get_scoreboard_groups(rows)
	self:announce_top_scores(sorted_rows, groups, nil, false, true)
end

mod.flush_top_score_announcement = function(self)
	local pending = self.top_score_announcement_pending
	if not pending or self.top_score_announcement_sent then
		return
	end

	local sent, failure_reason = self:send_top_score_chat_message(pending.message)
	if sent then
		self.top_score_announcement_sent = true
		self.top_score_announcement_pending = nil
		self.top_score_announcement_retry_timer = nil
		return
	end

	pending.attempts = pending.attempts + 1
	local attempt_limit = failure_reason == "no_channel" and max_no_channel_attempts or max_send_attempts
	if pending.attempts >= attempt_limit then
		self.top_score_announcement_sent = true
		self.top_score_announcement_pending = nil
		self.top_score_announcement_retry_timer = nil
	else
		self.top_score_announcement_retry_timer = send_retry_delay
	end
end

mod.update_top_score_announcements = function(self, dt)
	if not self.top_score_announcement_pending or self.top_score_announcement_sent then
		return
	end

	self.top_score_announcement_retry_timer = (self.top_score_announcement_retry_timer or 0) - dt
	if self.top_score_announcement_retry_timer <= 0 then
		self:flush_top_score_announcement()
	end
end

return mod
