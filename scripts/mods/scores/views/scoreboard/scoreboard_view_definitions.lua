local mod = get_mod("scores")

local UIWorkspaceSettings = mod:original_require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local ScoreboardViewSettings = mod:io_dofile("scores/scripts/mods/scores/views/scoreboard/scoreboard_view_settings")
local FrameStyle = mod:io_dofile("scores/scripts/mods/scores/frame_style")
local base_z = 100

local scenegraph_definition = FrameStyle.scoreboard_scenegraph(UIWorkspaceSettings.screen, ScoreboardViewSettings, base_z)

local widget_definitions = {
    scoreboard = FrameStyle.scoreboard_widget_definition(UIWidget, ScoreboardViewSettings, "scoreboard", 0, base_z),
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



