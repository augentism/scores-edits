local mod = get_mod("scores")
mod.name = "scores"

local DMF = get_mod("DMF")

-- Scoreboard plugins (Ovenproof's Community Patch and friends) resolve their host
-- with `get_mod("scoreboard")` and install *no hooks at all* when that is nil, so
-- this mod answers to that name too. Plugins then run unmodified and stay
-- updatable from their own source.
--
-- Deliberately a wrapper around the global rather than `DMF.mods["scoreboard"] = mod`:
-- `dmf.mods_update_event` iterates `pairs(_mods)`, so a second entry pointing here
-- would run `mod.update` twice every frame -- double-ticking the coherency timer,
-- accuracy polling and the account cache with no visible symptom.
--
-- A real scoreboard mod always wins the lookup, so having both installed degrades
-- to the old behaviour instead of fighting over the plugins.
-- Re-capture the real `get_mod` whenever the global is not our own wrapper. A mod
-- reload re-executes DMF too, which builds a fresh `_mods` registry and a fresh
-- `get_mod` closing over it; a cached copy of the previous one keeps answering out
-- of the abandoned registry and every lookup silently returns a stale mod object.
-- Comparing against our stored wrapper is what distinguishes "DMF replaced it"
-- (recapture) from "only this mod reloaded" (keep, so wrappers never nest).
local previous_wrapper = rawget(_G, "_scores_get_mod_wrapper")
local real_get_mod = rawget(_G, "_scores_get_mod_original")
if real_get_mod == nil or rawget(_G, "get_mod") ~= previous_wrapper then
	real_get_mod = rawget(_G, "get_mod")
	_G._scores_get_mod_original = real_get_mod
end

local function scoreboard_alias(name)
	local found = real_get_mod(name)
	if found then
		return found
	end

	-- Resolved through the live registry rather than the `mod` upvalue, so this
	-- can never hand a plugin a mod object left over from a previous load.
	if name == "scoreboard" then
		return real_get_mod("scores")
	end
end

_G._scores_get_mod_wrapper = scoreboard_alias
_G.get_mod = scoreboard_alias

local function load(path)
	return mod:io_dofile("scores/scripts/mods/scores/"..path)
end

load("core/state")
load("core/format")
load("core/row_options")
load("core/options")
load("core/views")
load("scoreboard_row_registry")
load("row_display")
load("row_layout")
load("row_widget")
load("player_inspect")
load("announcements")
load("history_storage")
load("history_serializer")
load("history")
load("tracking/hook_registry")
load("tracking/coherency")
load("tracking/pickups")
load("tracking/defense")
load("tracking/combat")
load("tracking/objectives")
load("tactical_overlay")
load("integrations/gameplay_lifecycle")
load("integrations/end_view")
load("integrations/history_chat")

function mod.on_all_mods_loaded()
	mod:load_package("packages/ui/views/end_player_view/end_player_view")
	mod:load_package("packages/ui/views/store_item_detail_view/store_item_detail_view")
	mod:collect_scoreboard_rows()
end

function mod.reload_mods()
	mod:collect_scoreboard_rows()
end

function mod.update(main_dt)
	-- DMF keeps calling `update` on a mod whose script aborted part-way through
	-- loading, and each call then throws on the first missing method -- one error
	-- per frame, forever, burying the real failure. `initialized` is set by the
	-- last line of this file, so it is the signal that every submodule loaded.
	if not mod.initialized then
		return
	end

	mod._player_account_cache_timer = (mod._player_account_cache_timer or 0) - (main_dt or 0)
	if mod._player_account_cache_timer <= 0 then
		mod._player_account_cache_timer = 1
		mod:refresh_player_account_cache()
	end

	mod:update_history_profile_snapshots(main_dt)
	mod:update_pending_ammo_scores()
	mod:update_servo_skull_tracking(main_dt)
	mod:update_accuracy_scores()
	mod:update_coherency(main_dt)
	mod:update_history_loadout_suspension()
end

function mod.on_setting_changed(setting_id)
	if setting_id == "dev_mode" then
		mod.update_option(setting_id)
	elseif setting_id == "tactical_overview" then
		mod.tactical_overview = mod:get("tactical_overview")
	elseif setting_id == "ammo_efficiency" then
		mod:refresh_ammo_scores()
	elseif setting_id == "split_damage_dealt" then
		mod.include_overkill_damage = mod:get("split_damage_dealt") == true
	elseif setting_id == "player_name_display" and mod.refresh_scoreboard_name_display then
		mod:refresh_scoreboard_name_display()
	end
end

mod:initialize()
mod:migrate_history_save_mode()
mod:register_scoreboard_view()
mod:register_scoreboard_history_view()
