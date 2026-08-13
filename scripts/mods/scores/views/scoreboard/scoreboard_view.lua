local mod = get_mod("scores")

local UIRenderer = mod:original_require("scripts/managers/ui/ui_renderer")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local ViewElementInputLegend = mod:original_require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")
local ViewElementPlayerSocialPopup = mod:original_require("scripts/ui/view_elements/view_element_player_social_popup/view_element_player_social_popup")
local SocialMenuRosterView = mod:original_require("scripts/ui/views/social_menu_roster_view/social_menu_roster_view")

local ViewSettings = mod:io_dofile("scores/scripts/mods/scores/views/scoreboard/scoreboard_view_settings")
local FrameStyle = mod:io_dofile("scores/scripts/mods/scores/frame_style")

local ScoreboardView = class("ScoreboardView", "BaseView")

local base_z = 100
local default_vertical_offset = -100
local max_player_hotspots = ViewSettings.scoreboard_max_players or 4

local function setting_number(setting_id, fallback)
	local value = mod:get(setting_id)
	return type(value) == "number" and value or fallback
end

local function view_setting_number(settings, setting_id, fallback)
	local value = settings and settings[setting_id]
	return type(value) == "number" and value or fallback
end

local function history_save_mode()
	if mod.migrate_history_save_mode then
		mod:migrate_history_save_mode()
	end

	return tonumber(mod:get("history_save_mode")) or 2
end

local function should_auto_save_history()
	local mode = history_save_mode()
	if mode == 1 then
		return false
	end

	if mod.capture_mission_metadata then
		mod:capture_mission_metadata(nil, nil, false)
	end

	return mode == 2 or (mode == 3 and mod.mission_havoc_rank ~= nil)
end

local function is_scoreboard_widget(name)
	return name == "scoreboard" or string.sub(name or "", 1, 15) == "scoreboard_row_"
end

local function set_widget_visible(widget, visible)
	if not widget then
		return
	end

	widget.alpha_multiplier = visible and 1 or 0
	widget.visible = visible
end

local function set_player_hotspots_enabled(widget, enabled)
	local content = widget and widget.content
	if not content then
		return
	end

	for player_index = 1, max_player_hotspots do
		local hotspot = content["player_hotspot_"..player_index]
		if hotspot then
			if enabled then
				if hotspot._scores_enabled_before_hide ~= nil then
					hotspot.enabled = hotspot._scores_enabled_before_hide
					hotspot._scores_enabled_before_hide = nil
				end
			else
				if hotspot._scores_enabled_before_hide == nil then
					hotspot._scores_enabled_before_hide = hotspot.enabled
				end
				hotspot.enabled = false
				hotspot.is_hover = false
			end
		end
	end
end

ScoreboardView.init = function(self, settings, context)
	self._player_manager = Managers.player
	self._definitions = mod:io_dofile("scores/scripts/mods/scores/views/scoreboard/scoreboard_view_definitions")
	self._settings = ViewSettings
	self.end_view = context and context.end_view
	self.is_history = context and context.scoreboard_history or false
	self.groups = context and context.groups or {}
	self.loaded_players = context and context.players or nil
	self.loaded_rows = context and context.rows and mod:collect_scoreboard_rows(context.rows) or mod.registered_scoreboard_rows
	ScoreboardView.super.init(self, self._definitions, settings)
	self._pass_draw = true
	self._pass_input = true
	mod._widget_timers = {}
	mod._widget_times = {}
	mod._wait_timer = 0
end

ScoreboardView.on_enter = function(self)
	self._definitions = mod:io_dofile("scores/scripts/mods/scores/views/scoreboard/scoreboard_view_definitions")
	mod._wait_timer = 0
	ScoreboardView.super.on_enter(self)
	self._using_cursor_navigation = Managers.ui:using_cursor_navigation()

	self.scoreboard_widget = self._widgets_by_name.scoreboard
	self.scoreboard_widget.alpha_multiplier = 0
	local base_vertical_offset = view_setting_number(self._settings, "scoreboard_end_view_top_offset", default_vertical_offset)
	self._ui_scenegraph.scoreboard.position[2] = base_vertical_offset + setting_number("end_scoreboard_vertical_offset", 0)
	self.scoreboard_widget.offset = {0, 0, base_z}
	mod._widget_times.scoreboard = 0

	self.row_widgets = {}
	self:setup_row_widgets()
	mod:announce_top_scores(self.sorted_rows or {}, self.groups, self.loaded_players, self.is_history, self.end_view)
	if not self.is_history then
		self:_setup_input_legend()
	end

	if self.end_view and should_auto_save_history() then
		mod:save_scoreboard_history_entry(self.sorted_rows or {})
	end

	if self.end_view and mod.end_scoreboard_visible == false then
		self:set_end_scoreboard_visible(false)
	end
