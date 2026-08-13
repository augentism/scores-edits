local mod = get_mod("scores")

local Missions = mod:original_require("scripts/settings/mission/mission_templates")
local Danger = mod:original_require("scripts/utilities/danger")
local ScriptWorld = mod:original_require("scripts/foundation/utilities/script_world")
local UIRenderer = mod:original_require("scripts/managers/ui/ui_renderer")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local UIWidgetGrid = mod:original_require("scripts/ui/widget_logic/ui_widget_grid")
local TextUtilities = mod:original_require("scripts/utilities/ui/text")
local ViewElementInputLegend = mod:original_require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")
local ViewElementPlayerSocialPopup = mod:original_require("scripts/ui/view_elements/view_element_player_social_popup/view_element_player_social_popup")
local SocialMenuRosterView = mod:original_require("scripts/ui/views/social_menu_roster_view/social_menu_roster_view")

local ScoreboardHistoryView = class("ScoreboardHistoryView", "BaseView")

local function short_datetime(value)
	local text = tostring(value or "")
	return string.gsub(text, "^(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d):%d%d$", "%1")
end

local function result_label(entry)
	if entry.victory_defeat == "won" then
		return TextUtilities.apply_color_to_text("WON", Color.ui_green_light(255, true))
	elseif entry.victory_defeat == "lost" then
		return TextUtilities.apply_color_to_text("LOST", Color.ui_red_light(255, true))
	end
	return nil
end

local function mission_name(entry)
	local mission = entry.mission_name and Missions[entry.mission_name]
	return mission and Localize(mission.mission_name) or nil
end

local difficulty_colors = {
	[1] = Color.ui_green_light(210, true),
	[2] = Color.ui_green_light(230, true),
	[3] = Color.terminal_text_header(240, true),
	[4] = Color.ui_orange_light(255, true),
	[5] = Color.ui_red_light(255, true),
	[6] = Color.terminal_text_header(255, true),
}

local function history_difficulty_label(entry)
	local challenge = tonumber(entry.mission_challenge)
	local havoc_rank = tonumber(entry.mission_havoc_rank)
	local resistance = tonumber(entry.mission_resistance)

	if havoc_rank then
		return "Havoc "..havoc_rank
	end

	local danger = challenge and resistance and Danger.danger_by_difficulty(challenge, resistance) or nil
	if danger and danger.display_name then
		return Localize(danger.display_name)
	end

	return nil
end

local function history_difficulty_color(entry)
	local havoc_rank = tonumber(entry.mission_havoc_rank)
	if havoc_rank then
		return Color.ui_red_light(255, true)
	end

	local difficulty = tonumber(entry.mission_resistance) or tonumber(entry.mission_challenge)
	return difficulty_colors[difficulty] or Color.terminal_text_header(210, true)
end

