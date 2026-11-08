local mod = get_mod("Mourningstar_dialogue_improved")

local WwiseGameSyncSettings = require("scripts/settings/wwise_game_sync/wwise_game_sync_settings")
local HudElementMissionSpeakerPopupDefinitions =
	require("scripts/ui/hud/elements/mission_speaker_popup/hud_element_mission_speaker_popup_definitions")
local HudElementMissionSpeakerPopupSettings =
	require("scripts/ui/hud/elements/mission_speaker_popup/hud_element_mission_speaker_popup_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local HudElementMissionSpeakerPopup =
	require("scripts/ui/hud/elements/mission_speaker_popup/hud_element_mission_speaker_popup")
local DialogueSpeakerVoiceSettings = require("scripts/settings/dialogue/dialogue_speaker_voice_settings")

local save_data = Managers.save and Managers.save:account_data()
local interface_settings = save_data and save_data.interface_settings

mod:hook_require(
	"scripts/ui/hud/elements/mission_speaker_popup/hud_element_mission_speaker_popup_definitions",
	function(definitions)
		local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
		local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
		local UIWidget = require("scripts/managers/ui/ui_widget")

		definitions.scenegraph_definition = definitions.scenegraph_definition or {}
		definitions.scenegraph_definition.custom_radio_subtitle = definitions.scenegraph_definition.custom_radio_subtitle
			or {
				horizontal_alignment = "center",
				parent = "screen",
				vertical_alignment = "bottom",
				size = {
					800,
					100,
				},
				position = {
					0,
					-200,
					999,
				},
			}

		local subtitle_text_style = table.clone(UIFontSettings.body)

		subtitle_text_style.horizontal_alignment = "center"
		subtitle_text_style.vertical_alignment = "center"
		subtitle_text_style.text_horizontal_alignment = "center"
		subtitle_text_style.text_vertical_alignment = "center"
		subtitle_text_style.offset = {
			0,
			0,
			2,
		}
		subtitle_text_style.text_color = {
			255,
			255,
			255,
			255,
		}
		subtitle_text_style.size = {
			800,
			100,
		}
		subtitle_text_style.drop_shadow = true
		--[[
		definitions.widget_definitions = definitions.widget_definitions or {}
		definitions.widget_definitions.custom_radio_subtitle = UIWidget.create_definition({
			{
				pass_type = "text",
				style_id = "text",
				value_id = "custom_radio_subtitle",
				value = "",
				style = subtitle_text_style,
			},
		}, "custom_radio_subtitle")

		definitions.widget_definitions.custom_radio_subtitle_background = UIWidget.create_definition({
			{
				pass_type = "rect",
				style_id = "rect",
				style = {
					color = {
						0,
						0,
						0,
						0,
					},
					horizontal_alignment = "center",
					vertical_alignment = "center",
					size = {
						800,
						100,
					},
				},
			},
		}, "custom_radio_subtitle")]]
	end
)

local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local add_definitions = function(definitions)
	if not definitions then
		return
	end

	definitions.scenegraph_definition = definitions.scenegraph_definition or {}
	definitions.widget_definitions = definitions.widget_definitions or {}
	definitions.scenegraph_definition.screen = definitions.scenegraph_definition.screen or UIWorkspaceSettings.screen
	definitions.scenegraph_definition.custom_radio_canvas = definitions.scenegraph_definition.custom_radio_canvas
		or {
			horizontal_alignment = "center",
			parent = "screen",
			vertical_alignment = "center",
			size = {
				1920,
				1080,
			},
			position = {
				0,
				0,
				99,
			},
		}

	-- Add custom definition for in-view radio popup
	local portrait_size = HudElementMissionSpeakerPopupSettings.portrait_size

	local name_text_style = table.clone(UIFontSettings.hud_body)

	name_text_style.horizontal_alignment = "right"
	name_text_style.vertical_alignment = "top"
	name_text_style.text_horizontal_alignment = "right"
	name_text_style.text_vertical_alignment = "bottom"
	name_text_style.size = {
		650,
		40,
	}
	name_text_style.offset = {
		-(portrait_size[1] + 20),
		15,
		100,
	}
	name_text_style.drop_shadow = true
	name_text_style.font_size = 24

	local title_text_style = table.clone(name_text_style)

	title_text_style.offset = {
		-(portrait_size[1] + 20),
		-10,
		100,
	}
	title_text_style.text_color = UIHudSettings.color_tint_main_2

	definitions.scenegraph_definition.custom_radio_background = {
		horizontal_alignment = "right",
		parent = "custom_radio_canvas",
		vertical_alignment = "top",
		size = portrait_size,
		position = {
			-50,
			300,
			100,
		},
	}

	definitions.widget_definitions.custom_radio_popup = UIWidget.create_definition({
		{
			pass_type = "texture",
			style_id = "custom_radio_portrait",
			value = "content/ui/materials/base/ui_radio_portrait_base",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "top",
				offset = {
					-1,
					0,
					99,
				},
				color = {
					255,
					255,
					255,
					255,
				},
				material_values = {
					distortion = 1,
				},
			},
			visibility_function = function(content)
				return mod.enabled and mod.showRadio
			end,
		},
		{
			pass_type = "texture",
			style_id = "custom_radio_frame",
			value = "content/ui/materials/hud/backgrounds/weapon_frame",
			style = {
				horizontal_alignment = "right",
				vertical_alignment = "center",
				color = UIHudSettings.color_tint_main_3,
				offset = {
					0,
					0,
					100,
				},
				size_addition = {
					8,
					5,
				},
			},
			visibility_function = function(content)
				return mod.enabled and mod.showRadio
			end,
		},
	}, "custom_radio_background")

	definitions.widget_definitions.custom_radio_name_text = UIWidget.create_definition({
		{
			pass_type = "text",
			style_id = "custom_radio_name_text",
			value = "",
			value_id = "custom_radio_name_text",
			style = name_text_style,
			visibility_function = function(content)
				return mod.enabled and mod.showRadio
			end,
		},
	}, "custom_radio_background")

	definitions.widget_definitions.custom_radio_title_text = UIWidget.create_definition({
		{
			pass_type = "text",
			style_id = "custom_radio_title_text",
			value_id = "custom_radio_title_text",
			value = Localize("loc_mission_speaker_title_text"),
			style = title_text_style,
			visibility_function = function(content)
				return mod.enabled and mod.showRadio
			end,
		},
	}, "custom_radio_background")

	definitions.widget_definitions.custom_radio_radio = UIWidget.create_definition({
		{
			pass_type = "texture",
			style_id = "custom_radio_soundwave",
			value = "content/ui/materials/icons/hud/radio",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "top",
				size = {
					64,
					32,
				},
				offset = {
					-250,
					55,
					100,
				},
				color = UIHudSettings.color_tint_main_2,
			},
			visibility_function = function(content)
				return mod.enabled and mod.showRadio
			end,
		},
	}, "custom_radio_background")

	local num_bars = HudElementMissionSpeakerPopupSettings.bar_amount

	for i = 1, num_bars do
		local name = "custom_radio_bar_" .. i

		definitions.widget_definitions[name] = UIWidget.create_definition({
			{
				pass_type = "texture",
				style_id = "background",
				value = "content/ui/materials/backgrounds/default_square",
				style = {
					horizontal_alignment = "center",
					vertical_alignment = "bottom",
					size = HudElementMissionSpeakerPopupSettings.bar_size,
					color = UIHudSettings.color_tint_main_4,
					offset = {
						0,
						0,
						98,
					},
				},
				visibility_function = function(content)
					return mod.enabled and mod.showRadio
				end,
			},
			{
				pass_type = "texture",
				style_id = "bar",
				value = "content/ui/materials/backgrounds/default_square",
				style = {
					horizontal_alignment = "center",
					vertical_alignment = "bottom",
					size = HudElementMissionSpeakerPopupSettings.bar_size,
					color = UIHudSettings.color_tint_main_2,
					offset = {
						0,
						0,
						99,
					},
				},
				visibility_function = function(content)
					return mod.enabled and mod.showRadio
				end,
			},
			{
				pass_type = "texture",
				style_id = "frame",
				value = "content/ui/materials/frames/line_light",
				style = {
					horizontal_alignment = "center",
					vertical_alignment = "bottom",
					size = HudElementMissionSpeakerPopupSettings.bar_size,
					color = UIHudSettings.color_tint_main_3,
					size_addition = {
						4,
						4,
					},
					offset = {
						0,
						2,
						100,
					},
				},
				visibility_function = function(content)
					return mod.enabled and mod.showRadio
				end,
			},
		}, "custom_radio_background")
	end

	-- Subtitle widget on screens with custom radio
	definitions.scenegraph_definition.custom_radio_subtitle = definitions.scenegraph_definition.custom_radio_subtitle
		or {
			horizontal_alignment = "center",
			parent = "screen",
			vertical_alignment = "bottom",
			size = {
				800,
				100,
			},
			position = {
				0,
				-200,
				101,
			},
		}

	local subtitle_text_style = table.clone(UIFontSettings.body)

	subtitle_text_style.horizontal_alignment = "center"
	subtitle_text_style.vertical_alignment = "center"
	subtitle_text_style.text_horizontal_alignment = "center"
	subtitle_text_style.text_vertical_alignment = "center"
	subtitle_text_style.offset = {
		0,
		0,
		2,
	}
	subtitle_text_style.text_color = {
		interface_settings and interface_settings.subtitle_text_opacity * 255 or 255,
		255,
		255,
		255,
	}
	subtitle_text_style.size = {
		1000,
		100,
	}
	subtitle_text_style.drop_shadow = true

	subtitle_text_style.font_size = interface_settings and interface_settings.subtitle_font_size or 14

	definitions.widget_definitions.custom_radio_subtitle = UIWidget.create_definition({
		{
			pass_type = "text",
			style_id = "text",
			value_id = "custom_radio_subtitle",
			value = "",
			style = subtitle_text_style,
			visibility_function = function(content)
				return mod.enabled and mod.showRadio and mod.subtitle_active
			end,
		},
	}, "custom_radio_subtitle")

	definitions.widget_definitions.custom_radio_subtitle_background = UIWidget.create_definition({
		{
			pass_type = "rect",
			style_id = "rect",
			style = {
				color = {
					0,
					0,
					0,
					0,
				},
				horizontal_alignment = "center",
				vertical_alignment = "center",
				size = {
					800,
					100,
				},
			},
			visibility_function = function(content)
				return mod.enabled and mod.showRadio and mod.subtitle_active
			end,
		},
	}, "custom_radio_subtitle")
