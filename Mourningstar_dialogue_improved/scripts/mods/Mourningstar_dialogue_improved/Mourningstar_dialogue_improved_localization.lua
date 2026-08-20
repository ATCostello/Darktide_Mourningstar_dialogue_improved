local mod = get_mod("Mourningstar_dialogue_improved")
mod.version = "1.2.11"
mod:info("Mourningstar Dialogue Improved is installed, using version: " .. tostring(mod.version))

local colours = {
	title = "200,140,20",
	subtitle = "226,199,126",
	text = "169,191,153",
}

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function utf8_chars(s)
	local chars = {}
	for char in string.gmatch(s, "[%z\1-\127\194-\244][\128-\191]*") do
		table.insert(chars, char)
	end
	return chars
end

mod.gradientText = function(text, startColor, endColor, colorSpaces)
	local result = ""
	local chars = utf8_chars(text)
	local visibleIndex = 0

	for _, char in ipairs(chars) do
		if colorSpaces or char ~= " " then
			visibleIndex = visibleIndex + 1
		end
	end

	local currentIndex = 0

	for _, char in ipairs(chars) do
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

	result = "{#color(" .. colours.title .. ")}" .. result .. "{#reset()}"
	return result
end

local mod_name = {
	en = "Mourningstar Dialogue Improved",
	ru = "Улучшенные диалоги Звезды Скорби",
	["zh-cn"] = "哀星对话增强",
	["zh-tw"] = "哀星對話改善",
}

