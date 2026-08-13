local mod = get_mod("scores")

local ScoreboardDefinitions = mod:io_dofile("scores/scripts/mods/scores/ui_definitions")
local ScoreboardViewSettings = mod:io_dofile("scores/scripts/mods/scores/views/scoreboard/scoreboard_view_settings")
local FrameStyle = mod:io_dofile("scores/scripts/mods/scores/frame_style")

local base_z = 100
local compact_row_threshold = 15
local dense_row_threshold = 20
local compact_section_spacing = 12
local dense_section_spacing = 6
local max_players = ScoreboardViewSettings.scoreboard_max_players or 4

local function row_height(row, compact_level)
	local header = row.name == "header" or row.player_header
	local height = (row.name == "score" or row.big) and 42
		or row.player_header and 78
		or header and ScoreboardViewSettings.scoreboard_row_header_height
		or row.section and 38
		or row.score and ScoreboardViewSettings.scoreboard_row_big_height
		or 25

	if compact_level >= 2 and not header then
		if row.name == "score" or row.big then
			height = 30
		elseif row.section then
			height = 30
		elseif row.score then
			height = 28
		else
			height = 17
		end
	elseif compact_level >= 1 and not header then
		if row.name == "score" or row.big then
			height = 36
		elseif row.section then
			height = 34
		elseif row.score then
			height = 32
		else
			height = 21
		end
	end

	return height
end

local function section_spacing(compact_level)
	return compact_level >= 2 and dense_section_spacing
		or compact_level >= 1 and compact_section_spacing
		or ScoreboardViewSettings.scoreboard_section_spacing
end