end

-- add custom radio widget to specific views (wanted to be able to pick and choose ;))
mod:hook_require("scripts/ui/views/inventory_view/inventory_view_definitions", function(definitions)
	add_definitions(definitions)
end)

mod:hook_require(
	"scripts/ui/views/inventory_background_view/inventory_background_view_definitions",
	function(definitions)
		add_definitions(definitions)
	end
)

mod:hook_require("scripts/ui/views/masteries_overview_view/masteries_overview_view_definitions", function(definitions)
	add_definitions(definitions)
end)

mod:hook_require("scripts/ui/views/mastery_view/mastery_view_definitions", function(definitions)
	add_definitions(definitions)
end)

mod:hook_require("scripts/ui/views/inventory_cosmetics_view/inventory_cosmetics_view_definitions", function(definitions)
	add_definitions(definitions)
end)

mod:hook_require("scripts/ui/views/inventory_weapons_view/inventory_weapons_view_definitions", function(definitions)
	add_definitions(definitions)
end)

mod:hook_require(
	"scripts/ui/views/inventory_weapon_cosmetics_view/inventory_weapon_cosmetics_view_definitions",
	function(definitions)
		add_definitions(definitions)
	end
)

mod:hook_require(
	"scripts/ui/views/inventory_weapon_details_view/inventory_weapon_details_view_definitions",
	function(definitions)
		add_definitions(definitions)
	end
)

