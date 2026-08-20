return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Mourningstar_dialogue_improved` encountered an error loading the Darktide Mod Framework.")

		new_mod("Mourningstar_dialogue_improved", {
			mod_script       = "Mourningstar_dialogue_improved/scripts/mods/Mourningstar_dialogue_improved/Mourningstar_dialogue_improved",
			mod_data         = "Mourningstar_dialogue_improved/scripts/mods/Mourningstar_dialogue_improved/Mourningstar_dialogue_improved_data",
			mod_localization = "Mourningstar_dialogue_improved/scripts/mods/Mourningstar_dialogue_improved/Mourningstar_dialogue_improved_localization",
		})
	end,
	packages = {},
}
