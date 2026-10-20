local _, ns = ...

-- Hide Blizzard's own action bars. Same approach Ellesmere uses on this
-- client: reparent the bars to a hidden frame instead of calling Hide(),
-- which taints Blizzard's protected show/hide path. MainActionBar stays in
-- Blizzard's parent chain (the micro menu needs it after pet battles), so it
-- is made invisible and unclickable instead. The pet bar stays where it is:
-- PetBar.lua borrows its buttons and keeps the bar itself running unseen.
local REPARENT = {
	"MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
	"MultiBar5", "MultiBar6", "MultiBar7", "StanceBar",
}

local hiddenParent = CreateFrame("Frame", "KeyzenBarsHiddenParent", UIParent)
hiddenParent:SetAllPoints(UIParent)
hiddenParent:Hide()

local function NoMouse(frame)
	if not frame or type(frame.EnableMouse) ~= "function" then return end
	frame:EnableMouse(false)
	if frame.EnableMouseClicks then frame:EnableMouseClicks(false) end
	if frame.EnableMouseMotion then frame:EnableMouseMotion(false) end
end

-- The main bar's buttons stay on screen at alpha 0, so they also stop
-- taking the mouse; otherwise they swallow drops meant for our bars under them.
local function QuietButtons(frame)
	if type(frame.actionButtons) ~= "table" then return end
	for _, button in pairs(frame.actionButtons) do
		button:UnregisterAllEvents()
		button:SetAttributeNoHandler("statehidden", true)
		NoMouse(button)
	end
end

-- The page arrows on the main bar stay clickable at alpha 0.
local function KillPager(bar)
	local pager = bar.ActionBarPageNumber
	if not pager then return end
	NoMouse(pager)
	NoMouse(pager.UpButton)
	NoMouse(pager.DownButton)
end

-- The gold dividers between main bar buttons come from a pool Blizzard
-- refills whenever the bar lays itself out.
local function HideDividers(bar)
	if bar.dividersPool and bar.dividersPool.EnumerateActive then
		for divider in bar.dividersPool:EnumerateActive() do divider:Hide() end
	end
end

local function HideMainBar(bar)
	bar:SetAlpha(0)
	NoMouse(bar)
	KillPager(bar)
	HideDividers(bar)
	hooksecurefunc(bar, "Show", function(self)
		self:SetAlpha(0)
		KillPager(self)
	end)
	-- Blizzard sets the bar's alpha back up in places (moving the micro menu
	-- and bags is one), which brings its art back. Keep it at 0.
	local locking
	hooksecurefunc(bar, "SetAlpha", function(self, alpha)
		if locking or alpha == 0 then return end
		locking = true
		self:SetAlpha(0)
		locking = false
	end)
	for _, method in ipairs({ "UpdateDividers", "Layout", "UpdateGridLayout" }) do
		if type(bar[method]) == "function" then hooksecurefunc(bar, method, HideDividers) end
	end
	if bar.Selection then bar.Selection:SetAlpha(0) end
	local caps = bar.EndCaps
	if caps then
		caps:Hide()
		for _, cap in ipairs({ caps.LeftEndCap, caps.RightEndCap }) do
			if cap and cap.Selection then cap.Selection:SetAlpha(0) NoMouse(cap.Selection) end
		end
	end
	if bar.BorderArt then bar.BorderArt:Hide() end
	QuietButtons(bar)
end

function ns.HideBlizzardBars()
	-- Some clients have both frames; hide each one once.
	local done = {}
	for _, name in ipairs({ "MainActionBar", "MainMenuBar" }) do
		local bar = _G[name]
		if bar and not done[bar] then
			done[bar] = true
			HideMainBar(bar)
		end
	end
	for _, name in ipairs(REPARENT) do
		local bar = _G[name]
		if bar then
			bar:UnregisterAllEvents()
			bar:SetParent(hiddenParent)
			QuietButtons(bar)
		end
	end
	if _G.ActionBarParent then _G.ActionBarParent:SetParent(hiddenParent) end
end
