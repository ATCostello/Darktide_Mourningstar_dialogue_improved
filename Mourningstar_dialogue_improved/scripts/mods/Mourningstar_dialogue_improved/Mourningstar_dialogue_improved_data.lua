local mod = get_mod("Mourningstar_dialogue_improved")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {

			{
				setting_id = "general_settings",
				type = "group",

				sub_widgets = {
					{
						setting_id = "mod_name_pizazz_toggle",
						type = "checkbox",
						default_value = true,
						tooltip = "mod_name_pizazz_tooltip",
					},
					{

						setting_id = "disable_mourningstar_chatter",
						type = "checkbox",
						default_value = false,
						tooltip = "disable_mourningstar_chatter_tooltip",
					},
					{

						setting_id = "disable_radio_chatter",
						type = "checkbox",
						default_value = false,
						tooltip = "disable_radio_chatter_tooltip",
					},
					{

						setting_id = "disable_all_chatter",
						type = "checkbox",
						default_value = false,
						tooltip = "disable_all_chatter_tooltip",
					},
				},
			},
		},
	},
}
