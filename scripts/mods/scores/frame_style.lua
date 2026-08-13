local mod = get_mod("scores")
local UIFontSettings = mod:original_require("scripts/managers/ui/ui_font_settings")

local FrameStyle = {}

local function rect_pass(offset, size, color)
	return {
		pass_type = "rect",
		style = {
			vertical_alignment = "center",
			horizontal_alignment = "center",
			offset = offset,
			size = size,
			color = color,
			disabled_color = color,
			default_color = color,
			hover_color = color,
			visible = false,
		},
	}
end

local function texture_pass(value, offset, size, color)
	return {
		pass_type = "texture",
		value = value,
		style = {
			vertical_alignment = "center",
			scale_to_material = true,
			horizontal_alignment = "center",
			offset = offset,
			size = size,
			color = color,
			disabled_color = color,
			default_color = color,
			hover_color = color,
		},
	}
end

local function title_pass(value, offset, size)
	local style = table.clone(UIFontSettings.header_1)
	style.horizontal_alignment = "center"
	style.vertical_alignment = "center"
	style.text_horizontal_alignment = "left"
	style.text_vertical_alignment = "center"
	style.offset = offset
	style.size = size

	return {
		pass_type = "text",
		value = value,
		style = style,
	}
end

local function title_offset(settings, base_x, height, base_z, title_z)
	local inset = settings.scoreboard_title_inset
	return {
		base_x - settings.scoreboard_size[1] / 2 + inset[1],
		-height / 2 + inset[2],
		base_z + title_z,
	}
end

FrameStyle.scoreboard_passes = function(settings, base_x, base_z, z_offsets)
	local width = settings.scoreboard_size[1]
	local height = settings.scoreboard_size[2]
	local offsets = z_offsets or {}
	local frame_width = width - 4
	local panel_width = width + 10
	local opaque_width = width - 18
	local frame_vertical_inset = 18
	local opaque_height = height - frame_vertical_inset * 2
	local passes = {
		rect_pass(
			{base_x, 0, base_z + (offsets.opaque_background or -1)},
			{opaque_width, opaque_height},
			Color.black(255, true)
		),
		texture_pass(
			"content/ui/materials/backgrounds/terminal_basic",
			{base_x, 0, base_z + (offsets.background or 0)},
			{panel_width, height},
			Color.terminal_grid_background(255, true)
		),
		texture_pass(
			"content/ui/materials/frames/dropshadow_heavy",
			{base_x, 0, base_z + (offsets.shadow or 2)},
			{panel_width, height - 3},
			Color.black(255, true)
		),
		texture_pass(
			"content/ui/materials/frames/inner_shadow_medium",
			{base_x, 0, base_z + (offsets.inner_shadow or 1)},
			{panel_width - 20, height - 28},
			Color.terminal_grid_background(255, true)
		),
		texture_pass(
			"content/ui/materials/dividers/horizontal_frame_big_upper",
			{base_x, -height / 2 + frame_vertical_inset, base_z + (offsets.frame or 200)},
			{frame_width, 36},
			Color.gray(255, true)
		),
		texture_pass(
			"content/ui/materials/dividers/horizontal_frame_big_lower",
			{base_x, height / 2 - frame_vertical_inset, base_z + (offsets.frame or 200)},
			{frame_width, 36},
			Color.gray(255, true)
		),
		title_pass(
			mod:localize("scoreboard_title"),
			title_offset(settings, base_x, height, base_z, offsets.title or 210),
			settings.scoreboard_title_size
		),
	}

	return passes
end

FrameStyle.update_backdrop_opacity = function(scoreboard_widget)
	local style = scoreboard_widget and scoreboard_widget.style and scoreboard_widget.style.style_id_1
	if style then
		style.visible = mod:get("opaque_scoreboard_backdrop") == true
	end
end

FrameStyle.update_title_offset = function(style, settings, base_x, height, base_z, title_z)
	if style then
		style.offset = title_offset(settings, base_x, height, base_z, title_z)
	end
end

FrameStyle.scoreboard_widget_definition = function(UIWidget, settings, scenegraph_id, base_x, base_z, z_offsets)
	return UIWidget.create_definition(
		FrameStyle.scoreboard_passes(settings, base_x, base_z, z_offsets),
		scenegraph_id
	)
end

FrameStyle.scoreboard_scenegraph = function(screen, settings, base_z, rows_position)
	return {
		screen = screen,
		scoreboard = {
			vertical_alignment = "center",
			parent = "screen",
			horizontal_alignment = "center",
			size = {settings.scoreboard_size[1], settings.scoreboard_size[2]},
			position = {0, 0, base_z},
		},
		scoreboard_rows = {
			vertical_alignment = "top",
			parent = "scoreboard",
			horizontal_alignment = "center",
			size = {settings.scoreboard_size[1], settings.scoreboard_size[2] - 100},
			position = rows_position or {0, 20, base_z + 1},
		},
	}
end

return FrameStyle

