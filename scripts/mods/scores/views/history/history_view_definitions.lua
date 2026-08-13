local mod = get_mod("scores")

local UISoundEvents = mod:original_require("scripts/settings/ui/ui_sound_events")
local ScrollbarPassTemplates = mod:original_require("scripts/ui/pass_templates/scrollbar_pass_templates")
local UIWorkspaceSettings = mod:original_require("scripts/settings/ui/ui_workspace_settings")
local UIFontSettings = mod:original_require("scripts/managers/ui/ui_font_settings")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")

local ViewSettings = mod:io_dofile("scores/scripts/mods/scores/views/history/history_view_settings")
local ScoreboardViewSettings = mod:io_dofile("scores/scripts/mods/scores/views/scoreboard/scoreboard_view_settings")
local FrameStyle = mod:io_dofile("scores/scripts/mods/scores/frame_style")

local grid_width = ViewSettings.grid_size[1]
local grid_height = ViewSettings.grid_size[2]
local grid_padding = ViewSettings.grid_padding
local content_width = grid_width - grid_padding[1] - grid_padding[3]
local content_height = grid_height - grid_padding[2] - grid_padding[4]
local blur = ViewSettings.grid_blur_edge_size
local scrollbar_width = ViewSettings.scrollbar_width
local base_z = 100
local preview_gap = 48
local scoreboard_scenegraph = FrameStyle.scoreboard_scenegraph(UIWorkspaceSettings.screen, ScoreboardViewSettings, base_z)
scoreboard_scenegraph.scoreboard.vertical_alignment = "top"
scoreboard_scenegraph.scoreboard.horizontal_alignment = "left"
scoreboard_scenegraph.scoreboard.parent = "history_content_area"
scoreboard_scenegraph.scoreboard.position = {grid_width + preview_gap, 0, base_z}

local scenegraph_definition = {
	screen = UIWorkspaceSettings.screen,
	history_content_area = {
		vertical_alignment = "top",
		horizontal_alignment = "left",
		parent = "screen",
		size = {grid_width + preview_gap + ScoreboardViewSettings.scoreboard_size[1], grid_height},
		position = {160, 198, 1},
	},
	title_text = {
		vertical_alignment = "top",
		horizontal_alignment = "left",
		parent = "screen",
		size = {520, 60},
		position = {160, 128, 2},
	},
	background = {
		vertical_alignment = "top",
		horizontal_alignment = "left",
		parent = "history_content_area",
		size = {grid_width, grid_height},
		position = {0, 0, 1},
	},
	grid_start = {
		vertical_alignment = "top",
		horizontal_alignment = "left",
		parent = "background",
		size = {content_width, content_height},
		position = {grid_padding[1], grid_padding[2], 0},
	},
	grid_content_pivot = {
		vertical_alignment = "top",
		horizontal_alignment = "left",
		parent = "grid_start",
		size = {0, 0},
		position = {0, 0, 1},
	},
	grid_mask = {
		vertical_alignment = "center",
		horizontal_alignment = "center",
		parent = "grid_start",
		size = {content_width + blur[1] * 2, content_height + blur[2] * 2},
		position = {0, 0, 0},
	},
	grid_interaction = {
		vertical_alignment = "top",
		horizontal_alignment = "left",
		parent = "grid_start",
		size = {content_width + scrollbar_width * 2, content_height + blur[2] * 2},
		position = {0, 0, 0},
	},
	scrollbar = {
		vertical_alignment = "center",
		horizontal_alignment = "right",
		parent = "grid_start",
		size = {scrollbar_width, content_height},
		position = {scrollbar_width + 6, 0, 1},
	},
	scoreboard = scoreboard_scenegraph.scoreboard,
	scoreboard_rows = scoreboard_scenegraph.scoreboard_rows,
}

local title_style = table.clone(UIFontSettings.header_1)
title_style.text_horizontal_alignment = "left"
title_style.text_vertical_alignment = "center"

local widget_definitions = {
	background = UIWidget.create_definition({
		{
			pass_type = "rect",
			style = {
				color = {170, 0, 0, 0},
			},
		},
	}, "screen"),
	list_background = UIWidget.create_definition({
		{
			pass_type = "rect",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "center",
				offset = {0, 0, -2},
				size = {grid_width - 18, grid_height - 36},
				color = Color.black(230, true),
			},
		},
		{
			pass_type = "texture",
			value = "content/ui/materials/backgrounds/terminal_basic",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "center",
				scale_to_material = true,
				offset = {0, 0, -1},
				size = {grid_width + 10, grid_height},
				color = Color.terminal_grid_background(255, true),
			},
		},
		{
			pass_type = "texture",
			value = "content/ui/materials/frames/dropshadow_heavy",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "center",
				scale_to_material = true,
				offset = {0, 0, 1},
				size = {grid_width + 10, grid_height - 3},
				color = Color.black(255, true),
			},
		},
		{
			pass_type = "texture",
			value = "content/ui/materials/frames/inner_shadow_medium",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "center",
				scale_to_material = true,
				offset = {0, 0, 0},
				size = {grid_width - 10, grid_height - 28},
				color = Color.terminal_grid_background(255, true),
			},
		},
		{
			pass_type = "texture",
			value = "content/ui/materials/dividers/horizontal_frame_big_upper",
			style = {
				vertical_alignment = "top",
				horizontal_alignment = "center",
				scale_to_material = true,
				offset = {0, 2, 2},
				size = {grid_width - 4, 36},
				color = Color.gray(255, true),
			},
		},
		{
			pass_type = "texture",
			value = "content/ui/materials/dividers/horizontal_frame_big_lower",
			style = {
				vertical_alignment = "bottom",
				horizontal_alignment = "center",
				scale_to_material = true,
				offset = {0, -2, 2},
				size = {grid_width - 4, 36},
				color = Color.gray(255, true),
			},
		},
	}, "background"),
	title_text = UIWidget.create_definition({
		{
			pass_type = "text",
			value_id = "text",
			style_id = "text",
			value = mod:localize("mod_history_view_title"),
			style = title_style,
		},
	}, "title_text"),
	grid_mask = UIWidget.create_definition({
		{
			pass_type = "texture",
			value = "content/ui/materials/offscreen_masks/ui_overlay_offscreen_vertical_blur",
			style = {
				color = {255, 255, 255, 255},
			},
		},
	}, "grid_mask"),
	grid_interaction = UIWidget.create_definition({
		{
			pass_type = "hotspot",
			content_id = "hotspot",
		},
	}, "grid_interaction"),
	scrollbar = UIWidget.create_definition(ScrollbarPassTemplates.default_scrollbar, "scrollbar"),
	scoreboard = FrameStyle.scoreboard_widget_definition(UIWidget, ScoreboardViewSettings, "scoreboard", 0, base_z),
}

local legend_inputs = {
	{
		input_action = "back",
		on_pressed_callback = "cb_on_back_pressed",
		display_name = "loc_settings_menu_close_menu",
		alignment = "left_alignment",
	},
	{
		input_action = "hotkey_item_sort",
		on_pressed_callback = "cb_reload_cache_pressed",
		display_name = "loc_scoreboard_scan",
		alignment = "left_alignment",
	},
	{
		input_action = "hotkey_character_delete",
		on_pressed_callback = "cb_delete_pressed",
		display_name = "loc_scoreboard_delete",
		alignment = "right_alignment",
		on_hover_sound = UISoundEvents.social_menu_block_player,
	},
}

return settings("ScoreboardHistoryViewDefinitions", {
	legend_inputs = legend_inputs,
	widget_definitions = widget_definitions,
	scenegraph_definition = scenegraph_definition,
})


