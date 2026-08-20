local mod = get_mod("Mourningstar_dialogue_improved")

local DialogueBreedSettings = require("scripts/settings/dialogue/dialogue_breed_settings")
local DialogueCategoryConfig = require("scripts/settings/dialogue/dialogue_category_config")
local DialogueEventQueue = require("scripts/extension_systems/dialogue/dialogue_event_queue")
local DialogueLookupContexts = require("scripts/settings/dialogue/dialogue_lookup_contexts")
local DialogueQueryQueue = require("scripts/extension_systems/dialogue/dialogue_query_queue")
local DialogueSettings = require("scripts/settings/dialogue/dialogue_settings")
local DialogueSystemSubtitle = require("scripts/extension_systems/dialogue/dialogue_system_subtitle")
local DialogueSystemWwise = require("scripts/extension_systems/dialogue/dialogue_system_wwise")
local NetworkLookup = require("scripts/network_lookup/network_lookup")

local DialogueSystem = require("scripts/extension_systems/dialogue/dialogue_system")

local HudElementMissionSpeakerPopup =
	require("scripts/ui/hud/elements/mission_speaker_popup/hud_element_mission_speaker_popup")
local DialogueSpeakerVoiceSettings = require("scripts/settings/dialogue/dialogue_speaker_voice_settings")

local player_manager = Managers.player

local function _dialogue_extension()
	local player = player_manager:local_player(1)

	if player == nil or player.player_unit == nil then
		return
	end

	local dialogue_extension = ScriptUnit.extension(player.player_unit, "dialogue_system")

	return dialogue_extension
end

local function _play_selected_sound_event(self, extension, sound_event, dialogue)
	custom_extension = _dialogue_extension()

	-- Do not play dialogue if the player is in a cutscene. (prevents overlapping audio issues)
	local ui_manager = Managers.ui
	local active_views = ui_manager:active_views()

	for i, view in pairs(active_views) do
		if view == "cutscene_view" or view == "video_view" then
			return
		end
	end

	if custom_extension then
		local game_mode_name = Managers.state.game_mode:game_mode_name()

		-- remove any dialogue filters from player's helmet (janky but works ;))
		custom_extension._voice_fx_preset = 0

		-- set route to player
		local wwise_route = self._wwise_routes[3]

		local vo_event = {
			sound_event = nil,
			type = "vorbis_external",
			wwise_route = nil,
			sound_event = sound_event,
			wwise_route = wwise_route,
		}

		custom_extension:play_event(vo_event)
	end
end

