local _, ns = ...

-- Blizzard's micro menu and bag buttons, moved into Keyzen Bars holders so
-- they unlock and drag with the other bars and take orientation, buttons per
-- row, spacing, size, opacity and visibility. Blizzard re-anchors these
-- buttons from time to time (Edit Mode, pet battles, a button appearing), so
-- every one of those is followed by our own layout again.

local MENU_FALLBACK = {
	"CharacterMicroButton", "ProfessionMicroButton", "PlayerSpellsMicroButton", "SpellbookMicroButton",
	"TalentMicroButton", "LegacyMicroButton", "AchievementMicroButton", "QuestLogMicroButton", "HousingMicroButton",
	"GuildMicroButton", "SocialsMicroButton", "LFDMicroButton", "FindMicroButton", "PVPMicroButton",
	"CollectionsMicroButton",
	"EJMicroButton", "StoreMicroButton", "HelpMicroButton", "MainMenuMicroButton",
}

local BAG_BUTTONS = {
	"BagBarExpandToggle", "KeyRingButton", "CharacterReagentBag0Slot", "CharacterBag3Slot", "CharacterBag2Slot",
	"CharacterBag1Slot", "CharacterBag0Slot", "MainMenuBarBackpackButton",
}

local lists = {}
local busy, queued

local function Collect(names)
	local list, seen = {}, {}
	for _, name in ipairs(names) do
		local button = _G[name]
		if button and not seen[button] then
			seen[button] = true
			list[#list + 1] = button
		end
	end
	return list
end

local function Layout(key)
	local holder, cfg, list = ns.Holder(key), ns.BarDB(key), lists[key]
	if not (holder and cfg and list) then return end
	busy = true
	local shown, w, h = {}, 1, 1
	local clickable = cfg.visibility ~= "hidden"
	-- Taking a button out of the micro menu makes Blizzard re-lay the rest,
	-- and its help-ticket code errors when the first or last button left has
	-- no position (Customer Support often has none). So every button that's
	-- moving gets a position before any of them leaves, then the hidden ones
	-- leave first, then the rest.
	local function Target(button)
		-- WoW Forever's keyring can be switched off on its own.
		if button == _G.KeyRingButton and cfg.showKeyring == false then return _G.KeyzenBarsHiddenParent end
		return holder
	end
	for _, button in ipairs(list) do
		if button:GetParent() ~= Target(button) then
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", holder, "TOPLEFT")
		end
	end
	for pass = 1, 2 do
		for _, button in ipairs(list) do
			local parent = Target(button)
			if button:GetParent() ~= parent and (pass == 2 or not button:IsShown()) then
				button:SetParent(parent)
			end
		end
	end
	for _, button in ipairs(list) do
		local parent = Target(button)
		button:EnableMouse(clickable)
		if parent == holder and button:IsShown() then
			shown[#shown + 1] = button
			w = math.max(w, button:GetWidth())
			h = math.max(h, button:GetHeight())
		end
	end
	local perRow = math.max(1, math.min(cfg.perRow, #shown))
	local lines = math.max(1, math.ceil(#shown / perRow))
	local horizontal = cfg.orientation ~= "vertical"
	local sp = cfg.spacing
	for i, button in ipairs(shown) do
		local along, across = (i - 1) % perRow, math.floor((i - 1) / perRow)
		local col, row = along, across
		if not horizontal then col, row = across, along end
		-- Cells are as big as the largest button; smaller ones sit centered.
		button:ClearAllPoints()
		button:SetPoint("CENTER", holder, "TOPLEFT", col * (w + sp) + w / 2, -row * (h + sp) - h / 2)
	end
	local cols, rows = perRow, lines
	if not horizontal then cols, rows = lines, perRow end
	holder:SetSize(math.max(1, cols * (w + sp) - sp), math.max(1, rows * (h + sp) - sp))
	busy = false
end

-- The gold dividers between bag slots are small frames of BagsBar's own,
-- anchored to the slots, so they follow the slots into our holder and stay
-- on screen when it hides. BagsBar makes new ones when it lays itself out,
-- so this runs after every layout.
local quieted = {}
local function KeepHidden(frame)
	frame:SetAlpha(0)
	if quieted[frame] then return end
	quieted[frame] = true
	if frame.EnableMouse then frame:EnableMouse(false) end
	local locking
	hooksecurefunc(frame, "SetAlpha", function(self, alpha)
		if locking or alpha == 0 then return end
		locking = true
		self:SetAlpha(0)
		locking = false
	end)
end

local function HideBagsBarArt()
	local bar = _G.BagsBar
	if not bar or not lists.bags then return end
	local ours = {}
	for _, button in ipairs(lists.bags) do ours[button] = true end
	for _, child in ipairs({ bar:GetChildren() }) do
		if not ours[child] then KeepHidden(child) end
	end
	for _, region in ipairs({ bar:GetRegions() }) do region:SetAlpha(0) end
end

local Queue

-- Some buttons are made after login, so late arrivals are picked up here.
local function AddLateButtons()
	local have = {}
	for _, button in ipairs(lists.menu) do have[button] = true end
	for _, name in ipairs(MENU_FALLBACK) do
		local button = _G[name]
		if button and not have[button] then
			lists.menu[#lists.menu + 1] = button
			button:HookScript("OnShow", Queue)
			button:HookScript("OnHide", Queue)
		end
	end
end

function ns.LayoutMenus()
	if not next(lists) then return end
	AddLateButtons()
	HideBagsBarArt()
	Layout("menu")
	Layout("bags")
end

function Queue()
	if busy or queued then return end
	queued = true
	C_Timer.After(0, function()
		queued = false
		ns.LayoutMenus()
	end)
end

function ns.MenuAvailable(key)
	return lists[key] ~= nil and #lists[key] > 0
end

function ns.CreateMenus()
	-- Blizzard's list first, then our names for buttons it leaves out (WoW
	-- Forever's Legacy talents button), then anything else still sitting in
	-- the micro menu.
	local names = {}
	for _, name in ipairs(MICRO_BUTTONS or {}) do names[#names + 1] = name end
	for _, name in ipairs(MENU_FALLBACK) do names[#names + 1] = name end
	lists.menu = Collect(names)
	local micro = _G.MicroMenu
	if micro then
		local have = {}
		for _, button in ipairs(lists.menu) do have[button] = true end
		for _, child in ipairs({ micro:GetChildren() }) do
			if child:IsObjectType("Button") and not have[child] then lists.menu[#lists.menu + 1] = child end
		end
	end
	lists.bags = Collect(BAG_BUTTONS)
	ns.CreateHolder("menu", "Menu")
	ns.CreateHolder("bags", "Bags")
	for _, list in pairs(lists) do
		for _, button in ipairs(list) do
			button:HookScript("OnShow", Queue)
			button:HookScript("OnHide", Queue)
		end
	end
	if micro and micro.Layout then hooksecurefunc(micro, "Layout", Queue) end
	if _G.BagsBar and _G.BagsBar.Layout then hooksecurefunc(_G.BagsBar, "Layout", Queue) end
	for _, fn in ipairs({ "UpdateMicroButtonsParent", "MoveMicroButtons", "UpdateMicroButtons" }) do
		if type(_G[fn]) == "function" then hooksecurefunc(fn, Queue) end
	end
end

------------------------------------------------------------------------------
-- Window buttons: macros that open a game window, made for the player and
-- put on the cursor to drop on any button. Ours draw their own icon (the
-- Character one shows the player's portrait) and hide the macro name.
------------------------------------------------------------------------------

local PREFIX = "KZ "

local WINDOWS = {
	{ text = "Character", buttons = { "CharacterMicroButton" }, icon = "INV_Shirt_White_01", portrait = true },
	{ text = "Spellbook", buttons = { "SpellbookMicroButton", "PlayerSpellsMicroButton" }, icon = "INV_Misc_Book_09" },
	{ text = "Talents", buttons = { "TalentMicroButton", "PlayerSpellsMicroButton" }, icon = "Ability_Marksmanship" },
	{ text = "Legacy talents", buttons = { "LegacyMicroButton" }, icon = "INV_Misc_Book_11" },
	{ text = "Professions", buttons = { "ProfessionMicroButton" }, icon = "Trade_BlackSmithing" },
	{ text = "Map", run = "ToggleWorldMap", icon = "INV_Misc_Map_01" },
	{ text = "Quest log", buttons = { "QuestLogMicroButton" }, icon = "INV_Misc_Note_01" },
	{ text = "Bags", run = "ToggleAllBags", icon = "INV_Misc_Bag_08" },
	{ text = "Achievements", buttons = { "AchievementMicroButton" }, icon = "INV_Misc_Ribbon_01" },
	{ text = "Guild", buttons = { "GuildMicroButton" }, icon = "INV_Shirt_GuildTabard_01" },
	{ text = "Friends", run = "ToggleFriendsFrame", icon = "INV_Letter_02" },
	{ text = "Group finder", buttons = { "LFDMicroButton" }, icon = "Spell_Holy_PrayerOfHealing" },
	{ text = "Collections", buttons = { "CollectionsMicroButton" }, icon = "Ability_Mount_RidingHorse" },
	{ text = "Adventure guide", buttons = { "EJMicroButton" }, icon = "INV_Misc_Book_17" },
	{ text = "Housing", buttons = { "HousingMicroButton" }, icon = "INV_Misc_Rune_01" },
	{ text = "Game menu", buttons = { "MainMenuMicroButton" }, icon = "Trade_Engineering" },
	{ text = "Keyzen Bars", slash = "kz", cmd = "KEYZENBARS", icon = "INV_Misc_Key_03",
		texture = "Interface\\AddOns\\KeyzenBars\\Media\\Icon.tga" },
	{ text = "EllesmereUI", slash = "eui", cmd = "EUIOPTIONS", icon = "INV_Gizmo_02",
		texture = "Interface\\AddOns\\EllesmereUI\\media\\eg-logo.tga" },
}

local byName = {}
for _, w in ipairs(WINDOWS) do byName[PREFIX .. w.text] = w end

local function Body(w)
	if w.slash then return SlashCmdList[w.cmd] and ("/" .. w.slash) or nil end
	if w.run then return type(_G[w.run]) == "function" and ("/run " .. w.run .. "()") or nil end
	for _, name in ipairs(w.buttons) do
		if _G[name] then return "/click " .. name end
	end
end

-- Only windows this client has. Spellbook and Talents can share a button.
function ns.WindowList()
	local list, used = {}, {}
	for _, w in ipairs(WINDOWS) do
		local body = Body(w)
		if body and not used[body] then
			used[body] = true
			list[#list + 1] = w
		end
	end
	return list
end

function ns.PickupWindow(w)
	if InCombatLockdown() then print("|cffe2ab70Keyzen Bars|r: macros can't be made in combat.") return end
	local body, name = Body(w), PREFIX .. w.text
	if not body then return end
	local index = GetMacroIndexByName(name)
	if index and index > 0 then
		EditMacro(index, name, w.icon, body)
	else
		local count = GetNumMacros()
		if count >= (MAX_ACCOUNT_MACROS or 120) then
			print("|cffe2ab70Keyzen Bars|r: your account macros are full. Delete one in /macro and try again.")
			return
		end
		index = CreateMacro(name, w.icon, body)
	end
	if index and index > 0 then PickupMacro(index) end
end

local custom = {} -- buttons showing a portrait or addon logo

-- Draws a window's own picture on a texture: the player's portrait or an
-- addon's logo. Returns false for windows that keep their macro icon.
function ns.WindowArt(texture, w)
	if w.portrait then
		SetPortraitTexture(texture, "player")
		texture:SetTexCoord(0.15, 0.85, 0.15, 0.85)
	elseif w.texture then
		texture:SetTexture(w.texture)
		texture:SetTexCoord(0, 1, 0, 1)
	else
		return false
	end
	return true
end

local function WindowOn(button)
	local slot = button._state_type == "action" and button._state_action
	if not (slot and HasAction(slot)) then return end
	if GetActionInfo(slot) ~= "macro" then return end
	return byName[GetActionText(slot) or ""]
end

local drawing

function ns.DecorateWindowButton(button)
	local w = WindowOn(button)
	if w and button.Name then button.Name:SetText("") end
	local icon = button.kzIcon
	-- The library puts the macro icon back on its own at times (model
	-- changes, for one) without telling us, so ours goes back on after.
	if not button.kzArtHook then
		button.kzArtHook = true
		hooksecurefunc(icon, "SetTexture", function()
			if drawing or not custom[button] then return end
			local current = WindowOn(button)
			if current then
				drawing = true
				ns.WindowArt(icon, current)
				drawing = false
			end
		end)
	end
	drawing = true
	if w and ns.WindowArt(icon, w) then
		custom[button] = true
	elseif custom[button] then
		-- Was a portrait or logo; put the normal crop back.
		custom[button] = nil
		local z = ns.DB.iconZoom
		icon:SetTexCoord(z, 1 - z, z, 1 - z)
	end
	drawing = false
end

local portraitEvents = CreateFrame("Frame")
portraitEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
portraitEvents:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "player")
portraitEvents:RegisterUnitEvent("UNIT_MODEL_CHANGED", "player")
portraitEvents:SetScript("OnEvent", function()
	-- Next frame, after the library has redrawn its icons for the same event.
	C_Timer.After(0, function()
		for button in pairs(custom) do ns.DecorateWindowButton(button) end
	end)
end)
