local mod = get_mod("scores")
local InteractionSettings = mod:original_require("scripts/settings/interaction/interaction_settings")
local PlayerUnitStatus = mod:original_require("scripts/utilities/attack/player_unit_status")
local Breed = mod:original_require("scripts/utilities/breed")
local CompanionServoSkullSettings = mod:original_require("scripts/settings/companion/companion_servo_skull_settings")
local interaction_results = InteractionSettings.results
local servo_skull_inject_ally_state = CompanionServoSkullSettings.STATES.inject_ally
local servo_skull_tracking_interval = 0.1
local servo_skull_discovery_interval = 2

local function servo_skull_help_row(ally_unit)
	local unit_data_extension = mod:safe_extension(ally_unit, "unit_data_system")
	local character_state = unit_data_extension and unit_data_extension:read_component("character_state")
	if not character_state then
		return nil
	elseif PlayerUnitStatus.is_hogtied(character_state) then
		return "rescued_operative"
	elseif PlayerUnitStatus.is_knocked_down(character_state) then
		return "revived_operative"
	elseif character_state.state_name == "netted" then
		return "team_saves"
	end
end

local function nearest_disabled_ally(skull_unit)
	local skull_position = Unit.world_position(skull_unit, 1)
	local closest_row
	local closest_distance
	for _, player in pairs(Managers.player:players()) do
		local ally_unit = player.player_unit
		local row_name = ally_unit and ALIVE[ally_unit] and servo_skull_help_row(ally_unit)
		if row_name and mod:servo_skull_row_enabled(row_name) then
			local distance = Vector3.distance_squared(skull_position, Unit.world_position(ally_unit, 1))
			if not closest_distance or distance < closest_distance then
				closest_row = row_name
				closest_distance = distance
			end
		end
	end
	return closest_row, closest_distance
end

mod.servo_skull_tracking = {}
mod.servo_skull_tracking_timer = 0
mod.servo_skull_tracking_active = false

mod.update_servo_skull_tracking = function(self, dt)
	if not self:servo_skull_tracking_enabled() then
		self.servo_skull_tracking_timer = 0
		self.servo_skull_tracking_active = false
		if self.servo_skull_tracking then table.clear(self.servo_skull_tracking) end
		return
	end

	self.servo_skull_tracking_timer = self.servo_skull_tracking_timer + dt
	local interval = self.servo_skull_tracking_active and servo_skull_tracking_interval or servo_skull_discovery_interval
	if self.servo_skull_tracking_timer < interval then
		return
	end
	self.servo_skull_tracking_timer = 0

	local state = Managers.state
	local session_manager = state and state.game_session
	local game_session = session_manager and session_manager:game_session()
	local unit_spawner = state and state.unit_spawner
	if not (game_session and unit_spawner and Managers.player and ALIVE) then
		return
	end

	local seen = {}
	local found_servo_skull = false
	for _, player in pairs(Managers.player:players()) do
		local owner_unit = player.player_unit
		local spawner = owner_unit and ALIVE[owner_unit] and self:safe_extension(owner_unit, "companion_spawner_system")
		local companions = spawner and spawner:companion_units() or {}
		for i = 1, #companions do
			local skull_unit = companions[i]
			local breed = skull_unit and ALIVE[skull_unit] and Breed.unit_breed_or_nil(skull_unit)
			if breed and breed.name == "companion_servo_skull" then
				found_servo_skull = true
				local game_object_id = unit_spawner:game_object_id(skull_unit)
				if game_object_id then
					seen[game_object_id] = true
					local skull_state = GameSession.game_object_field(game_session, game_object_id, "state")
					local entry = self.servo_skull_tracking[game_object_id]
					if skull_state == servo_skull_inject_ally_state then
						entry = entry or {account_id = self:account_id_from_player(player)}
						local row_name, distance = nearest_disabled_ally(skull_unit)
						if row_name and (not entry.closest_distance or distance < entry.closest_distance) then
							entry.row_name = row_name
							entry.closest_distance = distance
						end
						self.servo_skull_tracking[game_object_id] = entry
					elseif entry then
						if entry.account_id and entry.row_name and self:servo_skull_row_enabled(entry.row_name) then
							self:update_stat(entry.row_name, entry.account_id, 1)
						end
						self.servo_skull_tracking[game_object_id] = nil
					end
				end
			end
		end
	end

	for game_object_id in pairs(self.servo_skull_tracking) do
		if not seen[game_object_id] then
			self.servo_skull_tracking[game_object_id] = nil
		end
	end
	self.servo_skull_tracking_active = found_servo_skull
