local mod = get_mod("scores")

mod.end_scoreboard_visible = true

mod.load_package = function(self, package_name)
	local package_manager = self.package_manager
	if package_manager and not package_manager:is_loading(package_name) and not package_manager:has_loaded(package_name) then
		return package_manager:load(package_name, "scores", nil, true)
	end
end

mod.release_package = function(self, package_id)
	local package_manager = self.package_manager
	if package_manager and package_id then
		package_manager:release(package_id)
	end
end

mod.register_scoreboard_view = function(self)
	self.registered_scoreboard_view_settings = self.registered_scoreboard_view_settings or {}
	if self.registered_scoreboard_view_settings["scores_view"] then
		return true
	end

	self:add_require_path("scores/scripts/mods/scores/views/scoreboard/scoreboard_view")
	self:add_require_path("scores/scripts/mods/scores/views/scoreboard/scoreboard_view_definitions")
	self:add_require_path("scores/scripts/mods/scores/views/scoreboard/scoreboard_view_settings")
	local definitions = self:io_dofile("scores/scripts/mods/scores/views/scoreboard/scoreboard_view_definitions")
	local ok = self:register_view({
		view_name = "scores_view",
		view_settings = {
			init_view_function = function()
				return true
			end,
			class = "ScoreboardView",
			disable_game_world = false,
			display_name = "loc_scoreboard_view_display_name",
			game_world_blur = 0,
			load_always = true,
			load_in_hub = true,
			package = "packages/ui/views/options_view/options_view",
			path = "scores/scripts/mods/scores/views/scoreboard/scoreboard_view",
			state_bound = false,
			enter_sound_events = {
				"wwise/events/ui/play_ui_enter_short"
			},
			exit_sound_events = {
				"wwise/events/ui/play_ui_back_short"
			},
			wwise_states = {
				options = "ingame_menu"
			},
			scenegraph_definition = definitions.scenegraph_definition,
			widget_definitions = definitions.widget_definitions,
		},
		view_transitions = {},
		view_options = {
			close_all = false,
			close_previous = false,
			close_transition_time = nil,
			transition_time = nil
		}
	})
	if not ok then
		return false
	end
	self:io_dofile("scores/scripts/mods/scores/views/scoreboard/scoreboard_view")
	self.registered_scoreboard_view_settings["scores_view"] = true
	return true
end

mod.register_scoreboard_history_view = function(self)
	self.registered_scoreboard_view_settings = self.registered_scoreboard_view_settings or {}
	if self.registered_scoreboard_view_settings["scores_history_view"] then
		return true
	end

	self:add_require_path("scores/scripts/mods/scores/views/history/history_view")
	self:add_require_path("scores/scripts/mods/scores/views/history/history_view_definitions")
	self:add_require_path("scores/scripts/mods/scores/views/history/history_view_settings")
	local definitions = self:io_dofile("scores/scripts/mods/scores/views/history/history_view_definitions")
	local ok = self:register_view({
		view_name = "scores_history_view",
		view_settings = {
			init_view_function = function()
				return true
			end,
			class = "ScoreboardHistoryView",
			disable_game_world = false,
			display_name = "loc_scoreboard_history_view_display_name",
			game_world_blur = 1.1,
			load_always = true,
			load_in_hub = true,
			package = "packages/ui/views/options_view/options_view",
			path = "scores/scripts/mods/scores/views/history/history_view",
			state_bound = true,
			enter_sound_events = {
				"wwise/events/ui/play_ui_enter_short"
			},
			exit_sound_events = {
				"wwise/events/ui/play_ui_back_short"
			},
			wwise_states = {
				options = "ingame_menu"
			},
			scenegraph_definition = definitions.scenegraph_definition,
			widget_definitions = definitions.widget_definitions,
		},
		view_transitions = {},
		view_options = {
			close_all = false,
			close_previous = false,
			close_transition_time = nil,
			transition_time = nil
		}
	})
	if not ok then
		return false
	end
	self:io_dofile("scores/scripts/mods/scores/views/history/history_view")
	self.registered_scoreboard_view_settings["scores_history_view"] = true
	return true
end

mod.view_settings_available = function(self, view_name)
	if self.registered_scoreboard_view_settings and self.registered_scoreboard_view_settings[view_name] then
		return true
	end

	if self.refresh_managers then
		self:refresh_managers()
	end

	local ui_manager = self.ui_manager
	local view_settings = ui_manager and ui_manager._view_settings
	return view_settings and view_settings[view_name] ~= nil
end

