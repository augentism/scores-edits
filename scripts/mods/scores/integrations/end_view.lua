local mod = get_mod("scores")

local CLASS = CLASS

mod:hook_safe(CLASS.EndView, "on_enter", function(self, ...)
	mod.end_scoreboard_visible = mod:get("show_scoreboard_on_mission_end") ~= false
	local opened = mod:show_scoreboard_view({end_view = true})
	if opened then
		mod:apply_end_scoreboard_visibility()
	elseif mod.announce_end_view_scoreboard_fallback then
		mod:announce_end_view_scoreboard_fallback()
	end
end)

mod:hook_safe(CLASS.EndView, "on_exit", function(self, ...)
	mod:close_scoreboard_view()
end)

mod:hook_require("scripts/ui/views/end_player_view/end_player_view_definitions", function(instance)
	if not instance then
		return
	end

	local card_carousel = instance.scenegraph_definition.card_carousel
	if card_carousel then
		card_carousel.horizontal_alignment = "right"
		card_carousel.position = {-130, 350, 0}
	end
end)

mod:hook_safe(CLASS.EndPlayerView, "on_enter", function(self, ...)
	if mod.ui_manager then
		local view = mod.ui_manager:view_instance("scores_view")
		if view then view:move_scoreboard(0, -300) end
	end
end)

mod:hook_safe(CLASS.EndPlayerView, "on_exit", function(self, ...)
	if mod.ui_manager then
		local view = mod.ui_manager:view_instance("scores_view")
		if view then view:move_scoreboard(-300, 0) end
	end
end)

return mod
