local mod = get_mod("scores")

local CLASS = CLASS
local Managers = Managers
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = mod:original_require("scripts/settings/ui/ui_workspace_settings")

local ViewSettings = mod:io_dofile("scores/scripts/mods/scores/views/scoreboard/scoreboard_view_settings")
local FrameStyle = mod:io_dofile("scores/scripts/mods/scores/frame_style")

local base_z = 100
local base_x = -1
local scenegraph_ids = {
	-- Darktide's scenegraph field registry rejects sufficiently long IDs.
	root = "scores_tac_screen",
	scoreboard = "scores_tac_board",
	rows = "scores_tac_rows",
}
local hidden_native_widgets = {
	circumstance_info = true,
	expedition_currency = true,
}

mod.tactical_overview = mod:get("tactical_overview")

local function game_mode_name()
	local game_mode = Managers.state and Managers.state.game_mode
	return game_mode and game_mode:game_mode_name()
end

local function scoreboard_allowed_here()
	local mode = game_mode_name()
	return mode ~= "hub" and mode ~= "prologue_hub"
end

local function ensure_tactical_overlay_definition(definitions)
	for _, entry in pairs(definitions) do
		if entry.class_name == "HudElementTacticalOverlay" then
			return
		end
	end

	definitions[#definitions + 1] = {
		package = "packages/ui/hud/tactical_overlay/tactical_overlay",
		use_hud_scale = false,
		class_name = "HudElementTacticalOverlay",
		filename = "scripts/ui/hud/elements/tactical_overlay/hud_element_tactical_overlay",
		visibility_groups = {"tactical_overlay"},
	}
end

local function loaded_scoreboard_rows()
	if not mod.registered_scoreboard_rows or #mod.registered_scoreboard_rows == 0 then
		pcall(mod.collect_scoreboard_rows, mod)
	end

	return mod.registered_scoreboard_rows
end

local function install_scoreboard_scenegraph(definitions)
	local tactical_settings = table.clone(ViewSettings)
	local initial_height = mod.estimated_scoreboard_height and mod:estimated_scoreboard_height(loaded_scoreboard_rows())
	if initial_height then
		tactical_settings.scoreboard_size = {ViewSettings.scoreboard_size[1], initial_height}
	end
	local scenegraph = FrameStyle.scoreboard_scenegraph(UIWorkspaceSettings.screen, tactical_settings, base_z, {base_x, 20, base_z - 1})
	local root = {
		parent = "screen",
		vertical_alignment = "center",
		horizontal_alignment = "center",
		size = table.clone(tactical_settings.scoreboard_size),
		position = {0, 0, 0},
	}
	local scoreboard = scenegraph.scoreboard
	local rows = scenegraph.scoreboard_rows

	-- Keep the tactical scoreboard independent from the native overlay's shared
	-- screen node. Other HUD mods may alter that node or reuse generic IDs.
	-- HUD scenegraphs only retain nodes reachable from their native screen root.
	-- Use scoreboard-sized bounds so HUD editors do not expose this private root
	-- as an invisible full-screen element that blocks interaction with other HUD.
	scoreboard.parent = scenegraph_ids.root
	rows.parent = scenegraph_ids.scoreboard
	definitions.scenegraph_definition[scenegraph_ids.root] = root
	definitions.scenegraph_definition[scenegraph_ids.scoreboard] = scoreboard
	definitions.scenegraph_definition[scenegraph_ids.rows] = rows
	definitions.widget_definitions.scoreboard = FrameStyle.scoreboard_widget_definition(
		UIWidget,
		tactical_settings,
		scenegraph_ids.scoreboard,
		base_x,
		base_z,
		{
			shadow = 200,
			inner_shadow = 100,
			background = 0,
			frame = 200,
		}
	)
end

local function clear_overlay_rows(overlay)
	for i = 1, #(overlay.row_widgets or {}) do
		local widget = overlay.row_widgets[i]
		overlay._widgets_by_name[widget.name] = nil
		overlay:_unregister_widget_name(widget.name)
	end
	overlay.row_widgets = {}
end