mod.ensure_scoreboard_view_registered = function(self, view_name)
	if self.refresh_managers then
		self:refresh_managers()
	end

	if self:view_settings_available(view_name) then
		return true
	end

	local ok = true
	if view_name == "scores_view" then
		ok = pcall(self.register_scoreboard_view, self)
	elseif view_name == "scores_history_view" then
		ok = pcall(self.register_scoreboard_history_view, self)
	else
		ok = false
	end

	if not ok then
		if self.warning then
			self:warning("Unable to register %s before opening it.", view_name)
		end
		return false
	end

	return self:view_settings_available(view_name)
end

mod.show_scoreboard_view = function(self, context)
	if self.refresh_managers then
		self:refresh_managers()
	end

	self:close_scoreboard_view()
	if not self.ui_manager or not self:ensure_scoreboard_view_registered("scores_view") then
		return false
	end

	local ok, err = pcall(self.ui_manager.open_view, self.ui_manager, "scores_view", nil, false, false, nil, context or {}, {use_transition_ui = false})
	if not ok then
		if self.warning then
			self:warning("Unable to open scores_view: %s", tostring(err))
		end
		return false
	end

	return true
end

mod.scoreboard_opened = function(self)
	if self.refresh_managers then
		self:refresh_managers()
	end

	if not self.ui_manager then
		return false
	end

	local view = self.ui_manager:view_instance("scores_view")
	if not view then
		return false
	end

	local active = self.ui_manager:view_active("scores_view")
	local closing = self.ui_manager:is_view_closing("scores_view")
	return active and not closing
end

mod.end_scoreboard_opened = function(self)
	if not self:scoreboard_opened() then
		return false
	end

	local view = self.ui_manager and self.ui_manager:view_instance("scores_view")

	return view and view.end_view == true
end

mod.apply_end_scoreboard_visibility = function(self)
	if not self:end_scoreboard_opened() then
		return
	end

	local view = self.ui_manager:view_instance("scores_view")
	if view and view.set_end_scoreboard_visible then
		view:set_end_scoreboard_visible(self.end_scoreboard_visible ~= false)
	end
end

mod.refresh_scoreboard_name_display = function(self)
	if self.refresh_managers then
		self:refresh_managers()
	end

	if not self.ui_manager then
		return
	end

	local view_names = {"scores_view", "scores_history_view"}
	for i = 1, #view_names do
		local view_name = view_names[i]
		if self.ui_manager:view_active(view_name) then
			local ok, view = pcall(self.ui_manager.view_instance, self.ui_manager, view_name)
			view = ok and view or nil
			if view and view.setup_row_widgets then
				view:setup_row_widgets()
				if view.set_end_scoreboard_visible then
					view:set_end_scoreboard_visible(view._end_scoreboard_visible ~= false)
				end
			end
		end
	end
end

function mod.toggle_end_scoreboard_visibility()
	if mod.refresh_managers then
		mod:refresh_managers()
	end

	if mod:options_view_opened() then
		return
	end

	if not mod:end_scoreboard_opened() then
		return
	end

	mod.end_scoreboard_visible = mod.end_scoreboard_visible == false
	mod:apply_end_scoreboard_visibility()
end

mod.close_scoreboard_view = function(self)
	if self.refresh_managers then
		self:refresh_managers()
	end

	if self.ui_manager and self:scoreboard_opened() then
		self.ui_manager:close_view("scores_view", true)
	end
end

mod.scoreboard_history_opened = function(self)
	if self.refresh_managers then
		self:refresh_managers()
	end

	if not self.ui_manager then
		return false
	end

	local active = self.ui_manager:view_active("scores_history_view")
	local closing = self.ui_manager:is_view_closing("scores_history_view")
	return active and not closing
end

mod.options_view_opened = function(self)
	if self.refresh_managers then
		self:refresh_managers()
	end

	if not self.ui_manager then
		return false
	end

	local active = self.ui_manager:view_active("dmf_options_view")
	local closing = self.ui_manager:is_view_closing("dmf_options_view")
	return active or closing
end

function mod.open_scoreboard_history()
	if mod.refresh_managers then
		mod:refresh_managers()
	end

	if not mod.ui_manager or mod:options_view_opened() then
		return
	end

	if mod:scoreboard_history_opened() then
		mod.ui_manager:close_view("scores_history_view")
	elseif mod:ensure_scoreboard_view_registered("scores_history_view") then
		local ok, err = pcall(mod.ui_manager.open_view, mod.ui_manager, "scores_history_view", nil, false, false, nil, {}, {use_transition_ui = false})
		if not ok and mod.warning then
			mod:warning("Unable to open scores_history_view: %s", tostring(err))
		end
	end
end

function mod.open_scoreboard()
	if mod.refresh_managers then
		mod:refresh_managers()
	end

	if mod.hud_active or mod:options_view_opened() then
		return
	end

	if mod:scoreboard_opened() then
		mod:close_scoreboard_view()
	elseif mod:get("dev_mode") then
		mod:show_scoreboard_view()
	end
end

return mod


