local mod = get_mod("scores")

local UIWorkspaceSettings = mod:original_require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local ScoreboardViewSettings = mod:io_dofile("scores/scripts/mods/scores/views/scoreboard/scoreboard_view_settings")
local FrameStyle = mod:io_dofile("scores/scripts/mods/scores/frame_style")
local base_z = 100

-- Panel geometry depends on the row set, which grows when plugins register rows,
-- so the frame is sized from the resolved layout rather than the raw settings.
-- This file is re-executed each time the view is created, so it picks up column
-- and row changes; `adjust_size` corrects it again once the rows are measured.
local PanelSettings = mod.scoreboard_layout_settings and mod:scoreboard_layout_settings() or ScoreboardViewSettings

local scenegraph_definition = FrameStyle.scoreboard_scenegraph(UIWorkspaceSettings.screen, PanelSettings, base_z)

local widget_definitions = {
    scoreboard = FrameStyle.scoreboard_widget_definition(UIWidget, PanelSettings, "scoreboard", 0, base_z),
}

local legend_inputs = {
    {
        input_action = "hotkey_menu_special_1",
        on_pressed_callback = "cb_on_save_pressed",
        display_name = "loc_scoreboard_save",
        alignment = "left_alignment"
    },
}

local ScoreboardViewDefinitions = {
    legend_inputs = legend_inputs,
    widget_definitions = widget_definitions,
    scenegraph_definition = scenegraph_definition
}

return settings("ScoreboardViewDefinitions", ScoreboardViewDefinitions)



