local mod = get_mod("scores")

local UIFontSettings = mod:original_require("scripts/managers/ui/ui_font_settings")
local ScoreboardHistoryViewSettings = mod:io_dofile("scores/scripts/mods/scores/views/history/history_view_settings")

local grid_padding = ScoreboardHistoryViewSettings.grid_padding
local entry_width = ScoreboardHistoryViewSettings.grid_size[1] - grid_padding[1] - grid_padding[3]
local entry_height = 92
local text_width = entry_width - 28

local function text_style(base, y, height, font_size, color)
	local style = table.clone(base)
	style.offset = {14, y, 3}
	style.size = {text_width, height}
	style.font_size = font_size
	style.text_horizontal_alignment = "left"
	style.text_vertical_alignment = "center"
	style.text_color = color
	return style
end

local function focus_alpha(content, style)
	local hotspot = content.hotspot
	local hover = hotspot.anim_hover_progress or 0
	local selected = hotspot.is_selected and 1 or 0
	style.color[1] = math.max(hover, selected) * 90
end

local function entry_text(entry, key)
	local value = entry[key]
	return value and Managers.localization:localize(value) or ""
end

local blueprints = {
	history_entry = {
		size = {entry_width, entry_height},
		pass_template = {
			{
				style_id = "hotspot",
				pass_type = "hotspot",
				content_id = "hotspot",
				content = {
					use_is_focused = true,
				},
				style = {
					anim_hover_speed = 8,
					anim_input_speed = 8,
					anim_select_speed = 8,
					anim_focus_speed = 8,
				},
			},
			{
				pass_type = "rect",
				style_id = "fill",
				style = {
					offset = {0, 0, 1},
					color = Color.terminal_grid_background(0, true),
				},
				change_function = focus_alpha,
			},
			{
				pass_type = "rect",
				style_id = "left_rule",
				style = {
					offset = {0, 0, 2},
					size = {4, entry_height},
					color = Color.ui_orange_light(180, true),
				},
				visibility_function = function(content)
					local hotspot = content.hotspot
					return hotspot.is_selected or hotspot.is_focused
				end,
			},
			{
				pass_type = "text",
				style_id = "title",
				value_id = "title",
				value = "",
				style = text_style(UIFontSettings.body, 7, 20, 18, Color.white(255, true)),
			},
			{
				pass_type = "text",
				style_id = "mission",
				value_id = "mission",
				value = "",
				style = text_style(UIFontSettings.body_small, 29, 18, 16, Color.white(235, true)),
			},
			{
				pass_type = "text",
				style_id = "players",
				value_id = "players",
				value = "",
				style = text_style(UIFontSettings.body_small, 68, 20, 15, Color.white(220, true)),
			},
			{
				pass_type = "text",
				style_id = "details",
				value_id = "details",
				value = "",
				style = text_style(UIFontSettings.body_small, 49, 16, 14, Color.terminal_text_header(210, true)),
			},
		},
		init = function(parent, widget, entry, callback_name)
			widget.content.hotspot.pressed_callback = function()
				callback(parent, callback_name, widget, entry)()
			end
			widget.content.title = entry_text(entry, "display_name")
			widget.content.mission = entry_text(entry, "display_name4")
			widget.content.details = entry_text(entry, "display_name3")
			widget.content.players = entry_text(entry, "display_name2")
			widget.content.entry = entry
			if entry.details_color then
				widget.style.details.text_color = entry.details_color
			end
			mod:shrink_text(widget.content.title, widget.style.title, text_width, parent._ui_renderer)
			mod:shrink_text(widget.content.mission, widget.style.mission, text_width, parent._ui_renderer)
			mod:shrink_text(widget.content.details, widget.style.details, text_width, parent._ui_renderer)
			mod:shrink_text(widget.content.players, widget.style.players, text_width, parent._ui_renderer)
		end,
	},
}

return settings("ScoreboardHistoryViewBlueprints", blueprints)


