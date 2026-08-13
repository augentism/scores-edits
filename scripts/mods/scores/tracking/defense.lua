local mod = get_mod("scores")

mod.disabled_states = {
	ledge_hanging = true,
	grabbed = true,
	consumed = true,
	netted = true,
	pounced = true,
}
mod.player_state_tracker = mod.player_state_tracker or {}
mod.pending_shout_revives = mod.pending_shout_revives or {}

local function shout_source_unit(unit)
	local buff_extension = mod:safe_extension(unit, "buff_system")
	local buffs = buff_extension and (buff_extension._buffs or buff_extension._buffs_by_index) or {}

	for _, buff in pairs(buffs) do
		local template = buff and buff._template
		local name = template and template.name
		local is_voice_of_command = type(name) == "string"
			and string.find(name, "veteran", 1, true)
			and (string.find(name, "shout", 1, true)
				or string.find(name, "combat_ability_increase_and_restore_toughness", 1, true))
		if is_voice_of_command then
			local context = buff._context or buff._template_context
			local source_unit = context and (context.source_unit or context.owner_unit)
			if not source_unit and buff.source_unit then
				local ok, value = pcall(buff.source_unit, buff)
				source_unit = ok and value or nil
			end
			if source_unit and source_unit ~= unit then
				return source_unit
			end
		end
	end
end

local function character_state(extension)
	local component = extension and (extension._character_state_read_component or extension._character_state_component)
	return component and component.state_name
end

local function update_player_state(unit, state_name, t)
	if not unit or not state_name then
		return
	end

	local account_id = mod:account_id_from_unit(unit)
	if not account_id then
		return
	end

	local old_state = mod.player_state_tracker[account_id]
	local pending = mod.pending_shout_revives[account_id]
	if state_name == "knocked_down" then
		local source_unit = shout_source_unit(unit)
		if source_unit then
			mod.pending_shout_revives[account_id] = {source_unit = source_unit, expires_at = t + 1}
		elseif pending and t > pending.expires_at then
			mod.pending_shout_revives[account_id] = nil
		end
	elseif old_state == "knocked_down" and pending then
		if t <= pending.expires_at then
			local reviver_account_id = mod:account_id_from_unit(pending.source_unit)
			if reviver_account_id and mod:row_tracking_enabled("revived_rescued") then
				mod:update_stat("revived_operative", reviver_account_id, 1)
			end
		end
		mod.pending_shout_revives[account_id] = nil
	end
	if old_state and old_state ~= state_name then
		if state_name == "knocked_down" then
			if mod:row_tracking_enabled("times_downed") then
				mod:update_stat("times_downed", account_id, 1)
			end
		elseif state_name == "dead" then
			if mod:row_tracking_enabled("deaths") then
				mod:update_stat("deaths", account_id, 1)
			end
		elseif mod.disabled_states[state_name] then
			if mod:row_tracking_enabled("times_disabled") then
				mod:update_stat("times_disabled", account_id, 1)
			end
		end
	end
	mod.player_state_tracker[account_id] = state_name
end

local function update_damage_taken(extension, unit)
	local account_id = mod:account_id_from_unit(unit)
	if account_id and extension and extension._damage and extension._damage > 0 then
		mod:update_stat("damage_taken", account_id, extension._damage)
	end
end

local function on_player_health_update(extension, unit, t)
	update_damage_taken(extension, unit)
	update_player_state(unit, character_state(extension), t)
end

mod:register_tracking_hook({
	name = "blocked_attack",
	class = CLASS.WeaponSystem,
	method = "rpc_player_blocked_attack",
	handler = function(self, channel_id, unit_id, attacking_unit_id, hit_world_position, block_broken, weapon_template_id, attack_type_id, ...)
		local player_unit = mod:safe_unit(unit_id)
		local account_id = mod:account_id_from_unit(player_unit)
		if account_id and mod:row_tracking_enabled("attacks_blocked") then
			mod:update_stat("attacks_blocked", account_id, 1)
		end
	end,
})

mod:register_tracking_hook({
	name = "husk_health_update",
	class = CLASS.PlayerHuskHealthExtension,
	method = "fixed_update",
	handler = function(self, unit, dt, t, ...)
		on_player_health_update(self, unit, t)
	end,
})

mod:register_tracking_hook({
	name = "local_health_update",
	class = CLASS.PlayerUnitHealthExtension,
	method = "fixed_update",
	handler = function(self, unit, dt, t, ...)
		on_player_health_update(self, unit, t)
	end,
})

