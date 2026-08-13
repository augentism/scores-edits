local mod = get_mod("scores")
local Breed = mod:original_require("scripts/utilities/breed")

mod.bosses = {
	chaos_beast_of_nurgle = true,
	chaos_daemonhost = true,
	chaos_spawn = true,
	chaos_plague_ogryn = true,
	chaos_plague_ogryn_sprayer = true,
	renegade_captain = true,
	renegade_twin_captain = true,
	renegade_twin_captain_two = true,
	cultist_captain = true,
	chaos_mutator_daemonhost = true,
	chaos_ogryn_houndmaster = true,
}
mod.current_health = setmetatable({}, {__mode = "k"})
mod.player_account_ids_by_unit = setmetatable({}, {__mode = "k"})
mod.accuracy_shot_snapshots = mod.accuracy_shot_snapshots or {}
mod.accuracy_shot_snapshot_modes = mod.accuracy_shot_snapshot_modes or {}
mod.accuracy_last_hit_shot_count = mod.accuracy_last_hit_shot_count or {}
mod.accuracy_pending_end_time_skips = mod.accuracy_pending_end_time_skips or {}
mod.include_overkill_damage = mod:get("split_damage_dealt") == true

mod.damage_score_value = function(self, raw_damage, actual_damage)
	if self.include_overkill_damage then
		return raw_damage or 0
	end
	return actual_damage or 0
end

local function row_score(row_name, account_id)
	local row = mod:get_scoreboard_row(row_name)
	local data = row and row.data and row.data[account_id]
	return data and data.score or 0
end

mod.refresh_percent_row = function(self, row_name, numerator_row_name, denominator_row_name, account_id)
	if not account_id then
		return
	end

	local numerator = row_score(numerator_row_name, account_id)
	local denominator = row_score(denominator_row_name, account_id)
	local percentage = denominator > 0 and numerator / denominator * 100 or 0
	self:set_row_value(row_name, account_id, percentage)
end

mod.refresh_weakspot_hit_percent = function(self, account_id)
	self:refresh_percent_row("weakspot_hit_percent", "weakspot_damaging_hits", "damaging_hits", account_id)
end

mod.refresh_critical_hit_percent = function(self, account_id)
	self:refresh_percent_row("critical_hits", "critical_damaging_hits", "damaging_hits", account_id)
end

mod.refresh_accuracy = function(self, account_id)
	if not self:row_tracking_enabled("accuracy") then
		return
	end

	if not account_id then
		return
	end

	self:refresh_percent_row("accuracy", "ranged_shots_hit", "ranged_shots_fired", account_id)
end

mod.update_accuracy_shots_for_unit = function(self, unit, account_id)
	if not self:row_tracking_enabled("accuracy") then
		return
	end

	if not account_id then
		return
	end

	local shooting_status = self:safe_component(unit, "shooting_status")
	local current_shots = tonumber(self:safe_component_field(shooting_status, "num_shots"))
	if current_shots then
		self.accuracy_shot_snapshot_modes[account_id] = "num_shots"
		local previous_shots = self.accuracy_shot_snapshots[account_id]
		if previous_shots and current_shots > previous_shots then
			self:update_stat("ranged_shots_fired", account_id, current_shots - previous_shots)
			self:refresh_accuracy(account_id)
		elseif not previous_shots and current_shots > 0 then
			self:update_stat("ranged_shots_fired", account_id, current_shots)
			self:refresh_accuracy(account_id)
		end

		self.accuracy_shot_snapshots[account_id] = current_shots
		return
	end

	local current_end_time = tonumber(self:safe_component_field(shooting_status, "shooting_end_time"))
	if not current_end_time then
		return
	end

	self.accuracy_shot_snapshot_modes[account_id] = "end_time"
	local previous_end_time = self.accuracy_shot_snapshots[account_id]
	if current_end_time > 0 and current_end_time ~= previous_end_time then
		local pending_skips = self.accuracy_pending_end_time_skips[account_id] or 0
		if pending_skips > 0 then
			self.accuracy_pending_end_time_skips[account_id] = pending_skips > 1 and pending_skips - 1 or nil
		elseif previous_end_time ~= nil then
			self:update_stat("ranged_shots_fired", account_id, 1)
			self:refresh_accuracy(account_id)
		end
	end

	self.accuracy_shot_snapshots[account_id] = current_end_time
end

mod.credit_ranged_accuracy_hit = function(self, unit, account_id)
	if not self:row_tracking_enabled("accuracy") then
		return
	end

	self:update_accuracy_shots_for_unit(unit, account_id)

	local shots_fired = row_score("ranged_shots_fired", account_id)
	local last_hit_shot_count = self.accuracy_last_hit_shot_count[account_id] or 0
	if shots_fired <= last_hit_shot_count then
		if self.accuracy_shot_snapshot_modes[account_id] ~= "num_shots" then
			return
		end

		local shooting_status = self:safe_component(unit, "shooting_status")
		local current_end_time = tonumber(self:safe_component_field(shooting_status, "shooting_end_time"))
		self:update_stat("ranged_shots_fired", account_id, 1)
		shots_fired = shots_fired + 1
		if current_end_time then
			self.accuracy_pending_end_time_skips[account_id] = (self.accuracy_pending_end_time_skips[account_id] or 0) + 1
		end
	end

	self:update_stat("ranged_shots_hit", account_id, 1)
	self.accuracy_last_hit_shot_count[account_id] = shots_fired
	self:refresh_accuracy(account_id)
end

