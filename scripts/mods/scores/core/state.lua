local mod = get_mod("scores")

local DMF = get_mod("DMF")
local _os = DMF:persistent_table("_os")
_os.initialized = _os.initialized or false
if not _os.initialized then _os = DMF.deepcopy(Mods.lua.os) end

local Managers = Managers
local ScriptUnit = ScriptUnit
local table_clear = table.clear
local tonumber = tonumber

mod.initialize = function(self)
	if not self.initialized then
		self.definitions = self:io_dofile("scores/scripts/mods/scores/ui_definitions")
		self.ui_font_settings = self:original_require("scripts/managers/ui/ui_font_settings")
	end
	self:refresh_managers()
	self.initialized = true
end

mod.refresh_managers = function(self)
	self.ui_manager = Managers and Managers.ui or self.ui_manager
	self.player_manager = Managers and Managers.player or self.player_manager
	self.package_manager = Managers and Managers.package or self.package_manager
end

mod.set_mission_name = function(self, mission_name)
	self.mission_name = mission_name
end

mod.set_mission_circumstance = function(self, mission_circumstance)
	self.mission_circumstance = mission_circumstance
end

mod.set_mission_challenge = function(self, mission_challenge)
	self.mission_challenge = mission_challenge
end

mod.set_mission_havoc_rank = function(self, mission_havoc_rank)
	self.mission_havoc_rank = mission_havoc_rank
end

mod.set_mission_resistance = function(self, mission_resistance)
	self.mission_resistance = mission_resistance
end

mod.set_victory_defeat = function(self, victory_defeat)
	self.victory_defeat = victory_defeat
end

mod.initialize_timer = function(self)
	self.timer = _os.time()
end

mod.clear_transient_tracking = function(self)
	if self.current_health then table_clear(self.current_health) end
	if self.player_account_ids_by_unit then table_clear(self.player_account_ids_by_unit) end
	if self.accuracy_shot_snapshots then table_clear(self.accuracy_shot_snapshots) end
	if self.accuracy_shot_snapshot_modes then table_clear(self.accuracy_shot_snapshot_modes) end
	if self.accuracy_last_hit_shot_count then table_clear(self.accuracy_last_hit_shot_count) end
	if self.accuracy_pending_end_time_skips then table_clear(self.accuracy_pending_end_time_skips) end
	if self.ammo_interaction_snapshots then table_clear(self.ammo_interaction_snapshots) end
	if self.pending_ammo_scores then table_clear(self.pending_ammo_scores) end
	if self.interaction_units then table_clear(self.interaction_units) end
	if self.player_state_tracker then table_clear(self.player_state_tracker) end
	if self.pending_shout_revives then table_clear(self.pending_shout_revives) end
	if self.servo_skull_tracking then table_clear(self.servo_skull_tracking) end
	self.servo_skull_tracking_timer = 0
	self.servo_skull_tracking_active = false
	self._player_account_cache_timer = 0
	if self.clear_top_score_announcements then self:clear_top_score_announcements() end
	self.coherency_timer = self.coherency_frequency
end

mod.tracking_setting_enabled = function(self, setting_id)
	if not setting_id then
		return true
	end

	return self:get(setting_id) ~= false
end

mod.row_tracking_enabled = function(self, row_name)
	local row = self.get_scoreboard_row and self:get_scoreboard_row(row_name)

	return not row or self:tracking_setting_enabled(row.setting)
end

mod.history_capture_enabled = function(self)
	if self.migrate_history_save_mode then
		self:migrate_history_save_mode()
	end

	if tonumber(self:get("history_save_mode")) ~= 1 then
		return true
	end

	return self.scoreboard_history_opened and self:scoreboard_history_opened()
end

mod.servo_skull_tracking_enabled = function(self)
	return self:row_tracking_enabled("revived_rescued")
		or self:row_tracking_enabled("team_saves")
end

mod.servo_skull_row_enabled = function(self, row_name)
	if row_name == "team_saves" then
		return self:row_tracking_enabled("team_saves")
	elseif row_name == "revived_operative" or row_name == "rescued_operative" then
		return self:row_tracking_enabled("revived_rescued")
	end

	return false
end

mod.refresh_player_account_cache = function(self)
	local cache = self.player_account_ids_by_unit
	local player_manager = self.player_manager or Managers.player
	if not cache or not player_manager then
		return
	end

	local seen = {}
	for _, player in pairs(player_manager:players()) do
		local unit = player.player_unit
		local account_id = unit and self:account_id_from_player(player)
		if unit and account_id then
			cache[unit] = account_id
			seen[unit] = true
		end
	end

	for unit in pairs(cache) do
		if not seen[unit] then
			cache[unit] = nil
		end
	end