DialogueSystem._play_dialogue_event_implementation = function(
	self,
	go_id,
	is_level_unit,
	level_name_hash,
	dialogue_id,
	dialogue_index,
	dialogue_rule_index,
	optional_query
)
	-- disable dialog completely if wanted...
	local game_mode_name = Managers.state.game_mode:game_mode_name()
	if
		game_mode_name == "hub" and mod:get("disable_mourningstar_chatter") == true
		or mod:get("disable_all_chatter") == true
	then
		return
	end
	---------------------------------------------------------

	local dialogue_actor_unit = Managers.state.unit_spawner:unit(go_id, is_level_unit, level_name_hash)
	local extension = self._unit_to_extension_map[dialogue_actor_unit]

	if not extension then
		return
	end

	local is_a_player = extension:is_a_player()

	if is_a_player and not HEALTH_ALIVE[dialogue_actor_unit] then
		return
	end

	local dialogue_name = NetworkLookup.dialogue_names[dialogue_id]
	local dialogue_template = self._dialogue_templates[dialogue_name]
	local dialogue_category = dialogue_template.category

	-- filter out start of mission radio chatter
	if
		game_mode_name ~= "hub"
		and mod:get("disable_radio_chatter") == true
		and (dialogue_category == "vox_prio_0" or dialogue_category == "vox_prio_1")
	then
		return
	end

	if not self:_is_playable_dialogue_category(dialogue_category) then
		return
	end

	if self:_prevent_on_demand_vo(dialogue_actor_unit, dialogue_category) then
		return
	end

	local is_currently_playing_dialogue = extension:is_currently_playing_dialogue()

	if is_currently_playing_dialogue then
		extension:stop_currently_playing_vo()
	end

	local sound_event, subtitles_event, sound_event_duration =
		extension:get_dialogue_event(dialogue_name, dialogue_index)
	local rule = self._tagquery_database:get_rule(dialogue_rule_index)
	local is_sequence

	if sound_event then
		extension:set_last_query_sound_event(sound_event)
	end

	local dialogue = extension:request_empty_dialogue_table()

	table.merge(dialogue, dialogue_template)

	local speaker_name = extension:get_context().voice_template

	dialogue.speaker_name = speaker_name
	self._speaker_name = speaker_name

	local wwise_route_key = dialogue.wwise_route
	local class_name = extension:get_context().class_name

	if wwise_route_key == 1 then
		self._mission_giver_dialogue_playing = true

		if class_name == "tech_priest" then
			wwise_route_key = 21
		end
	elseif is_a_player and class_name == "cryptic" and wwise_route_key == 0 then
		wwise_route_key = 59
	end

	if not DEDICATED_SERVER then
		local wwise_route = self._wwise_route_default

		if wwise_route_key ~= nil then
			wwise_route = self._wwise_routes[wwise_route_key]
		end

		if not sound_event then
			return
		end

		if rule and (rule.pre_wwise_event or rule.post_wwise_event) then
			dialogue.dialogue_sequence = self:_create_sequence_events_table(
				rule.pre_wwise_event,
				wwise_route,
				sound_event,
				rule.post_wwise_event
			)

			-- If player is in the hub, then change the source of the sound
			local instance = Managers.ui:view_instance(Managers.ui:active_top_view())
			local game_mode_name = Managers.state.game_mode:game_mode_name()

			if game_mode_name == "hub" --[[and instance]] then
				dialogue.currently_playing_event_id = _play_selected_sound_event(self, extension, sound_event, dialogue)
			else
				dialogue.currently_playing_event_id = extension:play_event(dialogue.dialogue_sequence[1])
			end

			is_sequence = true
		else
			local vo_event = {
				sound_event = nil,
				type = "vorbis_external",
				wwise_route = nil,
				sound_event = sound_event,
				wwise_route = wwise_route,
			}

			dialogue.currently_playing_event_id = extension:play_event(vo_event)
			is_sequence = false
		end

		local concurrent_wwise_event = rule and rule.concurrent_wwise_event

		if concurrent_wwise_event then
			dialogue.concurrent_wwise_event_id = self:play_wwise_event(extension, concurrent_wwise_event)
		end

		local distance_culled_wwise_routes = DialogueSettings.distance_culled_wwise_routes
		local subtitle_distance = distance_culled_wwise_routes[wwise_route_key]

		if subtitle_distance then
			dialogue.subtitle_distance = subtitle_distance
			dialogue.is_audible = self:is_dialogue_audible(dialogue_actor_unit, dialogue)
		else
			dialogue.is_audible = true
		end

		local animation_event = "start_talking"

		self:_trigger_face_animation_event(dialogue_actor_unit, animation_event)
	end

	self._playing_units[dialogue_actor_unit] = extension
	dialogue.currently_playing_unit = dialogue_actor_unit
	dialogue.dialogue_timer = sound_event_duration
	dialogue.currently_playing_subtitle = subtitles_event
	dialogue.used_query = optional_query

	extension:set_is_currently_playing_dialogue(true)

	local category_config = DialogueCategoryConfig[dialogue_category]

	self._playing_dialogues[dialogue] = category_config

	table.insert(self._playing_dialogues_array, 1, dialogue)

	local sequence_table = dialogue.dialogue_sequence

	if sequence_table ~= nil and sequence_table[1].type == "vorbis_external" or not is_sequence then
		self._dialogue_system_subtitle:add_playing_localized_dialogue(speaker_name, dialogue)
	end

	if is_sequence == true then
		mod.updateCustomRadio(self)
	end
end

mod:hook_safe(CLASS.DialogueSystem, "update", function(self, context, dt, t)
	mod.updateCheck(self, dt)
end)

-- Cleanup dialogue and UI on mission load to prevent infinite loading screens (hopefully)
mod:hook_safe(CLASS.StateLoading, "on_enter", function(self, ...)
	local dialogue_extension = _dialogue_extension()
	if dialogue_extension and dialogue_extension:is_currently_playing_dialogue() then
		dialogue_extension:stop_currently_playing_vo()
	end
	mod.playing_dialogue = nil
	mod.hideCustomRadio()
end)

