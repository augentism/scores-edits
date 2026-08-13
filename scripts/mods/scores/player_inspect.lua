local mod = get_mod("scores")

local PlayerInfo = mod:original_require("scripts/managers/data_service/services/social/player_info")

mod.live_player_profiles = mod.live_player_profiles or {}
mod.latest_history_profiles = mod.latest_history_profiles or {}

-- Release the legacy per-history cache during hot reloads as well as fresh
-- starts. It retained complete live profile graphs for every saved match.
if mod.scoreboard_history_profiles then
	table.clear(mod.scoreboard_history_profiles)
	mod.scoreboard_history_profiles = nil
end

local function cache_profile_alias(cache, key, profile)
	key = key and tostring(key) or nil
	if key and key ~= "" and key ~= "nil" then
		cache[key] = profile
	end
end

local function identity_matches(identity, candidate)
	if not identity or not candidate then
		return false
	end

	return tostring(identity) == tostring(candidate)
end

local function account_name_from_player(mod, player, player_name)
	if mod.player_account_name then
		return mod:player_account_name(player, player_name)
	end

	return mod:safe_player_call(player, "account_name")
		or mod:safe_player_call(player, "accountName")
		or mod:safe_player_call(player, "account_username")
		or mod:safe_player_call(player, "platform_user_name")
		or mod:safe_player_call(player, "user_name")
		or mod:safe_player_call(player, "username")
end

mod.cache_live_player_profile = function(self, player)
	local account_id = self:account_id_from_player(player)
	local profile = self:safe_player_call(player, "profile")
	if account_id and profile then
		self.live_player_profiles = self.live_player_profiles or {}
		cache_profile_alias(self.live_player_profiles, account_id, profile)
		cache_profile_alias(self.live_player_profiles, account_name_from_player(self, player, self:safe_player_call(player, "name")), profile)
		cache_profile_alias(self.live_player_profiles, self:safe_player_call(player, "name"), profile)
		-- End-view row setup runs before automatic history persistence. Capture
		-- the same profile that powers working end-screen inspection as a bounded
		-- serialized snapshot, never as another retained profile graph.
		if self.capture_history_profile_snapshot then
			self:capture_history_profile_snapshot(player, profile)
		end
	end
	return profile
end

mod.live_player_profile = function(self, account_id)
	if account_id and self.live_player_profiles then
		return self.live_player_profiles[tostring(account_id)]
	end
end

mod.live_player_profile_by_identity = function(self, account_id, account_name, player_name)
	local profile = self:live_player_profile(account_id)
		or self:live_player_profile(account_name)
		or self:live_player_profile(player_name)
	if profile and profile.loadout then
		return profile
	end

	local player_manager = self.player_manager or Managers.player
	local players = player_manager and player_manager:players()
	for _, player in pairs(players or {}) do
		local player_account_id = self:account_id_from_player(player)
		local player_name_value = self:safe_player_call(player, "name")
		local player_account_name = account_name_from_player(self, player, player_name_value)

		if identity_matches(account_id, player_account_id)
			or identity_matches(account_name, player_account_name)
			or identity_matches(player_name, player_name_value) then
			return self:cache_live_player_profile(player)
		end
	end
end

mod.live_player_profile_by_player = function(self, player)
	return player and self:live_player_profile_by_identity(
		self:safe_player_call(player, "account_id"),
		self:safe_player_call(player, "account_name"),
		self:safe_player_call(player, "name")
	)
end

mod.clear_live_player_profiles = function(self)
	if self.live_player_profiles then
		table.clear(self.live_player_profiles)
	end
end

mod.promote_live_profiles_to_history = function(self, file_name)
	local latest = {}
	for identity, profile in pairs(self.live_player_profiles or {}) do
		latest[identity] = profile
	end
	self.latest_history_profiles = latest
	self.latest_history_profile_file = file_name
end

mod.latest_history_profile = function(self, file_name, account_id, account_name, player_name)
	if not file_name or file_name ~= self.latest_history_profile_file then
		return nil
	end

	local cache = self.latest_history_profiles or {}
	return cache[tostring(account_id or "")]
		or cache[tostring(account_name or "")]
		or cache[tostring(player_name or "")]
end

mod.history_social_player_info = function(self, player)
	local account_id = self:safe_player_call(player, "account_id")
	if not account_id or account_id == "" then return nil end
	local account_name = self:safe_player_call(player, "account_name")
	local player_name = self:safe_player_call(player, "name")
	local social_service = Managers.data_service and Managers.data_service.social
	local player_info = social_service and social_service:get_player_info_by_account_id(account_id) or PlayerInfo:new()
	player_info:set_account(account_id, account_name or player_name)
	return player_info
end

mod.set_history_loadout_suspended = function(self, suspended)
	self.history_loadout_suspended = suspended == true

	local view = Managers.ui and Managers.ui:view_instance("scores_history_view")
	if view and view.set_loadout_suspended then
		view:set_loadout_suspended(self.history_loadout_suspended)
	end
end

mod.update_history_loadout_suspension = function(self)
	if not self.history_loadout_suspended then
		return
	end

	local ui_manager = Managers.ui
	if not ui_manager then
		self.history_loadout_suspended = nil
		return
	end

	local inventory_view_name = "inventory_background_view"
	local inventory_open = ui_manager:view_active(inventory_view_name)
		and not ui_manager:is_view_closing(inventory_view_name)
	if not inventory_open then
		self:set_history_loadout_suspended(false)
	end
end

mod.inspect_player_profile = function(self, profile)
	if not profile or not profile.loadout then
		return
	end

	local local_player = Managers.player and Managers.player:local_player(1)
	if not local_player then
		return
	end

	local local_player_account_id = self:safe_player_call(local_player, "account_id")
	local local_player_peer_id = self:safe_player_call(local_player, "peer_id")
	if not local_player_account_id then
		return
	end
	if not Managers.ui then
		return
	end

	local player_info = PlayerInfo:new()
	player_info:set_account(local_player_account_id)

	player_info.local_player_id = function()
		return 1
	end
	player_info.peer_id = function()
		return local_player_peer_id
	end
	player_info.profile = function()
		return profile
	end
	player_info.name = function()
		return profile.name
	end

	local inventory_view_name = "inventory_background_view"
	if self:scoreboard_history_opened() then
		self:set_history_loadout_suspended(true)
	end

	if not Managers.ui:view_active(inventory_view_name) then
		local ok, err = pcall(Managers.ui.open_view, Managers.ui, inventory_view_name, nil, nil, nil, nil, {
			is_readonly = true,
			player = player_info,
		})
		if not ok then
			self:set_history_loadout_suspended(false)
			if self.warning then
				self:warning("Unable to open %s for history loadout: %s", inventory_view_name, tostring(err))
			end
			return
		end
	end
end

return mod
