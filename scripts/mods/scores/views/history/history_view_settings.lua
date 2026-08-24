local scoreboard_history_view_settings = {
    scrollbar_width = 10,
    max_visible_dropdown_options = 5,
    indentation_spacing = 40,
    shading_environment = "content/shading_environments/ui/system_menu",
    -- 820 is what fits: the history content area is top-anchored at y=198 on the
    -- 1080-tall nominal workspace, so this ends at 1018 and still clears the input
    -- legend along the bottom. Both the run list and the scoreboard preview beside
    -- it are sized from this, so they stay aligned.
    grid_size = {452, 820},
    grid_padding = {18, 34, 18, 18},
    grid_spacing = {0, 6},
    grid_blur_edge_size = {8, 8},
}
return settings("ScoreboardHistoryViewSettings", scoreboard_history_view_settings)  