end
mod.resource_pickup_rows = {
	loc_pickup_small_metal = "small_plasteel",
	loc_pickup_large_metal = "large_plasteel",
	loc_pickup_small_platinum = "small_diamantine",
	loc_pickup_large_platinum = "large_diamantine",
	small_metal = "small_plasteel",
	large_metal = "large_plasteel",
	small_platinum = "small_diamantine",
	large_platinum = "large_diamantine",
	loc_pickup_small_plasteel = "small_plasteel",
	loc_pickup_large_plasteel = "large_plasteel",
	loc_pickup_small_diamantine = "small_diamantine",
	loc_pickup_large_diamantine = "large_diamantine",
	loc_pickup_crafting_material_small_plasteel = "small_plasteel",
	loc_pickup_crafting_material_large_plasteel = "large_plasteel",
	loc_pickup_crafting_material_small_diamantine = "small_diamantine",
	loc_pickup_crafting_material_large_diamantine = "large_diamantine",
}
mod.resource_pickup_values = {
	small_plasteel = 10,
	large_plasteel = 25,
	small_diamantine = 10,
	large_diamantine = 25,
}

local function resource_from_description(description)
	if type(description) ~= "string" then
		return nil
	end

	local resource = mod.resource_pickup_rows[description]

	if not resource and description then
		local lower_description = string.lower(description)
		local is_large = string.find(lower_description, "large") ~= nil
			or string.find(lower_description, "big") ~= nil
			or string.find(lower_description, "large_") ~= nil

		if string.find(lower_description, "diamantine") then
			resource = is_large and "large_diamantine" or "small_diamantine"
		elseif string.find(lower_description, "plasteel") then
			resource = is_large and "large_plasteel" or "small_plasteel"
		end
	end

	return resource
end

local function resource_count_from_context(context, resource)
	return tonumber(context and (rawget(context, "amount") or rawget(context, "count") or rawget(context, "value")))
		or mod.resource_pickup_values[resource]
end

local function context_field(context, key)
	local ok, value = pcall(rawget, context, key)
	return ok and value or nil
end

local function should_scan_context_key(key)
	return type(key) ~= "string" or string.sub(key, 1, 1) ~= "_"
end

local function resource_from_context_tree(context, seen)
	if type(context) ~= "table" then
		return resource_from_description(context), nil
	end

	if seen and seen[context] then
		return nil, nil
	end
	seen = seen or {}
	seen[context] = true

	local descriptions = {
		context_field(context, "description"),
		context_field(context, "pickup_name"),
		context_field(context, "name"),
		context_field(context, "localized_string"),
		context_field(context, "item"),
		context_field(context, "item_name"),
		context_field(context, "pickup_type"),
	}

	for i = 1, #descriptions do
		local resource = resource_from_description(descriptions[i])
		if resource then
			return resource, resource_count_from_context(context, resource)
		end
	end

	for key, value in next, context do
		if should_scan_context_key(key) then
			local resource, count = resource_from_context_tree(value, seen)
			if resource then
				return resource, count or resource_count_from_context(context, resource)
			end
		end
	end

	return nil, nil
end

mod.resource_from_context = function(self, context)
	local resource, count = resource_from_context_tree(context)

	return resource, count
end

local function update_resource_from_interaction(interactee, account_id)
	local contexts = {
		interactee._override_contexts,
		interactee._template,
		interactee._interaction_template,
		interactee._interaction_context,
		interactee._context,
	}

	for i = 1, #contexts do
		local resource, count = mod:resource_from_context(contexts[i])
		if resource and count then
			mod:update_stat(resource, account_id, count)
			return true
		end
	end

	return false