local function build_overlay_rows(overlay, ui_renderer)
	local scoreboard_widget = overlay._widgets_by_name.scoreboard
	if not scoreboard_widget then
		return
	end

	mod._widget_timers = {}
	mod._widget_times = {}
	mod._wait_timer = 0
	local _, total_height = mod:setup_row_widgets(
		mod.registered_scoreboard_rows,
		{},
		overlay.row_widgets,
		overlay._widgets_by_name,
		nil,
		false,
		false,
		overlay,
		"_create_widget",
		ui_renderer,
		overlay._ui_scenegraph,
		scenegraph_ids
	)
	mod:adjust_size(total_height, scoreboard_widget, overlay._ui_scenegraph, nil, scenegraph_ids)
end

local function sync_visibility(overlay)
	local visible = mod.tactical_overview and scoreboard_allowed_here()
	if overlay._scores_visible == visible then
		return
	end
	overlay._scores_visible = visible
	local scoreboard_widget = overlay._widgets_by_name.scoreboard
	if scoreboard_widget then
		scoreboard_widget.visible = visible
	end
	for i = 1, #(overlay.row_widgets or {}) do
		overlay.row_widgets[i].visible = visible
	end
end

local function sync_alpha(overlay, ui_renderer)
	local alpha = mod.tactical_overview and overlay._alpha_multiplier or 0
	local scoreboard_widget = overlay._widgets_by_name.scoreboard
	if scoreboard_widget then
		FrameStyle.update_backdrop_opacity(scoreboard_widget)
		scoreboard_widget.alpha_multiplier = alpha
	end
	for i = 1, #(overlay.row_widgets or {}) do
		local widget = overlay.row_widgets[i]
		widget.alpha_multiplier = alpha
		UIWidget.draw(widget, ui_renderer)
		if widget.content and widget.content.player_hotspot_1 then
			mod:handle_player_header_hotspots(widget)
		end
	end
end

local function is_scoreboard_widget(name)
	return name == "scoreboard" or string.sub(name or "", 1, 15) == "scoreboard_row_"
end

local function conflicting_tactical_overlay_widgets(overlay)
	local cached = overlay._scores_conflicting_widgets
	if cached then
		return cached
	end
	cached = {}
	for name in pairs(hidden_native_widgets) do
		local widget = overlay._widgets_by_name and overlay._widgets_by_name[name]
		if widget and not is_scoreboard_widget(name) then
			cached[#cached + 1] = {widget = widget}
		end
	end
	overlay._scores_conflicting_widgets = cached
	return cached
end

local function hide_conflicting_tactical_overlay_widgets(overlay)
	local cached = conflicting_tactical_overlay_widgets(overlay)
	for i = 1, #cached do
		local state = cached[i]
		local widget = state.widget
		state.visible = widget.visible
		state.alpha_multiplier = widget.alpha_multiplier
		widget.visible = false
		widget.alpha_multiplier = 0
	end
	return cached
end

local function restore_native_tactical_overlay_widgets(cached)
	for i = 1, #cached do
		local state = cached[i]
		state.widget.visible = state.visible
		state.widget.alpha_multiplier = state.alpha_multiplier
	end
end

mod:hook_require("scripts/ui/hud/hud_elements_player_onboarding", function(instance)
	if instance then
		ensure_tactical_overlay_definition(instance)
	end
end)
mod:hook_require("scripts/ui/hud/elements/tactical_overlay/hud_element_tactical_overlay_definitions", function(instance)
	if instance then
		install_scoreboard_scenegraph(instance)
	end
end)

mod:hook(CLASS.HudElementTacticalOverlay, "_draw_widgets", function(func, self, dt, t, input_service, ui_renderer, render_settings, ...)
	sync_visibility(self)
	local visible = mod.tactical_overview and (self._alpha_multiplier or 0) > 0.001 and scoreboard_allowed_here()
	local hidden = visible and mod:get("hide_legacy_ui") ~= false and hide_conflicting_tactical_overlay_widgets(self) or nil
	if func then func(self, dt, t, input_service, ui_renderer, render_settings, ...) end
	if visible then
		if hidden then
			restore_native_tactical_overlay_widgets(hidden)
		end
		sync_alpha(self, ui_renderer)
	end
end)

mod:hook_safe(CLASS.HudElementTacticalOverlay, "update", function(self, dt, t, ui_renderer, render_settings, input_service, ...)
	self.row_widgets = self.row_widgets or {}
	local active_changed = self._active ~= mod.hud_active
	if active_changed then
		clear_overlay_rows(self)
		self._scores_visible = nil
	end

	if self._active and not mod.hud_active then
		build_overlay_rows(self, ui_renderer)
	end

	sync_visibility(self)
	mod.hud_active = self._active
end)


