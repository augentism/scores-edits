local mod = get_mod("scores")

local TextUtilities = mod:original_require("scripts/utilities/ui/text")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")

local ViewSettings = mod:io_dofile("scores/scripts/mods/scores/views/scoreboard/scoreboard_view_settings")
local Blueprints = mod:io_dofile("scores/scripts/mods/scores/views/scoreboard/scoreboard_view_blueprints")

local base_z = 100
local max_players = ViewSettings.scoreboard_max_players or 4
local compact_section_spacing = 12
local dense_section_spacing = 6
local vanilla_players = 4

local function player_pass_maps()
	local text_by_player = {}
	local icon_by_text = {}
	local account_by_text = {}
	local stripe_by_text = {}
	local pass_index = 2

	for player_index = 1, max_players do
		local icon_index = pass_index
		local text_index = pass_index + 1
		local account_index = pass_index + 2
		text_by_player[player_index] = text_index
		icon_by_text[text_index] = icon_index
		account_by_text[text_index] = account_index
		pass_index = pass_index + 3
		if player_index % 2 == 1 then
			stripe_by_text[text_index] = pass_index
			pass_index = pass_index + 1
		end
	end

	return text_by_player, icon_by_text, account_by_text, stripe_by_text
end

local function row_metrics(row, compact_level)
	local header = row.name == "header" or row.player_header
	local row_height = (row.name == "score" or row.big) and 42
		or row.player_header and 78
		or header and ViewSettings.scoreboard_row_header_height
		or row.section and 38
		or row.score and ViewSettings.scoreboard_row_big_height
		or 25
	local font_size = row.big and 34
		or row.player_header and 25
		or header and 18
		or row.section and 24
		or row.score and 28
		or 18

	if compact_level >= 2 and not header then
		if row.name == "score" or row.big then
			row_height = 30
			font_size = 26
		elseif row.section then
			row_height = 30
			font_size = 20
		elseif row.score then
			row_height = 28
			font_size = 20
		else
			row_height = 17
			font_size = 14
		end
	elseif compact_level >= 1 and not header then
		if row.name == "score" or row.big then
			row_height = 36
			font_size = 30
		elseif row.section then
			row_height = 34
			font_size = 22
		elseif row.score then
			row_height = 32
			font_size = 24
		else
			row_height = 21
			font_size = 16
		end
	end

	return row_height, font_size, header
end

local function section_spacing(compact_level)
	return compact_level >= 2 and dense_section_spacing
		or compact_level >= 1 and compact_section_spacing
		or ViewSettings.scoreboard_section_spacing
end

local function set_cell_style(pass_template, pass_index, font_size, row_height)
	local style = pass_template[pass_index].style
	style.font_size = font_size
	style.size[2] = row_height
end

local function clear_player_cells(pass_template, text_by_player, icon_by_text, account_by_text)
	for i = 1, max_players do
		local text_index = text_by_player[i]
		pass_template[text_index].value = ""
		local icon_index = icon_by_text[text_index]
		if icon_index then
			pass_template[icon_index].style.visible = false
		end
		local account_index = account_by_text[text_index]
		if account_index then
			pass_template[account_index].value = ""
			pass_template[account_index].style.visible = false
		end
	end
end

local function value_color(row_data, zero_setting, worst_setting, score_text)
	local cleaned_score = string.gsub(tostring(score_text), "s", "")
	local numeric = tonumber(cleaned_score)
	if numeric and numeric == 0 and zero_setting > 1 then
		return zero_setting == 3 and Color.ui_grey_light(255, true) or nil, zero_setting == 2
	end
	if row_data and row_data.is_best then
		return nil, false
	elseif row_data and row_data.is_worst and worst_setting == 2 then
		return Color.ui_grey_light(255, true), false
	end
	return nil, false
end

local function player_column_width(player_count)
	if player_count <= vanilla_players then
		return ViewSettings.scoreboard_column_width
	end

	local available_width = ViewSettings.scoreboard_size[1] - ViewSettings.scoreboard_column_header_width

	return math.floor(available_width / player_count)