mod.update_accuracy_scores = function(self)
	if not self:row_tracking_enabled("accuracy") then
		if self.accuracy_shot_snapshots then table.clear(self.accuracy_shot_snapshots) end
		if self.accuracy_shot_snapshot_modes then table.clear(self.accuracy_shot_snapshot_modes) end
		if self.accuracy_last_hit_shot_count then table.clear(self.accuracy_last_hit_shot_count) end
		if self.accuracy_pending_end_time_skips then table.clear(self.accuracy_pending_end_time_skips) end
		return
	end

	if not Managers.player then
		return
	end

	local seen = {}
	for _, player in pairs(Managers.player:players()) do
		local unit = player.player_unit
		local account_id = unit and self:account_id_from_player(player)
		if account_id then
			seen[account_id] = true
			self:update_accuracy_shots_for_unit(unit, account_id)
		end
	end

	for account_id in pairs(self.accuracy_shot_snapshots) do
		if not seen[account_id] then
			self.accuracy_shot_snapshots[account_id] = nil
			self.accuracy_shot_snapshot_modes[account_id] = nil
			self.accuracy_last_hit_shot_count[account_id] = nil
			self.accuracy_pending_end_time_skips[account_id] = nil
		end
	end
end

mod:register_tracking_hook({
	name = "attack_result",
	hot_path = true,
	class = CLASS.AttackReportManager,
	method = "add_attack_result",
	handler = function(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage,
	attack_result, attack_type, damage_efficiency, ...)
	local account_id = attacking_unit and mod.player_account_ids_by_unit[attacking_unit]
	if not account_id and attacking_unit then
		local player = mod:player_from_unit(attacking_unit)
		account_id = player and mod:account_id_from_player(player)
		if account_id then
			mod.player_account_ids_by_unit[attacking_unit] = account_id
		end
	end
	if account_id then
		local track_accuracy = mod:row_tracking_enabled("accuracy")
		local track_critical_percent = mod:row_tracking_enabled("critical_hits")
		local track_weakspot_hits = mod:row_tracking_enabled("weakspot_hits")
		local track_weakspot_percent = mod:row_tracking_enabled("weakspot_hit_percent")
		local track_damaging_hit_percent = track_weakspot_percent or track_critical_percent
		local track_boss_damage = mod:row_tracking_enabled("boss_damage_dealt")
		local unit_data_extension = mod:safe_extension(attacked_unit, "unit_data_system")
		local breed_or_nil = unit_data_extension and unit_data_extension:breed()
		local target_is_minion = breed_or_nil and Breed.is_minion(breed_or_nil)
		local raw_damage = damage or 0
		local actual_damage = raw_damage
		local overkill_damage = 0

		local is_critical_strike = false
		if track_critical_percent then
			local critical_strike_component = mod:safe_component(attacking_unit, "critical_strike")
			is_critical_strike = mod:safe_component_field(critical_strike_component, "is_active")
		end

		if track_weakspot_hits and hit_weakspot then
			mod:update_stat("weakspot_hits", account_id, 1)
		end

		if target_is_minion then
			-- Get health extension
			local current_health = mod.current_health[attacked_unit]
			local unit_health_extension = mod:safe_extension(attacked_unit, "health_system")
			local new_health = unit_health_extension and unit_health_extension:current_health()

			-- Attack result
			if attack_result == "damaged" and new_health then
				-- Current health
				if not current_health then
					current_health = new_health + actual_damage
				end
				-- Actual damage
				actual_damage = math.min(raw_damage, current_health)
				-- Update health
				mod.current_health[attacked_unit] = new_health

			elseif attack_result == "died" then
				-- Current health
				if not current_health then
					current_health = actual_damage
				end
				-- Actual damage
				actual_damage = current_health
				-- Overkill damage
				overkill_damage = math.max(raw_damage - actual_damage, 0)
				-- Update health
				mod.current_health[attacked_unit] = nil
				-- Update scoreboard
				mod:update_stat(breed_or_nil.name, account_id, 1)
				if attack_type == "ranged" then
					mod:update_stat("ranged_kills", account_id, 1)
				else
					mod:update_stat("melee_kills", account_id, 1)
				end
			end

			if actual_damage > 0 and (attack_result == "damaged" or attack_result == "died") then
				if track_damaging_hit_percent then
					mod:update_stat("damaging_hits", account_id, 1)
				end
				if track_weakspot_percent and hit_weakspot then
					mod:update_stat("weakspot_damaging_hits", account_id, 1)
				end
				if track_weakspot_percent then
					mod:refresh_weakspot_hit_percent(account_id)
				end
				if track_critical_percent and is_critical_strike then
					mod:update_stat("critical_damaging_hits", account_id, 1)
				end
				if track_critical_percent then
					mod:refresh_critical_hit_percent(account_id)
				end

				if track_accuracy and attack_type == "ranged" then
					mod:credit_ranged_accuracy_hit(attacking_unit, account_id)
				end
			end

			local score_damage = mod:damage_score_value(raw_damage, actual_damage)

			-- Damage is the inclusive total. Boss damage is tracked in addition as
			-- a subset so it can never exceed Damage for the same scoring mode.
			mod:update_stat("actual_damage_dealt", account_id, score_damage)
			if overkill_damage > 0 then
				mod:update_stat("overkill_damage_dealt", account_id, overkill_damage)
			end

			if track_boss_damage and mod.bosses[breed_or_nil.name] then
				mod:update_stat("boss_damage_dealt", account_id, score_damage)
			end
		end
	end
	end,
})

mod:register_tracking_hook({
	name = "husk_health_init",
	class = CLASS.HuskHealthExtension,
	method = "init",
	call_order = "after",
	handler = function(self, extension_init_context, unit, extension_init_data, game_session, game_object_id, owner_id, ...)
	if unit and self.max_health then
		mod.current_health[unit] = self:max_health()
	end
	end,
})