mod:hook_require(
	"scripts/ui/views/inventory_weapon_marks_view/inventory_weapon_marks_view_definitions",
	function(definitions)
		add_definitions(definitions)
	end
)

mod:hook_require("scripts/ui/views/crafting_view/crafting_view_definitions", function(definitions)
	add_definitions(definitions)
end)

mod:hook_require(
	"scripts/ui/views/crafting_mechanicus_barter_items_view/crafting_mechanicus_barter_items_view_definitions",
	function(definitions)
		add_definitions(definitions)
	end
)

mod:hook_require(
	"scripts/ui/views/crafting_mechanicus_modify_options_view/crafting_mechanicus_modify_options_view_definitions",
	function(definitions)
		add_definitions(definitions)
	end
)

mod:hook_require(
	"scripts/ui/views/crafting_mechanicus_modify_view/crafting_mechanicus_modify_view_definitions",
	function(definitions)
		add_definitions(definitions)
	end
)

mod:hook_require(
	"scripts/ui/views/crafting_mechanicus_replace_perk_view/crafting_mechanicus_replace_perk_view_definitions",
	function(definitions)
		add_definitions(definitions)
	end
)

mod:hook_require(
	"scripts/ui/views/crafting_mechanicus_replace_trait_view/crafting_mechanicus_replace_trait_view_definitions",
	function(definitions)
		add_definitions(definitions)
	end
)

