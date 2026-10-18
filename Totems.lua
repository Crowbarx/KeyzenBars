local _, ns = ...

-- The shaman call totem bar (Blizzard's MultiCastActionBarFrame: Call of the
-- Elements, the four element slots and Totemic Recall), moved into a Keyzen
-- Bars holder so it unlocks, drags, sizes and fades like the other bars, and
-- given the Keyzen button look. The bar stays Blizzard's: its own code fills
-- it and its buttons are secure, so everything here runs out of combat and a
-- combat request waits for it to end.
--
-- The bar is an Edit Mode system. Its own SetPoint and SetScale tell Edit
-- Mode the bar moved, so the saved base methods are used instead, and every
-- time Edit Mode or a bar update puts it back, it is pinned here again.
-- If EllesmereUI's Call Totem Bar has the bar, this leaves it alone.

local bar = _G.MultiCastActionBarFrame
local BTN = 30 -- the bar's button size, in its own units

local SUMMON = _G.MultiCastSummonSpellButton
local RECALL = _G.MultiCastRecallSpellButton
local SLOT, ACT = {}, {}
for i = 1, 4 do SLOT[i] = _G["MultiCastSlotButton" .. i] end
for i = 1, 12 do ACT[i] = _G["MultiCastActionButton" .. i] end

local holder, busy, queued
local borders = {}
local order = {}

local function Base(frame, method)
	return frame[method .. "Base"] or frame[method]
end

-- EllesmereUI's version pins the bar to its own holder; two owners would
-- fight over it.
local function TakenByEllesmere()
	local other = _G.ERB_CallTotemBarFrame
	return other and other:IsShown()
end

local function Fade(region)
	if region and region.SetAlpha then region:SetAlpha(0) end
end

local function Skin(button)
	if not button then return end
	Fade(button:GetNormalTexture())
	Fade(button.SlotArt)
	Fade(button.SlotBackground)
	Fade(button.overlayTex)
	local name = button:GetName()
	if name and (button == SUMMON or button == RECALL) then Fade(_G[name .. "Highlight"]) end
	local icon = button.icon
	if icon then
		-- A masked texture ignores SetTexCoord, so the mask comes off first.
		if button.IconMask and icon.RemoveMaskTexture then
			pcall(icon.RemoveMaskTexture, icon, button.IconMask)
			button.IconMask:Hide()
		end
		local z = ns.DB.iconZoom or 0.08
		pcall(icon.SetTexCoord, icon, z, 1 - z, z, 1 - z)
	end
	local border = borders[button]
	if not border then
		border = ns.AddBorder(button, { 0, 0, 0 })
		borders[button] = border
	end
	local db = ns.DB
	border:SetThickness(db.borderSize or 1)
	border:SetColorTexture(unpack(db.borderColor or { 0, 0, 0, 1 }))
end

-- The shown buttons in a row or a column, each totem button on its element
-- slot. Blizzard's updates re-anchor the first slot by its BOTTOMLEFT and
-- Totemic Recall by its LEFT, so those are the points used here too.
local function Layout()
	if not holder or InCombatLockdown() or TakenByEllesmere() then return end
	local cfg = ns.BarDB("totem")
	if not cfg then return end
	busy = true
	if bar:GetParent() ~= holder then bar:SetParent(holder) end
	Base(bar, "SetScale")(bar, 1)

	wipe(order)
	if SUMMON and SUMMON:IsShown() then order[#order + 1] = SUMMON end
	local n = tonumber(bar.numActiveSlots) or 0
	for i = 1, n do order[#order + 1] = SLOT[i] end
	if RECALL and RECALL:IsShown() then order[#order + 1] = RECALL end
	local count = #order
	local gap = cfg.spacing or 4
	local vertical = cfg.orientation == "vertical"
	local len = count > 0 and (count * BTN + (count - 1) * gap) or BTN

	for i, button in ipairs(order) do
		local off = (i - 1) * (BTN + gap)
		local x = vertical and 0 or off
		local y = vertical and (len - BTN - off) or 0
		button:ClearAllPoints()
		if button == RECALL then
			button:SetPoint("LEFT", bar, "BOTTOMLEFT", x, y + BTN / 2)
		else
			button:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, y)
		end
	end
	for i, button in ipairs(ACT) do
		button:ClearAllPoints()
		button:SetPoint("CENTER", SLOT[(i - 1) % 4 + 1], "CENTER", 0, 0)
	end

	local w, h = len, BTN
	if vertical then w, h = BTN, len end
	bar:SetSize(w, h)
	Base(bar, "ClearAllPoints")(bar)
	Base(bar, "SetPoint")(bar, "TOPLEFT", holder, "TOPLEFT", 0, 0)
	holder:SetSize(w, h)

	Skin(SUMMON)
	Skin(RECALL)
	for _, button in ipairs(ACT) do Skin(button) end
	for i = 1, 4 do Fade(SLOT[i].overlayTex) end
	-- Edit Mode can't select or drag it while it's ours.
	if bar.Selection then
		bar.Selection:SetAlpha(0)
		bar.Selection:EnableMouse(false)
	end
	busy = false
end

-- Blizzard re-anchors the bar, its first slot and Totemic Recall on many of
-- its own updates; each is answered with our layout on the next frame.
local function Queue()
	if busy or queued or not holder then return end
	queued = true
	C_Timer.After(0, function()
		queued = false
		if InCombatLockdown() then ns.QueueTotems() else Layout() end
	end)
end

local waiting = CreateFrame("Frame")
waiting:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	Layout()
end)
function ns.QueueTotems()
	waiting:RegisterEvent("PLAYER_REGEN_ENABLED")
end

-- Blizzard hangs the flyout arrow above the hovered button; in a column that
-- covers the button above it, so a column gets it beside the button.
local function OnFlyoutArrow(arrow, _, parent)
	if not (holder and arrow and parent) or arrow:GetParent() ~= parent then return end
	local cfg = ns.BarDB("totem")
	arrow:ClearAllPoints()
	if cfg and cfg.orientation == "vertical" then
		arrow:SetPoint("LEFT", parent, "RIGHT", 0, 0)
	else
		arrow:SetPoint("BOTTOM", parent, "TOP", 0, 0)
	end
end

function ns.TotemsAvailable()
	return holder ~= nil
end

function ns.LayoutTotems()
	if InCombatLockdown() then ns.QueueTotems() return end
	Layout()
end

function ns.CreateTotems()
	if not (bar and SLOT[1]) then return end
	local _, class = UnitClass("player")
	if class ~= "SHAMAN" or TakenByEllesmere() then return end
	holder = ns.CreateHolder("totem", "Totems")
	if bar.ApplySystemAnchor then hooksecurefunc(bar, "ApplySystemAnchor", Queue) end
	if bar.BreakFrameSnap then hooksecurefunc(bar, "BreakFrameSnap", Queue) end
	local manager = _G.EditModeManagerFrame
	if manager and manager.UpdateBottomActionBarPositions then
		hooksecurefunc(manager, "UpdateBottomActionBarPositions", Queue)
	end
	if type(_G.MultiCastActionBarFrame_Update) == "function" then
		hooksecurefunc("MultiCastActionBarFrame_Update", Queue)
	end
	if type(_G.MultiCastFlyoutFrameOpenButton_Show) == "function" then
		hooksecurefunc("MultiCastFlyoutFrameOpenButton_Show", OnFlyoutArrow)
	end
	bar:HookScript("OnShow", Queue)
	Layout()
end
