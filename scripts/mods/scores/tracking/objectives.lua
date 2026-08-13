local mod = get_mod("scores")

mod:register_tracking_hook({
	name = "decoder_place_unit",
	class = CLASS.DecoderDeviceSystem,
	method = "rpc_decoder_device_place_unit",
	handler = function(self, channel_id, unit_id, ...)
	local unit = mod:safe_unit(unit_id, true)
	local player_unit = mod.interaction_units[unit]
	local player = mod:player_from_unit(player_unit)
	if player then
		local account_id = mod:account_id_from_player(player)
		mod:update_stat("gadget_operated", account_id, 1)
	end
	end,
})

	
mod:register_tracking_hook({
	name = "decoder_finished",
	class = CLASS.DecoderDeviceSystem,
	method = "rpc_decoder_device_finished",
	handler = function(self, channel_id, unit_id, ...)
	local unit = mod:safe_unit(unit_id, true)
	local player_unit = mod.interaction_units[unit]
	local player = mod:player_from_unit(player_unit)
	if player then
		local account_id = mod:account_id_from_player(player)
		mod:update_stat("gadget_operated", account_id, 1)
	end
	end,
})

mod:register_tracking_hook({
	name = "minigame_completed",
	class = CLASS.MinigameSystem,
	method = "rpc_minigame_sync_completed",
	handler = function(self, channel_id, unit_id, is_level_unit, ...)
	local unit = mod:safe_unit(unit_id, is_level_unit)
	local player_unit = mod.interaction_units[unit]
	local player = mod:player_from_unit(player_unit)
	if player then
		local account_id = mod:account_id_from_player(player)
		mod:update_stat("gadget_operated", account_id, 1)
	end
	end,
})