mod:hook_require(
	"scripts/ui/views/crafting_mechanicus_upgrade_expertise_view/crafting_mechanicus_upgrade_expertise_view_definitions",
	function(definitions)
		add_definitions(definitions)
	end
)

mod:hook_require(
	"scripts/ui/views/crafting_mechanicus_upgrade_item_view/crafting_mechanicus_upgrade_item_view_definitions",
	function(definitions)
		add_definitions(definitions)
	end
)

mod:hook_require("scripts/ui/views/cosmetics_vendor_view/cosmetics_vendor_view_definitions", function(definitions)
	add_definitions(definitions)
end)

mod:hook_require(
	"scripts/ui/views/cosmetics_vendor_background_view/cosmetics_vendor_background_view_definitions",
	function(definitions)
		add_definitions(definitions)
	end
)

mod:hook_require("scripts/ui/views/cosmetics_inspect_view/cosmetics_inspect_view_definitions", function(definitions)
	add_definitions(definitions)
end)

mod:hook_require("scripts/ui/views/contracts_view/contracts_view_definitions", function(definitions)
	add_definitions(definitions)
end)

mod:hook_require(
	"scripts/ui/views/contracts_background_view/contracts_background_view_definitions",
	function(definitions)
		add_definitions(definitions)
	end
)

mod:hook_require("scripts/ui/views/marks_goods_vendor_view/marks_goods_vendor_view_definitions", function(definitions)
	add_definitions(definitions)
end)

mod:hook_require("scripts/ui/views/marks_vendor_view/marks_vendor_view_definitions", function(definitions)
	add_definitions(definitions)
end)

mod:hook_require(
	"scripts/ui/views/credits_goods_vendor_view/credits_goods_vendor_view_definitions",
	function(definitions)
		add_definitions(definitions)
	end
)

mod:hook_require(
	"scripts/ui/views/credits_vendor_background_view/credits_vendor_background_view_definitions",
	function(definitions)
		add_definitions(definitions)
	end
)

mod:hook_require("scripts/ui/views/credits_vendor_view/credits_vendor_view_definitions", function(definitions)
	add_definitions(definitions)
end)

mod:hook_require("scripts/ui/views/penance_overview_view/penance_overview_view_definitions", function(definitions)
	add_definitions(definitions)
end)

mod:hook_require("scripts/ui/views/store_view/store_view_definitions", function(definitions)
	add_definitions(definitions)
end)

mod:hook_require("scripts/ui/views/store_item_detail_view/store_item_detail_view_definitions", function(definitions)
	add_definitions(definitions)
end)

mod:hook_require("scripts/ui/views/mastery_view/mastery_view_definitions", function(definitions)
	add_definitions(definitions)
end)

mod:hook_require("scripts/ui/views/masteries_overview_view/masteries_overview_view_definitions", function(definitions)
	add_definitions(definitions)
end)

mod:hook_require("scripts/ui/views/live_events_view/live_events_view_definitions", function(definitions)
	add_definitions(definitions)
end)

mod:hook_require(
	"scripts/ui/views/player_character_options_view/player_character_options_view_definitions",
	function(definitions)
		add_definitions(definitions)
	end
)

mod:hook_require(
	"scripts/ui/views/barber_vendor_background_view/barber_vendor_background_view_definitions",
	function(definitions)
		add_definitions(definitions)
	end
)

mod:hook_require(
	"scripts/ui/views/character_appearance_view/character_appearance_view_definitions",
	function(definitions)
		add_definitions(definitions)
	end
)