mod.localisation = {
	mod_name = {
		en = mod_name["en"],
		ru = mod_name["ru"],
		["zh-cn"] = mod_name["zh-cn"],
		["zh-tw"] = mod_name["zh-tw"],
	},
	mod_name_pizazz = {
		en = mod.gradientText(mod_name["en"], { 0, 207, 255 }, { 255, 180, 0 }, true),
		ru = mod.gradientText(mod_name["ru"], { 0, 207, 255 }, { 255, 180, 0 }, true),
		["zh-cn"] = mod.gradientText(mod_name["zh-cn"], { 0, 207, 255 }, { 255, 180, 0 }, true),
		["zh-tw"] = mod.gradientText(mod_name["zh-tw"], { 0, 207, 255 }, { 255, 180, 0 }, true),
	},
	mod_name_boring = {
		en = mod_name["en"],
		ru = mod_name["ru"],
		["zh-cn"] = mod_name["zh-cn"],
		["zh-tw"] = mod_name["zh-tw"],
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
		ru = "{#color("
			.. colours.text
			.. ")}"
			.. "Слушайте радиопереговоры в меню, полностью отключайте диалоги и многое другое для улучшения атмосферы хаба Звезды Скорби"
			.. "{#reset()}\n\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Автор: "
			.. "{#color("
			.. colours.text
			.. ")}Alfthebigheaded\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Версия: {#color("
			.. colours.text
			.. ")}"
			.. mod.version
			.. "{#reset()}",
		["zh-cn"] = "{#color("
			.. colours.text
			.. ")}"
			.. "在菜单中收听无线电对话，完全禁用对话等，以改善哀星号枢纽的对话体验"
			.. "{#reset()}\n\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}作者: "
			.. "{#color("
			.. colours.text
			.. ")}Alfthebigheaded\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}版本: {#color("
			.. colours.text
			.. ")}"
			.. mod.version
			.. "{#reset()}",
		["zh-tw"] = "{#color("
			.. colours.text
			.. ")}"
			.. "在選單中收聽無線電對話、完全停用對話等功能，以改善哀星號樞紐的對話體驗"
			.. "{#reset()}\n\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}作者: "
			.. "{#color("
			.. colours.text
			.. ")}Alfthebigheaded\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}版本: {#color("
			.. colours.text
			.. ")}"
			.. mod.version
			.. "{#reset()}",
	},
	mod_name_pizazz_toggle = {
		en = "Enable Name Pizazz",
		ru = "Включить красочное название",
		["zh-cn"] = "启用名称特效",
		["zh-tw"] = "啟用名稱特效",
	},
	mod_name_pizazz_tooltip = {
		en = "Toggles the rainbow colours effect on the mod name text. Requires a reload.\nIf enabled, you will get a small euphoric experience everytime you scroll through the mod menu, \nIf disabled - you will be a John Darktide and have no rainbow sprinkles (but I'll love you anyway).",
		ru = "Включает радужный эффект для названия мода. Требуется перезагрузка.\nЕсли включено, вы будете испытывать небольшую эйфорию каждый раз при прокрутке меню мода.\nЕсли выключено - вы будете обычным Джоном Дарктайдом без радужных блёсток (но я всё равно буду вас любить).",
		["zh-cn"] = "切换模组名称的彩虹颜色效果。需要重新加载。\n启用后，每次滚动模组菜单时你都会获得小小的愉悦体验。\n禁用后，你将失去彩虹点缀（但我仍然爱你）。",
		["zh-tw"] = "切換模組名稱的彩虹顏色效果。需要重新載入。\n啟用後，每次滾動模組選單時你都會獲得小小的愉悅體驗。\n停用後，你將成為一般的黑暗潮汐玩家，失去彩虹點綴（但我仍然愛你）。",
	},
	disable_mourningstar_chatter = {
		en = "Disable Mourningstar chatter?",
		ru = "Отключить диалоги Звезды Скорби?",
		["zh-cn"] = "禁用哀星号对话？",
		["zh-tw"] = "停用哀星號對話？",
	},
	disable_radio_chatter = {
		en = "Disable mission radio chatter?",
		ru = "Отключить радиопереговоры во время миссий?",
		["zh-cn"] = "禁用任务无线电对话？",
		["zh-tw"] = "停用任務無線電對話？",
	},
	disable_all_chatter = {
		en = "Disable all chatter?",
		ru = "Отключить все диалоги?",
		["zh-cn"] = "禁用所有对话？",
		["zh-tw"] = "停用所有對話？",
	},
	general_settings = {
		en = "{#color(" .. colours.title .. ")}General Settings{#reset()}",
		ru = "{#color(" .. colours.title .. ")}Общие настройки{#reset()}",
		["zh-cn"] = "{#color(" .. colours.title .. ")}通用设置{#reset()}",
		["zh-tw"] = "{#color(" .. colours.title .. ")}一般設定{#reset()}",
	},
	disable_mourningstar_chatter_tooltip = {
		en = "Toggles radio/npc chatter whilst within the Mourningstar hub.",
		ru = "Переключает радио/NPC диалоги в хабе Звезды Скорби.",
		["zh-cn"] = "在哀星号枢纽内切换无线电/NPC对话。",
		["zh-tw"] = "在哀星號樞紐內切換無線電/NPC對話。",
	},
	disable_radio_chatter_tooltip = {
		en = "Toggles in-mission radio chatter, but keeps player character interactions.",
		ru = "Переключает радиопереговоры во время миссий, но сохраняет взаимодействия с персонажами игроков.",
		["zh-cn"] = "切换任务中的无线电对话，但保留玩家角色互动。",
		["zh-tw"] = "切換任務中的無線電對話，但保留玩家角色互動。",
	},
	disable_all_chatter_tooltip = {
		en = "Toggles ALL npc chatter, including radios, player character interactions, npc conversations... all of it. (May cause some issues in solo play)",
		ru = "Переключает ВСЕ NPC диалоги, включая радио, взаимодействия с персонажами игроков, разговоры NPC... всё. (Может вызвать некоторые проблемы в одиночной игре)",
		["zh-cn"] = "切换所有NPC对话，包括无线电、玩家角色互动、NPC对话……全部。（单人游戏时可能会出现问题）",
		["zh-tw"] = "切換所有NPC對話，包括無線電、玩家角色互動、NPC對話……全部。（單人遊戲時可能會出現問題）",
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
