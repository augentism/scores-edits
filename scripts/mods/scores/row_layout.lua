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

-- Frame furniture above and below the rows (title bar, dividers). Carried over
-- verbatim from the single-column layout it replaces.
local frame_chrome_height = 55

-- Multi-column geometry. A "block" is one label column plus its player columns.
-- Two blocks plus the gap come to 1600, comfortably inside the 1920-wide nominal
-- UI workspace; the label and player cells shrink so that fits.
local multi_column_gap = 40
local multi_column_header_width = 220
local multi_column_block_width = 780

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

	local function add_hidden(row)
		-- Kept in the list purely so `row_lookup` / `summary_data` can still resolve
		-- it as a summary source (row_display.lua).
		local hidden_row = {}
		for key, value in pairs(row) do
			hidden_row[key] = value
		end
		hidden_row.visible = false
		rows[#rows+1] = hidden_row
	end

	-- Rows this mod owns are placed by the hand-authored `add_row` block above;
	-- anything of ours left over is a summary source and stays hidden. Plugin rows
	-- have no place in that block, so they are appended in registration order --
	-- which is the order the plugin declared them, the only thing its positional
	-- layout (section, then `blank_*` spacer, then next section) depends on.
	-- `ipairs`, not `pairs`: plugin layout is positional, and `pairs` gives no
	-- ordering guarantee. Both callers pass a plain array (the live registry, or a
	-- history entry's rows).
	local last_plugin = nil
	for _, row in ipairs(loaded_rows or {}) do
		if valid_rows[row.name] and not inserted_rows[row.name] then
			if self:is_own_scoreboard_row(row.name) or row.visible == false then
				add_hidden(row)
			else
				local plugin = row.mod
				if plugin ~= last_plugin then
					last_plugin = plugin
					add_section("section_plugin_"..tostring(plugin and plugin.name), self:plugin_section_label(plugin))
				end
				rows[#rows+1] = row
				inserted_rows[row.name] = true
			end
		end
	end

	return sorted
end

-- Names this mod declares itself. Read from the definitions table rather than the
-- live registry, because the registry also holds plugin rows -- and because rows
-- rebuilt from a saved history entry all come back owned by this mod, so
-- `row.mod` cannot tell our rows from a plugin's after a round trip.
mod.own_scoreboard_row_names = function(self)
	if not self._own_scoreboard_row_names then
		local names = {}
		for _, template in pairs(self.scoreboard_rows or {}) do
			if template.name then
				names[template.name] = true
			end
		end
		self._own_scoreboard_row_names = names
	end

	return self._own_scoreboard_row_names
end

mod.is_own_scoreboard_row = function(self, name)
	return name ~= nil and self:own_scoreboard_row_names()[name] == true
end

mod.plugin_section_label = function(self, plugin)
	if plugin and plugin ~= self and plugin.localize then
		local ok, localized = pcall(plugin.localize, plugin, "mod_name")
		if ok and localized and localized ~= "<>" and localized ~= "<mod_name>" then
			return localized
		end

		return tostring(plugin.name)
	end

	-- History entries lose the owning mod, so plugin rows read back as ours.
	return self:localize("section_plugin_rows")
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
	-- `ipairs`: the returned index picks which horizontal sub-column this child
	-- occupies, so declaration order has to be preserved. `pairs` gives no such
	-- guarantee and would shuffle the sub-columns between sessions.
	for _, group in ipairs(sorted_rows or {}) do
		for _, row in ipairs(group) do
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

-- Height a row adds to its column: its own height plus the gap that precedes a
-- section header. The first section sits flush under the player header.
local function consumed_row_height(row, compact_level)
	local consumed = row_height(row, compact_level)
	if row.section and row.name ~= "section_offense" then
		consumed = consumed + section_spacing(compact_level)
	end

	return consumed
end

mod.consumed_row_height = consumed_row_height

local function content_height(sorted_rows, compact_level)
	local height = 0

	for g = 1, #sorted_rows, 1 do
		local rows = sorted_rows[g]
		for i = 1, #rows, 1 do
			local row = rows[i]
			-- Child rows share their parent's line and never advance the offset.
			if row.visible ~= false and not row.parent then
				height = height + consumed_row_height(row, compact_level)
			end
		end
	end

	return height
end

mod.scoreboard_max_height = function(self)
	local ceiling = ScoreboardViewSettings.scoreboard_size[2]
	local configured = tonumber(self:get("scoreboard_max_height"))

	return math.min(configured or ceiling, ceiling)
end

-- Everything about how the board is shaped for the current row set, resolved once
-- per build. Plugin row sets (Ovenproof contributes ~46 more top-level rows) blow
-- past what one column can show even at maximum compaction, so the rows flow into
-- side-by-side columns instead of running off the bottom of the screen -- the panel
-- has no mask or scrollbar, so overflow is not clipped, it is just lost.
mod.scoreboard_layout = function(self, loaded_rows, sorted_rows, force_single_column)
	sorted_rows = sorted_rows or self:get_rows_in_groups(loaded_rows or self.registered_scoreboard_rows)

	local data_row_count = visible_data_row_count(sorted_rows)
	local compact_level = data_row_count > dense_row_threshold and 2
		or data_row_count > compact_row_threshold and 1
		or 0

	local total = content_height(sorted_rows, compact_level)
	local chrome = ScoreboardViewSettings.scoreboard_table_top_padding
		+ ScoreboardViewSettings.scoreboard_table_bottom_padding
		+ frame_chrome_height
	local budget = math.max(self:scoreboard_max_height() - chrome, 1)

	local columns = tonumber(self:get("scoreboard_columns")) or 0
	if columns ~= 1 and columns ~= 2 then
		columns = total > budget and 2 or 1
	end

	if force_single_column then
		-- The history preview shares its panel geometry with a scrollable run list
		-- beside it, so widening it would overlap that grid. Kept single-column
		-- until that view gets a layout of its own.
		columns = 1
	end

	local multi = columns > 1

	return {
		columns = columns,
		compact_level = compact_level,
		content_height = total,
		chrome_height = chrome,
		column_budget = budget,
		-- Even split rather than fill-then-spill: a first column running to the
		-- screen edge beside a nearly empty second one reads as a bug.
		column_target = math.ceil(total / columns),
		header_width = multi and multi_column_header_width or ScoreboardViewSettings.scoreboard_column_header_width,
		block_width = multi and multi_column_block_width or ScoreboardViewSettings.scoreboard_size[1],
		column_gap = multi and multi_column_gap or 0,
		sorted_rows = sorted_rows,
	}
end

mod.scoreboard_layout_panel_width = function(self, layout)
	return layout.block_width * layout.columns + layout.column_gap * (layout.columns - 1)
end

-- Horizontal offset for a row widget in column `column_index`. Columns are laid
-- out symmetrically about the (centred) rows node, so one column stays at 0 and
-- the single-column board is pixel-identical to before.
mod.scoreboard_column_offset = function(self, layout, column_index)
	local stride = layout.block_width + layout.column_gap

	return (column_index - 1) * stride - (layout.columns - 1) * stride / 2
end

-- A settings clone describing the panel this row set needs, for the frame/scenegraph
-- builders in frame_style.lua. They read `scoreboard_size` and nothing else.
mod.scoreboard_layout_settings = function(self, loaded_rows)
	local ok, layout = pcall(self.scoreboard_layout, self, loaded_rows)
	if not ok or not layout then
		return ScoreboardViewSettings
	end

	local settings_clone = table.clone(ScoreboardViewSettings)
	settings_clone.scoreboard_size = {
		self:scoreboard_layout_panel_width(layout),
		self:estimated_scoreboard_height(nil, layout),
	}

	return settings_clone
end

mod.estimated_scoreboard_height = function(self, loaded_rows, layout)
	layout = layout or self:scoreboard_layout(loaded_rows)

	local tallest = math.min(layout.column_target, layout.column_budget)
	local height = ScoreboardViewSettings.scoreboard_table_top_padding
		+ tallest
		+ ScoreboardViewSettings.scoreboard_table_bottom_padding
		+ frame_chrome_height

	return math.min(height, self:scoreboard_max_height())
end

mod.setup_row_widgets = function(self, loaded_rows, groups, row_widgets, widgets_by_name, loaded_players, is_history, end_view, obj, create_widget_callback, ui_renderer, scenegraph, scenegraph_ids)
	local sorted_rows = self:get_rows_in_groups(loaded_rows)
	local layout = self:scoreboard_layout(nil, sorted_rows, is_history)
	local counts_by_section = section_row_counts(sorted_rows)
	local compact_level = layout.compact_level

	-- Parked on the mod for the duration of the build: `create_row_widget` needs the
	-- column geometry, and it is reached through three different call sites (view,
	-- history preview, tactical overlay) that all funnel through here. Same idiom as
	-- `_widget_times` / `_wait_timer`.
	self._scoreboard_layout = layout

	local top_padding = ScoreboardViewSettings.scoreboard_table_top_padding
	local current_offset = top_padding
	local column_index = 1
	local column_heights = {}
	local visible_rows = 0
	local current_section = nil
	local section_visible_rows = 0
	local index = 1

	for g = 1, #sorted_rows, 1 do
		local rows = sorted_rows[g]
		for i = 1, #rows, 1 do
			local this_row = rows[i]
			if this_row.visible ~= false then
				-- Break before a top-level row once this column has had its share.
				-- Children are never separated from the parent whose line they share.
				if column_index < layout.columns
					and not this_row.parent
					and current_offset - top_padding >= layout.column_target
				then
					column_heights[column_index] = current_offset
					column_index = column_index + 1
					current_offset = top_padding
				end

				layout.column_index = column_index

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

	column_heights[column_index] = current_offset

	local tallest = 0
	for c = 1, #column_heights do
		tallest = math.max(tallest, column_heights[c])
	end

	-- Left in place deliberately: `adjust_size` runs after this and needs the same
	-- geometry. Every build overwrites it before any read.
	layout.column_index = nil

	return sorted_rows, tallest, layout
end

mod.adjust_size = function(self, total_height, scoreboard_widget, scenegraph, row_widgets, scenegraph_ids)
	local layout = self._scoreboard_layout
	local height = total_height + ScoreboardViewSettings.scoreboard_table_bottom_padding + frame_chrome_height
	-- Clamp to the user's ceiling, not the hardcoded panel size. The column flow is
	-- what keeps content inside this; the clamp is only a backstop.
	height = math.min(height, self:scoreboard_max_height())
	local width = layout and self:scoreboard_layout_panel_width(layout) or ScoreboardViewSettings.scoreboard_size[1]
	local style = scoreboard_widget and scoreboard_widget.style or {}
	local sizes = {height - 36, height, height - 3, height - 28}
	-- Width deltas per frame pass, mirroring FrameStyle.scoreboard_passes. Applied
	-- here too because the tactical overlay builds its scenegraph once at
	-- hook_require time and never rebuilds it, so a column-count change afterwards
	-- would otherwise leave the frame at its old width.
	local widths = {width - 18, width + 10, width + 10, width - 10}
	for i = 1, #sizes, 1 do
		local pass_style = style["style_id_"..i]
		if pass_style and pass_style.size then
			pass_style.size[2] = sizes[i]
			pass_style.size[1] = widths[i]
		end
	end
	for i = 5, 6, 1 do
		local pass_style = style["style_id_"..i]
		if pass_style and pass_style.size then
			pass_style.size[1] = width - 4
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
	local title_settings = {
		scoreboard_size = {width, height},
		scoreboard_title_inset = ScoreboardViewSettings.scoreboard_title_inset,
	}
	FrameStyle.update_title_offset(style.style_id_7, title_settings, 0, height, scoreboard_z, 210)
	FrameStyle.update_backdrop_opacity(scoreboard_widget)

	if scoreboard_graph then
		scoreboard_graph.size[1] = width
		scoreboard_graph.size[2] = height
	end

	local root_id = scenegraph_ids and scenegraph_ids.root
	local root_graph = root_id and rawget(scenegraph, root_id)
	if root_graph then
		root_graph.size[1] = width
		root_graph.size[2] = height
	end

	local rows_graph = rawget(scenegraph, rows_id)
	if rows_graph then
		rows_graph.size[1] = width
		rows_graph.size[2] = math.max(height - 40, 0)
	end
end

return mod


