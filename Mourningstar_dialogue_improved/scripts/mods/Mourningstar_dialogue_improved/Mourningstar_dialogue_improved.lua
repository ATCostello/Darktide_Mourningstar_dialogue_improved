local mod = get_mod("Mourningstar_dialogue_improved")
mod.enabled = mod:is_enabled()

mod:io_dofile(
	"Mourningstar_dialogue_improved/scripts/mods/Mourningstar_dialogue_improved/utils/custom_radio_definitions"
)

local DialogueBreedSettings = require("scripts/settings/dialogue/dialogue_breed_settings")
local DialogueCategoryConfig = require("scripts/settings/dialogue/dialogue_category_config")
local DialogueEventQueue = require("scripts/extension_systems/dialogue/dialogue_event_queue")
local DialogueLookupContexts = require("scripts/settings/dialogue/dialogue_lookup_contexts")
local DialogueQueryQueue = require("scripts/extension_systems/dialogue/dialogue_query_queue")
local DialogueSettings = require("scripts/settings/dialogue/dialogue_settings")
local DialogueSystemSubtitle = require("scripts/extension_systems/dialogue/dialogue_system_subtitle")
local DialogueSystemWwise = require("scripts/extension_systems/dialogue/dialogue_system_wwise")
local NetworkLookup = require("scripts/network_lookup/network_lookup")
local WwiseGameSyncSettings = require("scripts/settings/wwise_game_sync/wwise_game_sync_settings")
local HudElementMissionSpeakerPopupDefinitions =
	require("scripts/ui/hud/elements/mission_speaker_popup/hud_element_mission_speaker_popup_definitions")
