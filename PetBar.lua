local _, ns = ...

-- The pet bar: Blizzard's ten pet action buttons, moved into a Keyzen Bars
-- holder so they unlock, drag, size and fade like the other bars, with the
-- Keyzen button look. Blizzard's PetActionBar keeps running them (it fills
-- the icons, autocast and cooldowns, and its keybinds still press them);
-- it just isn't drawn. A secure driver shows the buttons only while there's
-- a pet. Moving them is protected, so layout waits for combat to end.

local bar = _G.PetActionBar
local COUNT = _G.NUM_PET_ACTION_SLOTS or 10
local VISIBILITY = "[petbattle][overridebar][vehicleui] hide; [pet] show; hide"

local holder, frame, busy, queued
local buttons, borders = {}, {}

local function Fade(region)
	if region and region.SetAlpha then region:SetAlpha(0) end
end

-- Visual only, so it's safe in combat. Blizzard puts some of this art back
-- on its updates, so it runs after each one.
local function Skin(button)
	local db = ns.DB
	Fade(button:GetNormalTexture())
	for _, key in ipairs({ "SlotBackground", "SlotArt", "Border", "FloatingBG" }) do Fade(button[key]) end
	local icon = button.icon or button.Icon
	if icon then
		if button.IconMask and icon.RemoveMaskTexture then
			pcall(icon.RemoveMaskTexture, icon, button.IconMask)
			button.IconMask:Hide()
		end
		icon:ClearAllPoints()
		icon:SetAllPoints(button)
		local z = db.iconZoom or 0.08
		icon:SetTexCoord(z, 1 - z, z, 1 - z)
		for _, getter in ipairs({ "GetHighlightTexture", "GetPushedTexture", "GetCheckedTexture" }) do
			local tex = button[getter] and button[getter](button)
			if tex then tex:SetAllPoints(icon) end
		end
	end
	local border = borders[button]
	if not border then
		border = ns.AddBorder(button, { 0, 0, 0 }, 0.06)
		borders[button] = border
	end
	border:SetThickness(db.borderSize or 1)
	border:SetColorTexture(unpack(db.borderColor or { 0, 0, 0, 1 }))
	local hotkey = button.HotKey
	if hotkey then
		hotkey:SetFont(ns.FontPath(db.keyFont), 11, "OUTLINE")
		hotkey:ClearAllPoints()
		hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -3)
	end
end

local function SkinAll()
	for _, button in ipairs(buttons) do Skin(button) end
end

local function Layout()
	if not frame or InCombatLockdown() then return end
	local cfg = ns.BarDB("pet")
	if not cfg then return end
	busy = true
	local size, sp = cfg.size or 30, cfg.spacing or 4
	local perRow = math.max(1, math.min(cfg.perRow or COUNT, #buttons))
	local lines = math.ceil(#buttons / perRow)
	local horizontal = cfg.orientation ~= "vertical"
	for i, button in ipairs(buttons) do
		if button:GetParent() ~= frame then button:SetParent(frame) end
		local along, across = (i - 1) % perRow, math.floor((i - 1) / perRow)
		local col, row = along, across
		if not horizontal then col, row = across, along end
		button:SetSize(size, size)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", col * (size + sp), -row * (size + sp))
	end
	local cols, rows = perRow, lines
	if not horizontal then cols, rows = lines, perRow end
	holder:SetSize(math.max(1, cols * (size + sp) - sp), math.max(1, rows * (size + sp) - sp))
	SkinAll()
	busy = false
end

local waiting = CreateFrame("Frame")
waiting:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	Layout()
end)

-- Blizzard re-lays its bar on its own updates, which puts the buttons back
-- on it; each is answered with our layout on the next frame (after combat,
-- if it happens in one).
local function Queue()
	if busy or queued or not frame then return end
	queued = true
	C_Timer.After(0, function()
		queued = false
		SkinAll()
		if InCombatLockdown() then waiting:RegisterEvent("PLAYER_REGEN_ENABLED") else Layout() end
	end)
end

function ns.PetBarAvailable()
	return holder ~= nil
end

function ns.LayoutPetBar()
	if not frame then return end
	if InCombatLockdown() then waiting:RegisterEvent("PLAYER_REGEN_ENABLED") return end
	Layout()
end

function ns.CreatePetBar()
	if not (bar and _G.PetActionButton1) then return end
	for i = 1, COUNT do
		local button = _G["PetActionButton" .. i]
		if button then buttons[#buttons + 1] = button end
	end
	holder = ns.CreateHolder("pet", "Pet")
	frame = CreateFrame("Frame", "KeyzenBarsPetFrame", holder, "SecureHandlerStateTemplate")
	frame:SetAllPoints(holder)
	RegisterStateDriver(frame, "visibility", VISIBILITY)

	-- Blizzard's bar stays alive (it runs the buttons) but is never drawn.
	bar:SetAlpha(0)
	bar:EnableMouse(false)
	if bar.Selection then
		bar.Selection:SetAlpha(0)
		bar.Selection:EnableMouse(false)
	end
	local locking
	hooksecurefunc(bar, "SetAlpha", function(self, alpha)
		if locking or alpha == 0 then return end
		locking = true
		self:SetAlpha(0)
		locking = false
	end)
	for _, method in ipairs({ "Update", "UpdateGridLayout", "Layout", "ApplySystemAnchor" }) do
		if type(bar[method]) == "function" then hooksecurefunc(bar, method, Queue) end
	end
	bar:HookScript("OnShow", Queue)
	Layout()
end
