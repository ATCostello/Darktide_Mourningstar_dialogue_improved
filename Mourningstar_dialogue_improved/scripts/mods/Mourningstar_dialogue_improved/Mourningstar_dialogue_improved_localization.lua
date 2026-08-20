local mod = get_mod("Mourningstar_dialogue_improved")
mod.version = "1.2.10"
mod:info("Mourningstar Dialogue Improved is installed, using version: " .. tostring(mod.version))

local colours = {
	title = "200,140,20",
	subtitle = "226,199,126",
	text = "169,191,153",
}

local function lerp(a, b, t)
	return a + (b - a) * t
end

mod.gradientText = function(text, startColor, endColor, colorSpaces)
	local result = ""
	local length = #text
	local visibleIndex = 0

	-- Count visible characters
	for i = 1, length do
		local char = text:sub(i, i)
		if colorSpaces or char ~= " " then
			visibleIndex = visibleIndex + 1
		end
	end

	local currentIndex = 0

	for i = 1, length do
		local char = text:sub(i, i)

		if not colorSpaces and char == " " then
			result = result .. char
		else
			currentIndex = currentIndex + 1
			local t = (visibleIndex <= 1) and 0 or (currentIndex - 1) / (visibleIndex - 1)

			local r = math.floor(lerp(startColor[1], endColor[1], t))
			local g = math.floor(lerp(startColor[2], endColor[2], t))
			local b = math.floor(lerp(startColor[3], endColor[3], t))

			result = result .. string.format("{#color(%d,%d,%d)}%s", r, g, b, char)
		end
	end

	result = "{#color(" .. colours.title .. ")} " .. result .. "{#reset()}"
	return result
end

local mod_name = {
	en = "Mourningstar Dialogue Improved",
}

mod.localisation = {
	mod_name = {
		en = mod_name["en"],
	},
	mod_name_pizazz = {
		en = mod.gradientText(mod_name["en"], { 0,207,255 }, { 255,180,0 }, true),
	},
	mod_name_boring = {
		en = mod_name["en"],
	},

	mod_description = {
		en = "{#color("
			.. colours.text
			.. ")}"
			.. "Listen to radio chatter within menus, completely disable chatter throughout and more, to improve the dialogue within the Mourningstar Hub"
			.. "{#reset()}\n\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Author: "
			.. "{#color("
			.. colours.text
			.. ")}Alfthebigheaded\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Version: {#color("
			.. colours.text
			.. ")}"
			.. mod.version
			.. "{#reset()}",
	},
	mod_name_pizazz_toggle = {
		en = "Enable Name Pizazz",
	},
	mod_name_pizazz_tooltip = {
		en = "Toggles the rainbow colours effect on the mod name text. Requires a reload.\nIf enabled, you will get a small euphoric experience everytime you scroll through the mod menu, \nIf disabled - you will be a John Darktide and have no rainbow sprinkles (but I'll love you anyway).",
	},
	disable_mourningstar_chatter = {
		en = "Disable Mourningstar chatter?",
	},
	disable_radio_chatter = {
		en = "Disable mission radio chatter?",
	},
	disable_all_chatter = {
		en = "Disable all chatter?",
	},
	general_settings = {
		en = "{#color(" .. colours.title .. ")}General Settings{#reset()}",
	},
	disable_mourningstar_chatter_tooltip = {
		en = "Toggles radio/npc chatter whilst within the Mourningstar hub.",
	},
	disable_radio_chatter_tooltip = {
		en = "Toggles in-mission radio chatter, but keeps player character interactions.",
	},
	disable_all_chatter_tooltip = {
		en = "Toggles ALL npc chatter, including radios, player character interactions, npc conversations... all of it. (May cause some issues in solo play)",
	},
}

mod.toggle_pizazz = function()
	for key, values in pairs(mod.localisation) do
		if key == "mod_name" then
			for language, text in pairs(values) do
				if mod:get("mod_name_pizazz_toggle") then
					mod.localisation[key][language] = mod.localisation["mod_name_pizazz"][language]
				else
					mod.localisation[key][language] = mod.localisation["mod_name_boring"][language]
				end
			end
		end
	end
end

mod.toggle_pizazz()

return mod.localisation
