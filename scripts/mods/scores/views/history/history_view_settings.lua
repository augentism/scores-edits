local mod = get_mod("scores")

local UIWorkspaceSettings = mod:original_require("scripts/settings/ui/ui_workspace_settings")

-- Darktide's UI is resolution independent: `screen` is a nominal 1920x1080 box
-- with scale = "fit", scaled to the player's display, so every size here is in
-- workspace units rather than pixels and looks the same at any resolution. What
-- does vary is how much of that box is usable, so it is derived rather than
-- guessed: the game reserves a band at the bottom (`bottom_panel`) for the input
-- legend, and this view puts its own title above the content.
local screen_size = UIWorkspaceSettings.screen.size
local bottom_reserved = UIWorkspaceSettings.bottom_panel.size[2] + 16

-- The stock `top_panel` band claims 0..200, but this view draws no top panel, so
-- only enough room for the view title is kept and the rest goes to the content.
local title_y = 64
local title_height = 60
local content_top = title_y + title_height + 10

local grid_width = 452
local grid_height = screen_size[2] - content_top - bottom_reserved

-- The scoreboard preview does not share the run list's top anchor. The list sits
-- under this view's title; the preview has nothing above it worth reserving room
-- for, so it starts at the top of the screen and runs down to the same reserved
-- bottom band. That is roughly 130 units of extra height for the rows.
local preview_top = 0
local preview_height = screen_size[2] - preview_top - bottom_reserved

local scoreboard_history_view_settings = {
    scrollbar_width = 10,
    max_visible_dropdown_options = 5,
    indentation_spacing = 40,
    shading_environment = "content/shading_environments/ui/system_menu",
    title_y = title_y,
    title_height = title_height,
    content_top = content_top,
    -- Sizes the saved-run list only; the preview is taller, see preview_height.
    grid_size = {grid_width, grid_height},
    preview_top = preview_top,
    preview_height = preview_height,
    grid_padding = {18, 34, 18, 18},
    grid_spacing = {0, 6},
    grid_blur_edge_size = {8, 8},
}
return settings("ScoreboardHistoryViewSettings", scoreboard_history_view_settings)
