local mod = get_mod("scores")

local ScoreboardViewSettings = mod:io_dofile("scores/scripts/mods/scores/views/scoreboard/scoreboard_view_settings")

local base_z = 0
local max_players = ScoreboardViewSettings.scoreboard_max_players or 4
local horizontal_padding = ScoreboardViewSettings.scoreboard_horizontal_padding
local row_height = ScoreboardViewSettings.scoreboard_row_height
local column_width = ScoreboardViewSettings.scoreboard_column_width
local header_width = ScoreboardViewSettings.scoreboard_column_header_width
local row_background_padding = horizontal_padding - 25
local player_tooltip_y = 84
local player_tooltip_margin = 6
local player_tooltip_padding_x = 12
local player_tooltip_padding_y = 7
local player_tooltip_height = 60

local function text_style(offset, size, alignment)
	return {
		offset = offset,
		size = size,
		font_size = 16,
		text_horizontal_alignment = alignment,
		text_vertical_alignment = "center",
		text_color = Color.terminal_text_header(255, true),
		color = Color.white(200, true),
		default_color = Color.white(200, true),
		hover_color = Color.white(200, true),
		disabled_color = Color.white(200, true),
		visible = true,
	}
end

local function background_style(offset, size, alpha)
	return {
		horizontal_alignment = "left",
		color = Color.terminal_frame(alpha, true),
		disabled_color = Color.terminal_frame(alpha, true),
		default_color = Color.terminal_frame(alpha, true),
		hover_color = Color.terminal_frame(alpha, true),
		offset = offset,
		size = size,
	}
end

local function player_hotspot_change(content, style)
	if not content.enabled then
		style.visible = false
		return
	end

	style.visible = true
	local target_styles = content.target_text_styles or (content.target_text_style and {content.target_text_style})
	if target_styles then
		content.default_text_colors = content.default_text_colors or {}
		for i = 1, #target_styles do
			local target_style = target_styles[i]
			local default_text_color = content.default_text_colors[i] or target_style.text_color
			content.default_text_colors[i] = default_text_color
			target_style.text_color = content.is_hover
				and Color.ui_orange_light(255, true)
				or default_text_color
		end
	end
end

local function player_tooltip_passes(player_index)
	local x = header_width + column_width * (player_index - 1)
	local function visible(content)
		local hotspot = content["player_hotspot_"..player_index]
		return hotspot and hotspot.enabled and hotspot.is_hover == true or false
	end
	return {
		{
			value_id = "player_tooltip_background_"..player_index,
			style_id = "player_tooltip_background_"..player_index,
			pass_type = "texture",
			value = "content/ui/materials/backgrounds/default_square",
			style = {
				offset = {x + player_tooltip_margin, player_tooltip_y, base_z + 20},
				size = {column_width - player_tooltip_margin * 2, player_tooltip_height},
				color = Color.black(220, true),
				visible = true,
			},
			visibility_function = visible,
		},
		{
			value_id = "player_tooltip_"..player_index,
			style_id = "player_tooltip_"..player_index,
			pass_type = "text",
			value = "",
			style = {
				offset = {x + player_tooltip_margin + player_tooltip_padding_x, player_tooltip_y + player_tooltip_padding_y, base_z + 21},
				size = {column_width - (player_tooltip_margin + player_tooltip_padding_x) * 2, player_tooltip_height - player_tooltip_padding_y * 2},
				font_size = 16,
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_header(255, true),
				visible = true,
			},
			visibility_function = visible,
		},
	}
end

local function player_hotspot_pass(player_index)
	local x = header_width + column_width * (player_index - 1)
	return {
		content_id = "player_hotspot_"..player_index,
		style_id = "player_hotspot_"..player_index,
		pass_type = "hotspot",
		content = {
			use_is_focused = false,
		},
		style = {
			offset = {x, 0, base_z + 5},
			size = {column_width, row_height},
			anim_hover_speed = 8,
			anim_input_speed = 8,
			anim_focus_speed = 8,
			visible = false,
		},
		change_function = player_hotspot_change,
	}
end

local function player_column_passes(player_index)
	local x = header_width + column_width * (player_index - 1)
	local passes = {
		{
			value_id = "icon_"..player_index,
			value = "content/ui/materials/icons/currencies/marks_big",
			style_id = player_index == 1 and "texture" or "icon_"..player_index,
			pass_type = "texture",
			style = {
				offset = {x, 2, base_z + 1},
				size = {row_height, row_height - 4},
				visible = false,
			},
		},
		{
			value_id = "text"..player_index,
			value = "",
			pass_type = "text",
			style = text_style({x, 0, base_z + 1}, {column_width, row_height}, "center"),
			custom = true,
		},
		{
			value_id = "account_text"..player_index,
			value = "",
			pass_type = "text",
			style = text_style({x, 0, base_z + 1}, {column_width, row_height}, "center"),
			custom = true,
		},
	}

	if player_index % 2 == 1 then
		passes[#passes + 1] = {
			value_id = "bg"..player_index,
			value = "",
			pass_type = "texture",
			style = background_style({x, 0, base_z}, {column_width, row_height}, 100),
		}
	end

	return passes
end

local function scoreboard_row_passes()
	local passes = {
		{
			value_id = "text",
			value = "",
			pass_type = "text",
			style = text_style(
				{horizontal_padding, 0, base_z + 1},
				{header_width - horizontal_padding, row_height},
				"left"
			),
			custom = true,
		},
	}

	for player_index = 1, max_players do
		local column_passes = player_column_passes(player_index)
		for i = 1, #column_passes do
			passes[#passes + 1] = column_passes[i]
		end
	end

	for player_index = 1, max_players do
		passes[#passes + 1] = player_hotspot_pass(player_index)
		local tooltip_passes = player_tooltip_passes(player_index)
		for i = 1, #tooltip_passes do
			passes[#passes + 1] = tooltip_passes[i]
		end
	end

	passes[#passes + 1] = {
		value_id = "bg",
		value = "",
		pass_type = "texture",
		style = background_style(
			{row_background_padding, 0, base_z},
			{ScoreboardViewSettings.scoreboard_size[1] - row_background_padding * 2, 0},
			200
		),
	}

	return passes
end

local blueprints = {
	scoreboard_row = {
		size = {
			ScoreboardViewSettings.scoreboard_size[1],
			row_height,
		},
		pass_template = scoreboard_row_passes(),
	},
}

return settings("OptionsViewContentBlueprints", blueprints)


