local mod = get_mod("scores")

local ScoreboardData = mod:io_dofile("scores/scripts/mods/scores/scores_data")

local CLASS = CLASS

function mod.find_option_in_data(obj, setting_id)
	for _, option in pairs(obj) do
		if option.setting_id == setting_id then
			return option
		elseif option.sub_widgets and #option.sub_widgets > 0 then
			local sub = mod.find_option_in_data(option.sub_widgets, setting_id)
			if sub then return sub end
		end
	end
end

function mod.fetch_option_from_data(setting_id)
	return mod.find_option_in_data(ScoreboardData.options.widgets, setting_id)
end

function mod.fetch_option_from_view(setting_id)
	if not mod.ui_manager then
		return nil
	end
	local options_view = mod.ui_manager:view_instance("dmf_options_view")
	local category_widgets = options_view and options_view._settings_category_widgets
	if category_widgets then
		for _, mod_group in pairs(category_widgets) do
			for _, widget_data in pairs(mod_group) do
				local entry = widget_data.widget
					and widget_data.widget.content
					and widget_data.widget.content.entry
				if entry and entry.display_name == mod:localize(setting_id) then
					return widget_data
				end
			end
		end
	end
end

function mod.update_option(setting_id)
	if not mod.ui_manager then
		return
	end
	local options_view = mod.ui_manager:view_instance("dmf_options_view")
	if options_view then
		local data_option = mod.fetch_option_from_data(setting_id)
		if data_option and data_option.type == "checkbox" then
			local visible = mod:get(setting_id)
			for _, sub_widget in pairs(data_option.sub_widgets or {}) do
				local option = mod.fetch_option_from_view(sub_widget.setting_id)
				if option and option.widget and option.widget.content then
					option.widget.content.disabled = visible == false
					if option.widget.content.hotspot then
						option.widget.content.hotspot.disabled = visible == false
					end
				end
			end
		end
	end
end

local function update_options(options)
	for _, option in pairs(options or {}) do
		mod.update_option(option.setting_id)
		update_options(option.sub_widgets)
	end
end

function mod.update_options()
	update_options(ScoreboardData.options.widgets)
end

function mod.migrate_history_save_mode(self)
	if self:get("history_save_mode_migrated") then
		return
	end

	if self:get("save_all_scoreboards") == false then
		self:set("history_save_mode", 1)
	elseif tonumber(self:get("history_save_mode")) == nil then
		self:set("history_save_mode", 2)
	end

	self:set("history_save_mode_migrated", true)
end

if CLASS.BaseView then
	local success = pcall(function()
		mod:hook_safe(CLASS.BaseView, "_on_view_load_complete", function(self, loaded, ...)
			if self.view_name == "dmf_options_view" then
				mod.update_options()
			end
		end)
	end)
	if not success then
		-- Hook failed, method likely doesn't exist on this game version
	end
end

return mod