end

function mod.developer_diagnostics()
	local self = mod

	if self:get("dev_mode") ~= true then
		return
	end

	if self.refresh_managers then
		self:refresh_managers()
	end

	local function status(label, ok)
		return label..": "..(ok and "ok" or "unavailable")
	end

	local diagnostics = {
		"Scores diagnostics",
		"version: "..tostring(self.version),
		status("player manager", self.player_manager ~= nil),
		status("ui manager", self.ui_manager ~= nil),
		status("accuracy tracking", self:row_tracking_enabled("accuracy")),
		status("weakspot hit percent", self:row_tracking_enabled("weakspot_hit_percent")),
		status("critical hit percent", self:row_tracking_enabled("critical_hits")),
		status("coherency tracking", self:row_tracking_enabled("coherency_efficiency")),
		status("servo-skull tracking", self:servo_skull_tracking_enabled()),
		status("history profile polling", self:history_capture_enabled()),
	}

	if self.appdata_path then
		local path = self:appdata_path()
		diagnostics[#diagnostics+1] = "history path: "..tostring(path)
		diagnostics[#diagnostics+1] = status("history path writable", self:create_scoreboard_history_directory())
	end

	if self.echo then
		self:echo(table.concat(diagnostics, "\n"))
	end
end

mod.clear = function(self)
	for _, data in pairs(self.registered_scoreboard_rows or {}) do
		if data.data then
			table_clear(data.data)
		else
			data.data = {}
		end
	end
	self:clear_transient_tracking()
	self.checked_history_files = nil
end

mod.safe_player_call = function(self, player, method_name)
	local ok, method = pcall(function()
		return player and player[method_name]
	end)
	if not ok then
		return nil
	end
	if type(method) == "function" then
		local method_ok, value = pcall(method, player)
		return method_ok and value or nil
	elseif method ~= nil then
		return method
	end
end

mod.account_id_from_player = function(self, player)
	return self:safe_player_call(player, "account_id") or self:safe_player_call(player, "name")
end

mod.player_from_unit = function(self, unit)
	local player_manager = self.player_manager or Managers.player
	if unit and player_manager then
		for _, player in pairs(player_manager:players()) do
			if player.player_unit == unit then
				return player
			end
		end
	end
end

mod.account_id_from_unit = function(self, unit)
	local player = self:player_from_unit(unit)
	return player and self:account_id_from_player(player)
end

mod.safe_extension = function(self, unit, extension_name)
	return unit and ScriptUnit and ScriptUnit.has_extension(unit, extension_name)
end

mod.safe_component = function(self, unit, component_name)
	local extension = self:safe_extension(unit, "unit_data_system")
	if not extension then
		return nil
	end

	local ok, component = pcall(extension.read_component, extension, component_name)
	return ok and component or nil
end

mod.safe_component_field = function(self, component, field_name)
	local ok, value = pcall(function()
		return component and component[field_name]
	end)

	return ok and value or nil
end

mod.safe_unit = function(self, unit_id, is_level_unit)
	local unit_spawner = Managers.state and Managers.state.unit_spawner
	return unit_spawner and unit_spawner:unit(unit_id, is_level_unit)
end

mod.safe_context = function(self, context, ...)
	local value = context
	for i = 1, select("#", ...) do
		local key = select(i, ...)
		value = value and value[key]
	end
	return value
end

mod.local_player_or_nil = function(self, player_manager)
	if player_manager and type(player_manager.local_player) == "function" then
		return player_manager:local_player(1)
	end
end

mod.is_in_hub = function(self)
	local game_mode = Managers and Managers.state and Managers.state.game_mode
	local game_mode_name = game_mode and game_mode:game_mode_name()
	return game_mode_name == "hub" or game_mode_name == "prologue_hub"
end

mod.scoreboard_players = function(self, player_manager, loaded_players, use_all_players)
	if loaded_players then
		return loaded_players
	end

	if player_manager and (use_all_players or not self:is_in_hub()) then
		return player_manager:players()
	end

	local local_player = self:local_player_or_nil(player_manager)
	if local_player then
		return {local_player}
	end

	return {}
end

mod.me = function(self)
	local local_player = self.player_manager and self.player_manager:local_player(1)
	return local_player and self:account_id_from_player(local_player)
end

mod.is_me = function(self, account_id)
	local my_account_id = self:me()
	return my_account_id and account_id == my_account_id
end

mod.is_numeric = function(self, x)
	return tonumber(x) ~= nil
end

return mod


