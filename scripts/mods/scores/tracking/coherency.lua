local mod = get_mod("scores")

mod.coherency_frequency = 10
mod.coherency_timer = mod.coherency_frequency

mod.update_coherency = function(self, dt)
	if not self:row_tracking_enabled("coherency_efficiency") then
		return
	end

	if self.player_manager and self.coherency_timer then
        if self.coherency_timer <= 0 then
            local players = self.player_manager:players()
            for _, player in pairs(players) do
                local unit = player.player_unit
                if unit then
                    local coherency_extension = self:safe_extension(unit, "coherency_system")
                    if coherency_extension then
                        local num_units_in_coherency = coherency_extension:num_units_in_coherency()
                        local account_id = self:account_id_from_player(player)
                        self:update_stat("coherency_efficiency", account_id, num_units_in_coherency)
                    end
                end
            end
            self.coherency_timer = self.coherency_frequency
        else
            self.coherency_timer = self.coherency_timer - dt
        end
	end
end


