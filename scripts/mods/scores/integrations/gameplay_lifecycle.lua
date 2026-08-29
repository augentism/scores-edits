local mod = get_mod("scores")

local CLASS = CLASS
local Havoc = mod:original_require("scripts/utilities/havoc")
local Circumstances = mod:io_dofile("scores/scripts/mods/scores/circumstances")

local function parsed_havoc_data(mechanism_data)
	if type(mechanism_data) ~= "table" or not mechanism_data.havoc_data then
		return nil
	end

	local ok, havoc_data = pcall(Havoc.parse_data, mechanism_data.havoc_data)
	return ok and type(havoc_data) == "table" and havoc_data or nil
end

local function havoc_rank_from_mechanism_data(mechanism_data)
	local havoc_data = parsed_havoc_data(mechanism_data)
	return havoc_data and tonumber(havoc_data.havoc_rank) or nil
end

-- Circumstances come from two places and mean the same thing to a player: a normal
-- mission names one directly, a havoc mission stacks several inside its payload,
-- which Havoc.parse_data already splits out for us.
local function circumstances_from_mechanism_data(mechanism_data)
	local havoc_data = parsed_havoc_data(mechanism_data)
	local named = type(mechanism_data) == "table" and mechanism_data.circumstance_name or nil

	return Circumstances.merge(named, havoc_data and havoc_data.circumstances)
end

local function current_mechanism_data()
	local mechanism_manager = Managers and Managers.mechanism
	if not mechanism_manager or type(mechanism_manager.mechanism_data) ~= "function" then
		return {}
	end

	local ok, data = pcall(mechanism_manager.mechanism_data, mechanism_manager)
	return ok and type(data) == "table" and data or {}
end

mod.capture_mission_metadata = function(self, supplied_data, supplied_mission_name, replace_missing)
	local data = type(supplied_data) == "table" and supplied_data or {}
	local live_data = current_mechanism_data()
	local mission_name = supplied_mission_name or data.mission_name or live_data.mission_name

	local function value(key)
		return data[key] ~= nil and data[key] or live_data[key]
	end

	local function assign(setter, captured)
		if replace_missing or captured ~= nil then
			setter(self, captured)
		end
	end

	assign(self.set_mission_name, mission_name)
	assign(self.set_mission_circumstance, value("circumstance_name"))
	assign(self.set_mission_challenge, value("challenge"))
	local havoc_source = data.havoc_data and data or live_data
	assign(self.set_mission_havoc_rank, havoc_rank_from_mechanism_data(havoc_source))
	assign(self.set_mission_circumstances, circumstances_from_mechanism_data(havoc_source))
	assign(self.set_mission_resistance, value("resistance"))
end

function mod.on_game_state_changed(status, state_name)
	if state_name == "StateGameplay" and status == "enter" then
		mod:clear()
	elseif state_name == "StateGameplay" and status == "exit" then
		mod:clear_transient_tracking()
	end
end

mod:hook_safe(CLASS.StateGameplay, "on_enter", function(self, parent, params, creation_context, ...)
	-- A gameplay-state transition starts a new profile lifetime, including hub
	-- transitions where the previous game-mode manager can still report the
	-- mission being left. Clearing unconditionally avoids relying on that stale
	-- state and bounds this cache to one gameplay session.
	if mod.clear_live_player_profiles then
		mod:clear_live_player_profiles()
	end
	if mod.clear_history_profile_snapshots then
		mod:clear_history_profile_snapshots()
	end
	mod:capture_mission_metadata(
		params and params.mechanism_data,
		params and params.mission_name,
		true
	)
	mod:refresh_player_account_cache()
	mod:initialize_timer()
end)

if CLASS.GameModeManager then
	local success = pcall(function()
		mod:hook_safe(CLASS.GameModeManager, "_set_end_conditions_met", function(self, outcome, ...)
			mod:set_victory_defeat(outcome)
			if mod.capture_history_profile_snapshots then
				mod:capture_history_profile_snapshots()
			end
		end)
	end)
	if not success then
		-- Hook failed, method likely doesn't exist on this game version.
	end
end

return mod
