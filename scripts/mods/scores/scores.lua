local mod = get_mod("scores")
mod.name = "scores"

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