end

mod.ammunition = {
	loc_pickup_consumable_small_clip_01 = "small_clip",
	loc_pickup_consumable_large_clip_01 = "large_clip",
	loc_pickup_deployable_ammo_crate_01 = "crate",
}
mod.ammunition_score = {
	small_clip = 15,
	large_clip = 50,
	crate = 100,
}
mod.ammunition_counter = {
	small_clip = "ammo_small_picked_up",
	large_clip = "ammo_large_picked_up",
	crate = "ammo_crate_picked_up",
}
mod.ammo_interaction_snapshots = {}
mod.pending_ammo_scores = {}
mod.interaction_units = {}

local function first_number(value)
	if _G.type(value) == "table" then
		return tonumber(value[1])
	end
	return tonumber(value)
end

local function read_secondary_ammo(unit)
	local wieldable_component = mod:safe_component(unit, "slot_secondary")
	if not wieldable_component then
		return nil
	end
	local ammo = {
		clip = first_number(mod:safe_component_field(wieldable_component, "current_ammunition_clip")),
		max_clip = first_number(mod:safe_component_field(wieldable_component, "max_ammunition_clip")),
		reserve = first_number(mod:safe_component_field(wieldable_component, "current_ammunition_reserve")),
		max_reserve = first_number(mod:safe_component_field(wieldable_component, "max_ammunition_reserve")),
	}
	if ammo.clip == nil or ammo.max_clip == nil or ammo.reserve == nil or ammo.max_reserve == nil then
		return nil
	end
	return ammo
end

mod.ammo_score_from_snapshots = function(self, pickup_type, before, after)
	local nominal_score = self.ammunition_score[pickup_type]
	if not nominal_score then
		return nil, nil
	end
	if not before or not after or before.max_reserve <= 0 then
		return nominal_score, nominal_score
	end

	local before_total = before.clip + before.reserve
	local after_total = after.clip + after.reserve
	local gained = math.max(after_total - before_total, 0)
	local actual_score = math.min(gained / before.max_reserve * 100, nominal_score)
	return actual_score, nominal_score
end

local function row_score(row, account_id)
	local data = row and row.data and row.data[account_id]
	return data and data.score or 0
end

mod.refresh_ammo_score = function(self, account_id)
	if not account_id then
		return
	end
	local actual_score = row_score(self:get_scoreboard_row("ammo_score_actual"), account_id)
	local nominal_score = row_score(self:get_scoreboard_row("ammo_score_nominal"), account_id)
	local display_score = nominal_score
	if self:get("ammo_efficiency") ~= false then
		display_score = nominal_score > 0 and actual_score / nominal_score * 100 or 0
	end
	self:set_row_value("ammo_collected", account_id, display_score)
end

mod.refresh_ammo_scores = function(self)
	local account_ids = {}
	for _, row_name in ipairs({"ammo_score_actual", "ammo_score_nominal"}) do
		local row = self:get_scoreboard_row(row_name)
		for account_id in pairs(row and row.data or {}) do
			account_ids[account_id] = true
		end
	end
	for account_id in pairs(account_ids) do
		self:refresh_ammo_score(account_id)
	end
end

local function update_ammo_score(account_id, pickup_type, before, after)
	local actual_score, nominal_score = mod:ammo_score_from_snapshots(pickup_type, before, after)
	if not actual_score then
		return
	end
	mod:update_stat("ammo_score_actual", account_id, actual_score)
	mod:update_stat("ammo_score_nominal", account_id, nominal_score)
	mod:update_stat(mod.ammunition_counter[pickup_type], account_id, 1)
	mod:refresh_ammo_score(account_id)
end

