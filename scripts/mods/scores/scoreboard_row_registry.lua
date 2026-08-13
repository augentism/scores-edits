local mod = get_mod("scores")


local math = math
local type = type
local pairs = pairs
local math_max = math.max
local table_insert = table.insert


local ScoreboardDefinitions = mod:io_dofile("scores/scripts/mods/scores/ui_definitions")

mod.registered_scoreboard_rows = {}
mod.scoreboard_row_index = {}
mod.scoreboard_rows = mod:io_dofile("scores/scripts/mods/scores/scoreboard_row_definitions")


mod.collect_scoreboard_rows = function(self, loaded_rows)
	if not loaded_rows then
		self.registered_scoreboard_rows = {}
		self.scoreboard_row_index = {}
		for _, template in pairs(mod.scoreboard_rows) do
			if not template.name then
				error("scoreboard row is missing a name")
			elseif self.scoreboard_row_index[template.name] then
				error("duplicate scoreboard row name: "..template.name)
			end
			local entry = self:register_scoreboard_row(mod, template)
			local index = #self.registered_scoreboard_rows + 1
			table_insert(self.registered_scoreboard_rows, index, entry)
			self.scoreboard_row_index[entry.name] = entry
		end
	else
		local entries = {}
		local index = {}
		for _, template in pairs(loaded_rows) do
			if template.name and index[template.name] then
				error("duplicate loaded scoreboard row name: "..template.name)
			end
			local entry = self:register_scoreboard_row(self, template)
			entries[#entries+1] = entry
			index[entry.name] = entry
		end
		return entries
	end
end

mod.register_scoreboard_row = function(self, this_mod, template)
	local iteration_type = template.iteration
	local iteration = ScoreboardDefinitions.iteration_types.ADD
	if type(iteration_type) == "string" then
		iteration = ScoreboardDefinitions.iteration_types[iteration_type]
		if not iteration then
			error("unknown scoreboard row iteration type: "..iteration_type)
		end
	end

	local validation_type = template.validation
	local validation = ScoreboardDefinitions.validation_types.ASC
	if type(validation_type) == "string" then
		validation = ScoreboardDefinitions.validation_types[validation_type]
		if not validation then
			error("unknown scoreboard row validation type: "..validation_type)
		end
	end

	local update = template.update
	if type(update) == "string" then
		update = this_mod[update]
	end

	return {
		mod = this_mod,
		name = template.name,
		text = template.text,
		iteration = iteration,
		iteration_type = iteration_type,
		validation = validation,
		validation_type = validation_type,
		parent = template.parent,
		group = template.group,
		summary = template.summary,
		setting = template.setting,
		is_time = template.is_time,
		is_text = template.is_text,
		update = update,
		visible = template.visible,
		normalize = template.normalize,
		big = template.big,
		icon = template.icon,
		icon_package = template.icon_package,
		icon_width = template.icon_width,
		decimals = template.decimals,
		suffix = template.suffix,
		player_header = template.player_header,
		data = template.data,
	}
end

mod.set_row_value = function(self, row_name, account_id, value)
	if not row_name or not account_id then
		return
	end
	local row = self:get_scoreboard_row(row_name)
	if row then
		row.data = row.data or {}
		row.data[account_id] = row.data[account_id] or {}
		row.data[account_id].value = value
		row.data[account_id].score = self:is_numeric(value) and math_max(0, value) or 0
		row.data[account_id].text = nil
	end
end

mod.set_row_text = function(self, row_name, account_id, text)
	if not row_name or not account_id then
		return
	end
	local row = self:get_scoreboard_row(row_name)
	if row then
		row.data = row.data or {}
		row.data[account_id] = row.data[account_id] or {}
		row.data[account_id].value = 0
		row.data[account_id].score = 0
		row.data[account_id].text = text
	end
end

mod.update_stat = function(self, name, account_id, value)
	self:update_row_value(name, account_id, value)
end

mod.update_row_value = function(self, row_name, account_id, value)
	if not row_name or not account_id then
		return
	end
	if self:is_numeric(value) then
		local value = value and math_max(0, value) or 0
		local row = self:get_scoreboard_row(row_name)
		if row then
			row.data = row.data or {}
			local character_data = row.data[account_id]
			local iteration = row.iteration
			local old_value = character_data and character_data.value or 0
			local new_value, add_score = iteration.value(value, old_value)
			local old_score = character_data and character_data.score or 0
			local new_score = old_score + add_score
			row.data[account_id] = row.data[account_id] or {}
			row.data[account_id].value = value
			row.data[account_id].score = new_score
			row.data[account_id].text = nil
		end
	else
		local row = self:get_scoreboard_row(row_name)
		if row then
			row.data = row.data or {}
			row.data[account_id] = row.data[account_id] or {}
			row.data[account_id].text = value
			row.data[account_id].value = 0
			row.data[account_id].score = 0
		end
	end
end


mod.get_scoreboard_row = function(self, row_name)
	return self.scoreboard_row_index and self.scoreboard_row_index[row_name]
end


