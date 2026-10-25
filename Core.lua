local ADDON, ns = ...
local LAB = LibStub("LibActionButton-1.0-ElvUI")

local PREFIX = "|cff8fd65aKeyzen Bars|r: "
local MAX_EXTRA_BARS = 10
local MAX_STANCES = 10

local function BarDefaults(x, y, page)
	return { show = true, scale = 1, alpha = 1, size = 38, spacing = 4, visibility = "always", page = page,
		point = { "CENTER", "UIParent", "CENTER", x, y } }
end

local DEFAULTS = {
	lockFrames = true,
	lockButtons = true,
	clickWhenUnlocked = false,
	blockShiftPaging = true,
	disableFormPaging = false,
	hideBlizzard = true,

	-- Icons
	borderSize = 1,
	borderColor = { 0, 0, 0, 1 },
	iconZoom = 0.08,
	showBackground = true,
	bgColor = { 0.06, 0.06, 0.06, 0.85 },
	hideEmpty = false,
	cooldownNumbers = true,
	cooldownFontSize = 12,
	swipeAlpha = 0.8,
	rangeColoring = true,
	rangeColor = { 0.8, 0.1, 0.1, 1 },
	showEquipped = false,
	equippedColor = { 0.3, 0.9, 0.3, 1 },

	-- Text
	showKeybind = true,
	keyFont = "mbold",
	keyFontSize = 12,
	keyColor = { 1, 1, 1, 1 },
	keyPosition = "TOPRIGHT",
	fingerNames = true,
	showMacro = true,
	macroFontSize = 10,
	countFontSize = 12,
	textFont = "mbold",

	-- Animations
	flash = true,
	pushedStyle = "medium",
	highlightStyle = "medium",
	interactionColor = { 1, 1, 1, 1 },
	procGlow = true,
	glowColor = { 1, 0.82, 0.35, 1 },
	activeHighlight = true,
	activeColor = { 1, 0.82, 0, 1 },

	bars = {
		keyzen = BarDefaults(0, -120),
		naga = BarDefaults(320, -120, 4),
		stance = BarDefaults(0, 40),
		-- Blizzard's micro menu and bag buttons, moved into our own holders
		menu = { show = true, scale = 1, alpha = 1, spacing = 0, perRow = 12, orientation = "horizontal",
			visibility = "always", point = { "BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -8, 8 } },
		bags = { show = true, scale = 1, alpha = 1, spacing = 4, perRow = 12, orientation = "horizontal", showKeyring = true,
			visibility = "always", point = { "BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -8, 56 } },
		-- Vehicle and flight exit button (Vehicle.lua)
		vehicle = { show = true, scale = 1, alpha = 1, size = 36, visibility = "always",
			point = { "BOTTOM", "UIParent", "BOTTOM", -260, 200 } },
		-- Blizzard's pet action buttons (PetBar.lua)
		pet = { show = true, scale = 1, alpha = 1, size = 30, spacing = 4, perRow = 10, orientation = "horizontal",
			visibility = "always", point = { "BOTTOM", "UIParent", "BOTTOM", 0, 240 } },
		-- Blizzard's shaman call totem bar (Totems.lua)
		totem = { show = true, scale = 1, alpha = 1, spacing = 4, orientation = "horizontal",
			visibility = "always", point = { "BOTTOM", "UIParent", "BOTTOM", 0, 200 } },
		-- Experience bar (XPBar.lua)
		xp = { show = true, scale = 1, alpha = 1, visibility = "always",
			point = { "TOP", "UIParent", "TOP", 0, -40 }, width = 571, height = 22,
			texture = "flat", classColor = true, color = { 0.6, 0.4, 1 }, trackAlpha = 0.9, border = true,
			font = "mbold", fontSize = 13, lineFontSize = 11, textStyle = "smooth",
			showTimes = true, showRate = true, showLastGain = true, questOverlay = true, restedOverlay = true,
			showAtMax = false, hideBlizzard = true },
	},
	ownMenus = true,
	autoAddSpells = true,
	keyzen = { device = "keyzen", showMain = true, showReach = true, showFixed = true, showFar = false, showThumb = false,
		mainPage = 1, reachPage = 6 },
	extra = {},

	-- Options window
	optContentScale = 0.75,
	optWindowSize = 1,
	optArtAlpha = 0.5,
	optTint = 0.35,
	optAccent = { 0.89, 0.67, 0.44, 1 },
	optTheme = "classcolor",
	optClassAccent = true,
}

-- Blizzard commands that flip the action bar page (Shift+1-6, Shift+wheel by
-- default). Their keys are pointed at a button that does nothing.
local PAGE_COMMANDS = {
	"ACTIONPAGE1", "ACTIONPAGE2", "ACTIONPAGE3", "ACTIONPAGE4", "ACTIONPAGE5", "ACTIONPAGE6",
	"NEXTACTIONPAGE", "PREVIOUSACTIONPAGE",
}

local MODIFIER_KEYS = {
	LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
	LMETA = true, RMETA = true, UNKNOWN = true,
}

-- Free fonts shipped in Media\Fonts (SIL Open Font License, Ubuntu Font
-- Licence; the texts are in Licenses\), then WoW's own. Fonts other addons
-- register with LibSharedMedia are added when the font list is opened.
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
local FONT_FILES = {
	{ "mbold", "Montserrat Bold", "Montserrat-Bold.ttf" },
	{ "mmedium", "Montserrat Medium", "Montserrat-Medium.ttf" },
	{ "mblack", "Montserrat Black", "Montserrat-Black.ttf" },
	{ "barlow", "Barlow Condensed", "Barlow Condensed.ttf" },
	{ "changa", "Changa", "Changa.ttf" },
	{ "cinzel", "Cinzel", "Cinzel.ttf" },
	{ "cinzelbold", "Cinzel Bold", "Cinzel-Bold.ttf" },
	{ "cinzeldeco", "Cinzel Decorative", "Cinzel Decorative.ttf" },
	{ "exo", "Exo", "Exo.otf" },
	{ "firalight", "Fira Sans Light", "FiraSans Light.ttf" },
	{ "firaregular", "Fira Sans", "FiraSans-Regular.ttf" },
	{ "firamedium", "Fira Sans Medium", "FiraSans-Medium.ttf" },
	{ "firasemibold", "Fira Sans SemiBold", "FiraSans-SemiBold.ttf" },
	{ "firabold", "Fira Sans Bold", "FiraSans Bold.ttf" },
	{ "geistlight", "Geist Light", "Geist-Light.otf" },
	{ "geist", "Geist", "Geist-Regular.otf" },
	{ "geistmedium", "Geist Medium", "Geist-Medium.otf" },
	{ "geistsemibold", "Geist SemiBold", "Geist-SemiBold.otf" },
	{ "geistbold", "Geist Bold", "Geist-Bold.otf" },
	{ "inter", "Inter", "Inter-Regular.ttf" },
	{ "intermedium", "Inter Medium", "Inter-Medium.ttf" },
	{ "intersemibold", "Inter SemiBold", "Inter-SemiBold.ttf" },
	{ "oswald", "Oswald", "Oswald-Regular.ttf" },
	{ "poppins", "Poppins", "Poppins.ttf" },
	{ "russo", "Russo One", "Russo One.ttf" },
	{ "ubuntu", "Ubuntu", "Ubuntu.ttf" },
}
ns.FONTS = {}
for _, f in ipairs(FONT_FILES) do
	ns.FONTS[#ns.FONTS + 1] = { key = f[1], name = f[2], path = MEDIA .. "Fonts\\" .. f[3] }
end
for _, f in ipairs({
	{ "default", "WoW default", STANDARD_TEXT_FONT },
}) do
	ns.FONTS[#ns.FONTS + 1] = { key = f[1], name = f[2], path = f[3] }
end
ns.MEDIA = MEDIA

local function SharedMedia() return LibStub("LibSharedMedia-3.0", true) end

-- Every font to offer: ours, then LibSharedMedia's (keys "lsm:<name>").
function ns.AllFonts()
	local list, seen = {}, {}
	for _, font in ipairs(ns.FONTS) do
		list[#list + 1] = font
		seen[font.path:lower()] = true
	end
	local lsm = SharedMedia()
	if lsm then
		local names = lsm:List("font")
		for _, name in ipairs(names) do
			local path = lsm:Fetch("font", name, true)
			if path and not seen[path:lower()] then
				seen[path:lower()] = true
				list[#list + 1] = { key = "lsm:" .. name, name = name, path = path }
			end
		end
	end
	return list
end

local function FontPath(key)
	for _, font in ipairs(ns.FONTS) do
		if font.key == key then return font.path end
	end
	local name = type(key) == "string" and key:match("^lsm:(.+)$")
	local lsm = name and SharedMedia()
	local path = lsm and lsm:Fetch("font", name, true)
	return path or ns.FONTS[1].path
end
ns.FontPath = FontPath

local DB
local holders = {}      -- [barKey] = frame
local headers = {}      -- [name] = secure header
local buttons = {}      -- [buttonId] = LAB button
local defsById = {}
local fixedCells = {}
local stanceButtons = {}
local movers = {}
local extraBuilt = {}   -- [index] = true once its frames exist
local bindOwner, capture
local pending = {}
local bindMode = false

local function Print(msg) print(PREFIX .. msg) end
ns.Print = Print

local function DeepDefaults(target, defaults)
	for k, v in pairs(defaults) do
		if type(v) == "table" then
			if type(target[k]) ~= "table" then target[k] = {} end
			DeepDefaults(target[k], v)
		elseif target[k] == nil then
			target[k] = v
		end
	end
end

-- Settings from the first test versions lived at the top level.
local function MigrateOldSettings(db)
	db.bars = db.bars or {}
	if db.point then db.bars.keyzen = db.bars.keyzen or { point = db.point } db.point = nil end
	if db.nagaPoint then db.bars.naga = db.bars.naga or { point = db.nagaPoint } db.nagaPoint = nil end
	if db.stancePoint then db.bars.stance = db.bars.stance or { point = db.stancePoint } db.stancePoint = nil end
	if db.locked ~= nil then db.lockFrames = db.locked db.locked = nil end
	db.scale = nil
	-- Menu and bag settings moved into bars when they became movable bars.
	for _, key in ipairs({ "menu", "bags" }) do
		if type(db[key]) == "table" then
			db.bars[key] = db.bars[key] or {}
			db.bars[key].visibility = db.bars[key].visibility or db[key].visibility
			db.bars[key].scale = db.bars[key].scale or db[key].scale
			db[key] = nil
		end
	end
	-- Button size and spacing used to be one setting for every bar.
	if db.buttonSize then
		for _, key in ipairs({ "keyzen", "naga", "stance" }) do
			db.bars[key] = db.bars[key] or {}
			db.bars[key].size = db.bars[key].size or db.buttonSize
			db.bars[key].spacing = db.bars[key].spacing or db.spacing
		end
		for _, cfg in ipairs(db.extra or {}) do
			if not cfg.ownSize then cfg.size = db.buttonSize end
			cfg.spacing = cfg.spacing or db.spacing
			cfg.ownSize = nil
		end
		db.buttonSize, db.spacing = nil, nil
	end
end

local function BarDB(key)
	local n = tonumber(key:match("^extra(%d+)$"))
	if n then return DB.extra[n] end
	return DB.bars[key]
end
ns.BarDB = BarDB

------------------------------------------------------------------------------
-- Labels
------------------------------------------------------------------------------

local function ShortKey(key)
	if not key or key == "" then return "" end
	if key == "SPACE" then return "Space" end
	if key == "TAB" then return "Tab" end
	if key == "ESCAPE" then return "Esc" end
	return (key:gsub("ALT%-", "A"):gsub("CTRL%-", "C"):gsub("SHIFT%-", "S"))
end

-- Naga buttons show the number printed on the mouse while they keep their
-- default numpad key.
local function KeyLabel(def, key)
	if def.bar == "naga" and key == def.key then return tostring(def.n) end
	if def.name and DB.fingerNames and key == def.key then return def.name end
	return ShortKey(key)
end

local function KeyName(def)
	if def.bar == "naga" then return "Naga " .. def.n end
	if def.bar == "extra" then return ns.ExtraBarName(def.extra) .. " button " .. def.i end
	if def.deviceName then return def.deviceName end
	return "Key #" .. def.id
end

------------------------------------------------------------------------------
-- Geometry
------------------------------------------------------------------------------

-- Keyzen grid: column 7 is a half-width gap between fingers and thumb.
local function CellPoint(c, r, step)
	local x = (c - 1) * step
	if ns.ACTIVE_LAYOUT.halfGap ~= false and c >= 8 then x = x - step / 2 end
	return x, -(r - 1) * step
end

local function Place(frame, parent, x, y, size)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	frame:SetSize(size, size)
end

-- Cooldown numbers sized for small square buttons.
local cooldownFont = CreateFont("KeyzenBarsCooldownFont")
cooldownFont:SetFont(MEDIA .. "Fonts\\Montserrat-Bold.ttf", 12, "OUTLINE")

------------------------------------------------------------------------------
-- Look
------------------------------------------------------------------------------

-- An outline drawn as four edges just outside the frame, so the inside stays
-- see-through when the fill is hidden. The returned object takes
-- SetColorTexture like a single texture would, plus SetThickness.
local function AddBorder(frame, rgb, fill)
	local edges = {}
	for i = 1, 4 do edges[i] = frame:CreateTexture(nil, "BACKGROUND", nil, -8) end
	local border = {}
	function border:SetColorTexture(r, g, b, a)
		for _, t in ipairs(edges) do t:SetColorTexture(r, g, b, a or 1) end
	end
	function border:SetThickness(t)
		for _, e in ipairs(edges) do
			e:ClearAllPoints()
			e:SetShown(t > 0)
		end
		if t <= 0 then return end
		local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
		top:SetPoint("TOPLEFT", frame, "TOPLEFT", -t, t)
		top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", t, t)
		top:SetHeight(t)
		bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -t, -t)
		bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", t, -t)
		bottom:SetHeight(t)
		left:SetPoint("TOPLEFT", frame, "TOPLEFT", -t, t)
		left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -t, -t)
		left:SetWidth(t)
		right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", t, t)
		right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", t, -t)
		right:SetWidth(t)
	end
	border:SetColorTexture(rgb[1], rgb[2], rgb[3], 1)
	border:SetThickness(1)
	if not fill then return border end
	local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
	bg:SetAllPoints(frame)
	bg:SetColorTexture(fill, fill, fill, 0.85)
	return border, bg
end
ns.AddBorder = AddBorder

-- Proc glow: a pulsing outline in the glow color, shown while Blizzard lights
-- up the spell (Keyzen Bars ships without LibCustomGlow).
local function AddGlow(button)
	local glow = CreateFrame("Frame", nil, button)
	glow:SetAllPoints(button)
	glow:SetFrameLevel(button:GetFrameLevel() + 6)
	glow.border = AddBorder(glow, { 1, 1, 1 })
	glow.border:SetThickness(2)
	glow.tint = glow:CreateTexture(nil, "OVERLAY")
	glow.tint:SetAllPoints(glow)
	local anim = glow:CreateAnimationGroup()
	anim:SetLooping("BOUNCE")
	local pulse = anim:CreateAnimation("Alpha")
	pulse:SetFromAlpha(1)
	pulse:SetToAlpha(0.35)
	pulse:SetDuration(0.45)
	glow.anim = anim
	glow:Hide()
	return glow
end

local function StyleButton(button, def)
	local icon = button.icon or button.Icon
	if button.IconMask and icon.RemoveMaskTexture then
		icon:RemoveMaskTexture(button.IconMask)
		button.IconMask:Hide()
	end
	icon:ClearAllPoints()
	icon:SetAllPoints(button)
	button.kzIcon = icon

	local normal = button:GetNormalTexture()
	if normal then normal:SetAlpha(0) end
	for _, key in ipairs({ "NormalTexture", "SlotBackground", "SlotArt", "Border", "FloatingBG" }) do
		local region = button[key]
		if region then region:SetAlpha(0) end
	end
	button.kzStates = {}
	for _, getter in ipairs({ "GetHighlightTexture", "GetPushedTexture", "GetCheckedTexture" }) do
		local tex = button[getter] and button[getter](button)
		if tex then
			tex:SetAllPoints(icon)
			button.kzStates[getter] = tex
		end
	end

	button.kzBorder, button.kzBg = AddBorder(button, { 0, 0, 0 }, 0.06)
	button.kzGlow = AddGlow(button)

	-- Label and press flash sit above the cooldown swipe.
	local overlay = CreateFrame("Frame", nil, button)
	overlay:SetAllPoints(button)
	overlay:SetFrameLevel(button:GetFrameLevel() + 5)
	local label = overlay:CreateFontString(nil, "OVERLAY")
	label:SetFont(FontPath("mbold"), 12, "OUTLINE")
	button.kzLabel = label

	local flash = overlay:CreateTexture(nil, "OVERLAY")
	flash:SetAllPoints(button)
	flash:SetColorTexture(1, 1, 1, 1)
	flash:SetAlpha(0)
	local anim = flash:CreateAnimationGroup()
	local fade = anim:CreateAnimation("Alpha")
	fade:SetFromAlpha(0.45)
	fade:SetToAlpha(0)
	fade:SetDuration(0.3)
	button.kzFlash = anim

	local bindTint = overlay:CreateTexture(nil, "ARTWORK")
	bindTint:SetAllPoints(button)
	bindTint:SetColorTexture(0.55, 0.85, 0.35, 0.25)
	bindTint:Hide()
	button.kzBindTint = bindTint

	-- PreClick runs even for empty buttons, so the flash works before any
	-- spell is placed.
	button:HookScript("PreClick", function(self, _, down)
		-- A click that puts down the spell on the cursor always goes through
		-- (PreClick runs before the click itself checks kzBlockMouse).
		if GetCursorInfo() and not InCombatLockdown() then self:SetAttribute("kzBlockMouse", nil) end
		if DB.flash and down ~= false then self.kzFlash:Stop() self.kzFlash:Play() end
	end)
	button:HookScript("OnEnter", function(self)
		if bindMode then
			local key = DB.keys[def.id]
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(KeyName(def) .. ": " .. ((key and key ~= "") and key or "not bound"))
			GameTooltip:AddLine("Press a key to bind it. Delete clears it. Esc stops.", 1, 1, 1)
			GameTooltip:Show()
		end
	end)
end

------------------------------------------------------------------------------
-- Holders (movable containers, one per bar)
------------------------------------------------------------------------------

local function CreateHolder(key, title)
	local frame = CreateFrame("Frame", "KeyzenBarsHolder_" .. key, UIParent)
	frame:SetSize(1, 1)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)

	local mover = CreateFrame("Frame", nil, frame)
	mover:SetAllPoints(frame)
	mover:SetFrameStrata("DIALOG")
	mover:EnableMouse(true)
	mover:RegisterForDrag("LeftButton")
	local bg = mover:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(mover)
	bg:SetColorTexture(0.3, 0.6, 0.2, 0.35)
	local text = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("BOTTOM", mover, "TOP", 0, 4)
	text:SetText(title)
	mover.kzText = text
	mover:SetScript("OnDragStart", function() frame:StartMoving() end)
	mover:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		local point, _, relPoint, x, y = frame:GetPoint()
		BarDB(key).point = { point, "UIParent", relPoint, x, y }
	end)
	mover:Hide()
	movers[key] = mover
	holders[key] = frame
	return frame
end

local function CreateHeader(name, parent)
	local header = CreateFrame("Frame", "KeyzenBars" .. name .. "Header", parent, "SecureHandlerStateTemplate")
	header:SetAllPoints(parent)
	headers[name] = header
	return header
end
ns.CreateHolder = CreateHolder
function ns.Holder(key) return holders[key] end

------------------------------------------------------------------------------
-- Action buttons
------------------------------------------------------------------------------

-- The action slot a Keyzen or Naga button shows. Each bar can sit on any
-- action page; each button keeps its place on the page. The main keys
-- still swap pages for stances and forms like the default main bar.
local function SlotFor(def)
	if def.bar == "main" then return ((DB.keyzen.mainPage or 1) - 1) * 12 + def.i end
	if def.bar == "reach" then return ((DB.keyzen.reachPage or 6) - 1) * 12 + (def.slot - 60) end
	if def.bar == "naga" then return ((DB.bars.naga.page or 4) - 1) * 12 + (def.slot - 36) end
	return def.slot
end

local function SetActionState(button, state, slot)
	local stateKey = tostring(state)
	if button:GetAttribute("gse-lab-state-" .. stateKey) then
		if button.gseLabOriginal then
			button.gseLabOriginal[stateKey] = { kind = "action", action = slot }
		end
		return
	end
	button:SetState(state, "action", slot)
end

local SPECIAL_ACTION_INDEX = {}
for index, key in ipairs({ "4", "3", "2", "1", "5", "6", "7", "8", "9", "0", "-", "=" }) do
	SPECIAL_ACTION_INDEX[key] = index
end

local function SpecialActionIndex(def)
	local key = DB.keys[def.id]
	local index = key and SPECIAL_ACTION_INDEX[key]
	if index then return index end
	if (not key or key == "") and def.name then return SPECIAL_ACTION_INDEX[def.name] end
end

local VEHICLE_EXIT_SPECIAL_STATE = {
	func = function()
		local button = _G.KeyzenBarsVehicleExit
		if button then button:Click() end
	end,
	tooltip = "Leave vehicle",
	texture = "Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up",
}

local function IsSpecialBarPage(page)
	return page == 11
		or (GetVehicleBarIndex and page == GetVehicleBarIndex())
		or (GetOverrideBarIndex and page == GetOverrideBarIndex())
end

local function ApplySlots()
	for _, list in ipairs({ ns.KEYS, ns.NAGA }) do
		for _, def in ipairs(list) do
			local button = buttons[def.id]
			if button and def.bar ~= "main" then SetActionState(button, 0, SlotFor(def)) end
		end
	end
	for _, def in ipairs(ns.KEYS) do
		local button = buttons[def.id]
		if button and def.bar == "main" then SetActionState(button, 1, SlotFor(def)) end
	end
	for _, def in ipairs(ns.KEYS) do
		local button = buttons[def.id]
		if button then
			local actionIndex = SpecialActionIndex(def)
			for page = 1, 18 do
				if IsSpecialBarPage(page) then
					if actionIndex then
						SetActionState(button, page, (page - 1) * 12 + actionIndex)
					elseif def.name == "17" then
						button:SetState(page, "custom", VEHICLE_EXIT_SPECIAL_STATE)
					else
						SetActionState(button, page, SlotFor(def))
					end
				end
			end
		end
	end
end

local function CreateButton(def, header)
	defsById[def.id] = def
	local config = {
		showGrid = true,
		clickOnDown = GetCVarBool("ActionButtonUseKeyDown"),
		hideElements = { hotkey = true, equipped = true, borderIfEmpty = true },
		tooltip = "enabled",
	}
	local button = LAB:CreateButton(def.id, "KeyzenBarsButton" .. def.id, header, config)
	button.kzConfig = config
	if button.cooldown and button.cooldown.SetCountdownFont then
		button.cooldown:SetCountdownFont("KeyzenBarsCooldownFont")
	end
	if def.bar == "main" then
		for page = 1, 18 do
			button:SetState(page, "action", (page - 1) * 12 + def.i)
		end
		button:SetState(0, "action", SlotFor(def))
		button:SetState(1, "action", SlotFor(def))
	elseif def.bar == "reach" then
		local index = def.slot - 60
		for page = 1, 18 do
			button:SetState(page, "action", (page - 1) * 12 + index)
		end
		button:SetState(0, "action", SlotFor(def))
		button:SetState(1, "action", SlotFor(def))
	elseif def.slot then
		button:SetState(0, "action", SlotFor(def))
	end
	-- With buttons unlocked and "cast on click" off, a mouse click does
	-- nothing, so spells can be dragged around without firing. Keybinds
	-- arrive as the "Keybind" button and always cast.
	SecureHandlerWrapScript(button, "OnClick", header, [[
		if button ~= "Keybind" and self:GetAttribute("kzBlockMouse")
			and not (self:GetAttribute("gse-secure") and self:GetAttribute("type") == "click") then return false end
	]])
	StyleButton(button, def)
	buttons[def.id] = button
	return button
end

local function MainPageCondition()
	local cond = ""
	if GetOverrideBarIndex and GetVehicleBarIndex then
		cond = format("[overridebar] %d; [vehicleui][possessbar] %d; ", GetOverrideBarIndex(), GetVehicleBarIndex())
	end
	cond = cond .. "[bonusbar:5] 11; "
	if GetTempShapeshiftBarIndex then
		cond = cond .. format("[shapeshift] %d; ", GetTempShapeshiftBarIndex())
	end
	if DB.disableFormPaging then return cond .. "1" end
	local _, class = UnitClass("player")
	if class == "PRIEST" then cond = cond .. "[form:1] 7; " end
	-- Stances, forms and stealth swap the main bar like the default UI does.
	-- No [bar:N] here on purpose: Shift paging never moves this bar.
	return cond .. "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; 1"
end

local function ReachPageCondition()
	local cond = ""
	if GetOverrideBarIndex and GetVehicleBarIndex then
		cond = format("[overridebar] %d; [vehicleui][possessbar] %d; ", GetOverrideBarIndex(), GetVehicleBarIndex())
	end
	return cond .. "[bonusbar:5] 11; " .. tostring(DB.keyzen.reachPage or 6)
end

local function MakeFixedCell(def, parent)
	local cell = CreateFrame("Frame", nil, parent)
	AddBorder(cell, { 0.2, 0.2, 0.2 }, 0.12)
	local text = cell:CreateFontString(nil, "OVERLAY")
	text:SetFont(FontPath("mbold"), 11, "OUTLINE")
	text:SetPoint("CENTER")
	text:SetTextColor(0.6, 0.6, 0.6)
	text:SetText(def.label)
	cell:SetAlpha(def.faint and 0.15 or 0.7)
	cell.kzDef = def
	fixedCells[#fixedCells + 1] = cell
end

------------------------------------------------------------------------------
-- Extra bars: plain bars of 1-12 buttons on any action page
------------------------------------------------------------------------------

local function ExtraButtonId(n, i) return 1000 + n * 12 + i end

local function BuildExtraBar(n)
	if extraBuilt[n] then return end
	local holder = CreateHolder("extra" .. n, "Bar " .. n)
	local header = CreateHeader("Extra" .. n, holder)
	for i = 1, 12 do
		CreateButton({ id = ExtraButtonId(n, i), bar = "extra", extra = n, i = i }, header)
	end
	extraBuilt[n] = true
end

------------------------------------------------------------------------------
-- Stance / form bar: one button per form, cast by spell ID
------------------------------------------------------------------------------

local function UpdateStanceLooks()
	for i, button in ipairs(stanceButtons) do
		local icon, active, castable = GetShapeshiftFormInfo(i)
		if icon then
			button.icon:SetTexture(icon)
			button.icon:SetDesaturated(not castable)
			button.icon:SetAlpha(active and 1 or 0.75)
			if active and DB.activeHighlight then button.border:SetColorTexture(unpack(DB.activeColor)) else button.border:SetColorTexture(unpack(DB.borderColor)) end
		end
	end
end

local function CreateStanceBar()
	local holder = CreateHolder("stance", "Stances")
	for i = 1, MAX_STANCES do
		local button = CreateFrame("Button", "KeyzenBarsStance" .. i, holder, "SecureActionButtonTemplate")
		button:RegisterForClicks("AnyUp")
		button.border, button.bg = AddBorder(button, { 0, 0, 0 }, 0.06)
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetAllPoints(button)
		local highlight = button:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints(button)
		highlight:SetColorTexture(1, 1, 1, 0.15)
		button:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetShapeshift(i)
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", GameTooltip_Hide)
		button:Hide()
		stanceButtons[i] = button
	end
end

------------------------------------------------------------------------------
-- Applying settings. Everything that touches secure frames waits for the end
-- of combat.
------------------------------------------------------------------------------

local function UpdateLabels()
	for id, button in pairs(buttons) do
		button.kzLabel:SetText(KeyLabel(defsById[id], DB.keys[id]))
	end
end

local function PagingKeySignature()
	local parts = {}
	for _, command in ipairs(PAGE_COMMANDS) do
		parts[#parts + 1] = strjoin(",", command, GetBindingKey(command))
	end
	return table.concat(parts, ";")
end

local lastPagingSignature

local function ButtonActive(def)
	if def.bar == "main" then return DB.bars.keyzen.show and DB.keyzen.showMain end
	if def.bar == "reach" then
		if def.group == "far" and not DB.keyzen.showFar then return false end
		if def.group == "thumb" and not DB.keyzen.showThumb then return false end
		return DB.bars.keyzen.show and DB.keyzen.showReach
	end
	if def.bar == "naga" then return DB.bars.naga.show end
	if def.bar == "extra" then
		local cfg = DB.extra[def.extra]
		return cfg and cfg.show and def.i <= cfg.count
	end
end

local function ApplyBindings()
	if InCombatLockdown() then pending.bindings = true return end
	lastPagingSignature = PagingKeySignature()
	ClearOverrideBindings(bindOwner)
	local used = {}
	for id, button in pairs(buttons) do
		local key = DB.keys[id]
		if key and key ~= "" and ButtonActive(defsById[id]) then
			used[key] = true
			SetOverrideBindingClick(bindOwner, true, key, button:GetName(), "Keybind")
		end
	end
	if DB.blockShiftPaging then
		for _, command in ipairs(PAGE_COMMANDS) do
			for _, key in ipairs({ GetBindingKey(command) }) do
				if not used[key] then
					SetOverrideBindingClick(bindOwner, true, key, "KeyzenBarsNoop")
				end
			end
		end
	end
	UpdateLabels()
end
ns.ApplyBindings = ApplyBindings

local STRENGTH = { off = 0, light = 0.1, medium = 0.2, strong = 0.35 }

local LABEL_POINTS = {
	TOPRIGHT = { "TOPRIGHT", -2, -3, "RIGHT" },
	TOPLEFT = { "TOPLEFT", 3, -3, "LEFT" },
	TOP = { "TOP", 0, -3, "CENTER" },
	CENTER = { "CENTER", 0, 0, "CENTER" },
	BOTTOMRIGHT = { "BOTTOMRIGHT", -2, 3, "RIGHT" },
	BOTTOMLEFT = { "BOTTOMLEFT", 3, 3, "LEFT" },
}

local IsOverlayed = (C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed) or IsSpellOverlayed

-- pcall: on clients with secret values a spell's glow state can be one we
-- aren't allowed to test, and then the button simply doesn't glow.
local function SpellGlows(button)
	if not (DB.procGlow and IsOverlayed and button:HasAction()) then return false end
	local ok, on = pcall(function()
		local id = button:GetSpellId()
		return (id and IsOverlayed(id)) and true or false
	end)
	return ok and on
end

local function UpdateGlow(button)
	local glow = button.kzGlow
	if SpellGlows(button) then
		local c = DB.glowColor
		glow.border:SetColorTexture(c[1], c[2], c[3], 1)
		glow.tint:SetColorTexture(c[1], c[2], c[3], 0.18)
		if not glow:IsShown() then glow:Show() glow.anim:Play() end
	elseif glow:IsShown() then
		glow.anim:Stop()
		glow:Hide()
	end
end

-- Active stance, form, aura or auto attack. Blizzard marks those as checked;
-- a form spell is also matched by ID in case the client doesn't.
local function IsActive(button)
	if button:GetChecked() then return true end
	local form = GetShapeshiftForm and GetShapeshiftForm() or 0
	if form == 0 or not button:HasAction() then return false end
	local ok, on = pcall(function()
		local formSpell = select(4, GetShapeshiftFormInfo(form))
		return formSpell ~= nil and button:GetSpellId() == formSpell
	end)
	return ok and on
end

local function UpdateBorderColor(button)
	local c = DB.borderColor
	if DB.showEquipped and button:HasAction() and button:IsEquipped() then c = DB.equippedColor end
	if DB.activeHighlight and IsActive(button) then c = DB.activeColor end
	button.kzBorder:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
end

local function UpdateCooldownLooks(button)
	local cd = button.cooldown
	if not cd then return end
	if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(not DB.cooldownNumbers) end
	if cd.SetSwipeColor then cd:SetSwipeColor(0, 0, 0, DB.swipeAlpha) end
end

-- Icon crop, outline, fill and press/hover tints, shared by action and
-- stance buttons.
local function ApplyLooks(icon, border, bg)
	local z = DB.iconZoom
	icon:SetTexCoord(z, 1 - z, z, 1 - z)
	border:SetThickness(DB.borderSize)
	border:SetColorTexture(unpack(DB.borderColor))
	local c = DB.bgColor
	bg:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
	bg:SetShown(DB.showBackground)
end

-- Unlocked buttons ignore mouse clicks so spells can be moved without
-- casting them. A click is also how a spell on the cursor gets put down (a
-- drop onto a full button leaves its old spell on the cursor), so clicks go
-- through while the cursor holds something.
local function MouseBlocked()
	return (not DB.lockButtons and not DB.clickWhenUnlocked and not GetCursorInfo()) or nil
end

local function UpdateMouseBlock()
	if InCombatLockdown() then pending.settings = true return end
	local blockMouse = MouseBlocked()
	for _, button in pairs(buttons) do button:SetAttribute("kzBlockMouse", blockMouse) end
end

local function UpdateButtonSettings()
	if InCombatLockdown() then pending.settings = true return end
	local keyDown = GetCVarBool("ActionButtonUseKeyDown")
	local blockMouse = MouseBlocked()
	local textFont = FontPath(DB.textFont)
	local ic = DB.interactionColor
	local labelPoint = LABEL_POINTS[DB.keyPosition] or LABEL_POINTS.TOPRIGHT
	cooldownFont:SetFont(textFont, DB.cooldownFontSize, "OUTLINE")
	local rc = DB.rangeColor
	for _, button in pairs(buttons) do
		button:SetAttribute("buttonlock", DB.lockButtons or nil)
		button:SetAttribute("kzBlockMouse", blockMouse)
		button:SetAttribute("checkmouseovercast", GetCVarBool("enableMouseoverCast") or nil)
		local config = button.kzConfig
		config.clickOnDown = keyDown
		-- Hidden empty buttons still show while a spell is on the cursor.
		config.showGrid = not DB.hideEmpty
		config.hideElements.macro = not DB.showMacro
		config.outOfRangeColoring = DB.rangeColoring and "button" or "none"
		config.colors = { range = { rc[1], rc[2], rc[3] } }
		config.text = {
			macro = { font = { font = textFont, size = DB.macroFontSize, flags = "OUTLINE" },
				position = { anchor = "BOTTOM", relAnchor = "BOTTOM", offsetX = 0, offsetY = 2 } },
			count = { font = { font = textFont, size = DB.countFontSize, flags = "OUTLINE" },
				position = { anchor = "BOTTOMRIGHT", relAnchor = "BOTTOMRIGHT", offsetX = -2, offsetY = 3 } },
		}
		button:UpdateConfig(config)

		ApplyLooks(button.kzIcon, button.kzBorder, button.kzBg)
		if ns.DecorateWindowButton then ns.DecorateWindowButton(button) end
		if not button.kzCheckHook then
			button.kzCheckHook = true
			hooksecurefunc(button, "SetChecked", UpdateBorderColor)
		end
		UpdateBorderColor(button)
		for getter, tex in pairs(button.kzStates) do
			if getter == "GetCheckedTexture" then
				local a = DB.activeColor
				tex:SetColorTexture(a[1], a[2], a[3], DB.activeHighlight and 0.25 or 0)
			else
				local style = getter == "GetPushedTexture" and DB.pushedStyle or DB.highlightStyle
				tex:SetColorTexture(ic[1], ic[2], ic[3], STRENGTH[style] or 0.2)
			end
		end

		local label = button.kzLabel
		label:SetFont(FontPath(DB.keyFont), DB.keyFontSize, "OUTLINE")
		label:SetWidth(math.max(1, button:GetWidth() - 4))
		label:SetWordWrap(false)
		label:SetTextColor(unpack(DB.keyColor))
		label:ClearAllPoints()
		label:SetPoint(labelPoint[1], labelPoint[2], labelPoint[3])
		label:SetJustifyH(labelPoint[4])
		label:SetShown(DB.showKeybind)

		if button.cooldown and button.cooldown.SetCountdownFont then
			button.cooldown:SetCountdownFont("KeyzenBarsCooldownFont")
		end
		UpdateCooldownLooks(button)
		UpdateGlow(button)
	end
	for _, button in ipairs(stanceButtons) do
		ApplyLooks(button.icon, button.border, button.bg)
	end
	UpdateStanceLooks()
end

local function LayoutKeyzen()
	local holder, cfg = holders.keyzen, DB.bars.keyzen
	local size, step = cfg.size, cfg.size + cfg.spacing
	holder:SetSize(CellPoint(ns.ACTIVE_LAYOUT.columns, 1, step) + size,
		ns.ACTIVE_LAYOUT.rows * step - cfg.spacing)
	for _, def in ipairs(ns.KEYS) do
		local button = buttons[def.id]
		local x, y = CellPoint(def.c, def.r, step)
		Place(button, holder, x, y, size)
		button:SetShown(not ((def.group == "far" and not DB.keyzen.showFar)
			or (def.group == "thumb" and not DB.keyzen.showThumb)))
	end
	for _, cell in ipairs(fixedCells) do
		local x, y = CellPoint(cell.kzDef.c, cell.kzDef.r, step)
		Place(cell, holder, x, y, size)
		cell:SetShown(DB.keyzen.showFixed)
	end
	headers.Main:SetShown(DB.keyzen.showMain)
	headers.Reach:SetShown(DB.keyzen.showReach)
end

local function LayoutNaga()
	local holder, cfg = holders.naga, DB.bars.naga
	local size, step = cfg.size, cfg.size + cfg.spacing
	holder:SetSize(3 * step - cfg.spacing, 4 * step - cfg.spacing)
	for _, def in ipairs(ns.NAGA) do
		Place(buttons[def.id], holder, (def.c - 1) * step, -(def.r - 1) * step, size)
	end
end

local function LayoutExtra(n)
	local cfg = DB.extra[n]
	local holder = holders["extra" .. n]
	local perRow = math.max(1, math.min(cfg.perRow, cfg.count))
	local rows = math.ceil(cfg.count / perRow)
	local size, step = cfg.size, cfg.size + cfg.spacing
	holder:SetSize(perRow * step - cfg.spacing, rows * step - cfg.spacing)
	for i = 1, 12 do
		local button = buttons[ExtraButtonId(n, i)]
		local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
		Place(button, holder, col * step, -row * step, size)
		button:SetState(0, "action", (cfg.page - 1) * 12 + i)
		button:SetShown(i <= cfg.count)
	end
end

local function LayoutStances()
	local holder, cfg = holders.stance, DB.bars.stance
	local size, step = cfg.size, cfg.size + cfg.spacing
	local count = GetNumShapeshiftForms() or 0
	for i, button in ipairs(stanceButtons) do
		Place(button, holder, (i - 1) * step, 0, size)
		local spellID = i <= count and select(4, GetShapeshiftFormInfo(i))
		if spellID then
			button:SetAttribute("type", "spell")
			button:SetAttribute("spell", spellID)
			button:Show()
		else
			button:SetAttribute("type", nil)
			button:Hide()
		end
	end
	holder:SetSize(math.max(1, count) * step - cfg.spacing, size)
	UpdateStanceLooks()
end

------------------------------------------------------------------------------
-- Visibility: bars fade in and out by alpha, which is allowed in combat.
-- Faded bars keep working from their keys.
------------------------------------------------------------------------------

local function Visible(vis, frame)
	if vis == "always" then return true end
	if vis == "hidden" then return false end
	if vis == "combat" then return InCombatLockdown() end
	if vis == "nocombat" then return not InCombatLockdown() end
	if vis == "target" then return UnitExists("target") end
	if vis == "mouseover" then return frame:IsMouseOver() end
	return true
end

local fader = CreateFrame("Frame")
local fadeElapsed = 0
fader:SetScript("OnUpdate", function(_, elapsed)
	if not DB then return end
	fadeElapsed = fadeElapsed + elapsed
	if fadeElapsed < 0.03 then return end
	local dt = fadeElapsed
	fadeElapsed = 0
	-- Everything shows while you set things up or drag a spell around.
	local setup = not DB.lockFrames or bindMode or (ns.OptionsShown and ns.OptionsShown())
	local dragging = GetCursorInfo() ~= nil
	local function Fade(frame, want)
		local a = frame:GetAlpha()
		if a == want then return end
		local stepA = dt * 6
		if math.abs(want - a) <= stepA then a = want elseif want > a then a = a + stepA else a = a - stepA end
		frame:SetAlpha(a)
	end
	for key, frame in pairs(holders) do
		local cfg = BarDB(key)
		if cfg and cfg.show then
			local on = setup or dragging or Visible(cfg.visibility, frame)
			Fade(frame, on and cfg.alpha or 0)
		end
	end
end)

local function ApplyHolder(key)
	local cfg, frame = BarDB(key), holders[key]
	if not cfg then
		frame:Hide()
		movers[key]:Hide()
		return
	end
	frame:SetScale(cfg.scale)
	if cfg.visibility == "always" then frame:SetAlpha(cfg.alpha) end
	frame:ClearAllPoints()
	local p = cfg.point
	frame:SetPoint(p[1], UIParent, p[3], p[4], p[5])
	frame:SetShown(cfg.show)
	movers[key]:SetShown(cfg.show and not DB.lockFrames)
	local n = tonumber(key:match("^extra(%d+)$"))
	if n then movers[key].kzText:SetText(ns.ExtraBarName(n)) end
end

-- Re-apply every setting. The options window calls this after each change.
local function Refresh()
	if InCombatLockdown() then
		pending.refresh = true
		Print("Changes will apply when combat ends.")
		return
	end
	for n, cfg in ipairs(DB.extra) do
		DeepDefaults(cfg, { page = 2, count = 12, perRow = 12, show = true, scale = 1, alpha = 1,
			size = 38, spacing = 4, visibility = "always",
			point = { "CENTER", "UIParent", "CENTER", 0, -260 - n * 10 } })
		BuildExtraBar(n)
	end
	ApplySlots()
	RegisterStateDriver(headers.Main, "page", MainPageCondition())
	RegisterStateDriver(headers.Reach, "page", ReachPageCondition())
	LayoutKeyzen()
	LayoutNaga()
	LayoutStances()
	for n in pairs(extraBuilt) do
		if DB.extra[n] then LayoutExtra(n) end
	end
	for key in pairs(holders) do ApplyHolder(key) end
	UpdateButtonSettings()
	if ns.LayoutMenus then ns.LayoutMenus() end
	if ns.LayoutTotems then ns.LayoutTotems() end
	if ns.LayoutPetBar then ns.LayoutPetBar() end
	if ns.LayoutVehicleExit then ns.LayoutVehicleExit() end
	if ns.StyleXPBar then
		ns.StyleXPBar()
		ns.ApplyBlizzardXP()
	end
	ApplyBindings()
end
ns.Refresh = Refresh

------------------------------------------------------------------------------
-- Profiles, like ElvUI's: every character points at a named set of settings,
-- and single modules can be copied between sets. Saved variables:
--   KeyzenBarsDB = { profiles = { [name] = settings },
--                    profileKeys = { ["Name - Realm"] = name },
--                    xpChars = per-character XP bar data }
-- Switching, copying into or resetting the current profile reloads the UI,
-- since every bar is built from the settings at login.
------------------------------------------------------------------------------

local function CharKey()
	return (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
end

local function ProfileRoot()
	local root = KeyzenBarsDB or {}
	KeyzenBarsDB = root
	if type(root.profiles) ~= "table" then
		-- Before profiles every setting sat at the top: that becomes Default.
		local old = {}
		for k, v in pairs(root) do
			if k ~= "xpChars" then old[k] = v end
		end
		for k in pairs(old) do root[k] = nil end
		root.profiles = { Default = old }
	end
	root.profileKeys = root.profileKeys or {}
	return root
end

local function ActiveProfile(root)
	local name = root.profileKeys[CharKey()]
	if not (name and root.profiles[name]) then name = "Default" end
	root.profiles[name] = root.profiles[name] or {}
	return name
end

local function DeepCopy(v)
	if type(v) ~= "table" then return v end
	local t = {}
	for k, x in pairs(v) do t[k] = DeepCopy(x) end
	return t
end

-- What each module covers, as paths into a profile.
ns.PROFILE_MODULES = {
	{ key = "behavior", text = "Behavior", fields = { "lockFrames", "lockButtons", "clickWhenUnlocked",
		"blockShiftPaging", "disableFormPaging", "hideBlizzard", "autoAddSpells" } },
	{ key = "bars", text = "Bars", desc = "Positions, sizes, fading and extra bars.",
		fields = { "bars.keyzen", "bars.naga", "bars.stance", "keyzen", "extra" } },
	{ key = "keys", text = "Keybinds", fields = { "keys" } },
	{ key = "buttons", text = "Buttons", fields = { "borderSize", "borderColor", "iconZoom", "showBackground",
		"bgColor", "hideEmpty", "cooldownNumbers", "cooldownFontSize", "swipeAlpha", "rangeColoring", "rangeColor",
		"showEquipped", "equippedColor" } },
	{ key = "text", text = "Text", fields = { "showKeybind", "keyFont", "keyFontSize", "keyColor", "keyPosition",
		"fingerNames", "showMacro", "macroFontSize", "countFontSize", "textFont" } },
	{ key = "animations", text = "Animations", fields = { "flash", "pushedStyle", "highlightStyle",
		"interactionColor", "procGlow", "glowColor", "activeHighlight", "activeColor" } },
	{ key = "menus", text = "Utility bars", fields = { "ownMenus", "bars.menu", "bars.bags", "bars.totem", "bars.pet", "bars.vehicle" } },
	{ key = "xp", text = "Experience", fields = { "bars.xp" } },
	{ key = "window", text = "Options window", fields = { "optContentScale", "optWindowSize", "optArtAlpha",
		"optTint", "optAccent", "optTheme", "optClassAccent" } },
}

local function CopyField(from, to, path)
	local a, b = path:match("^(%w+)%.(%w+)$")
	if a then
		from, to, path = from[a] or {}, to, b
		to[a] = to[a] or {}
		to = to[a]
	end
	to[path] = DeepCopy(from[path])
end

function ns.ProfileNames()
	local names = {}
	for name in pairs(KeyzenBarsDB.profiles) do names[#names + 1] = name end
	table.sort(names)
	return names
end

function ns.CurrentProfile() return ActiveProfile(KeyzenBarsDB) end

-- Characters using a profile, for the delete prompt.
function ns.ProfileUsers(name)
	local n = 0
	for _, p in pairs(KeyzenBarsDB.profileKeys) do
		if p == name then n = n + 1 end
	end
	return n
end

function ns.SetProfile(name)
	local root = KeyzenBarsDB
	root.profiles[name] = root.profiles[name] or {}
	root.profileKeys[CharKey()] = name
	ReloadUI()
end

-- A new profile starts from the defaults, or as a copy of the current one.
function ns.NewProfile(name, copyCurrent)
	local root = KeyzenBarsDB
	if root.profiles[name] then return false end
	root.profiles[name] = copyCurrent and DeepCopy(DB) or {}
	ns.SetProfile(name)
	return true
end

function ns.CopyProfile(from)
	local source = KeyzenBarsDB.profiles[from]
	if not source or source == DB then return end
	local copy = DeepCopy(source)
	wipe(DB)
	for k, v in pairs(copy) do DB[k] = v end
	ReloadUI()
end

function ns.ResetProfile()
	wipe(DB)
	ReloadUI()
end

function ns.DeleteProfile(name)
	local root = KeyzenBarsDB
	if name == ns.CurrentProfile() or not root.profiles[name] then return end
	root.profiles[name] = nil
	for char, p in pairs(root.profileKeys) do
		if p == name then root.profileKeys[char] = nil end
	end
end

-- Copies the chosen modules between the current profile and another one.
-- "import" brings them into the current profile (and reloads), "export"
-- sends the current profile's to the other.
function ns.CopyModules(other, chosen, direction)
	local target = KeyzenBarsDB.profiles[other]
	if not target or target == DB then return end
	local from, to = DB, target
	if direction == "import" then from, to = target, DB end
	for _, module in ipairs(ns.PROFILE_MODULES) do
		if chosen[module.key] then
			for _, path in ipairs(module.fields) do CopyField(from, to, path) end
		end
	end
	if direction == "import" then ReloadUI() end
end

------------------------------------------------------------------------------
-- New spells: when one is learned, put it on the first empty button of the
-- shown bars (Keyzen main keys, then reach keys, Naga, extra bars). Bag bars
-- are left for items. Placing needs no combat, so spells learned in combat
-- wait for it to end.
------------------------------------------------------------------------------

local spellQueue = {}

local function OpenSlots()
	local slots = {}
	if DB.bars.keyzen.show then
		for _, def in ipairs(ns.KEYS) do
			if ButtonActive(def) then slots[#slots + 1] = SlotFor(def) end
		end
	end
	if DB.bars.naga.show then
		for _, def in ipairs(ns.NAGA) do slots[#slots + 1] = SlotFor(def) end
	end
	for _, cfg in ipairs(DB.extra) do
		if cfg.show and cfg.kind ~= "bag" then
			for i = 1, cfg.count do slots[#slots + 1] = (cfg.page - 1) * 12 + i end
		end
	end
	return slots
end

local function IsPassive(spellID)
	if C_Spell and C_Spell.IsSpellPassive then return C_Spell.IsSpellPassive(spellID) end
	return IsPassiveSpell and IsPassiveSpell(spellID)
end

local function OnABar(spellID)
	if C_ActionBar and C_ActionBar.FindSpellActionButtons then
		local found = C_ActionBar.FindSpellActionButtons(spellID)
		return found and #found > 0
	end
	return false
end

local function PlaceSpell(spellID)
	-- Never touch the cursor while the player is holding something on it.
	if GetCursorInfo() then return end
	local ok, skip = pcall(function() return IsPassive(spellID) or OnABar(spellID) end)
	if not ok or skip then return end
	for _, slot in ipairs(OpenSlots()) do
		if not HasAction(slot) then
			if C_Spell and C_Spell.PickupSpell then C_Spell.PickupSpell(spellID) else PickupSpell(spellID) end
			if GetCursorInfo() then
				PlaceAction(slot)
				ClearCursor()
			end
			return
		end
	end
end

local function FlushSpells()
	if not DB.autoAddSpells or InCombatLockdown() then return end
	local list = spellQueue
	spellQueue = {}
	for _, spellID in ipairs(list) do PlaceSpell(spellID) end
end

-- Blizzard's own "add new spells" would fill its slots too and doubles up.
function ns.ApplyAutoSpells()
	if DB.autoAddSpells and GetCVar("AutoPushSpellToActionBar") then SetCVar("AutoPushSpellToActionBar", "0") end
end

local function OnSpellLearned(spellID)
	if not DB.autoAddSpells or type(spellID) ~= "number" then return end
	spellQueue[#spellQueue + 1] = spellID
	-- The spellbook settles a moment after the event.
	C_Timer.After(0.5, FlushSpells)
end

function ns.ExtraBarName(n)
	local cfg = DB.extra[n]
	return (cfg and cfg.kind == "bag" and "Bag bar " or "Bar ") .. n
end

-- First action page nobody else uses. The Keyzen and Naga have theirs (1, 6
-- and 4 unless moved), and 7-10 are the main bar's stance and form pages.
local function FreePage()
	local used = { [DB.keyzen.mainPage or 1] = true, [DB.keyzen.reachPage or 6] = true, [DB.bars.naga.page or 4] = true }
	for _, cfg in ipairs(DB.extra) do if cfg.page then used[cfg.page] = true end end
	for _, page in ipairs({ 2, 3, 5 }) do
		if not used[page] then return page end
	end
	return 2
end

-- kind "bag": a strip of small buttons along the bottom of the screen for
-- hearthstones, potions and anything else worth keeping in reach.
function ns.AddExtraBar(kind)
	if #DB.extra >= MAX_EXTRA_BARS then Print("That's the most extra bars for now.") return end
	local n = #DB.extra + 1
	local cfg = { page = FreePage() }
	if kind == "bag" then
		local bags = 0
		for _, other in ipairs(DB.extra) do if other.kind == "bag" then bags = bags + 1 end end
		cfg.kind = "bag"
		cfg.size = 30
		cfg.point = { "BOTTOM", "UIParent", "BOTTOM", 0, 8 + bags * 38 }
	end
	DB.extra[n] = cfg
	Refresh()
	return n
end

-- Removing shifts later bars down so their settings and keys stay together.
function ns.RemoveExtraBar(n)
	if not DB.extra[n] then return end
	for m = n, #DB.extra do
		for i = 1, 12 do
			DB.keys[ExtraButtonId(m, i)] = DB.keys[ExtraButtonId(m + 1, i)]
		end
	end
	table.remove(DB.extra, n)
	Refresh()
end

------------------------------------------------------------------------------
-- Hover-to-bind: hover a button, press the key the Azeron or Naga sends
------------------------------------------------------------------------------

local function SetBindMode(on)
	if on and InCombatLockdown() then Print("Can't bind keys in combat.") return end
	bindMode = on
	capture:SetShown(on)
	capture:EnableKeyboard(on)
	for _, button in pairs(buttons) do button.kzBindTint:SetShown(on) end
	if on then
		Print("Bind mode on. Hover a button and press a key. Delete clears a key. Esc stops.")
	else
		GameTooltip:Hide()
		Print("Bind mode off.")
	end
end
ns.SetBindMode = SetBindMode
function ns.InBindMode() return bindMode end

local function HoveredButton()
	for id, button in pairs(buttons) do
		if button:IsVisible() and button:IsMouseOver() then return id, button end
	end
end

local function OnCaptureKey(_, key)
	if MODIFIER_KEYS[key] then return end
	if key == "ESCAPE" then SetBindMode(false) return end
	local id, button = HoveredButton()
	if not id then Print("Hover one of the bar buttons first.") return end
	if key == "DELETE" then
		DB.keys[id] = ""
		Print("Cleared " .. KeyName(defsById[id]) .. ".")
	else
		local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
			.. (IsShiftKeyDown() and "SHIFT-" or "") .. key
		for otherId, otherKey in pairs(DB.keys) do
			if otherKey == combo and otherId ~= id then DB.keys[otherId] = "" end
		end
		DB.keys[id] = combo
		Print(KeyName(defsById[id]) .. " is now " .. combo .. ".")
	end
	ApplySlots()
	ApplyBindings()
	if button:IsMouseOver() then button:GetScript("OnEnter")(button) end
end

------------------------------------------------------------------------------
-- Setup
------------------------------------------------------------------------------

local function DefaultKeys()
	local keys = {}
	for _, def in ipairs(ns.KEYS) do keys[def.id] = def.key end
	for _, def in ipairs(ns.NAGA) do keys[def.id] = def.key end
	return keys
end

local function KnownKeyIds()
	local ids = {}
	for _, layout in pairs(ns.DEVICE_LAYOUTS) do
		for _, def in ipairs(layout.keys) do ids[def.id] = true end
	end
	for _, def in ipairs(ns.NAGA) do ids[def.id] = true end
	return ids
end

-- Keep saved keys, fill in defaults for buttons that didn't have one, and
-- drop keys of Keyzen buttons that no longer exist. Extra bar ids are > 1000.
local function MergeKeys(saved)
	local keys = DefaultKeys()
	local known = KnownKeyIds()
	for id, key in pairs(saved or {}) do
		if known[id] or id > 1000 then keys[id] = key end
	end
	return keys
end

function ns.ResetKeys()
	local keys = DefaultKeys()
	local known = KnownKeyIds()
	for id, key in pairs(DB.keys) do
		if id > 1000 or (known[id] and keys[id] == nil) then keys[id] = key end
	end
	DB.keys = keys
	ApplySlots()
	ApplyBindings()
	Print("Keyzen and Naga keys reset to the plan defaults.")
end

local function Init()
	local root = ProfileRoot()
	DB = root.profiles[ActiveProfile(root)]
	root.profileKeys[CharKey()] = ActiveProfile(root)
	MigrateOldSettings(DB)
	DeepDefaults(DB, DEFAULTS)
	ns.ACTIVE_LAYOUT = ns.DEVICE_LAYOUTS[DB.keyzen.device] or ns.DEVICE_LAYOUTS.keyzen
	DB.keyzen.device = ns.ACTIVE_LAYOUT == ns.DEVICE_LAYOUTS.cyborg2 and "cyborg2" or "keyzen"
	ns.KEYS, ns.FIXED = ns.ACTIVE_LAYOUT.keys, ns.ACTIVE_LAYOUT.fixed
	DB.keys = MergeKeys(DB.keys)
	ns.DB = DB

	bindOwner = CreateFrame("Frame", "KeyzenBarsBindOwner", UIParent)
	CreateFrame("Button", "KeyzenBarsNoop", UIParent, "SecureActionButtonTemplate")

	local keyzen = CreateHolder("keyzen", "Keyzen")
	local main = CreateHeader("Main", keyzen)
	main:SetAttribute("_onstate-page", [[
		self:SetAttribute("state", newstate)
		control:ChildUpdate("state", newstate)
	]])
	local reach = CreateHeader("Reach", keyzen)
	reach:SetAttribute("_onstate-page", [[
		self:SetAttribute("state", newstate)
		control:ChildUpdate("state", newstate)
	]])
	for _, def in ipairs(ns.FIXED) do MakeFixedCell(def, keyzen) end
	for _, def in ipairs(ns.KEYS) do CreateButton(def, def.bar == "main" and main or reach) end

	local naga = CreateHolder("naga", "Naga")
	local nagaHeader = CreateHeader("Naga", naga)
	for _, def in ipairs(ns.NAGA) do CreateButton(def, nagaHeader) end

	CreateStanceBar()
	if DB.ownMenus and ns.CreateMenus then ns.CreateMenus() end
	if ns.CreateTotems then ns.CreateTotems() end
	if ns.CreatePetBar then ns.CreatePetBar() end
	if ns.CreateVehicleExit then ns.CreateVehicleExit() end
	if ns.CreateXPBar then ns.CreateXPBar() end

	LAB.RegisterCallback(ns, "OnButtonUpdate", function(_, button)
		if button.kzGlow then
			UpdateGlow(button)
			UpdateBorderColor(button)
			if ns.DecorateWindowButton then ns.DecorateWindowButton(button) end
		end
	end)
	LAB.RegisterCallback(ns, "OnCooldownUpdate", function(_, button)
		if button.kzGlow then UpdateCooldownLooks(button) end
	end)

	capture = CreateFrame("Frame", nil, UIParent)
	capture:SetAllPoints(UIParent)
	capture:EnableMouse(false)
	capture:SetPropagateKeyboardInput(false)
	capture:SetScript("OnKeyDown", OnCaptureKey)
	capture:Hide()

	ns.ApplyAutoSpells()
	Refresh()
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
	"UPDATE_BINDINGS", "CVAR_UPDATE", "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_FORM",
	"UPDATE_SHAPESHIFT_USABLE", "SPELLS_CHANGED", "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW",
	"SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED",
	"LEARNED_SPELL_IN_SKILL_LINE", "LEARNED_SPELL_IN_TAB", "CURSOR_CHANGED", "CURSOR_UPDATE" }) do
	pcall(events.RegisterEvent, events, event) -- not every client has every event
end
events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON then
		-- Saved variables are ready here, still before combat state is restored.
		local root = ProfileRoot()
		if root.profiles[ActiveProfile(root)].hideBlizzard ~= false then ns.HideBlizzardBars() end
	elseif event == "PLAYER_LOGIN" then
		if InCombatLockdown() then pending.init = true else Init() end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pending.init then pending.init = nil Init() return end
		if pending.refresh then
			wipe(pending)
			Refresh()
			return
		end
		if pending.settings then pending.settings = nil UpdateButtonSettings() end
		if pending.bindings then pending.bindings = nil ApplyBindings() end
		if pending.stances then pending.stances = nil LayoutStances() end
		FlushSpells()
	elseif event == "PLAYER_REGEN_DISABLED" then
		if bindMode then SetBindMode(false) end
		if ns.HideOptions then ns.HideOptions() end
	elseif not DB then
		return
	elseif event == "LEARNED_SPELL_IN_SKILL_LINE" or event == "LEARNED_SPELL_IN_TAB" then
		OnSpellLearned(arg1)
	elseif event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_USABLE" then
		UpdateStanceLooks()
		for _, button in pairs(buttons) do UpdateBorderColor(button) end
	elseif event == "UPDATE_SHAPESHIFT_FORMS" or event == "SPELLS_CHANGED" then
		if InCombatLockdown() then pending.stances = true UpdateStanceLooks() else LayoutStances() end
	elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
		for _, button in pairs(buttons) do UpdateGlow(button) end
	elseif event == "PLAYER_ENTERING_WORLD" or event == "EDIT_MODE_LAYOUTS_UPDATED" then
		if ns.LayoutMenus then ns.LayoutMenus() end
	elseif event == "CURSOR_CHANGED" or event == "CURSOR_UPDATE" then
		UpdateMouseBlock()
	elseif event == "UPDATE_BINDINGS" then
		-- Normal keybinds changed: re-check which keys flip bar pages. Our own
		-- override calls also fire this event, so only act on a real change.
		if PagingKeySignature() ~= lastPagingSignature then ApplyBindings() end
	elseif event == "CVAR_UPDATE" and (arg1 == "ActionButtonUseKeyDown" or arg1 == "enableMouseoverCast") then
		UpdateButtonSettings()
	end
end)

SLASH_KEYZENBARS1 = "/kz"
SLASH_KEYZENBARS2 = "/keyzen"
SlashCmdList.KEYZENBARS = function(msg)
	if not DB then Print("Not loaded yet. Try again after combat.") return end
	local cmd = strsplit(" ", strtrim(msg or ""):lower())
	if cmd == "bind" then
		SetBindMode(not bindMode)
	elseif cmd == "unlock" then
		DB.lockFrames = false Refresh()
	elseif cmd == "lock" then
		DB.lockFrames = true Refresh()
	elseif cmd == "reset" then
		ns.ResetKeys()
	else
		ns.ToggleOptions()
	end
end

-- /kb toggles bind mode, like most action bar addons. If another addon also
-- takes /kb, /kzbind always works.
SLASH_KEYZENBARSBIND1 = "/kb"
SLASH_KEYZENBARSBIND2 = "/kzbind"
SlashCmdList.KEYZENBARSBIND = function()
	if not DB then Print("Not loaded yet. Try again after combat.") return end
	SetBindMode(not bindMode)
end