mod.update_pending_ammo_scores = function(self)
	if not self:row_tracking_enabled("ammo_collected") then
		if self.ammo_interaction_snapshots then table.clear(self.ammo_interaction_snapshots) end
		if self.pending_ammo_scores then table.clear(self.pending_ammo_scores) end
		return
	end

	for unit, pending in pairs(self.pending_ammo_scores) do
		self.pending_ammo_scores[unit] = nil
		update_ammo_score(pending.account_id, pending.pickup_type, pending.before, read_secondary_ammo(unit))
	end
end

mod:register_tracking_hook({
	name = "interactee_stopped",
	class = CLASS.InteracteeExtension,
	method = "stopped",
	handler = function(self, result, ...)
	local unit = self._interactor_unit
	local ammo_before = unit and mod.ammo_interaction_snapshots[unit]
	if unit then
		mod.ammo_interaction_snapshots[unit] = nil
	end
	if result == interaction_results.success then
		local type = self:interaction_type() or ""
		if unit then
			local player = mod:player_from_unit(unit)
			if player then
				local account_id = mod:account_id_from_player(player)
				local door_context = self._override_contexts and self._override_contexts.door_control_panel
				local door_description = door_context and door_context.description
				local track_resources = mod:row_tracking_enabled("resources_collected")
				if track_resources and type == "forge_material" then
					local resource_contexts = self._override_contexts or {}
					local resource, count = mod:resource_from_context(
						resource_contexts.forge_material
						or resource_contexts.pickup
						or resource_contexts
					)
					if resource and count then
						mod:update_stat(resource, account_id, count)
						return
					end
				end

				if track_resources and update_resource_from_interaction(self, account_id) then
					return

				elseif type == "default" or type == "moveable_platform" or type == "scripted_scenario" or type == "luggable_socket" or (type == "door_control_panel" and door_description ~= "loc_interactable_door") then
					mod:update_stat("machinery_operated", account_id, 1)

				elseif type == "pocketable" then
					mod:update_stat("machinery_operated", account_id, 1)

				elseif type == "health_station" and mod:row_tracking_enabled("heal_station_used") then
					mod:update_stat("heal_station_used", account_id, 1)

				elseif type == "servo_skull" or type == "servo_skull_activator" then
					mod.interaction_units[self._unit] = unit
					mod:update_stat("gadget_operated", account_id, 1)

				elseif type == "decoding" or type == "setup_decoding" then
					mod.interaction_units[self._unit] = unit

				elseif type == "ammunition" and mod:row_tracking_enabled("ammo_collected") then
					local ammo_description = mod:safe_context(self._override_contexts, "ammunition", "description")
					local ammo = ammo_description and mod.ammunition[ammo_description]
					if ammo then
						mod.pending_ammo_scores[unit] = {
							account_id = account_id,
							pickup_type = ammo,
							before = ammo_before,
						}
					end
				else
					mod.interaction_units[self._unit] = unit
				end
			end
		end
	end
	end,
})

mod:register_tracking_hook({
	name = "interactee_started",
	class = CLASS.InteracteeExtension,
	method = "started",
	handler = function(self, interactor_unit, ...)

	mod.interaction_units[self._unit] = interactor_unit

	if mod:row_tracking_enabled("ammo_collected") then
		mod.ammo_interaction_snapshots[interactor_unit] = read_secondary_ammo(interactor_unit)
	end

	end,
})

mod:register_tracking_hook({
	name = "player_interactee_stopped",
	class = CLASS.PlayerInteracteeExtension,
	method = "stopped",
	handler = function(self, result, ...)
	local type = self:interaction_type() or ""
	if result == interaction_results.success then
		local unit = self._interactor_unit
		if unit then
			local player = mod:player_from_unit(unit)
			if player then
				local account_id = mod:account_id_from_player(player)
				if type == "revive" and mod:row_tracking_enabled("revived_rescued") then
					mod:update_stat("revived_operative", account_id, 1)
				elseif type == "rescue" and mod:row_tracking_enabled("revived_rescued") then
					mod:update_stat("rescued_operative", account_id, 1)
				elseif (type == "pull_up" or type == "remove_net") and mod:row_tracking_enabled("team_saves") then
					mod:update_stat("team_saves", account_id, 1)
				end
			end
		end
	end
	end,
})