end

local function pass_by_style_id(pass_template, style_id)
	for i = 1, #pass_template do
		local pass = pass_template[i]
		if pass and pass.style_id == style_id then
			return pass
		end
	end

	return nil
end

local function set_pass_x(pass_template, style_id, x, width)
	local pass = style_id and pass_by_style_id(pass_template, style_id)
	local style = pass and pass.style
	if not style then
		return
	end

	style.offset[1] = x
	style.size[1] = width
end

local function set_pass_index_x(pass_template, pass_index, x, width)
	local pass = pass_index and pass_template[pass_index]
	local style = pass and pass.style
	if not style then
		return
	end

	style.offset[1] = x
	style.size[1] = width
end

local function configure_player_columns(pass_template, text_by_player, icon_by_text, account_by_text, stripe_by_text, player_count, row_height)
	local width = player_column_width(player_count)

	for player_index = 1, max_players do
		local text_index = text_by_player[player_index]
		local icon_index = text_index and icon_by_text[text_index]
		local account_index = text_index and account_by_text[text_index]
		local stripe_index = text_index and stripe_by_text[text_index]
		local x = ViewSettings.scoreboard_column_header_width + width * (player_index - 1)

		set_pass_index_x(pass_template, text_index, x, width)
		set_pass_index_x(pass_template, icon_index, x, row_height)
		set_pass_index_x(pass_template, account_index, x, width)
		set_pass_index_x(pass_template, stripe_index, x, width)
		set_pass_x(pass_template, "player_hotspot_"..player_index, x, width)
		set_pass_x(pass_template, "player_tooltip_background_"..player_index, x + 6, width - 12)
		set_pass_x(pass_template, "player_tooltip_"..player_index, x + 18, width - 36)
	end

	return width
end

local function color_copy(color)
	if type(color) ~= "table" then
		return nil
	end

	return {
		color[1] or 255,
		color[2] or 255,
		color[3] or 255,
		color[4] or 255,
	}
end

local function color_selection_player_color(player)
	if not player then
		return nil
	end

	local ok, color_mod = pcall(function()
		return get_mod("ColorSelection")
	end)
	if not ok or not color_mod or not color_mod.is_enabled or not color_mod:is_enabled() or not color_mod.get_color_for_account_id then
		return nil
	end

	local account_id = mod:safe_player_call(player, "account_id")
	local slot = mod:safe_player_call(player, "slot")
	local color_ok, color = pcall(function()
		return color_mod.get_color_for_account_id(account_id, slot)
	end)

	return color_ok and color_copy(color) or nil
end

local function player_header_display_names(player_name, account_name)
	local mode = mod:get("player_name_display")
	if not account_name or account_name == "" then
		return player_name, nil
	end

	if mode == "character" then
		return player_name, nil
	elseif mode == "account" then
		return account_name, nil
	elseif mode == "both" or mode == "character_first" then
		return player_name, account_name
	end

	return player_name, nil
end

local function widget_z(scenegraph, scenegraph_ids)
	local rows_id = scenegraph_ids and scenegraph_ids.rows or "scoreboard_rows"
	local rows_graph = scenegraph and rawget(scenegraph, rows_id)
	local position = rows_graph and rows_graph.position
	return position and position[3] or base_z + 1
end

local function widget_offset(end_view, row, current_offset, widgets_by_name, scenegraph, scenegraph_ids)
	local z = widget_z(scenegraph, scenegraph_ids)
	if end_view and row.parent then
		local parent = widgets_by_name["scoreboard_row_"..row.parent]
		return {0, parent and parent.offset[2] or current_offset, z}
	end
	return {0, current_offset, z}
end