local function mission_label(entry)
	local pieces = {}
	local mission = mission_name(entry)
	local result = result_label(entry)

	if mission then
		pieces[#pieces+1] = mission
	end
	if result then
		pieces[#pieces+1] = result
	end
	if entry.timer and entry.timer ~= "" then
		pieces[#pieces+1] = entry.timer
	end

	return table.concat(pieces, " | ")
end

local function player_names(entry)
	local names = {}
	for _, player in pairs(entry.players or {}) do
		local name = player.name or ""
		if player.string_symbol then
			name = player.string_symbol.." "..name
		end
		names[#names+1] = name
	end
	return table.concat(names, ", ")
end

ScoreboardHistoryView.init = function(self, settings)
	self._definitions = mod:io_dofile("scores/scripts/mods/scores/views/history/history_view_definitions")
	self._blueprints = mod:io_dofile("scores/scripts/mods/scores/views/history/history_view_blueprints")
	self._settings = mod:io_dofile("scores/scripts/mods/scores/views/history/history_view_settings")
	ScoreboardHistoryView.super.init(self, self._definitions, settings)
	self._pass_draw = false
	self.ui_manager = Managers.ui
	self:_create_offscreen_renderer()
end

ScoreboardHistoryView._create_offscreen_renderer = function(self)
	local class_name = self.__class_name
	local world_name = class_name.."_ui_offscreen_world"
	local viewport_name = class_name.."_ui_offscreen_world_viewport"
	self._offscreen_world = Managers.ui:create_world(world_name, 10, "ui", self.view_name)
	self._offscreen_viewport = Managers.ui:create_viewport(self._offscreen_world, viewport_name, "overlay_offscreen", 1, self._settings.shading_environment)
	self._offscreen_viewport_name = viewport_name
	self._ui_offscreen_renderer = Managers.ui:create_renderer(class_name.."_ui_offscreen_renderer", self._offscreen_world)
end

ScoreboardHistoryView.on_enter = function(self)
	ScoreboardHistoryView.super.on_enter(self)
	self._using_cursor_navigation = Managers.ui:using_cursor_navigation()
	self.scoreboard_widget = self._widgets_by_name.scoreboard
	if self.scoreboard_widget then
		self.scoreboard_widget.visible = false
		self.scoreboard_widget.alpha_multiplier = 0
	end
	self.row_widgets = {}
	self:_setup_input_legend()
	self:_rebuild_history_list(false)
end

ScoreboardHistoryView._setup_input_legend = function(self)
	self._input_legend_element = self:_add_element(ViewElementInputLegend, "input_legend", 10)
	for i = 1, #self._definitions.legend_inputs do
		local legend_input = self._definitions.legend_inputs[i]
		local visibility = legend_input.visibility_function
		if legend_input.display_name == "loc_scoreboard_delete" then
			visibility = function()
				return self.entry ~= nil
			end
		end
		self._input_legend_element:add_entry(
			legend_input.display_name,
			legend_input.input_action,
			visibility,
			legend_input.on_pressed_callback and callback(self, legend_input.on_pressed_callback),
			legend_input.alignment
		)
	end
end

ScoreboardHistoryView._entry_widget_data = function(self, entry)
	local label_key = "loc_scoreboard_history_view_entry_"..tostring(entry.date)
	local mission_key = label_key.."_mission"
	local details_key = label_key.."_details"
	local players_key = label_key.."_players"
	mod:add_global_localize_strings({
		[label_key] = {
			en = short_datetime(entry.date or entry.name),
		},
		[mission_key] = {
			en = mission_label(entry),
		},
		[details_key] = {
			en = history_difficulty_label(entry) or "",
		},
		[players_key] = {
			en = player_names(entry),
		},
	})
	return {
		widget_type = "history_entry",
		display_name = label_key,
		display_name4 = mission_key,
		display_name3 = details_key,
		details_color = history_difficulty_color(entry),
		display_name2 = players_key,
		file = entry.file,
	}
end

ScoreboardHistoryView._rebuild_history_list = function(self, scan_dir)
	self:_clear_history_widgets()

	local content = {}
	local entries = mod:get_scoreboard_history_entries(scan_dir)
	for i = #entries, 1, -1 do
		content[#content+1] = self:_entry_widget_data(entries[i])
	end

	self._category_content_widgets, self._category_alignment_list = self:_create_history_widgets(content)
	self._category_content_grid = UIWidgetGrid:new(
		self._category_content_widgets,
		self._category_alignment_list,
		self._ui_scenegraph,
		"grid_start",
		"down",
		self._settings.grid_spacing,
		nil,
		true
	)
	self._category_content_grid:set_render_scale(self._render_scale)
	self._category_content_grid:assign_scrollbar(self._widgets_by_name.scrollbar, "grid_content_pivot", "grid_start")
	self._category_content_grid:set_scrollbar_progress(0)
end

ScoreboardHistoryView._clear_history_widgets = function(self)
	for _, widget in pairs(self._category_content_widgets or {}) do
		self:_unregister_widget_name(widget.name)
	end
	self._category_content_widgets = {}
	self._category_alignment_list = {}
end

ScoreboardHistoryView._create_history_widgets = function(self, entries)
	local widgets = {}
	local alignment = {}
	local definitions = {}
	for i = 1, #entries do
		local entry = entries[i]
		local template = self._blueprints[entry.widget_type]
		if template then
			definitions[entry.widget_type] = definitions[entry.widget_type]
				or UIWidget.create_definition(template.pass_template, "grid_content_pivot", nil, template.size)
			local widget = self:_create_widget("history_entry_"..i, definitions[entry.widget_type])
			widget.file = entry.file
			if template.init then
				template.init(self, widget, entry, "cb_on_category_pressed")
			end
			widgets[#widgets+1] = widget
			alignment[#alignment+1] = widget
		end
	end
	return widgets, alignment
end

ScoreboardHistoryView._clear_preview_widgets = function(self)
	for _, widget in ipairs(self.row_widgets or {}) do
		self._widgets_by_name[widget.name] = nil
		self:_unregister_widget_name(widget.name)
	end
	self.row_widgets = {}
	self.sorted_rows = nil
	self.loaded_rows = nil
	self.loaded_players = nil
	self.groups = nil
	self._preview_file_path = nil
	-- The decoded profile snapshots live under entry.players. Views may be
	-- retained after closing, so explicitly drop the entry instead of relying
	-- on the view object itself being collected.
	self.entry = nil

	if self.scoreboard_widget then
		self.scoreboard_widget.visible = false
		self.scoreboard_widget.alpha_multiplier = 0
	end
end

ScoreboardHistoryView._preview_players = function(self, entry, file_name)
	local players = {}
	for player_index = 1, 4 do
		local player_data = entry.players and entry.players[tostring(player_index)]
		if player_data then
			local account_id = player_data.account_id
			local decoded_profile = player_data.profile
			local latest_profile = mod:latest_history_profile(file_name, account_id, player_data.account_name, player_data.name)
			local profile = decoded_profile and decoded_profile.loadout and decoded_profile
				or latest_profile
				or decoded_profile
			local player = {
				account_id = function() return player_data.account_id end,
				name = function() return player_data.name end,
				account_name = function() return player_data.account_name end,
				string_symbol = player_data.string_symbol,
			}

			if profile and profile.loadout then
				player.scoreboard_history_profile = true
				player.profile = function() return profile end
			end
			players[#players+1] = player
		end
	end
	return players
end

ScoreboardHistoryView._open_entry_preview = function(self, widget)
	if not widget or not widget.file then
		return
	end

	local base_path = mod:appdata_path()
	if not base_path then
		return
	end

	local file_path = base_path..widget.file
	if self._preview_file_path == file_path then
		return
	end

	self:_clear_preview_widgets()
	self.entry, self.groups = mod:load_scoreboard_history_entry(file_path, widget.file, false)
	self._preview_file_path = file_path
	self._logged_history_hover = nil

	self.loaded_players = self:_preview_players(self.entry, widget.file)
	self.loaded_rows = mod:collect_scoreboard_rows(self.entry.rows)
	self.row_widgets = {}
	self.scoreboard_widget = self._widgets_by_name.scoreboard

	if not self.scoreboard_widget then
		return
	end

	self.scoreboard_widget.visible = true
	self.scoreboard_widget.alpha_multiplier = 1

	mod._widget_timers = {}
	mod._widget_times = {}
	mod._wait_timer = 0

	local total_height = 0
	self.sorted_rows, total_height = mod:setup_row_widgets(
		self.loaded_rows,
		self.groups or {},
		self.row_widgets,
		self._widgets_by_name,
		self.loaded_players,
		true,
		false,
		self,
		"_create_widget",
		self._ui_renderer,
		self._ui_scenegraph
	)
	mod:adjust_size(total_height, self.scoreboard_widget, self._ui_scenegraph, self.row_widgets)

	for _, row_widget in ipairs(self.row_widgets or {}) do
		row_widget.alpha_multiplier = 1
	end
end

ScoreboardHistoryView._update_history_selection = function(self)
	for _, widget in pairs(self._category_content_widgets or {}) do
		local hotspot = widget.content.hotspot
		if hotspot and hotspot.is_focused and self._selected_history_widget ~= widget then
			self._selected_history_widget = widget
			hotspot.is_selected = true
			self:_open_entry_preview(widget)
		elseif hotspot and widget ~= self._selected_history_widget then
			hotspot.is_selected = false
		end
	end
end

ScoreboardHistoryView.cb_on_category_pressed = function(self, widget)
	self._selected_history_widget = widget
	self:_open_entry_preview(widget)
end

ScoreboardHistoryView.cb_on_back_pressed = function(self)
	if self._loadout_suspended then
		return
	end

	if self._popup_menu then
		self:_close_popup_menu()
		return
	end
	self.ui_manager:close_view("scores_history_view")
end

ScoreboardHistoryView.cb_show_history_player_social = function(self, player)
	if self._popup_menu then return end
	local player_info = mod:history_social_player_info(player)
	if not player_info then return end
	if self.scoreboard_widget then
		self.scoreboard_widget.visible = false
	end
	self._history_social_player = player
	local popup = self:_add_element(ViewElementPlayerSocialPopup, "player_social_popup", 300)
	self._popup_menu = popup
	popup:set_player_info(self, player_info)
	popup:on_navigation_input_changed(self._using_cursor_navigation)
	popup:set_close_popup_request_callback(callback(self, "cb_close_popup_menu"))
end

ScoreboardHistoryView._close_popup_menu = function(self)
	if self._popup_menu and not self._popup_closing then
		self._popup_closing = true
		self._popup_menu:close(callback(self, "cb_on_popup_menu_closed"))
	end
end

ScoreboardHistoryView._remove_popup_menu = function(self)
	self._popup_menu = nil
	self._popup_closing = nil
	self._history_social_player = nil
	self:_remove_element("player_social_popup")
	if self.scoreboard_widget and self.entry then
		self.scoreboard_widget.visible = true
	end
end

ScoreboardHistoryView.set_loadout_suspended = function(self, suspended)
	self._loadout_suspended = suspended == true

	if self._input_legend_element and self._input_legend_element.set_visibility then
		self._input_legend_element:set_visibility(not self._loadout_suspended)
	end
end

ScoreboardHistoryView._fade_widgets = function() end
ScoreboardHistoryView._refresh_party_list = function() end
ScoreboardHistoryView.formatted_character_name = function(self, player_info)
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
	ScoreboardHistoryView[name] = SocialMenuRosterView[name]
end
ScoreboardHistoryView._show_confirmation_popup = SocialMenuRosterView._show_confirmation_popup

ScoreboardHistoryView.cb_show_player_profile = function(self)
	local player = self._history_social_player
	local profile = player and (mod:safe_player_call(player, "profile") or mod:live_player_profile_by_player(player))
	self:_close_popup_menu()
	if profile and profile.loadout then
		mod:inspect_player_profile(profile)
	end
end

-- Inspect From Social injects this callback into SocialMenuRosterView
-- instances, but the history view only borrows that view's popup callbacks.
-- Provide the extension's exact callback contract here as well.
ScoreboardHistoryView.cb_inspect_operative = function(self, player_info)
	local player = self._history_social_player
	local profile = player and (mod:safe_player_call(player, "profile") or mod:live_player_profile_by_player(player))
		or mod:safe_player_call(player_info, "profile")
	self:_close_popup_menu()
	if profile and profile.loadout then
		mod:inspect_player_profile(profile)
	end
end

ScoreboardHistoryView.cb_delete_pressed = function(self)
	if self.entry and mod:delete_scoreboard_history_entry(self.entry.name) then
		self:_clear_preview_widgets()
		self.entry = nil
		self._selected_history_widget = nil
		self:_rebuild_history_list(false)
	end
end

ScoreboardHistoryView.cb_reload_cache_pressed = function(self)
	self:_clear_preview_widgets()
	self.entry = nil
	self._selected_history_widget = nil
	self:_rebuild_history_list(true)
end

ScoreboardHistoryView.update = function(self, dt, t, input_service, view_data)
	if self._loadout_suspended then
		return ScoreboardHistoryView.super.update(self, dt, t, input_service)
	end

	self._using_cursor_navigation = Managers.ui:using_cursor_navigation()
	if self._popup_menu and input_service and input_service:get("back") then
		self:_close_popup_menu()
	end
	if self._category_content_grid then
		self._category_content_grid:update(dt, t, input_service)
	end
	self:_update_history_selection()
	return ScoreboardHistoryView.super.update(self, dt, t, input_service)
end

ScoreboardHistoryView.draw = function(self, dt, t, input_service, layer)
	if self._loadout_suspended then
		return
	end

	local interaction = self._widgets_by_name.grid_interaction
	local widgets = self._category_content_widgets or {}
	if not self._popup_menu and self._category_content_grid and interaction then
		self:_draw_grid(self._category_content_grid, widgets, interaction, dt, t, input_service)
	end
	ScoreboardHistoryView.super.draw(self, dt, t, input_service, layer)
	if not self._popup_menu then
		self:_draw_preview_rows(dt, input_service)
	end
end

ScoreboardHistoryView._draw_elements = function(self, dt, t, ui_renderer, render_settings, input_service)
	ScoreboardHistoryView.super._draw_elements(self, dt, t, ui_renderer, render_settings, input_service)
end

ScoreboardHistoryView._draw_grid = function(self, grid, widgets, interaction_widget, dt, t, input_service)
	local renderer = self._ui_offscreen_renderer
	UIRenderer.begin_pass(renderer, self._ui_scenegraph, input_service, dt, self._render_settings)
	for i = 1, #widgets do
		local widget = widgets[i]
		if grid:is_widget_visible(widget) then
			local hotspot = widget.content.hotspot
			if hotspot then
				hotspot.force_disabled = false
			end
			UIWidget.draw(widget, renderer)
		end
	end
	UIRenderer.end_pass(renderer)
end

ScoreboardHistoryView._draw_preview_rows = function(self, dt, input_service)
	if not self.row_widgets or #self.row_widgets == 0 then
		return
	end

	local renderer = self._ui_renderer
	UIRenderer.begin_pass(renderer, self._ui_scenegraph, input_service, dt, self._render_settings)
	for _, widget in ipairs(self.row_widgets or {}) do
		UIWidget.draw(widget, renderer)
		mod:handle_player_header_hotspots(widget, input_service)
	end
	UIRenderer.end_pass(renderer)
end

ScoreboardHistoryView.on_exit = function(self)
	if self._popup_menu then
		self:_remove_popup_menu()
	end
	if self._input_legend_element then
		self._input_legend_element = nil
		self:_remove_element("input_legend")
	end

	self:_clear_preview_widgets()
	self:_clear_history_widgets()

	if self._ui_offscreen_renderer then
		Managers.ui:destroy_renderer(self.__class_name.."_ui_offscreen_renderer")
		ScriptWorld.destroy_viewport(self._offscreen_world, self._offscreen_viewport_name)
		Managers.ui:destroy_world(self._offscreen_world)
		self._ui_offscreen_renderer = nil
		self._offscreen_viewport = nil
		self._offscreen_viewport_name = nil
		self._offscreen_world = nil
	end

	ScoreboardHistoryView.super.on_exit(self)
end

return ScoreboardHistoryView