mod.get_scoreboard_groups = function(self, loaded_rows)
	local groups = {}
	local group_mods = {}
	groups[#groups+1] = "none"
	for _, row in pairs(loaded_rows or {}) do
		if row.group and not table.contains(groups, row.group) then
			groups[#groups+1] = row.group
			group_mods[row.group] = row.mod
		end
	end
	return groups, group_mods
end

mod.get_rows_in_groups = function(self, loaded_rows)
	local sorted = {{}}
	local rows = sorted[1]
	local valid_rows = {}
	local inserted_rows = {}

	for _, row in pairs(loaded_rows or {}) do
		if self:row_setting_valid(row) then
			valid_rows[row.name] = row
		end
	end

	local function add_section(name, text)
		rows[#rows+1] = {
			mod = mod,
			name = name,
			text = text,
			section = true,
			validation = ScoreboardDefinitions.validation_types.ASC,
			validation_type = "ASC",
		}
	end

	local function add_player_header(name)
		rows[#rows+1] = {
			mod = mod,
			name = name,
			text = "",
			player_header = true,
			validation = ScoreboardDefinitions.validation_types.ASC,
			validation_type = "ASC",
		}
	end

	local function add_row(name)
		local row = valid_rows[name]
		if row then
			rows[#rows+1] = row
			inserted_rows[name] = true
		end
	end

	add_player_header("player_header")
	add_section("section_offense", "section_offense")
	add_row("damage_dealt")
	add_row("weakspot_hits")
	add_row("weakspot_hit_percent")
	add_row("accuracy")
	add_row("critical_hits")
	add_row("kills")
	add_row("melee_kills")
	add_row("ranged_kills")
	add_row("lesser_enemies")
	add_row("melee_ranged_threats")
	add_row("special_threats")
	add_row("boss_damage_dealt")

	add_section("section_defense", "section_defense")
	add_row("damage_taken")
	add_row("times_downed")
	add_row("deaths")
	add_row("times_disabled")
	add_row("attacks_blocked")
	add_row("heal_station_used")

	add_section("section_support", "section_support")
	add_row("operated")
	add_row("revived_rescued")
	add_row("team_saves")
	add_row("coherency_efficiency")
	add_row("ammo_collected")
	if self:get("split_resources_collected") then
		add_row("plasteel")
		add_row("diamantine")
	else
		add_row("resources_collected")
	end

	for _, row in pairs(loaded_rows or {}) do
		if valid_rows[row.name] and not inserted_rows[row.name] then
			local hidden_row = {}
			for key, value in pairs(row) do
				hidden_row[key] = value
			end
			hidden_row.visible = false
			rows[#rows+1] = hidden_row
		end
	end

	return sorted
end

local function clone_row_data(data)
	local cloned = {}
	for account_id, values in pairs(data or {}) do
		local cloned_values = {}
		for key, value in pairs(values) do
			cloned_values[key] = value
		end
		cloned[account_id] = cloned_values
	end
	return cloned
end

local function average(data, players)
	local sum = 0
	local num_player = 0
	players = players or {}
	for i = 1, math.min(#players, max_players) do
		local player = players[i]
		if player then
			num_player = num_player + 1
			local account_id = mod:account_id_from_player(player)
			local value = data[account_id] and data[account_id].score or 0
			sum = sum + value
		end
	end
	local num = num_player
	if num == 0 then
		return 0
	end
	return sum / num
end

mod.normalize_values = function(self, players, this_row)
	local target_average = 100
	if this_row.data then
		local data = clone_row_data(this_row.data)
		local av = average(data, players)
		if av ~= 0 then
			local factor = target_average / av
			for _, values in pairs(data) do
				values.score = values.score * factor
			end
		end
		return data
	end
	return this_row.data
end

mod.display_values = function(self, players, this_row)
	if this_row.score or this_row.normalize then
		return self:normalize_values(players, this_row)
	end
	return clone_row_data(this_row.data)
end

mod.get_row_children = function(self, parent, row_name, sorted_rows)
	local children = {}
	local index = 0
	local this_index = 0
	for _, group in pairs(sorted_rows or {}) do
		for _, row in pairs(group) do
			if row.parent and parent == row.parent then
				index = index + 1
				if row.name == row_name then
					this_index = index
				end
				children[#children+1] = row
			end
		end
	end
	return children, this_index
end

local function is_visible_data_row(row)
	return row.visible ~= false
		and not row.parent
		and not row.section
		and not row.player_header
		and row.name ~= "header"
end

local function section_row_counts(sorted_rows)
	local counts = {}
	local current_section = nil

	for g = 1, #sorted_rows, 1 do
		local rows = sorted_rows[g]
		for i = 1, #rows, 1 do
			local row = rows[i]
			if row.visible ~= false and row.section then
				current_section = row.name
				counts[current_section] = counts[current_section] or 0
			elseif current_section and is_visible_data_row(row) then
				counts[current_section] = counts[current_section] + 1
			end
		end
	end

	return counts
end

local function visible_data_row_count(sorted_rows)
	local count = 0

	for g = 1, #sorted_rows, 1 do
		local rows = sorted_rows[g]
		for i = 1, #rows, 1 do
			if is_visible_data_row(rows[i]) then
				count = count + 1
			end
		end
	end

	return count
end

mod.estimated_scoreboard_height = function(self, loaded_rows)
	local sorted_rows = self:get_rows_in_groups(loaded_rows or self.registered_scoreboard_rows)
	local data_row_count = visible_data_row_count(sorted_rows)
	local compact_level = data_row_count > dense_row_threshold and 2
		or data_row_count > compact_row_threshold and 1
		or 0
	local height = ScoreboardViewSettings.scoreboard_table_top_padding

	for g = 1, #sorted_rows, 1 do
		local rows = sorted_rows[g]
		for i = 1, #rows, 1 do
			local row = rows[i]
			if row.visible ~= false and not row.parent then
				local consumed_height = row_height(row, compact_level)
				if row.section and row.name ~= "section_offense" then
					consumed_height = consumed_height + section_spacing(compact_level)
				end
				height = height + consumed_height
			end
		end
	end

	height = height + ScoreboardViewSettings.scoreboard_table_bottom_padding + 55

	return math.min(height, ScoreboardViewSettings.scoreboard_size[2])
end

mod.setup_row_widgets = function(self, loaded_rows, groups, row_widgets, widgets_by_name, loaded_players, is_history, end_view, obj, create_widget_callback, ui_renderer, scenegraph, scenegraph_ids)
	local current_offset = ScoreboardViewSettings.scoreboard_table_top_padding
	local visible_rows = 0
	local sorted_rows = self:get_rows_in_groups(loaded_rows)
	local counts_by_section = section_row_counts(sorted_rows)
	local data_row_count = visible_data_row_count(sorted_rows)
	local compact_level = data_row_count > dense_row_threshold and 2
		or data_row_count > compact_row_threshold and 1
		or 0
	local current_section = nil
	local section_visible_rows = 0
	local index = 1
	for g = 1, #sorted_rows, 1 do
		local rows = sorted_rows[g]
		for i = 1, #rows, 1 do
			local this_row = rows[i]
			if this_row.visible ~= false then
				local name = "scoreboard_row_"..this_row.name
				local section_row_state = nil
				if this_row.section then
					current_section = this_row.name
					section_visible_rows = 0
				elseif is_visible_data_row(this_row) then
					visible_rows = visible_rows + 1
					section_visible_rows = section_visible_rows + 1
					section_row_state = {
						index = section_visible_rows,
						count = counts_by_section[current_section] or 0,
					}
				end
				local widget, row_height = self:create_row_widget(index, current_offset, visible_rows, this_row, section_row_state, sorted_rows, groups, widgets_by_name, loaded_players, is_history, end_view, obj, create_widget_callback, ui_renderer, compact_level, scenegraph, scenegraph_ids)

				if widget then
					row_widgets = row_widgets or {}
					row_widgets[#row_widgets+1] = widget
					widgets_by_name = widgets_by_name or {}
					widgets_by_name[name] = widget
					if not this_row.parent then
						current_offset = current_offset + row_height
					end
				end
			end
			index = index + 1
		end
	end

	return sorted_rows, current_offset
end

mod.adjust_size = function(self, total_height, scoreboard_widget, scenegraph, row_widgets, scenegraph_ids)
	local height = total_height + ScoreboardViewSettings.scoreboard_table_bottom_padding + 55
	height = math.min(height, ScoreboardViewSettings.scoreboard_size[2])
	local style = scoreboard_widget and scoreboard_widget.style or {}
	local sizes = {height - 36, height, height - 3, height - 28}
	for i = 1, #sizes, 1 do
		local pass_style = style["style_id_"..i]
		if pass_style and pass_style.size then
			pass_style.size[2] = sizes[i]
		end
	end
	if style.style_id_5 and style.style_id_5.offset then
		style.style_id_5.offset[2] = -height / 2 + 18
	end
	if style.style_id_6 and style.style_id_6.offset then
		style.style_id_6.offset[2] = height / 2 - 18
	end
	local scoreboard_id = scenegraph_ids and scenegraph_ids.scoreboard or "scoreboard"
	local rows_id = scenegraph_ids and scenegraph_ids.rows or "scoreboard_rows"
	local scoreboard_graph = rawget(scenegraph, scoreboard_id)
	local scoreboard_z = scoreboard_graph and scoreboard_graph.position and scoreboard_graph.position[3] or base_z
	FrameStyle.update_title_offset(style.style_id_7, ScoreboardViewSettings, 0, height, scoreboard_z, 210)
	FrameStyle.update_backdrop_opacity(scoreboard_widget)

	if scoreboard_graph then
		scoreboard_graph.size[2] = height
	end

	local root_id = scenegraph_ids and scenegraph_ids.root
	local root_graph = root_id and rawget(scenegraph, root_id)
	if root_graph then
		root_graph.size[2] = height
	end

	local rows_graph = rawget(scenegraph, rows_id)
	if rows_graph then
		rows_graph.size[2] = math.max(height - 40, 0)
	end
end

return mod