local HudElementMissionSpeakerPopupSettings =
	require("scripts/ui/hud/elements/mission_speaker_popup/hud_element_mission_speaker_popup_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local DialogueSystem = require("scripts/extension_systems/dialogue/dialogue_system")
local HudElementMissionSpeakerPopup =
	require("scripts/ui/hud/elements/mission_speaker_popup/hud_element_mission_speaker_popup")
local DialogueSpeakerVoiceSettings = require("scripts/settings/dialogue/dialogue_speaker_voice_settings")

local player_manager = Managers.player

mod.showRadio = false
mod.playing_dialogue = nil
mod.subtitle_active = false

local function _dialogue_extension()
	if not player_manager or not player_manager.local_player then
		return
	end

	local player = player_manager:local_player(1)

	if player == nil or player.player_unit == nil then
		return
	end

	local ok, dialogue_extension = pcall(ScriptUnit.extension, player.player_unit, "dialogue_system")
	if not ok then
		return
	end

	return dialogue_extension
end

local function _game_time()
	local time_manager = Managers and Managers.time

	if not time_manager then
		return
	end

	local ok, time = pcall(time_manager.time, time_manager, "gameplay")

	if ok then
		return time
	end
end

local function should_disable_and_is_vocator(dialogue)
	if
		dialogue.category
		and dialogue.category ~= "npc_prio_0"
		and dialogue.speaker_name
		and (string.match(dialogue.speaker_name, "vocator_[a-z]") or string.match(
			dialogue.speaker_name,
			"mourningstar_servitor_[a-z]"
		))
		and mod:get("disable_vocator_updates")
	then
		return true
	else
		return false
	end
	return false
end

local function should_disable_and_is_mission_update(dialogue)
	if
		dialogue.category
		and dialogue.category == "npc_prio_0"
		and dialogue.speaker_name
		and string.match(dialogue.speaker_name, "mourningstar_servitor_[a-z]")
		and mod:get("disable_mission_update_chatter")
	then
		return true
	else
		return false
	end
	return false
end

local function _play_selected_sound_event(self, extension, sound_event, dialogue)
	if dialogue and dialogue.skipped then
		return
	end

	custom_extension = _dialogue_extension()

	-- Do not play dialogue if the player is in a cutscene. (prevents overlapping audio issues)
	local ui_manager = Managers.ui
	local active_views = ui_manager and ui_manager:active_views() or {}

	for i, view in pairs(active_views) do
		if view == "cutscene_view" or view == "video_view" then
			return
		end
	end

	if custom_extension then
		local game_mode_name = (Managers.state and Managers.state.game_mode)
			and Managers.state.game_mode:game_mode_name()

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

		dialogue.vo_event = vo_event
		dialogue.audible_in_menu = true -- custom variable to show it's using my own playback route

		custom_extension:play_event(vo_event)
	end
end

mod.updateCustomRadio = function(self, dt)
	local playing_dialogues_array = self._playing_dialogues_array or {}
	local instance = nil

	if Managers.ui and Managers.ui.active_top_view then
		local active_top_view = Managers.ui:active_top_view()
		instance = active_top_view and Managers.ui:view_instance(active_top_view)
	end

	local game_mode_manager = Managers.state and Managers.state.game_mode
	local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name()

	if instance then
		if game_mode_name == "hub" and mod.playing_dialogue and mod.playing_dialogue ~= nil then
			mod.showRadio = true

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

mod.past_dialogue = {}
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
	local game_mode_manager = Managers.state and Managers.state.game_mode
	local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name()

	-- disable dialog completely if wanted...
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
	local dialogue_template = self._dialogue_templates and self._dialogue_templates[dialogue_name]
	if not dialogue_template then
		return
	end
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

	local rule = self._tagquery_database:get_rule(dialogue_rule_index)

	if rule and self._heard_speak_disabled then
		local concept = rule.criterias[1][4]

		if concept == "heard_speak" then
			if game_mode_name ~= "hub" then
				return
			end
		else
			self._heard_speak_disabled = false
		end
	end

	local is_currently_playing_dialogue = extension:is_currently_playing_dialogue()

	if is_currently_playing_dialogue then
		extension:stop_currently_playing_vo()
	end

	local sound_event, subtitles_event, sound_event_duration =
		extension:get_dialogue_event(dialogue_name, dialogue_index)
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

		local skip_menu_inclusion = false
		local instance = Managers.ui:view_instance(Managers.ui:active_top_view())

		local distance_culled_wwise_routes = DialogueSettings.distance_culled_wwise_routes
		local subtitle_distance = distance_culled_wwise_routes[wwise_route_key]

		if subtitle_distance then
			dialogue.subtitle_distance = subtitle_distance
			dialogue.is_audible = self:is_dialogue_audible(dialogue_actor_unit, dialogue)
		else
			dialogue.is_audible = true
		end

		if instance and not skip_menu_inclusion and not dialogue.is_audible then
			skip_menu_inclusion = true
			dialogue.skip_reason = "Inaudible"
		end

		if
			instance
			and not skip_menu_inclusion
			and sound_event
			and sound_event
			and string.match(sound_event, ".concourse_exchange.")
		then
			skip_menu_inclusion = true
			dialogue.skip_reason = "Skip vendor chatter"
		end

		if
			instance
			and not skip_menu_inclusion
			and dialogue.category
			and dialogue.category == "npc_prio_0"
			and dialogue.speaker_name
			and not string.match(dialogue.speaker_name, "mourningstar_servitor_[a-z]")
		then
			skip_menu_inclusion = true
			dialogue.skip_reason = "Skip general chatter"
		end

		-- skip mission terminal updates
		if instance and not skip_menu_inclusion and should_disable_and_is_mission_update(dialogue) then
			skip_menu_inclusion = true
			dialogue.skip_reason = "Disable mission updates setting"
		end

		-- skip vocator
		if instance and not skip_menu_inclusion and should_disable_and_is_vocator(dialogue) then
			skip_menu_inclusion = true
			dialogue.skip_reason = "Disable Vocator setting"
		end

		dialogue.skipped = skip_menu_inclusion

		if rule and (rule.pre_wwise_event or rule.post_wwise_event) then
			dialogue.dialogue_sequence = self:_create_sequence_events_table(
				rule.pre_wwise_event,
				wwise_route,
				sound_event,
				rule.post_wwise_event
			)

			-- If player is in the hub, then change the source of the sound
			local game_mode_name = Managers.state.game_mode:game_mode_name()

			if
				instance
				and game_mode_name == "hub"
				and not should_disable_and_is_mission_update(dialogue)
				and not should_disable_and_is_vocator(dialogue)
			then
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

			if
				instance
				and game_mode_name == "hub"
				and not should_disable_and_is_mission_update(dialogue)
				and not should_disable_and_is_vocator(dialogue)
			then
				dialogue.currently_playing_event_id = _play_selected_sound_event(self, extension, sound_event, dialogue)
			else
				dialogue.currently_playing_event_id = extension:play_event(vo_event)
			end

			is_sequence = false
		end

		if instance and not skip_menu_inclusion and dialogue and not dialogue.audible_in_menu then
			skip_menu_inclusion = true
			dialogue.skip_reason = "Inaudible in menus"
		end

		local concurrent_wwise_event = rule and rule.concurrent_wwise_event

		if concurrent_wwise_event then
			dialogue.concurrent_wwise_event_id = self:play_wwise_event(extension, concurrent_wwise_event)
		end

		local animation_event = "start_talking"

		self:_trigger_face_animation_event(dialogue_actor_unit, animation_event)
	end

	self._playing_units[dialogue_actor_unit] = extension
	dialogue.currently_playing_unit = dialogue_actor_unit
	dialogue.dialogue_timer = sound_event_duration or 3
	dialogue.currently_playing_subtitle = subtitles_event
	dialogue.used_query = optional_query

	extension:set_is_currently_playing_dialogue(true)
	local category_config = DialogueCategoryConfig[dialogue_category]

	self._playing_dialogues[dialogue] = category_config

	table.insert(self._playing_dialogues_array, 1, dialogue)

	dialogue.dialogue_start_time = Managers.time and Managers.time:time("main")

	if skip_menu_inclusion or dialogue.skipped then
		--mod:echo("skipped")
	else
		mod.playing_dialogue = dialogue
	end

	table.insert(mod.past_dialogue, dialogue)

	local sequence_table = dialogue.dialogue_sequence

	if sequence_table ~= nil and sequence_table[1].type == "vorbis_external" or not is_sequence then
		self._dialogue_system_subtitle:add_playing_localized_dialogue(speaker_name, dialogue)
	end
end

-- Cleanup dialogue and UI on mission load to prevent infinite loading screens.
mod:hook_safe(CLASS.StateLoading, "on_enter", function(self, ...)
	local dialogue_extension = _dialogue_extension()
	if dialogue_extension and dialogue_extension:is_currently_playing_dialogue() then
		dialogue_extension:stop_currently_playing_vo()
	end
end)

local function _apply_custom_subtitle_style(widgets_by_name, interface_settings, ui_renderer, text)
	local TextUtils = require("scripts/utilities/ui/text")
	local subtitle_widget = widgets_by_name and widgets_by_name.custom_radio_subtitle
	local background_widget = widgets_by_name and widgets_by_name.custom_radio_subtitle_background

	local fingerprint = table.concat({
		text or "",
		tostring(interface_settings and interface_settings.subtitle_font_size),
		tostring(interface_settings and interface_settings.subtitle_text_opacity),
		tostring(interface_settings and interface_settings.subtitle_background_opacity),
	}, "|")

	if subtitle_widget and subtitle_widget._custom_subtitle_style_fingerprint == fingerprint then
		return
	end

	if subtitle_widget then
		local style = subtitle_widget.style.text
		if interface_settings and interface_settings.subtitle_font_size then
			style.font_size = interface_settings.subtitle_font_size
		end
		style.text_color[1] =
			math.floor(255 * ((interface_settings and interface_settings.subtitle_text_opacity or 100) * 0.01))

		if ui_renderer and text and text ~= "" and style.size and style.size[1] then
			local rows = TextUtils.word_wrap(ui_renderer, text, style, style.size and style.size[1])
			local longest_width = 0
			local dummy_size = {
				2000,
				20,
			}
			for i = 1, #rows do
				local row_width = TextUtils.text_size(ui_renderer, rows[i], style, dummy_size)
				if row_width > longest_width then
					longest_width = row_width
				end
			end
			local total_height = TextUtils.text_height(ui_renderer, text, style, style.size)
			local width_padding = style.font_size * 1.5
			local height_padding = style.font_size / 3

			style.size[2] = math.ceil(total_height)

			if background_widget then
				background_widget.style.rect.size[1] = math.ceil(longest_width + width_padding)
				background_widget.style.rect.size[2] = math.ceil(total_height + height_padding)
				local color = background_widget.style.rect.color
				color[1] = math.floor(
					255 * ((interface_settings and interface_settings.subtitle_background_opacity or 100) * 0.01)
				)
			end
		end

		subtitle_widget._custom_subtitle_style_fingerprint = fingerprint
	end
end

local function _is_valid_custom_radio_speaker(speaker_name)
	if not speaker_name then
		return false
	end

	local vs = DialogueSpeakerVoiceSettings[speaker_name]

	if not vs or not vs.full_name then
		return false
	end

	return Managers.localization:exists(vs.full_name)
end

mod:hook_safe(CLASS.DialogueSystem, "update", function(self, context, dt, t)
	self._next_update = self._next_update or 0
	if t < self._next_update then
		return
	end

	self._next_update = t + 0.25

	mod.updateCheck(self, dt)

	local game_mode_manager = Managers.state and Managers.state.game_mode
	local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name()

	if game_mode_name ~= "hub" then
		return
	end

	--[[local spacing = mod:get("mourningstar_chatter_spacing")

	if spacing then
		if not self._mission_settings_override then
			self._mission_settings_override = table.clone(DialogueSettings.mission_dialogue_settings or {})
		end

		local changed = mod._last_mourningstar_chatter_spacing ~= spacing

		if self._mission_settings_override.npc_story_tick_time ~= nil then
			self._mission_settings_override.npc_story_tick_time = spacing
		end

		if changed and self._next_npc_story_line_update_t and self._next_npc_story_line_update_t - t > spacing then
			self._next_npc_story_line_update_t = t + spacing
		end

		mod._last_mourningstar_chatter_spacing = spacing
	end]]
end)

function mod.on_disabled()
	mod.enabled = mod:is_enabled()
	mod.showRadio = false
end

function mod.on_enabled()
	mod.enabled = mod:is_enabled()
	mod.showRadio = false
	mod.subtitle_active = false
end

dbg_mdi = mod

mod.updateCustomSubtitles = function(self, dt)
	local instance = nil

	if Managers.ui and Managers.ui.active_top_view then
		local active_top_view = Managers.ui:active_top_view()
		instance = active_top_view and Managers.ui:view_instance(active_top_view)
	end

	if instance then
		local widgets_by_name = instance._widgets_by_name
		if widgets_by_name and widgets_by_name.custom_radio_subtitle then
			local subtitle_text = ""

			local game_mode_manager = Managers.state and Managers.state.game_mode
			local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name()

			if game_mode_name == "hub" and mod.playing_dialogue and mod:get("show_custom_radio_subtitles") ~= false then
				local save_data = Managers.save and Managers.save:account_data()
				interface_settings = save_data and save_data.interface_settings or interface_settings
				local subtitles_enabled = interface_settings and interface_settings.subtitle_enabled
				local speaker_enabled = interface_settings and interface_settings.subtitle_speaker_enabled

				if subtitles_enabled then
					local dialogue = mod.playing_dialogue
					local subtitle_key = dialogue.currently_playing_subtitle
					local speaker_name = dialogue.speaker_name

					local localized_subtitle

					if subtitle_key and subtitle_key ~= "" then
						local no_cache = true
						local exists = Managers.localization:exists(subtitle_key)

						if exists then
							localized_subtitle = Managers.localization:localize(subtitle_key, no_cache)
						end
					end

					if localized_subtitle and localized_subtitle ~= "" then
						local speaker_display_name

						if speaker_name then
							local speaker_voice_settings = DialogueSpeakerVoiceSettings[speaker_name]
							local short_name = speaker_voice_settings and speaker_voice_settings.short_name

							if short_name then
								speaker_display_name = Managers.localization:localize(short_name)
							end
						end

						local subtitle_format_context = {
							speaker = speaker_display_name,
							subtitle = localized_subtitle,
						}

						local format_key = "loc_subtitle_speaker_format"

						if not speaker_enabled or not speaker_display_name then
							format_key = "loc_subtitle_speaker_format_speakerless"
							subtitle_format_context.speaker = nil
						end

						if Managers.localization:exists(format_key) then
							subtitle_text = Managers.localization:localize(format_key, true, subtitle_format_context)
						else
							if speaker_display_name then
								subtitle_text = speaker_display_name .. ": " .. localized_subtitle
							else
								subtitle_text = localized_subtitle
							end
						end
					end
				end
			end

			widgets_by_name.custom_radio_subtitle.content.custom_radio_subtitle = subtitle_text

			local game_subtitle_text = ""
			local game_subtitles_widgets = mod.get_game_subtitles_widget()

			if
				game_subtitles_widgets
				and game_subtitles_widgets.subtitles
				and game_subtitles_widgets.subtitles.content
			then
				game_subtitle_text = game_subtitles_widgets.subtitles.content.text or ""
			end

			local game_subtitles_on = (#game_subtitle_text > 1) or subtitles_enabled == true or subtitles_enabled == 1
			local show_subtitle = subtitle_text ~= "" and not game_subtitles_on

			widgets_by_name.custom_radio_subtitle.content.custom_radio_subtitle = show_subtitle and subtitle_text or ""
			mod.subtitle_active = show_subtitle

			local ui_renderer = instance._ui_renderer

			_apply_custom_subtitle_style(widgets_by_name, interface_settings, ui_renderer, subtitle_text)
		end
	end
end

mod.updateCheck = function(self, dt)
	local game_mode_manager = Managers.state and Managers.state.game_mode
	local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name()

	if not game_mode_manager or game_mode_name ~= "hub" then
		mod.playing_dialogue = nil
		mod.game_subtitles_widgets = nil
		mod.showRadio = false
		mod.subtitle_active = false
		return
	end

	-- Remove dialogue that has now finished
	if mod.playing_dialogue then
		local time_now = Managers.time and Managers.time:time("main")
		local dialogue_complete_time = time_now

		if mod.playing_dialogue.dialogue_timer and mod.playing_dialogue.dialogue_start_time then
			dialogue_complete_time = mod.playing_dialogue.dialogue_start_time + mod.playing_dialogue.dialogue_timer
				or mod.playing_dialogue.dialogue_start_time
		end

		if time_now > dialogue_complete_time then
			mod.playing_dialogue = nil
			mod.game_subtitles_widgets = nil
			mod.showRadio = false
			mod.subtitle_active = false
		end
	end

	local playing_dialogues_array = self._playing_dialogues_array or {}

	if not mod.playing_dialogue and #playing_dialogues_array > 0 then
		--mod.playing_dialogue = playing_dialogues_array[1]
	end

	if mod.playing_dialogue and not _is_valid_custom_radio_speaker(mod.playing_dialogue.speaker_name) then
		mod.playing_dialogue = nil
		return
	end

	if mod.playing_dialogue then
		mod.updateCustomRadio(self, dt)
		mod.updateCustomSubtitles(self, dt)
	else
		mod.showRadio = false
		mod.subtitle_active = false
	end

	mod.enabled = mod:is_enabled()
end

mod.get_game_subtitles_widget = function()
	local cached = mod.game_subtitles_widgets

	if not (cached and cached.subtitles and cached.subtitles.content) then
		local ui_manager = Managers and Managers.ui
		local uce = ui_manager and ui_manager._ui_constant_elements
		local elem = uce and uce._elements and uce._elements.ConstantElementSubtitles
		cached = elem and elem._widgets_by_name
		mod.game_subtitles_widgets = cached
	end

	return cached
end

mod.customradio_update_widget = function(name_text, icon, dt)
	local game_mode_manager = Managers.state and Managers.state.game_mode
	local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name()
	if game_mode_name ~= "hub" then
		return
	end

	local instance = nil
	if Managers.ui and Managers.ui.active_top_view then
		local active_top_view = Managers.ui:active_top_view()
		instance = active_top_view and Managers.ui:view_instance(active_top_view)
	end

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

				if not widget then
					break
				end

				widget.offset = {
					bar_offset[1] - (bar_size[1] + bar_spacing) * (i - 1),
					bar_offset[2],
					bar_offset[3],
				}
				bar_widgets[i] = widget
			end

			instance._bar_widgets = bar_widgets

			mod.update_bar_value(instance)
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

	-- Subtitle text on custom radio screens
	if instance then
		local widgets_by_name = instance._widgets_by_name

		if widgets_by_name and widgets_by_name.custom_radio_subtitle then
			local subtitle_text = ""

			if mod.playing_dialogue and mod:get("show_custom_radio_subtitles") ~= false then
				local save_data = Managers.save and Managers.save:account_data()
				local interface_settings = save_data and save_data.interface_settings
				local subtitles_enabled = interface_settings and interface_settings.subtitle_enabled
				local speaker_enabled = interface_settings and interface_settings.subtitle_speaker_enabled

				if subtitles_enabled then
					local dialogue = mod.playing_dialogue
					local subtitle_key = dialogue.currently_playing_subtitle
					local speaker_name = dialogue.speaker_name
					local instance_ref = instance

					local localized_subtitle

					if subtitle_key and subtitle_key ~= "" then
						local no_cache = true
						local exists = Managers.localization:exists(subtitle_key)

						if exists then
							localized_subtitle = instance_ref:_localize(subtitle_key, no_cache)
						end
					end

					if localized_subtitle and localized_subtitle ~= "" then
						local speaker_display_name

						if speaker_name then
							local speaker_voice_settings = DialogueSpeakerVoiceSettings[speaker_name]
							local short_name = speaker_voice_settings and speaker_voice_settings.short_name

							if short_name then
								speaker_display_name = instance_ref:_localize(short_name)
							end
						end

						local subtitle_format_context = {
							speaker = speaker_display_name,
							subtitle = localized_subtitle,
						}

						local format_key = "loc_subtitle_speaker_format"

						if not speaker_enabled or not speaker_display_name then
							format_key = "loc_subtitle_speaker_format_speakerless"
							subtitle_format_context.speaker = nil
						end

						if Managers.localization:exists(format_key) then
							subtitle_text = instance_ref:_localize(format_key, true, subtitle_format_context)
						else
							if speaker_display_name then
								subtitle_text = speaker_display_name .. ": " .. localized_subtitle
							else
								subtitle_text = localized_subtitle
							end
						end
					end
				end
			end

			local game_subtitle_text = ""
			local game_subtitles_widgets = mod.get_game_subtitles_widget()
			if
				game_subtitles_widgets
				and game_subtitles_widgets.subtitles
				and game_subtitles_widgets.subtitles.content
			then
				game_subtitle_text = game_subtitles_widgets.subtitles.content.text or ""
			end
			local game_subtitles_on = (#game_subtitle_text > 1) or subtitles_enabled == true or subtitles_enabled == 1
			local show_subtitle = subtitle_text ~= "" and not game_subtitles_on

			widgets_by_name.custom_radio_subtitle.content.custom_radio_subtitle = show_subtitle and subtitle_text or ""
			mod.subtitle_active = show_subtitle
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

-- HUD rendering whenever custom chatter is playing

mod:hook(
	CLASS.HudElementMissionSpeakerPopup,
	"_draw_widgets",
	function(orig, self, dt, t, input_service, ui_renderer, render_settings)
		if not mod.playing_dialogue and not self._mod_chatter_speaker_active then
			local fast_widgets = self._widgets_by_name

			if fast_widgets and fast_widgets.custom_radio_subtitle then
				fast_widgets.custom_radio_subtitle.visible = false

				if fast_widgets.custom_radio_subtitle_background then
					fast_widgets.custom_radio_subtitle_background.visible = false
				end
			end

			orig(self, dt, t, input_service, ui_renderer, render_settings)

			return
		end

		--[[
		local dialogue = mod.playing_dialogue

		local base_radio_active = self._is_speaking and not self._mod_chatter_speaker_active

		if dialogue and not base_radio_active and _is_valid_custom_radio_speaker(dialogue.speaker_name) then
			local speaker_name = dialogue.speaker_name

			if speaker_name and (not self._is_speaking or self._speaker_name ~= speaker_name) then
				self._speaker_name = speaker_name
				self:_mission_speaker_stop()
				self._is_speaking = false

				local speaker_voice_settings = DialogueSpeakerVoiceSettings[speaker_name]
				local mission_giver_icon = speaker_voice_settings and speaker_voice_settings.icon
				local mission_giver_full_name = (speaker_voice_settings and speaker_voice_settings.full_name)
					or "++REDACTED++"
				local mission_giver_full_name_localized = self:_localize(mission_giver_full_name)

				self:_mission_speaker_start(
					mission_giver_full_name_localized,
					mission_giver_icon or "content/ui/textures/icons/npc_portraits/mission_givers/default"
				)
				self._is_speaking = true
				self._mod_chatter_speaker_active = true
			end
		elseif not dialogue and self._mod_chatter_speaker_active then
			self._speaker_name = nil
			self:_mission_speaker_stop()
			self._is_speaking = false
			self._mod_chatter_speaker_active = false
		end]]

		orig(self, dt, t, input_service, ui_renderer, render_settings)
	end
)