end

ScoreboardView._setup_input_legend = function(self)
	self._input_legend_element = self:_add_element(ViewElementInputLegend, "input_legend", 10)
	for _, legend_input in ipairs(self._definitions.legend_inputs) do
		local visibility_function = legend_input.visibility_function
		self._input_legend_element:add_entry(
			legend_input.display_name,
			legend_input.input_action,
			function()
				if self.end_view and self._end_scoreboard_visible == false then
					return false
				end

				return visibility_function and visibility_function() or true
			end,
			legend_input.on_pressed_callback and callback(self, legend_input.on_pressed_callback),
			legend_input.alignment
		)
	end
end

ScoreboardView.delete_row_widgets = function(self)
	for _, widget in ipairs(self.row_widgets or {}) do
		self._widgets_by_name[widget.name] = nil
		self:_unregister_widget_name(widget.name)
	end
	self.row_widgets = {}
end

ScoreboardView.get_scoreboard_groups = function(self)
	return mod:get_scoreboard_groups(self.loaded_rows)
end

ScoreboardView.get_rows_in_groups = function(self)
	return mod:get_rows_in_groups(self.loaded_rows)
end

ScoreboardView.create_row_widget = function(self, index, current_offset, visible_rows, row, section_row_state, sorted_rows, groups, widgets_by_name, loaded_players, is_history, end_view, obj, create_widget_callback, ui_renderer, compact_level, scenegraph)
	return mod:create_row_widget(index, current_offset, visible_rows, row, section_row_state, self.sorted_rows, self.groups, self._widgets_by_name, self.loaded_players, self.is_history, self.end_view, self, "_create_widget", self._ui_renderer, compact_level, scenegraph)
end

ScoreboardView.setup_row_widgets = function(self)
	self:delete_row_widgets()
	local total_height = 0
	self.sorted_rows, total_height = mod:setup_row_widgets(self.loaded_rows, self.groups, self.row_widgets, self._widgets_by_name, self.loaded_players, self.is_history, self.end_view, self, "_create_widget", self._ui_renderer, self._ui_scenegraph)
	mod:adjust_size(total_height, self.scoreboard_widget, self._ui_scenegraph, self.row_widgets)
end

ScoreboardView.remove_input_legend = function(self)
	if self._input_legend_element then
		self._input_legend_element = nil
		self:_remove_element("input_legend")
	end
end

ScoreboardView.set_end_scoreboard_visible = function(self, visible)
	if not self.end_view then
		return
	end

	visible = visible ~= false
	self._end_scoreboard_visible = visible
	mod._widget_timers = {}

	for name, widget in pairs(self._widgets_by_name or {}) do
		if is_scoreboard_widget(name) then
			set_widget_visible(widget, visible)
			set_player_hotspots_enabled(widget, visible)
		end
	end

	for _, widget in ipairs(self.row_widgets or {}) do
		set_widget_visible(widget, visible)
		set_player_hotspots_enabled(widget, visible)
	end

	self._input_legend_hidden_by_end_scoreboard = visible == false
end

ScoreboardView.on_exit = function(self)
	if self._popup_menu then
		self:_remove_popup_menu()
	end
	self:remove_input_legend()
	ScoreboardView.super.on_exit(self)
end

ScoreboardView.cb_on_save_pressed = function(self)
	self:remove_input_legend()
	mod:save_scoreboard_history_entry(self.sorted_rows or {})
end

ScoreboardView.update_scoreboard_offset = function(self, offset_x)
	offset_x = offset_x or 0
	for _, widget in pairs(self._widgets_by_name) do
		for _, style in pairs(widget.style or {}) do
			local base_offset = style.original_offset
			if not base_offset then
				base_offset = table.clone(style.offset or {0, 0, 0})
				style.original_offset = base_offset
			end
			style.offset = {base_offset[1] + offset_x, base_offset[2], base_offset[3]}
		end
	end
end

ScoreboardView.update_scoreboard = function(self, dt)
	local move = self.scoreboard_move
	if not move then
		return
	end

	move.elapsed = math.min(move.elapsed + dt, move.duration)
	local progress = move.elapsed / move.duration
	local eased = 1 - math.ease_sine(1 - progress)
	self:update_scoreboard_offset(math.lerp(move.from, move.to, eased))

	if progress >= 1 then
		self.scoreboard_move = nil
		if move.callback then
			move.callback()
		end
	end
end

