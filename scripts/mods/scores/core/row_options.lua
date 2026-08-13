local mod = get_mod("scores")

mod.row_setting_key = function(self, setting)
	if type(setting) ~= "string" then
		return nil
	end
	local parts = string.split(setting, " ")
	return parts and parts[1] or setting
end

mod.scores_plugin_setting_default = function(self, setting)
	if setting == "plugin_ammo" then
		return 1
	elseif setting == "plugin_damage_dealt" then
		return 1
	end
	return true
end

mod.is_scores_plugin_setting = function(self, row, setting)
	return row.mod == self
		and type(setting) == "string"
		and string.sub(setting, 1, 7) == "plugin_"
end

mod.parse_row_setting_value = function(self, value)
	if value == "true" then
		return true
	elseif value == "false" then
		return false
	end
	return tonumber(value)
end

mod.row_setting_current_value = function(self, row, setting, expected)
	local value = self:is_scores_plugin_setting(row, setting)
		and self:scores_plugin_setting_default(setting)
		or row.mod:get(setting)
	if value == nil and expected ~= nil then
		value = type(expected) == "boolean" and false or 1
	end
	return value
end

mod.row_setting_valid = function(self, row)
	local setting = row.setting
	if not setting then
		return true
	end

	local parts = string.split(setting, " ")
	if parts and #parts > 1 then
		local expected = self:parse_row_setting_value(parts[3])
		local value = self:row_setting_current_value(row, parts[1], expected)
		if parts[2] == "=" then
			return value == expected
		elseif parts[2] == "<" then
			return value < expected
		elseif parts[2] == ">" then
			return value > expected
		end
		return true
	end

	return self:row_setting_current_value(row, setting)
end

mod.row_setting_label = function(self, row, base_label)
	local key = self:row_setting_key(row.setting)
	if not key then
		return base_label
	end

	local setting_value = row.mod:get(key)
	if setting_value == nil and self:is_scores_plugin_setting(row, key) then
		setting_value = self:scores_plugin_setting_default(key)
	end
	if setting_value == nil then
		return base_label
	end

	local candidate = row.mod:localize(row.text.."_"..tostring(setting_value))
	if candidate ~= "<>" and candidate ~= "<"..row.text.."_"..tostring(setting_value)..">" then
		return candidate
	end

	return base_label
end

return mod
