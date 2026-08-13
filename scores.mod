return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Scores` encountered an error loading the Darktide Mod Framework.")

		new_mod("scores", {
			mod_script       = "scores/scripts/mods/scores/scores",
			mod_data         = "scores/scripts/mods/scores/scores_data",
			mod_localization = "scores/scripts/mods/scores/scores_localization",
		})
	end,
	packages = {},
}



