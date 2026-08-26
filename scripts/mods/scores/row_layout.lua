local mod = get_mod("scores")

local ScoreboardDefinitions = mod:io_dofile("scores/scripts/mods/scores/ui_definitions")
local ScoreboardViewSettings = mod:io_dofile("scores/scripts/mods/scores/views/scoreboard/scoreboard_view_settings")
local FrameStyle = mod:io_dofile("scores/scripts/mods/scores/frame_style")
local HavocModifiers = mod:io_dofile("scores/scripts/mods/scores/havoc_modifiers")

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
-- Two blocks plus the gap come to 1880, inside the 1920-wide nominal UI workspace.
--
-- The label column keeps its full single-column width on purpose. Plugin rows can
-- carry labels pre-padded with tabs to a fixed pixel width -- Ovenproof builds
-- "Total Ammo <pad> [ Taken | Wasted ]" that way, sized against this exact column
-- -- so narrowing it makes every one of those labels overflow into the next cell.
-- All the space for a second block comes out of the player columns instead.
local multi_column_gap = 40
local multi_column_header_width = ScoreboardViewSettings.scoreboard_column_header_width
local multi_column_block_width = 920

-- Read from the history view's own settings rather than restated here: the preview
-- panel is sized to match the saved-run list it sits beside, and a second copy of
-- that number is one nobody remembers to change.
local HistoryViewSettings = mod:io_dofile("scores/scripts/mods/scores/views/history/history_view_settings")
local history_preview_height = HistoryViewSettings.grid_size and HistoryViewSettings.grid_size[2] or 760