ScoreboardView.move_scoreboard = function(self, from_offset_x, to_offset_x, callback)
	self.scoreboard_move = {
		elapsed = 0,
		duration = 0.75,
		from = from_offset_x,
		to = to_offset_x,
		callback = callback,
	}
end

ScoreboardView.update = function(self, dt, t, input_service, view_data)
	if self._popup_menu and input_service and input_service:get("back") then
		self:_close_popup_menu()
	end
	self:update_scoreboard(dt)
	return ScoreboardView.super.update(self, dt, t, input_service)
end

ScoreboardView.animate_rows = function(self, dt)
	if self.end_view and self._end_scoreboard_visible == false then
		return
	end

	mod:animate_rows(dt, self._widgets_by_name)
end

ScoreboardView.draw = function(self, dt, t, input_service, layer)
	self:_draw_elements(dt, t, self._ui_renderer, self._render_settings, input_service)
	self:_draw_widgets(dt, input_service)
end

ScoreboardView._draw_elements = function(self, dt, t, ui_renderer, render_settings, input_service)
	ScoreboardView.super._draw_elements(self, dt, t, ui_renderer, render_settings, input_service)
end

ScoreboardView._draw_widgets = function(self, dt, input_service)
	if self._popup_menu then
		return
	end
	if self.end_view and self._end_scoreboard_visible == false then
		return
	end
	local renderer = self._ui_renderer
	FrameStyle.update_backdrop_opacity(self.scoreboard_widget)
	UIRenderer.begin_pass(renderer, self._ui_scenegraph, input_service, dt, self._render_settings)
	self:animate_rows(dt)
	for _, widget in pairs(self._widgets_by_name) do
		UIWidget.draw(widget, renderer)
		mod:handle_player_header_hotspots(widget)
	end
	UIRenderer.end_pass(renderer)
end

ScoreboardView.cb_show_history_player_social = function(self, player)
	if self._popup_menu then return end
	local player_info = mod:history_social_player_info(player)
	if not player_info then return end
	self._history_social_player = player
	self.scoreboard_widget.visible = false
	local popup = self:_add_element(ViewElementPlayerSocialPopup, "player_social_popup", 300)
	self._popup_menu = popup
	popup:set_player_info(self, player_info)
	popup:on_navigation_input_changed(self._using_cursor_navigation)
	popup:set_close_popup_request_callback(callback(self, "cb_close_popup_menu"))
end

ScoreboardView._close_popup_menu = function(self)
	if self._popup_menu and not self._popup_closing then
		self._popup_closing = true
		self._popup_menu:close(callback(self, "cb_on_popup_menu_closed"))
	end
end

ScoreboardView._remove_popup_menu = function(self)
	self._popup_menu = nil
	self._popup_closing = nil
	self._history_social_player = nil
	self:_remove_element("player_social_popup")
	if self.scoreboard_widget then self.scoreboard_widget.visible = true end
end

ScoreboardView._fade_widgets = function() end
ScoreboardView._refresh_party_list = function() end
ScoreboardView.formatted_character_name = function(self, player_info)
	return player_info and player_info:user_display_name() or ""
end

local social_callbacks = {
	"cb_close_popup_menu", "cb_on_popup_menu_closed", "cb_leave_party",
	"cb_vote_to_kick_player_from_party", "cb_invite_player_to_party",
	"cb_cancel_party_invite", "cb_join_players_party",
	"cb_show_xbox_profile", "cb_show_psn_profile", "cb_invite_player_to_guild",
	"cb_send_friend_request", "cb_cancel_friend_request", "cb_accept_friend_request",
	"cb_reject_friend_request", "cb_unfriend_player", "cb_mute_text_chat",
	"cb_mute_voice_chat", "cb_unblock_player", "cb_block_player",
	"cb_report_player", "cb_show_rename_popup",
}
for i = 1, #social_callbacks do
	local name = social_callbacks[i]
	ScoreboardView[name] = SocialMenuRosterView[name]
end
ScoreboardView._show_confirmation_popup = SocialMenuRosterView._show_confirmation_popup

ScoreboardView.cb_show_player_profile = function(self)
	local player = self._history_social_player
	local profile = player and mod:cache_live_player_profile(player)
	self:_close_popup_menu()
	if profile and profile.loadout then mod:inspect_player_profile(profile) end
end

ScoreboardView.cb_inspect_operative = function(self, player_info)
	local player = self._history_social_player
	local profile = player and mod:cache_live_player_profile(player)
		or mod:safe_player_call(player_info, "profile")
	self:_close_popup_menu()
	if profile and profile.loadout then mod:inspect_player_profile(profile) end
end

return ScoreboardView