local function apply_child_columns(pass_template, row, text_by_player, icon_by_text, stripe_by_text, sorted_rows, column_width)
	if not row.parent then
		return
	end

	local children, child_index = mod:get_row_children(row.parent, row.name, sorted_rows)
	if #children <= 1 then
		return
	end

	for _, text_index in pairs(text_by_player) do
		local style = pass_template[text_index].style
		local child_width = column_width / #children
		local offset_x = child_width * (child_index - 1)
		style.offset[1] = style.offset[1] + offset_x
		style.size[1] = child_width

		local stripe_index = stripe_by_text[text_index]
		if stripe_index then
			pass_template[stripe_index].style.visible = false
		end

		local icon_index = icon_by_text[text_index]
		if icon_index and row.icon then
			style.size[1] = child_width / 2
			style.offset[1] = style.offset[1] + child_width / 2
			style.text_horizontal_alignment = "left"
			pass_template[icon_index].style.offset[1] = pass_template[icon_index].style.offset[1] + offset_x + child_width / 2 - pass_template[icon_index].style.size[1]
		end
	end
end

local function paint_row_background(pass_template, stripe_by_text, row_height, section_row_state)
	for _, stripe_index in pairs(stripe_by_text) do
		pass_template[stripe_index].style.visible = false
	end

	local row_background = pass_template[#pass_template].style
	row_background.visible = false

	if mod:get("row_backgrounds") == false then
		return
	end

	if not section_row_state or section_row_state.count <= 3 or section_row_state.index % 2 ~= 0 then
		return
	end

	local band_color = Color.terminal_frame(80, true)
	row_background.visible = true
	row_background.size[2] = row_height
	row_background.color = band_color
	row_background.disabled_color = band_color
	row_background.default_color = band_color
	row_background.hover_color = band_color
end

local function set_player_header_hotspot_target(widget, text_by_player, icon_by_text, account_by_text, player_index, pressed_callback, right_pressed_callback)
	local hotspot = widget and widget.content and widget.content["player_hotspot_"..player_index]
	local hotspot_style = widget and widget.style and widget.style["player_hotspot_"..player_index]
	local text_index = text_by_player[player_index]
	local icon_index = icon_by_text[text_index]
	local account_index = account_by_text[text_index]
	local text_style = widget and widget.style and widget.style["style_id_"..text_index]
	local account_style = widget and widget.style and widget.style["style_id_"..account_index]
	local icon_style = widget and widget.style and (widget.style["style_id_"..icon_index] or widget.style["icon_"..player_index] or widget.style.texture)
	if hotspot and hotspot_style and text_style then
		local target_text_styles = icon_style and {icon_style, text_style} or {text_style}
		if account_style then
			target_text_styles[#target_text_styles + 1] = account_style
		end
		hotspot.enabled = true
		hotspot.target_text_style = nil
		hotspot.target_text_styles = target_text_styles
		hotspot.default_text_colors = nil
		hotspot.pressed_callback = pressed_callback
		hotspot.right_pressed_callback = right_pressed_callback
		local tooltip = pressed_callback
			and TextUtilities.localize_with_button_hint("left_pressed", "loc_scoreboard_view_loadout", nil, nil, Localize("loc_input_legend_text_template"))
			or ""
		if right_pressed_callback then
			local right_tooltip = TextUtilities.localize_with_button_hint("right_pressed", "loc_scoreboard_view_social_profile", nil, nil, Localize("loc_input_legend_text_template"))
			tooltip = tooltip ~= "" and tooltip.."\n"..right_tooltip or right_tooltip
		end
		widget.content["player_tooltip_"..player_index] = tooltip
		hotspot_style.size[2] = widget.style.style_id_1.size[2]
		hotspot_style.visible = true
	end
end

local function player_inspect_profile(player, end_view)
	if player and player.scoreboard_history_profile then
		return mod:safe_player_call(player, "profile") or mod:live_player_profile_by_player(player)
	end

	if end_view then
		return mod:cache_live_player_profile(player)
	end
end

local function attach_player_header_hotspots(widget, widgets_by_name, model, text_by_player, icon_by_text, account_by_text, row, is_history, end_view, obj)
	if not row.player_header then
		return
	end

	for player_index = 1, math.min(#model.players, max_players) do
		local player = model.players[player_index]
		local profile = player_inspect_profile(player, end_view)
		local inspect_profile = profile and profile.loadout and profile
		local pressed_callback = inspect_profile and function()
				mod:inspect_player_profile(inspect_profile)
			end or nil
		local social_player = is_history or end_view
		local right_pressed_callback = social_player and obj and obj.cb_show_history_player_social and function()
			obj:cb_show_history_player_social(player)
		end or nil
		if pressed_callback or right_pressed_callback then
			set_player_header_hotspot_target(widget, text_by_player, icon_by_text, account_by_text, player_index, pressed_callback, right_pressed_callback)
		end
	end
end

mod.create_row_widget = function(self, index, current_offset, visible_rows, source_row, section_row_state, sorted_rows, groups, widgets_by_name, loaded_players, is_history, end_view, obj, create_widget_callback, ui_renderer, compact_level, scenegraph, scenegraph_ids)
	local model = self:row_display_model(source_row, sorted_rows, groups, loaded_players, is_history, end_view)
	local row = model.row
	local row_height, font_size, is_header = row_metrics(row, compact_level)
	local text_by_player, icon_by_text, account_by_text, stripe_by_text = player_pass_maps()
	local template = table.clone(Blueprints.scoreboard_row)
	local pass_template = template.pass_template
	local player_count = math.min(#model.players, max_players)
	local column_width = configure_player_columns(pass_template, text_by_player, icon_by_text, account_by_text, stripe_by_text, math.max(player_count, 1), row_height)

	if row.section and row.name ~= "section_offense" then
		current_offset = current_offset + section_spacing(compact_level)
	end
	if row.parent then
		local parent = widgets_by_name["scoreboard_row_"..row.parent]
		if parent then
			current_offset = parent.offset[2]
			row_height = parent.style.style_id_1.size[2]
		end
	end

	pass_template[1].style.font_size = font_size
	pass_template[1].style.size[2] = row_height
	pass_template[1].value = ""
	for _, text_index in pairs(text_by_player) do
		set_cell_style(pass_template, text_index, font_size, row_height)
		local account_index = account_by_text[text_index]
		if account_index then
			set_cell_style(pass_template, account_index, font_size, row_height)
			pass_template[account_index].style.visible = false
		end
		if row.player_header then
			pass_template[text_index].style.font_size = 22
			pass_template[text_index].style.size[2] = 20
			pass_template[text_index].style.offset[2] = 43
			pass_template[text_index].style.text_vertical_alignment = "center"
			if account_index then
				pass_template[account_index].style.font_size = 14
				pass_template[account_index].style.size[2] = 16
				pass_template[account_index].style.offset[2] = 61
				pass_template[account_index].style.text_vertical_alignment = "center"
				pass_template[account_index].style.text_color = Color.terminal_text_header(170, true)
			end
		end
	end

	if row.icon then
		for _, icon_index in pairs(icon_by_text) do
			pass_template[icon_index].style.size[1] = row.icon_width or pass_template[icon_index].style.size[1]
			pass_template[icon_index].style.size[2] = row_height
		end
	end

	clear_player_cells(pass_template, text_by_player, icon_by_text, account_by_text)

	if row.player_header or row.name == "header" then
		for player_index = 1, player_count do
			local player = model.players[player_index]
			local player_name, class_symbol, account_name = mod:player_display_pair(player)
			local player_color = color_selection_player_color(player)
			local display_name, secondary_name = player_header_display_names(player_name, account_name)
			local value = class_symbol ~= "" and class_symbol.." "..display_name or display_name
			if row.player_header then
				local text_index = text_by_player[player_index]
				local icon_index = icon_by_text[text_index]
				local account_index = account_by_text[text_index]
				pass_template[text_index].value = display_name
				if player_color then
					pass_template[text_index].style.text_color = player_color
				end
				if account_index and secondary_name and secondary_name ~= "" then
					pass_template[account_index].value = secondary_name
					pass_template[account_index].style.visible = true
				end
				if icon_index and class_symbol ~= "" then
					pass_template[icon_index].pass_type = "text"
					pass_template[icon_index].value = class_symbol
					pass_template[icon_index].style.visible = true
					pass_template[icon_index].style.font_size = 38
					pass_template[icon_index].style.size = {column_width, 40}
					pass_template[icon_index].style.offset[2] = 1
					pass_template[icon_index].style.text_horizontal_alignment = "center"
					pass_template[icon_index].style.text_vertical_alignment = "center"
					pass_template[icon_index].style.text_color = player_color or Color.terminal_text_header(255, true)
				end
			else
				pass_template[text_by_player[player_index]].value = value
			end
		end
	elseif row.section then
		pass_template[1].value = model.label
	elseif row.parent then
		pass_template[1].value = ""
	else
		pass_template[1].value = model.label
	end

	if row.icon and not row.parent then
		for _, text_index in pairs(text_by_player) do
			local icon_index = icon_by_text[text_index]
			pass_template[text_index].style.text_horizontal_alignment = "left"
			pass_template[text_index].style.offset[1] = pass_template[text_index].style.offset[1] + pass_template[icon_index].style.size[1]
		end
	end

	if #model.children > 0 then
		clear_player_cells(pass_template, text_by_player, icon_by_text, account_by_text)
	end
	apply_child_columns(pass_template, row, text_by_player, icon_by_text, stripe_by_text, sorted_rows, column_width)

	local zero_setting = mod:get("zero_values")
	local worst_setting = mod:get("worst_values")
	local has_long_cell_text = false
	if not is_header and not row.section and #model.children == 0 then
		for player_index = 1, player_count do
			local player = model.players[player_index]
			local account_id = mod:account_id_from_player(player)
			local row_data = account_id and model.display_data and model.display_data[account_id]
			local score = row_data and row_data.score or 0
			local cell_text = nil
			if row.is_text then
				cell_text = row_data and row_data.text or " "
			elseif row_data and row_data.text_data then
				cell_text = row_data.text_data
				has_long_cell_text = true
			else
				local decimals = row.decimals or 0
				decimals = row.is_time and 1 or decimals
				cell_text = row.is_time and mod:shorten_time(score, decimals) or mod:shorten_value(score, decimals)
				if row.suffix then
					cell_text = cell_text..row.suffix
				end
			end

			if not row.is_text then
				local color, hide = value_color(row_data, zero_setting, worst_setting, cell_text)
				if hide then
					pass_template[text_by_player[player_index]].style.visible = false
				elseif color then
					cell_text = TextUtilities.apply_color_to_text(tostring(cell_text), color)
				elseif row_data and row_data.is_best then
					local text_index = text_by_player[player_index]
					pass_template[text_index].style.font_size = font_size + 1
					cell_text = TextUtilities.apply_color_to_text(tostring(cell_text), Color.ui_orange_light(255, true))
					if mod:is_me(account_id) and not row.parent then
						pass_template[1].value = TextUtilities.apply_color_to_text(tostring(pass_template[1].value), Color.ui_orange_light(255, true))
					end
				end
			end

			local text_index = text_by_player[player_index]
			local icon_index = icon_by_text[text_index]
			pass_template[text_index].value = cell_text
			if row.icon then
				pass_template[icon_index].value = row.icon
				pass_template[icon_index].style.visible = pass_template[text_index].style.visible ~= false
			end
		end
	end

	paint_row_background(pass_template, stripe_by_text, row_height, section_row_state)

	local rows_scenegraph_id = scenegraph_ids and scenegraph_ids.rows or "scoreboard_rows"
	local definition = UIWidget.create_definition(pass_template, rows_scenegraph_id, nil, template.size)
	if not definition then
		return nil
	end

	local widget = obj[create_widget_callback](obj, "scoreboard_row_"..row.name, definition)
	widget.alpha_multiplier = 0
	widget.offset = widget_offset(end_view, row, current_offset, widgets_by_name, scenegraph, scenegraph_ids)
	attach_player_header_hotspots(widget, widgets_by_name, model, text_by_player, icon_by_text, account_by_text, row, is_history, end_view, obj)

	if is_header or row.is_text or has_long_cell_text then
		for player_index = 1, player_count do
			local account_id = mod:account_id_from_player(model.players[player_index])
			local row_data = account_id and model.display_data and model.display_data[account_id]
			local text = pass_template[text_by_player[player_index]].value
			if row.is_text and row_data then
				text = row_data.text or " "
			elseif row_data and row_data.text_data then
				text = row_data.text_data
			end
			if text and ui_renderer then
				mod:shrink_text(text, widget.style["style_id_"..text_by_player[player_index]], column_width, ui_renderer)
			end
			local account_index = account_by_text[text_by_player[player_index]]
			local account_text = account_index and pass_template[account_index].value
			if row.player_header and account_text and account_text ~= "" and ui_renderer then
				mod:shrink_text(account_text, widget.style["style_id_"..account_index], column_width, ui_renderer)
			end
		end
	end

	self._widget_times[widget.name] = current_offset / 1000

	local consumed_height = row_height
	if row.section and row.name ~= "section_offense" then
		consumed_height = consumed_height + section_spacing(compact_level)
	end

	return widget, consumed_height
end

mod.animate_rows = function(self, dt, widgets_by_name)
	self._widget_timers = self._widget_timers or {}
	self._wait_timer = self._wait_timer or 0
	for _, widget in pairs(widgets_by_name) do
		local name = widget.name
		local timer = self._widget_timers[name]
		if not timer and widget.alpha_multiplier == 0 and self._wait_timer >= (self._widget_times[name] or 0) then
			timer = 0
		end
		if timer then
			timer = timer + dt
			local progress = math.min(timer / ViewSettings.scoreboard_fade_length, 1)
			widget.alpha_multiplier = progress
			self._widget_timers[name] = progress < 1 and timer or nil
		end
	end
	self._wait_timer = self._wait_timer + dt
end

local function sync_player_hotspot_visual(hotspot, hotspot_style)
	if not hotspot.enabled then
		hotspot_style.visible = false
		return
	end

	hotspot_style.visible = true
	local target_styles = hotspot.target_text_styles or (hotspot.target_text_style and {hotspot.target_text_style})
	if not target_styles then
		return
	end

	hotspot.default_text_colors = hotspot.default_text_colors or {}
	for i = 1, #target_styles do
		local target_style = target_styles[i]
		local default_color = hotspot.default_text_colors[i] or target_style.text_color
		hotspot.default_text_colors[i] = default_color
		target_style.text_color = hotspot.is_hover and Color.ui_orange_light(255, true) or default_color
	end
end

mod.handle_player_header_hotspots = function(self, widget, input_service)
	local content = widget and widget.content
	if not content then
		return
	end

	for player_index = 1, max_players do
		local hotspot = content["player_hotspot_"..player_index]
		local hotspot_style = widget.style and widget.style["player_hotspot_"..player_index]
		-- History rows are created disabled and enabled after their profile has
		-- been decoded. Their separate render pass does not reliably rerun the
		-- blueprint change function, so keep hover visuals in sync explicitly.
		if hotspot and hotspot_style then
			sync_player_hotspot_visual(hotspot, hotspot_style)
		end
		local hovered = hotspot and hotspot.is_hover
		local right_pressed = hotspot and hotspot.on_right_pressed
		local left_pressed = hotspot and hotspot.on_pressed
		if hovered and input_service then
			right_pressed = right_pressed or input_service:get("right_pressed")
			left_pressed = left_pressed or input_service:get("left_pressed")
		end
		if right_pressed and hotspot.right_pressed_callback then
			hotspot.right_pressed_callback()
		elseif left_pressed and hotspot.pressed_callback then
			hotspot.pressed_callback()
		end
	end
end

return mod