mod.playing_dialogue = nil

mod.updateCheck = function(self, dt)
	mod.hideCustomRadio()

	if mod.playing_dialogue then
		mod.showCustomRadio()
		mod.playing_dialogue.dialogue_timer = mod.playing_dialogue.dialogue_timer or 4

		if mod.playing_dialogue.dialogue_timer then
			mod.playing_dialogue.dialogue_timer = mod.playing_dialogue.dialogue_timer - (dt / 3)

			if mod.playing_dialogue.dialogue_timer <= 0 then
				-- remove finished dialogue subtitles
				self:_remove_stopped_dialogue(mod.playing_dialogue.currently_playing_unit, mod.playing_dialogue)

				mod.playing_dialogue = nil
				mod.hideCustomRadio()
			end

			mod.updateCustomRadio(self, dt)
		end
	else
		mod.hideCustomRadio()
	end
end

mod.updateCustomRadio = function(self, dt)
	local instance = Managers.ui:view_instance(Managers.ui:active_top_view())

	if #self._playing_dialogues_array > 0 then
		mod.playing_dialogue = self._playing_dialogues_array[1]
	end

	if instance then
		if mod.playing_dialogue and mod.playing_dialogue ~= nil then
			local speaker_name = mod.playing_dialogue.speaker_name
			local mission_giver_icon
			local mission_giver_full_name_localized

			if speaker_name then
				local speaker_voice_settings = DialogueSpeakerVoiceSettings[speaker_name]
				mission_giver_icon = speaker_voice_settings and speaker_voice_settings.icon
				local mission_giver_full_name = speaker_voice_settings and speaker_voice_settings.full_name
					or "++REDACTED++"
				if mission_giver_full_name then
					mission_giver_full_name_localized = instance:_localize(mission_giver_full_name)
				end
			end

			mod.customradio_update_widget(mission_giver_full_name_localized, mission_giver_icon, dt)
		else
			mod.customradio_update_widget(nil, nil, dt)
		end
	end
end

mod.showCustomRadio = function()
	local instance = Managers.ui:view_instance(Managers.ui:active_top_view())

	if instance then
		local widgets_by_name = instance._widgets_by_name

		if widgets_by_name then
			for name, widget in pairs(widgets_by_name) do
				if widget.scenegraph_id == "custom_radio_background" then
					widget.visible = true
				end
			end
		end
	end
end

mod.hideCustomRadio = function()
	local active_views = Managers.ui:active_views()

	for i, view in pairs(active_views) do
		local instance = Managers.ui:view_instance(view)
		if instance then
			local widgets_by_name = instance._widgets_by_name

			if widgets_by_name then
				for name, widget in pairs(widgets_by_name) do
					if widget.scenegraph_id == "custom_radio_background" then
						widget.visible = false
					end
				end
			end
		end
	end
end

local WwiseGameSyncSettings = require("scripts/settings/wwise_game_sync/wwise_game_sync_settings")
local HudElementMissionSpeakerPopupDefinitions =
	require("scripts/ui/hud/elements/mission_speaker_popup/hud_element_mission_speaker_popup_definitions")
local HudElementMissionSpeakerPopupSettings =
	require("scripts/ui/hud/elements/mission_speaker_popup/hud_element_mission_speaker_popup_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")

mod.updatetimer = 0