-- Delegates to the same table row_widget.lua draws with, so the measuring pass and
-- the drawing pass can never disagree about how tall a row is. row_widget loads
-- after this file, but every caller here runs at build time, well after that.
local function row_height(row, compact_level)
	if mod.row_metrics then
		return (mod.row_metrics(row, compact_level))
	end

	return row.player_header and 78
		or (row.name == "header") and ScoreboardViewSettings.scoreboard_row_header_height
		or 25
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
			-- A child row draws inside its parent's line and has no label of its own,
			-- so it is meaningless without that parent on screen. Parents drop out
			-- when their own setting is off or they are declared hidden, and an
			-- orphan left behind falls back to the next row's offset and draws on
			-- top of it.
			local orphaned = row.parent ~= nil and not inserted_rows[row.parent]

			if self:is_own_scoreboard_row(row.name) or row.visible == false or orphaned then
				add_hidden(row)
			else
				local plugin = row.mod
				if plugin ~= last_plugin then
					last_plugin = plugin
					local plugin_key = self.scoreboard_row_plugin_names and self.scoreboard_row_plugin_names[plugin]
					add_section("section_plugin_"..tostring(plugin_key or row.name), self:plugin_section_label(plugin))
				end
				rows[#rows+1] = row
				inserted_rows[row.name] = true
			end
		end
	end

	-- Mission context rather than per-player stats, so it goes last where it can be
	-- scrolled to, and renders as label-only `info` rows with no player cells.
	local modifiers = self.active_havoc_modifiers and self:active_havoc_modifiers()
	local labels = modifiers and HavocModifiers.labels(modifiers) or nil
	if labels and #labels > 0 then
		add_section("section_havoc_modifiers", self:localize("section_havoc_modifiers"))
		for i = 1, #labels do
			rows[#rows+1] = {
				mod = mod,
				name = "havoc_modifier_"..i,
				text = labels[i],
				-- Already a finished sentence from the game's own settings, and it can
				-- contain a literal %, which would break a trip through localize.
				raw_text = true,
				info = true,
				validation = ScoreboardDefinitions.validation_types.ASC,
				validation_type = "ASC",
			}
		end
	end

	return sorted
end

-- Whichever mission the board is currently showing: the saved run being previewed
-- in the history view, otherwise the one being played.
mod.active_havoc_modifiers = function(self)
	return self._history_havoc_modifiers or self.mission_havoc_modifiers
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
		if ok and type(localized) == "string" and localized ~= "" and localized ~= "<>" and localized ~= "<mod_name>" then
			return localized
		end

		-- DMF leaves no name on the mod object, so fall back to the registry key
		-- captured at registration. `tostring(plugin.name)` used to end up here and
		-- put a section header reading "nil" on the board.
		local registry_name = self.scoreboard_row_plugin_names and self.scoreboard_row_plugin_names[plugin]
		if type(registry_name) == "string" and registry_name ~= "" then
			return registry_name
		end
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
mod.scoreboard_layout = function(self, loaded_rows, sorted_rows, options)
	options = options or {}
	sorted_rows = sorted_rows or self:get_rows_in_groups(loaded_rows or self.registered_scoreboard_rows)

	local data_row_count = visible_data_row_count(sorted_rows)
	local compact_level = data_row_count > dense_row_threshold and 2
		or data_row_count > compact_row_threshold and 1
		or 0

	local total = content_height(sorted_rows, compact_level)
	local chrome = ScoreboardViewSettings.scoreboard_table_top_padding
		+ ScoreboardViewSettings.scoreboard_table_bottom_padding
		+ frame_chrome_height
	local max_height = math.min(options.max_height or self:scoreboard_max_height(), self:scoreboard_max_height())
	local budget = math.max(max_height - chrome, 1)

	-- Only the end-of-mission board can go multi-column, and only on request.
	-- Everywhere else -- and by default everywhere -- a tall panel that scrolls beats
	-- a wide one: the in-mission overlay sits on top of the game, and the history
	-- preview sits beside the saved-run list.
	local columns = 1
	if not options.single_column and tonumber(self:get("scoreboard_columns")) == 2 then
		columns = 2
	end

	local multi = columns > 1

	return {
		columns = columns,
		compact_level = compact_level,
		content_height = total,
		chrome_height = chrome,
		column_budget = budget,
		max_height = max_height,
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
mod.scoreboard_layout_settings = function(self, loaded_rows, options)
	local ok, layout = pcall(self.scoreboard_layout, self, loaded_rows, nil, options)
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

	return math.min(height, layout.max_height or self:scoreboard_max_height())
end

-- Scrolling for panels that have no scrollbar and no mask: the rows are shifted and
-- any row that would land outside the frame is simply not drawn. Whole rows only --
-- a straddling one would paint over the border with nothing to clip it.
local scroll_step = 60

mod.scroll_extent = function(self, content_height, viewport)
	return math.max((content_height or 0) - (viewport or 0), 0)
end

mod.update_scroll_state = function(self, state, input_service, content_height, viewport)
	local extent = self:scroll_extent(content_height, viewport)
	if extent <= 0 then
		state.scroll = 0
		return 0
	end

	local scroll_axis = input_service and input_service:get("scroll_axis")
	local delta = scroll_axis and scroll_axis[2] or 0
	if delta ~= 0 then
		state.scroll = math.clamp((state.scroll or 0) - delta * scroll_step, 0, extent)
	else
		state.scroll = math.clamp(state.scroll or 0, 0, extent)
	end

	return state.scroll
end

-- Positions one row for the current scroll offset. Returns whether it should draw.
mod.apply_row_scroll = function(self, widget, scroll, viewport)
	local base = widget._scores_base_offset_y
	if base == nil then
		base = widget.offset[2]
		widget._scores_base_offset_y = base
	end

	local y = base - (scroll or 0)
	widget.offset[2] = y

	if not viewport or viewport <= 0 then
		return true
	end

	local height = widget._scores_row_height or 0
	return y >= -0.5 and y + height <= viewport
end

mod.setup_row_widgets = function(self, loaded_rows, groups, row_widgets, widgets_by_name, loaded_players, is_history, end_view, obj, create_widget_callback, ui_renderer, scenegraph, scenegraph_ids)
	local sorted_rows = self:get_rows_in_groups(loaded_rows)
	-- Only the tactical overlay passes its own scenegraph ids; that is how this
	-- distinguishes the three surfaces without threading another argument through
	-- every caller.
	local is_overlay = scenegraph_ids ~= nil
	local layout = self:scoreboard_layout(nil, sorted_rows, {
		single_column = is_history or is_overlay,
		-- The preview panel is pinned to the height of the saved-run list it sits
		-- beside, rather than growing to the full row set and running off-screen.
		max_height = is_history and history_preview_height or nil,
	})
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
	-- Clamp to whatever ceiling this surface resolved (the history preview uses a
	-- smaller one). Content past it is reachable by scrolling, not lost.
	height = math.min(height, layout and layout.max_height or self:scoreboard_max_height())
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


