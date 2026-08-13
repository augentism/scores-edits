local mod = get_mod("scores")

local scoreboard_horizontal_padding = 30
local scoreboard_title_size = {150, 64}

local scoreboard_view_settings = {
    shading_environment = "content/shading_environments/ui/system_menu",
    scoreboard_size = {1000, 1000},
    scoreboard_max_players = 7,
    scoreboard_row_height = 26,
    scoreboard_row_header_height = 42,
    scoreboard_row_big_height = 36,
    scoreboard_column_width = 172,
    scoreboard_column_header_width = 282,
    scoreboard_horizontal_padding = scoreboard_horizontal_padding,
    scoreboard_end_view_top_offset = -100,
    scoreboard_table_top_padding = 20,
    scoreboard_table_bottom_padding = 0,
    scoreboard_section_spacing = 18,
    scoreboard_title_inset = {scoreboard_horizontal_padding + scoreboard_title_size[1] / 2, 72},
    scoreboard_title_size = scoreboard_title_size,
    scoreboard_fade_length = 0.1,
}
return settings("ScoreboardViewSettings", scoreboard_view_settings)  