mod.customradio_update_widget = function(name_text, icon, dt)
	local instance = Managers.ui:view_instance(Managers.ui:active_top_view())

	if instance and name_text then
		local widgets_by_name = instance._widgets_by_name

		if widgets_by_name and widgets_by_name.custom_radio_name_text then
			widgets_by_name.custom_radio_name_text.content.custom_radio_name_text = name_text
			widgets_by_name.custom_radio_popup.style.custom_radio_portrait.material_values.main_texture = icon
				or "content/ui/textures/icons/npc_portraits/mission_givers/default"

			widgets_by_name.custom_radio_popup.style.custom_radio_portrait.material_values.distortion = 0.4

			-- update bars
			local num_bars = HudElementMissionSpeakerPopupSettings.bar_amount
			local bar_offset = HudElementMissionSpeakerPopupSettings.bar_offset
			local bar_size = HudElementMissionSpeakerPopupSettings.bar_size
			local bar_spacing = HudElementMissionSpeakerPopupSettings.bar_spacing
			local bar_widgets = {}

			for i = 1, num_bars do
				local name = "custom_radio_bar_" .. i
				local widget = widgets_by_name[name]

				widget.offset = {
					bar_offset[1] - (bar_size[1] + bar_spacing) * (i - 1),
					bar_offset[2],
					bar_offset[3],
				}
				bar_widgets[i] = widget
			end

			instance._bar_widgets = bar_widgets

			if mod.updatetimer > 1 then
				mod.update_bar_value(instance)
				mod.updatetimer = 0
			else
				if dt then
					mod.updatetimer = mod.updatetimer + (dt * 3)
				else
					mod.updatetimer = mod.updatetimer + 0.1
				end
			end
		end
	elseif instance then
		local widgets_by_name = instance._widgets_by_name

		if widgets_by_name and widgets_by_name.custom_radio_name_text and widgets_by_name.custom_radio_popup then
			widgets_by_name.custom_radio_name_text.content.custom_radio_name_text = "++REDACTED++"
			widgets_by_name.custom_radio_popup.style.custom_radio_portrait.material_values.main_texture =
				"content/ui/textures/icons/npc_portraits/mission_givers/default"
			widgets_by_name.custom_radio_popup.style.custom_radio_portrait.material_values.distortion = 1
		end
	end
end

mod.update_bar_value = function(instance)
	local bar_widgets = instance._bar_widgets
	local num_bars = #bar_widgets
	local next_bar_index = math.index_wrapper((instance._previous_bar_index or 0) + 1, num_bars)
	local anim_progress =
		math.min((1 + math.sin(Application.time_since_launch() * 6) * 0.03) * math.random_range(0.3, 0.8), 1)
	local bar_size = HudElementMissionSpeakerPopupSettings.bar_size
	local bar_height = bar_size[2]

	for i = num_bars, 1, -1 do
		local new_bar_height

		if i > 1 then
			new_bar_height = bar_widgets[i - 1].style.bar.size[2]
		else
			new_bar_height = bar_height * anim_progress
		end

		local widget = bar_widgets[i]

		widget.style.bar.size[2] = new_bar_height
	end

	instance._previous_bar_index = next_bar_index
end

local add_definitions = function(definitions)
	if not definitions then
		return
	end

	local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

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
			visible = false,
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
		visible = false,
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
			visible = false,
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
		},
		{
			pass_type = "texture",
			style_id = "custom_radio_frame",
			visible = false,
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
		},
	}, "custom_radio_background")

	definitions.widget_definitions.custom_radio_name_text = UIWidget.create_definition({
		{
			pass_type = "text",
			style_id = "custom_radio_name_text",
			visible = false,
			value = "<name_text>",
			value_id = "custom_radio_name_text",
			style = name_text_style,
		},
	}, "custom_radio_background")

	definitions.widget_definitions.custom_radio_title_text = UIWidget.create_definition({
		{
			pass_type = "text",
			style_id = "custom_radio_title_text",
			visible = false,
			value_id = "custom_radio_title_text",
			value = Localize("loc_mission_speaker_title_text"),
			style = title_text_style,
		},
	}, "custom_radio_background")

	definitions.widget_definitions.custom_radio_radio = UIWidget.create_definition({
		{
			pass_type = "texture",
			style_id = "custom_radio_soundwave",
			visible = false,
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
		},
	}, "custom_radio_background")

	local num_bars = HudElementMissionSpeakerPopupSettings.bar_amount

	for i = 1, num_bars do
		local name = "custom_radio_bar_" .. i

		definitions.widget_definitions[name] = UIWidget.create_definition({
			{
				pass_type = "texture",
				style_id = "background",
				visible = false,
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
			},
			{
				pass_type = "texture",
				style_id = "bar",
				visible = false,
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
			},
			{
				pass_type = "texture",
				style_id = "frame",
				visible = false,
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
			},
		}, "custom_radio_background")
	end
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

mod:hook_require("scripts/ui/views/barber_vendor_background_view/barber_vendor_background_view_definitions", function(definitions)
	add_definitions(definitions)
end)

mod:hook_require("scripts/ui/views/character_appearance_view/character_appearance_view_definitions", function(definitions)
	add_definitions(definitions)
end)