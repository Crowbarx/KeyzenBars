local _, ns = ...

-- Experience bar in ToxiUI's look: the class gradient fill on a dark tinted
-- track, completed quest XP and rested XP shown ahead of the fill, and three
-- lines of numbers (times above, the bar's own text, rate and bonuses below).
-- It sits in a Keyzen Bars holder, so it moves, fades and locks like the
-- other bars.

ns.XP_TEXTURES = {
	{ value = "flat", text = "Flat", file = "Interface\\Buttons\\WHITE8x8" },
	{ value = "blizzard", text = "Blizzard", file = "Interface\\TargetingFrame\\UI-StatusBar" },
}

-- ToxiUI's class gradient: deep end on the left, bright end on the right.
local CLASS_GRADIENT = {
	DEATHKNIGHT = { "911622", "ff2855" }, DEMONHUNTER = { "8200a9", "e500d1" }, DRUID = { "e76200", "ffa900" },
	EVOKER = { "33706f", "32fedc" }, HUNTER = { "4acc35", "abed4f" }, MAGE = { "0080d7", "00d8ff" },
	MONK = { "009463", "00ff8c" }, PALADIN = { "d960a4", "ff95d8" }, PRIEST = { "b9b9b9", "fcfcfc" },
	ROGUE = { "ffb759", "fff368" }, SHAMAN = { "0061bf", "0a7ded" }, WARLOCK = { "562fbd", "9946ff" },
	WARRIOR = { "946837", "dfaa73" },
}
local QUEST_COLOR = { 1, 0.59, 0 }
local RESTED_COLOR = { 0.31, 0.56, 1 }
local MUTED = { 0.75, 0.75, 0.75 }

local function Hex(h)
	return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255
end

local function Colorize(rgb, text)
	local f = math.floor
	return string.format("|cff%02x%02x%02x%s|r", f(rgb[1] * 255 + 0.5), f(rgb[2] * 255 + 0.5), f(rgb[3] * 255 + 0.5), text)
end

local bar -- the frame and its parts, built once
local state = { quest = 0, complete = 0 }

local function Cfg() return ns.DB.bars.xp end

-- Per character, so alts keep their own session and played time.
local function CharDB()
	local DB = KeyzenBarsDB -- shared by every profile
	DB.xpChars = DB.xpChars or {}
	local key = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
	DB.xpChars[key] = DB.xpChars[key] or {}
	return DB.xpChars[key]
end

local function Now() return GetServerTime() end

local function MaxLevel()
	local max = GetMaxPlayerLevel and GetMaxPlayerLevel() or 60
	if GetMaxLevelForExpansionLevel and GetExpansionLevel then
		max = math.min(max, GetMaxLevelForExpansionLevel(GetExpansionLevel()) or max)
	end
	return max
end

local function AtMax()
	return UnitLevel("player") >= MaxLevel() or (IsXPUserDisabled and IsXPUserDisabled())
end

------------------------------------------------------------------------------
-- Numbers
------------------------------------------------------------------------------

local function Short(n)
	if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
	if n >= 1e4 then return string.format("%.1fK", n / 1e3) end
	return BreakUpLargeNumbers and BreakUpLargeNumbers(math.floor(n)) or tostring(math.floor(n))
end

local function Long(n)
	return BreakUpLargeNumbers and BreakUpLargeNumbers(math.floor(n)) or tostring(math.floor(n))
end

local function Time(sec)
	if not sec or sec < 60 then return "< 1m" end
	local d, h, m = math.floor(sec / 86400), math.floor(sec % 86400 / 3600), math.floor(sec % 3600 / 60)
	if d > 0 then return string.format("%dd %dh %dm", d, h, m) end
	if h > 0 then return string.format("%dh %dm", h, m) end
	return string.format("%dm", m)
end

-- Played time: the server tells us once (/played), then we count on from
-- there, so it ticks every second without asking again.
local function Played()
	local p = CharDB().played
	if not p then return end
	local since = Now() - p.at
	return p.total + since, p.level + since
end

local function Session()
	local s = CharDB().session
	local elapsed = s and (Now() - s.start) or 0
	local rate = 0
	-- A minute in before the rate means much.
	if s and elapsed >= 60 and s.gained > 0 then rate = s.gained / elapsed * 3600 end
	return elapsed, rate, s and s.gained or 0
end

-- XP of quests in the log, split by done (ready to hand in) and not yet.
local function ScanQuests()
	local total, complete = 0, 0
	local QL = C_QuestLog
	if GetQuestLogRewardXP and QL and QL.GetNumQuestLogEntries then
		for i = 1, QL.GetNumQuestLogEntries() do
			local ok, id, xp, done = pcall(function()
				local info = QL.GetInfo and QL.GetInfo(i)
				if info and info.isHeader then return end
				local q = (info and info.questID) or (QL.GetQuestIDForLogIndex and QL.GetQuestIDForLogIndex(i))
				if not q or q == 0 then return end
				local finished = (QL.IsComplete and QL.IsComplete(q))
					or (QL.ReadyForTurnIn and QL.ReadyForTurnIn(q))
					or (info and info.isComplete == 1 or info and info.isComplete == true)
				return q, GetQuestLogRewardXP(q) or 0, finished
			end)
			if ok and id and xp > 0 then
				total = total + xp
				if done then complete = complete + xp end
			end
		end
	end
	state.quest, state.complete = total, complete
end

------------------------------------------------------------------------------
-- Drawing
------------------------------------------------------------------------------

local function Texture()
	local key = Cfg().texture
	for _, t in ipairs(ns.XP_TEXTURES) do
		if t.value == key then return t.file end
	end
	return ns.XP_TEXTURES[1].file
end

local function Colors()
	local cfg = Cfg()
	if cfg.classColor then
		local _, class = UnitClass("player")
		local g = CLASS_GRADIENT[class or ""]
		if g then
			local r1, g1, b1 = Hex(g[1])
			local r2, g2, b2 = Hex(g[2])
			return { r1, g1, b1 }, { r2, g2, b2 }
		end
	end
	local c = cfg.color
	return { c[1] * 0.6, c[2] * 0.6, c[3] * 0.6 }, { c[1], c[2], c[3] }
end

local function SetFill(sb, value, max)
	sb:SetMinMaxValues(0, math.max(1, max))
	sb:SetValue(math.min(value, max))
end

local function Draw()
	if not bar then return end
	local cfg = Cfg()
	local atMax = AtMax()
	local show = cfg.show and (not atMax or cfg.showAtMax)
	bar.body:SetShown(show)
	if not show then return end

	local cur, max = UnitXP("player") or 0, UnitXPMax("player") or 1
	local rested = GetXPExhaustion() or 0
	local remaining = math.max(0, max - cur)
	local complete = cfg.questOverlay and state.complete or 0
	if atMax then cur, max, rested, complete, remaining = 1, 1, 0, 0, 0 end

	SetFill(bar.fill, cur, max)
	SetFill(bar.questFill, cur + complete, max)
	SetFill(bar.restedFill, cur + complete + (cfg.restedOverlay and rested or 0), max)

	local level = UnitLevel("player")
	local deep, bright = Colors()
	bar.levelText:SetText("Level " .. Colorize(bright, level))
	if atMax then
		bar.valueText:SetText("Max level")
		bar.percentText:SetText("")
	else
		bar.valueText:SetText(string.format("%s / %s  %s", Long(cur), Long(max),
			Colorize(MUTED, "(" .. Long(remaining) .. " to go)")))
		local pct = cur / max * 100
		local text = string.format("%.1f%%", pct)
		if complete > 0 then text = text .. Colorize(QUEST_COLOR, string.format("  %.1f%%", (cur + complete) / max * 100)) end
		bar.percentText:SetText(text)
	end

	-- Times above the bar.
	local total, levelTime = Played()
	local elapsed, rate = Session()
	bar.levelTime:SetText(total and ((atMax and "Played " or "This level ") .. Colorize(bright, Time(atMax and total or levelTime))) or "")
	bar.totalTime:SetText((total and not atMax) and ("Played " .. Colorize(bright, Time(total))) or "")
	bar.sessionTime:SetText("Session " .. Colorize(bright, Time(elapsed)))
	bar.top:SetShown(cfg.showTimes)

	-- Rate and bonuses below it.
	if atMax then
		bar.rateText:SetText("")
		bar.bonusText:SetText("")
	else
		local last = CharDB().lastGain or 0
		local left
		if rate > 0 then
			left = string.format("Level in %s  %s", Colorize(bright, Time(remaining / rate * 3600)),
				Colorize(MUTED, "(" .. Short(rate) .. " XP/hr)"))
		else
			left = "Level in " .. Colorize(MUTED, "-- (no XP this session)")
		end
		if cfg.showLastGain and last > 0 then
			left = left .. Colorize(MUTED, string.format("   %s more like the last (%s)", Long(math.ceil(remaining / last)), Short(last)))
		end
		bar.rateText:SetText(left)
		local parts = {}
		if state.complete > 0 then
			parts[#parts + 1] = "Quests ready " .. Colorize(QUEST_COLOR, string.format("%.1f%%", state.complete / max * 100))
		end
		if state.quest > state.complete then
			parts[#parts + 1] = "In log " .. Colorize(QUEST_COLOR, string.format("%.1f%%", state.quest / max * 100))
		end
		parts[#parts + 1] = "Rested " .. Colorize(RESTED_COLOR, string.format("%.1f%%", rested / max * 100))
		bar.bonusText:SetText(table.concat(parts, "   "))
	end
	bar.bottom:SetShown(cfg.showRate)
end
ns.DrawXPBar = Draw

-- Size, texture, colors and fonts, from the settings.
local function Style()
	if not bar then return end
	local cfg = Cfg()
	local holder = bar.holder
	holder:SetSize(cfg.width, cfg.height)
	local tex = Texture()
	local deep, bright = Colors()
	for _, sb in ipairs({ bar.fill, bar.questFill, bar.restedFill }) do sb:SetStatusBarTexture(tex) end
	local fill = bar.fill:GetStatusBarTexture()
	fill:SetVertexColor(1, 1, 1, 1)
	if fill.SetGradient and CreateColor then
		fill:SetGradient("HORIZONTAL", CreateColor(deep[1], deep[2], deep[3], 1),
			CreateColor(bright[1], bright[2], bright[3], 1))
	else
		fill:SetVertexColor(bright[1], bright[2], bright[3], 1)
	end
	bar.questFill:SetStatusBarColor(QUEST_COLOR[1], QUEST_COLOR[2], QUEST_COLOR[3], 0.55)
	bar.restedFill:SetStatusBarColor(RESTED_COLOR[1], RESTED_COLOR[2], RESTED_COLOR[3], 0.45)
	bar.track:SetTexture(tex)
	local m = 0.35 -- ToxiUI's background multiplier
	bar.track:SetVertexColor(bright[1] * m * 0.5, bright[2] * m * 0.5, bright[3] * m * 0.5, cfg.trackAlpha)

	for _, fs in ipairs(bar.barTexts) do ns.ApplyTextStyle(fs, cfg.font, cfg.fontSize, cfg.textStyle) end
	for _, fs in ipairs(bar.lineTexts) do ns.ApplyTextStyle(fs, cfg.font, cfg.lineFontSize, cfg.textStyle) end
	bar.border:SetShown(cfg.border)
	Draw()
end
ns.StyleXPBar = Style

-- Text styles. "SLUG" is the client's vector font renderer: glyphs are drawn
-- at the screen's real resolution, so outlines stay smooth on 4K where the
-- normal renderer stair-steps them (the same fix as the ToxiUI plugin). On
-- this client a drop shadow only shows when it comes from a font object, so
-- strings are primed with one before SetFont.
ns.TEXT_STYLES = {
	{ value = "smooth", text = "Smooth outline", flags = "OUTLINE, SLUG" },
	{ value = "smoothshadow", text = "Smooth, shadow only", flags = "SLUG", shadow = true },
	{ value = "classic", text = "Classic outline", flags = "OUTLINE" },
	{ value = "shadow", text = "Shadow only", flags = "", shadow = true },
}

local shadowFont = CreateFont("KeyzenBarsShadowFont")
shadowFont:SetFont(STANDARD_TEXT_FONT, 12, "")
shadowFont:SetShadowColor(0, 0, 0, 1)
shadowFont:SetShadowOffset(1, -1)
local plainFont = CreateFont("KeyzenBarsPlainFont")
plainFont:SetFont(STANDARD_TEXT_FONT, 12, "")
plainFont:SetShadowColor(0, 0, 0, 0)
plainFont:SetShadowOffset(0, 0)

function ns.ApplyTextStyle(fs, fontKey, size, styleKey)
	local style = ns.TEXT_STYLES[1]
	for _, s in ipairs(ns.TEXT_STYLES) do
		if s.value == styleKey then style = s end
	end
	local flags = style.flags
	-- EllesmereUI's "Never Show Slug" setting wins when it's loaded.
	if flags:find("SLUG") and EllesmereUI and EllesmereUI.IsSlugDisabled and EllesmereUI.IsSlugDisabled() then
		flags = flags == "SLUG" and "" or "OUTLINE"
	end
	local slug = flags:find("SLUG") ~= nil
	fs:SetFontObject(style.shadow and shadowFont or plainFont)
	local path = ns.FontPath(fontKey)
	if not fs:SetFont(path, size, flags) then
		slug = false
		if not fs:SetFont(path, size, "OUTLINE") then fs:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE") end
	end
	if fs.SetScaleAnimationMode and FontStringScaleAnimationMode then
		fs:SetScaleAnimationMode(slug and FontStringScaleAnimationMode.Vertex or FontStringScaleAnimationMode.FontSize)
	end
	fs:SetTextColor(1, 1, 1, 1)
end

local function Text(parent, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(STANDARD_TEXT_FONT, 12, "")
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetJustifyH(justify)
	fs:SetWordWrap(false)
	return fs
end

local function Edge(parent, a, b, horizontal)
	local t = parent:CreateTexture(nil, "BORDER")
	t:SetColorTexture(0, 0, 0, 1)
	t:SetPoint(a, parent, a, 0, 0)
	t:SetPoint(b, parent, b, 0, 0)
	if horizontal then t:SetHeight(1) else t:SetWidth(1) end
end

local function Tooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:AddLine("Experience")
	local cur, max = UnitXP("player") or 0, UnitXPMax("player") or 1
	local rested = GetXPExhaustion() or 0
	local elapsed, rate, gained = Session()
	GameTooltip:AddDoubleLine("Current", string.format("%s / %s", Long(cur), Long(max)), 1, 1, 1, 1, 1, 1)
	GameTooltip:AddDoubleLine("To go", Long(math.max(0, max - cur)), 1, 1, 1, 1, 1, 1)
	GameTooltip:AddDoubleLine("Rested", Long(rested), 1, 1, 1, RESTED_COLOR[1], RESTED_COLOR[2], RESTED_COLOR[3])
	GameTooltip:AddDoubleLine("Quests ready to hand in", Long(state.complete), 1, 1, 1, QUEST_COLOR[1], QUEST_COLOR[2], QUEST_COLOR[3])
	GameTooltip:AddDoubleLine("All quests in log", Long(state.quest), 1, 1, 1, QUEST_COLOR[1], QUEST_COLOR[2], QUEST_COLOR[3])
	GameTooltip:AddDoubleLine("Gained this session", Long(gained), 1, 1, 1, 1, 1, 1)
	GameTooltip:AddDoubleLine("Session", Time(elapsed), 1, 1, 1, 1, 1, 1)
	GameTooltip:AddDoubleLine("XP per hour", rate > 0 and Long(rate) or "--", 1, 1, 1, 1, 1, 1)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Right-click: start a new session", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

local function NewSession()
	local c = CharDB()
	c.session = { start = Now(), gained = 0 }
	c.lastXP, c.lastMax = UnitXP("player"), UnitXPMax("player")
	Draw()
end

function ns.CreateXPBar()
	local holder = ns.CreateHolder("xp", "Experience")
	bar = { holder = holder }
	local body = CreateFrame("Frame", nil, holder)
	body:SetAllPoints(holder)
	bar.body = body

	bar.track = body:CreateTexture(nil, "BACKGROUND")
	bar.track:SetAllPoints(body)
	local function Fill(level)
		local sb = CreateFrame("StatusBar", nil, body)
		sb:SetAllPoints(body)
		sb:SetFrameLevel(body:GetFrameLevel() + level)
		return sb
	end
	bar.restedFill = Fill(1)
	bar.questFill = Fill(2)
	bar.fill = Fill(3)
	local border = CreateFrame("Frame", nil, body)
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)
	border:SetFrameLevel(body:GetFrameLevel() + 4)
	Edge(border, "TOPLEFT", "TOPRIGHT", true)
	Edge(border, "BOTTOMLEFT", "BOTTOMRIGHT", true)
	Edge(border, "TOPLEFT", "BOTTOMLEFT")
	Edge(border, "TOPRIGHT", "BOTTOMRIGHT")
	bar.border = border

	local overlay = CreateFrame("Frame", nil, body)
	overlay:SetAllPoints(body)
	overlay:SetFrameLevel(body:GetFrameLevel() + 5)
	bar.levelText = Text(overlay, "LEFT")
	bar.levelText:SetPoint("LEFT", 8, 0)
	bar.valueText = Text(overlay, "CENTER")
	bar.valueText:SetPoint("CENTER")
	bar.percentText = Text(overlay, "RIGHT")
	bar.percentText:SetPoint("RIGHT", -8, 0)
	bar.barTexts = { bar.levelText, bar.valueText, bar.percentText }

	local top = CreateFrame("Frame", nil, body)
	top:SetPoint("BOTTOMLEFT", body, "TOPLEFT", 0, 4)
	top:SetPoint("BOTTOMRIGHT", body, "TOPRIGHT", 0, 4)
	top:SetHeight(14)
	bar.top = top
	bar.levelTime = Text(top, "LEFT")
	bar.levelTime:SetPoint("LEFT", 2, 0)
	bar.totalTime = Text(top, "CENTER")
	bar.totalTime:SetPoint("CENTER")
	bar.sessionTime = Text(top, "RIGHT")
	bar.sessionTime:SetPoint("RIGHT", -2, 0)

	local bottom = CreateFrame("Frame", nil, body)
	bottom:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -4)
	bottom:SetPoint("TOPRIGHT", body, "BOTTOMRIGHT", 0, -4)
	bottom:SetHeight(14)
	bar.bottom = bottom
	bar.rateText = Text(bottom, "LEFT")
	bar.rateText:SetPoint("LEFT", 2, 0)
	bar.bonusText = Text(bottom, "RIGHT")
	bar.bonusText:SetPoint("RIGHT", -2, 0)
	bar.lineTexts = { bar.levelTime, bar.totalTime, bar.sessionTime, bar.rateText, bar.bonusText }

	body:EnableMouse(true)
	body:SetScript("OnEnter", Tooltip)
	body:SetScript("OnLeave", GameTooltip_Hide)
	body:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" then NewSession() end
	end)

	-- Ticks once a second for the clocks.
	local elapsed = 0
	body:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed >= 1 then elapsed = 0 Draw() end
	end)

	ns.ApplyBlizzardXP()
	ScanQuests()
	Style()
end

------------------------------------------------------------------------------
-- Blizzard's own XP bar
------------------------------------------------------------------------------

local blizzHooked
function ns.ApplyBlizzardXP()
	local frame = _G.StatusTrackingBarManager or _G.MainStatusTrackingBarContainer
	if not frame then return end
	if not blizzHooked then
		blizzHooked = true
		hooksecurefunc(frame, "Show", function(self)
			if ns.DB.bars.xp.hideBlizzard then self:Hide() end
		end)
	end
	if ns.DB.bars.xp.hideBlizzard then frame:Hide() else frame:Show() end
end

------------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------------

-- /played without the chat lines: chat frames stop listening for the
-- answer while we ask, then listen again.
local muted = {}
local function AskPlayed()
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		local cf = _G["ChatFrame" .. i]
		if cf and cf:IsEventRegistered("TIME_PLAYED_MSG") then
			cf:UnregisterEvent("TIME_PLAYED_MSG")
			muted[#muted + 1] = cf
		end
	end
	RequestTimePlayed()
	-- In case the answer never comes.
	C_Timer.After(10, function()
		for _, cf in ipairs(muted) do cf:RegisterEvent("TIME_PLAYED_MSG") end
		wipe(muted)
	end)
end

local questPending
local function QueueQuests()
	if questPending then return end
	questPending = true
	C_Timer.After(0.5, function()
		questPending = false
		ScanQuests()
		Draw()
	end)
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "TIME_PLAYED_MSG",
	"QUEST_LOG_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_UPDATE_RESTING", "DISABLE_XP_GAIN", "ENABLE_XP_GAIN" }) do
	pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event, a1, a2)
	if not (ns.DB and bar) then return end
	local c = CharDB()
	if event == "PLAYER_ENTERING_WORLD" then
		-- A new session on login; a /reload carries on the old one.
		if a1 or not c.session then NewSession() end
		c.lastXP, c.lastMax = c.lastXP or UnitXP("player"), c.lastMax or UnitXPMax("player")
		AskPlayed()
		QueueQuests()
		ns.ApplyBlizzardXP()
	elseif event == "PLAYER_XP_UPDATE" then
		local cur, max = UnitXP("player"), UnitXPMax("player")
		local last, lastMax = c.lastXP or cur, c.lastMax or max
		-- A level up wraps the number back round.
		local gain = cur >= last and (cur - last) or (lastMax - last + cur)
		if gain > 0 then
			c.session = c.session or { start = Now(), gained = 0 }
			c.session.gained = c.session.gained + gain
			c.lastGain = gain
		end
		c.lastXP, c.lastMax = cur, max
		Draw()
	elseif event == "PLAYER_LEVEL_UP" then
		local total = Played()
		if total then c.played = { total = total, level = 0, at = Now() } end
		QueueQuests()
	elseif event == "TIME_PLAYED_MSG" then
		c.played = { total = a1 or 0, level = a2 or 0, at = Now() }
		for _, cf in ipairs(muted) do cf:RegisterEvent("TIME_PLAYED_MSG") end
		wipe(muted)
		Draw()
	elseif event == "QUEST_LOG_UPDATE" then
		QueueQuests()
	else
		Draw()
	end
end)
