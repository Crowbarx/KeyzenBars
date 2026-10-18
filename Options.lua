local _, ns = ...

-- Settings window opened with /kz, laid out like EllesmereUI and Polestar: a
-- sidebar of pages, tabs along the top, and two columns of option rows over
-- the background art. Plain frames and color textures only, so it works the
-- same on every client. Each control writes to the saved settings, then
-- ns.Refresh() re-applies everything (or waits for combat to end).

local WIDTH, HEIGHT = 1000, 680
local SIDEBAR = 232
local HEADER = 108
local TABS = 46
local FOOTER = 66
local PAD = 32
local ROW_H = 52
local GAP = 2
local ART_W, ART_H = 734, 1000 -- OptionsBackground.png

local FONT_BOLD = ns.MEDIA .. "Fonts\\Montserrat-Bold.ttf"
local FONT_MED = ns.MEDIA .. "Fonts\\Montserrat-Medium.ttf"
local TEXT = { 0.95, 0.95, 0.95 }
local MUTED = { 0.64, 0.64, 0.68 }

local DB
local window, root, menu -- root holds everything and carries the content scale
local widgets = {}  -- refresh functions, run after every change
local views = {}    -- scrolling tab pages, re-laid out after every change
local selectedBar = "keyzen"

local function ClassRGB()
	local _, class = UnitClass("player")
	local c = class and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
		or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
	if c then return c.r, c.g, c.b end
end

local function Accent()
	if DB.optClassAccent then
		local r, g, b = ClassRGB()
		if r then return { r, g, b, 1 } end
	end
	return DB.optAccent
end

-- Window themes, like EllesmereUI's and Polestar's. Sylvanas is only offered
-- when this copy has her art.
local SYLVANAS = ns.MEDIA .. "OptionsBackground.png"
local THEMES = {
	{ value = "sylvanas", text = "Sylvanas", personal = true },
	{ value = "classcolor", text = "Class colored" },
	{ value = "midnight", text = "Midnight" },
	{ value = "dark", text = "Dark" },
}
local function ThemeChoices()
	local list = {}
	for _, t in ipairs(THEMES) do
		if not t.personal or ns.HAS_SYLVANAS then list[#list + 1] = t end
	end
	return list
end

local function RefreshWidgets()
	for _, fn in ipairs(widgets) do fn() end
	for _, view in ipairs(views) do view:Relayout() end
end

-- Sliders fire on every pixel of a drag, so the bars are rebuilt at most
-- once per frame.
local queued
local function Changed()
	RefreshWidgets()
	if queued then return end
	queued = true
	C_Timer.After(0, function()
		queued = false
		ns.Refresh()
	end)
end

------------------------------------------------------------------------------
-- Drawing helpers
------------------------------------------------------------------------------

local function SetFont(fs, path, size, color)
	fs:SetFont(path, size, "")
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 0.9)
	if color then fs:SetTextColor(color[1], color[2], color[3]) end
end

local function Label(parent, path, size, color, text)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	SetFont(fs, path, size, color)
	fs:SetJustifyH("LEFT")
	if text then fs:SetText(text) end
	return fs
end

local function Fill(parent, layer, r, g, b, a, sublevel)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel)
	t:SetColorTexture(r, g, b, a)
	return t
end

-- 1px outline inside the frame's edges. Returns a function that recolors it.
local function Outline(frame, r, g, b, a)
	local edges = {}
	for i = 1, 4 do edges[i] = frame:CreateTexture(nil, "BORDER") end
	edges[1]:SetPoint("TOPLEFT") edges[1]:SetPoint("TOPRIGHT") edges[1]:SetHeight(1)
	edges[2]:SetPoint("BOTTOMLEFT") edges[2]:SetPoint("BOTTOMRIGHT") edges[2]:SetHeight(1)
	edges[3]:SetPoint("TOPLEFT") edges[3]:SetPoint("BOTTOMLEFT") edges[3]:SetWidth(1)
	edges[4]:SetPoint("TOPRIGHT") edges[4]:SetPoint("BOTTOMRIGHT") edges[4]:SetWidth(1)
	local function Set(nr, ng, nb, na)
		for _, e in ipairs(edges) do e:SetColorTexture(nr, ng, nb, na or 1) end
	end
	Set(r, g, b, a)
	return Set
end

-- Down chevron from Blizzard's square button sheet (present on every client).
local function Chevron(parent)
	local t = parent:CreateTexture(nil, "OVERLAY")
	t:SetTexture("Interface\\Buttons\\SquareButtonTextures")
	t:SetTexCoord(0.453125, 0.640625, 0.203125, 0.015625)
	t:SetSize(12, 12)
	t:SetVertexColor(0.8, 0.8, 0.82)
	return t
end

local function FlatButton(parent, text, width, height, onClick, primary)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, height or 34)
	Fill(b, "BACKGROUND", 0, 0, 0, 0.5):SetAllPoints()
	local outline = Outline(b, 1, 1, 1, 0.16)
	b.text = Label(b, FONT_BOLD, 13, TEXT, text)
	b.text:SetPoint("CENTER")
	b.text:SetJustifyH("CENTER")
	local function Paint(hover)
		local a = Accent()
		if primary or hover then outline(a[1], a[2], a[3], 1) else outline(1, 1, 1, 0.16) end
		if primary then b.text:SetTextColor(a[1], a[2], a[3]) end
	end
	b:SetScript("OnEnter", function() Paint(true) end)
	b:SetScript("OnLeave", function() Paint(false) end)
	b:SetScript("OnClick", onClick)
	widgets[#widgets + 1] = function() Paint(b:IsMouseOver()) end
	return b
end

------------------------------------------------------------------------------
-- Popups: one dropdown list and Blizzard's color picker
------------------------------------------------------------------------------

local function CloseMenu()
	if menu then menu:Hide() end
end

local MENU_ITEM = 28
local MENU_ROWS = 12 -- longer lists scroll

-- choices: { { value =, text =, font = } }
local function OpenMenu(anchor, choices, current, pick)
	if not menu then
		menu = CreateFrame("Frame", nil, root)
		menu:SetFrameStrata("FULLSCREEN_DIALOG")
		menu:EnableMouse(true)
		Fill(menu, "BACKGROUND", 0.05, 0.05, 0.07, 0.98):SetAllPoints()
		Outline(menu, 1, 1, 1, 0.16)
		menu.scroll = CreateFrame("ScrollFrame", nil, menu)
		menu.scroll:SetPoint("TOPLEFT", 1, -1)
		menu.scroll:SetPoint("BOTTOMRIGHT", -1, 1)
		menu.child = CreateFrame("Frame", nil, menu.scroll)
		menu.scroll:SetScrollChild(menu.child)
		menu.thumb = Fill(menu, "ARTWORK", 1, 1, 1, 0.25)
		menu.thumb:SetWidth(3)
		menu.scroll:EnableMouseWheel(true)
		menu.scroll:SetScript("OnMouseWheel", function(self, delta)
			local maxScroll = math.max(0, menu.child:GetHeight() - self:GetHeight())
			self:SetVerticalScroll(math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * MENU_ITEM * 3)))
			menu:UpdateThumb()
		end)
		function menu:UpdateThumb()
			local view, total = self.scroll:GetHeight(), self.child:GetHeight()
			local maxScroll = total - view
			if maxScroll <= 0 then self.thumb:Hide() return end
			local h = math.max(20, view * view / total)
			self.thumb:SetHeight(h)
			self.thumb:ClearAllPoints()
			self.thumb:SetPoint("TOPRIGHT", -2, -1 - (self.scroll:GetVerticalScroll() / maxScroll) * (view - h))
			self.thumb:Show()
		end
		menu.items = {}
		-- A click anywhere else in the window closes the list.
		menu.catcher = CreateFrame("Button", nil, root)
		menu.catcher:SetAllPoints(root)
		menu.catcher:SetFrameStrata("FULLSCREEN")
		menu.catcher:SetScript("OnClick", CloseMenu)
		menu.catcher:Hide()
		menu:SetScript("OnHide", function() menu.catcher:Hide() end)
	end
	local a = Accent()
	local selected
	for i, choice in ipairs(choices) do
		local item = menu.items[i]
		if not item then
			item = CreateFrame("Button", nil, menu.child)
			item:SetHeight(MENU_ITEM)
			item:SetPoint("TOPLEFT", 0, -(i - 1) * MENU_ITEM)
			item:SetPoint("TOPRIGHT", 0, -(i - 1) * MENU_ITEM)
			item.hl = Fill(item, "HIGHLIGHT", 1, 1, 1, 0.08)
			item.hl:SetAllPoints()
			item.mark = Fill(item, "ARTWORK", 1, 1, 1, 1)
			item.mark:SetPoint("TOPLEFT", 0, -4)
			item.mark:SetPoint("BOTTOMLEFT", 0, 4)
			item.mark:SetWidth(3)
			item.text = Label(item, FONT_MED, 12, TEXT)
			item.text:SetPoint("LEFT", 14, 0)
			item.text:SetPoint("RIGHT", -10, 0)
			item.text:SetWordWrap(false)
			menu.items[i] = item
		end
		SetFont(item.text, choice.font or FONT_MED, choice.font and 14 or 12, TEXT)
		item.text:SetText(choice.text)
		item.mark:SetColorTexture(a[1], a[2], a[3], 1)
		item.mark:SetShown(choice.value == current)
		if choice.value == current then selected = i end
		item:SetScript("OnClick", function()
			CloseMenu()
			pick(choice.value)
		end)
		item:Show()
	end
	for i = #choices + 1, #menu.items do menu.items[i]:Hide() end
	local rows = math.min(#choices, MENU_ROWS)
	menu:SetSize(anchor:GetWidth(), rows * MENU_ITEM + 2)
	menu.child:SetSize(anchor:GetWidth() - 2, #choices * MENU_ITEM)
	menu:ClearAllPoints()
	menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	-- Open scrolled so the current choice is in view.
	local maxScroll = math.max(0, (#choices - rows) * MENU_ITEM)
	menu.scroll:SetVerticalScroll(math.min(maxScroll, math.max(0, ((selected or 1) - 3) * MENU_ITEM)))
	menu.catcher:Show()
	menu:Show()
	menu:UpdateThumb()
end

local function OpenColorPicker(get, set, hasAlpha)
	local c = get()
	local r, g, b, a = c[1], c[2], c[3], c[4] or 1
	local picker = ColorPickerFrame
	local function Apply()
		local nr, ng, nb = picker:GetColorRGB()
		local na = a
		if hasAlpha then
			if picker.GetColorAlpha then
				na = picker:GetColorAlpha()
			elseif OpacitySliderFrame then
				na = 1 - OpacitySliderFrame:GetValue() -- older pickers store transparency
			end
		end
		set({ nr, ng, nb, na })
		Changed()
	end
	local function Cancel()
		set({ r, g, b, a })
		Changed()
	end
	if picker.SetupColorPickerAndShow then
		picker:SetupColorPickerAndShow({
			r = r, g = g, b = b, opacity = a, hasOpacity = hasAlpha,
			swatchFunc = Apply, opacityFunc = Apply, cancelFunc = Cancel,
		})
	else
		picker.hasOpacity, picker.opacity = hasAlpha, 1 - a
		picker.func, picker.opacityFunc, picker.cancelFunc = Apply, Apply, Cancel
		picker:SetColorRGB(r, g, b)
		picker:Hide()
		picker:Show()
	end
	picker:SetFrameStrata("FULLSCREEN_DIALOG") -- above this window
end

------------------------------------------------------------------------------
-- Rows and controls
------------------------------------------------------------------------------

-- A section: small caps heading with a rule, then rows two to a line.
-- shown (optional) hides the whole section, e.g. Keyzen-only options.
local function Section(view, title, shown)
	local s = CreateFrame("Frame", nil, view.child)
	s.rows, s.shown = {}, shown
	local h = Label(s, FONT_BOLD, 11, MUTED, title:upper())
	h:SetPoint("TOPLEFT", 2, 0)
	local rule = Fill(s, "ARTWORK", 1, 1, 1, 0.08)
	rule:SetHeight(1)
	rule:SetPoint("LEFT", h, "RIGHT", 12, 0)
	rule:SetPoint("RIGHT", s, "RIGHT")
	view.sections[#view.sections + 1] = s
	return s
end

-- opts: full (whole line), disabled (function), reserve (px kept free for
-- controls so the description doesn't run under them)
local function Row(section, label, desc, opts)
	opts = opts or {}
	local row = CreateFrame("Frame", nil, section)
	row.full = opts.full
	row.controls = {}
	Fill(row, "BACKGROUND", 0, 0, 0, 0.4):SetAllPoints()
	local hover = Fill(row, "BACKGROUND", 1, 1, 1, 0.03, 1)
	hover:SetAllPoints()
	hover:Hide()
	row:EnableMouse(true)
	row:SetScript("OnEnter", function() hover:Show() end)
	row:SetScript("OnLeave", function() hover:Hide() end)
	row.text = Label(row, FONT_BOLD, 13, TEXT, label)
	if desc then
		row.text:SetPoint("TOPLEFT", 18, -11)
		row.sub = Label(row, FONT_MED, 11, MUTED, desc)
		row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -5)
		row.sub:SetPoint("RIGHT", row, "RIGHT", -(opts.reserve or 120), 0)
		row.sub:SetWordWrap(false)
	else
		row.text:SetPoint("LEFT", 18, 0)
	end
	section.rows[#section.rows + 1] = row
	if opts.disabled then
		widgets[#widgets + 1] = function()
			local off = opts.disabled()
			row:SetAlpha(off and 0.4 or 1)
			for _, c in ipairs(row.controls) do c:EnableMouse(not off) end
		end
	end
	return row
end

local function Swatch(row, rightOf, get, set, hasAlpha)
	local sw = CreateFrame("Button", nil, row)
	sw:SetSize(24, 24)
	if rightOf then sw:SetPoint("RIGHT", rightOf, "LEFT", -12, 0) else sw:SetPoint("RIGHT", -18, 0) end
	Outline(sw, 1, 1, 1, 0.35)
	local fill = sw:CreateTexture(nil, "ARTWORK")
	fill:SetPoint("TOPLEFT", 2, -2)
	fill:SetPoint("BOTTOMRIGHT", -2, 2)
	sw:SetScript("OnClick", function() OpenColorPicker(get, set, hasAlpha) end)
	row.controls[#row.controls + 1] = sw
	widgets[#widgets + 1] = function()
		local c = get()
		fill:SetColorTexture(c[1], c[2], c[3], 1)
	end
	return sw
end

-- opts.color = { get, set, hasAlpha } adds a color swatch beside the control.
local function AddColor(row, control, opts)
	if opts and opts.color then Swatch(row, control, opts.color[1], opts.color[2], opts.color[3]) end
end

local function Toggle(section, label, desc, get, set, opts)
	local row = Row(section, label, desc, opts)
	local sw = CreateFrame("Button", nil, row)
	sw:SetSize(42, 22)
	sw:SetPoint("RIGHT", -18, 0)
	local track = Fill(sw, "ARTWORK", 0.22, 0.22, 0.25, 1)
	track:SetAllPoints()
	local knob = sw:CreateTexture(nil, "OVERLAY")
	knob:SetSize(18, 18)
	sw:SetScript("OnClick", function()
		set(not get())
		Changed()
	end)
	row.controls[#row.controls + 1] = sw
	widgets[#widgets + 1] = function()
		local on = get() and true or false
		local a = Accent()
		if on then track:SetColorTexture(a[1], a[2], a[3], 1) else track:SetColorTexture(0.22, 0.22, 0.25, 1) end
		knob:ClearAllPoints()
		knob:SetPoint(on and "RIGHT" or "LEFT", sw, on and "RIGHT" or "LEFT", on and -2 or 2, 0)
		local k = on and 1 or 0.68
		knob:SetColorTexture(k, k, k, 1)
	end
	AddColor(row, sw, opts)
	return row
end

-- Slider with a typeable value box. opts.percent shows 0-1 values as 0-100.
local function Slider(section, label, desc, get, set, min, max, step, opts)
	opts = opts or {}
	local row = Row(section, label, desc, opts)
	local mult = opts.percent and 100 or 1
	local function Text(v)
		v = v * mult
		if opts.percent or step * mult >= 1 then return tostring(math.floor(v + 0.5)) end
		return format("%.2f", v)
	end

	local box = CreateFrame("EditBox", nil, row)
	box:SetSize(52, 28)
	box:SetPoint("RIGHT", -18, 0)
	box:SetAutoFocus(false)
	box:SetJustifyH("CENTER")
	box:SetFont(FONT_MED, 12, "")
	box:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
	Fill(box, "BACKGROUND", 0, 0, 0, 0.55):SetAllPoints()
	Outline(box, 1, 1, 1, 0.1)

	local slider = CreateFrame("Slider", nil, row)
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(opts.width or 160, 18)
	slider:SetPoint("RIGHT", box, "LEFT", -14, 0)
	slider:SetMinMaxValues(min, max)
	slider:SetValueStep(step)
	if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
	slider:EnableMouseWheel(false)
	local track = Fill(slider, "BACKGROUND", 1, 1, 1, 0.14)
	track:SetHeight(3)
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")
	local thumb = slider:CreateTexture(nil, "OVERLAY")
	thumb:SetSize(10, 18)
	thumb:SetColorTexture(1, 1, 1, 1)
	slider:SetThumbTexture(thumb)
	local fill = slider:CreateTexture(nil, "ARTWORK")
	fill:SetHeight(3)
	fill:SetPoint("LEFT")
	fill:SetPoint("RIGHT", thumb, "CENTER")

	local function Set(v)
		v = math.min(max, math.max(min, v))
		if v ~= get() then
			set(v)
			Changed()
		end
	end
	local updating
	slider:SetScript("OnValueChanged", function(_, v)
		if updating then return end
		Set(math.floor(v / step + 0.5) * step)
	end)
	box:SetScript("OnEnterPressed", function(self)
		local n = tonumber(self:GetText():match("%-?[%d%.]+") or "")
		if n then Set(n / mult) end
		self:ClearFocus()
	end)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	box:SetScript("OnEditFocusLost", function(self)
		self:HighlightText(0, 0)
		self:SetText(Text(get()))
	end)
	row.controls[#row.controls + 1] = slider
	row.controls[#row.controls + 1] = box
	widgets[#widgets + 1] = function()
		local v = get()
		updating = true
		slider:SetValue(v)
		updating = false
		if not box:HasFocus() then box:SetText(Text(v)) end
		local a = Accent()
		thumb:SetColorTexture(a[1], a[2], a[3], 1)
		fill:SetColorTexture(a[1], a[2], a[3], 0.8)
	end
	AddColor(row, slider, opts)
	return row
end

-- choices: list, or a function returning one, of { value =, text =, font = }
local function DropdownBox(parent, width, choices, get, set)
	local box = CreateFrame("Button", nil, parent)
	box:SetSize(width, 30)
	Fill(box, "BACKGROUND", 0, 0, 0, 0.55):SetAllPoints()
	local outline = Outline(box, 1, 1, 1, 0.14)
	local text = Label(box, FONT_BOLD, 12, TEXT)
	text:SetPoint("LEFT", 12, 0)
	text:SetPoint("RIGHT", -30, 0)
	text:SetWordWrap(false)
	local arrow = Chevron(box)
	arrow:SetPoint("RIGHT", -11, 0)
	local function List() return type(choices) == "function" and choices() or choices end
	box:SetScript("OnClick", function(self)
		if menu and menu:IsShown() then CloseMenu() return end
		OpenMenu(self, List(), get(), function(v)
			set(v)
			Changed()
		end)
	end)
	box:SetScript("OnEnter", function() local a = Accent() outline(a[1], a[2], a[3], 0.9) end)
	box:SetScript("OnLeave", function() outline(1, 1, 1, 0.14) end)
	widgets[#widgets + 1] = function()
		local list, current = List(), get()
		local shown = list[1]
		for _, choice in ipairs(list) do
			if choice.value == current then shown = choice end
		end
		if not shown then text:SetText("") return end
		SetFont(text, shown.font or FONT_BOLD, shown.font and 14 or 12, TEXT)
		text:SetText(shown.text)
	end
	return box
end

local function Dropdown(section, label, desc, choices, get, set, opts)
	opts = opts or {}
	opts.reserve = opts.reserve or (opts.width or 200) + 40
	local row = Row(section, label, desc, opts)
	local box = DropdownBox(row, opts.width or 200, choices, get, set)
	box:SetPoint("RIGHT", -18, 0)
	row.controls[#row.controls + 1] = box
	AddColor(row, box, opts)
	return row
end

local function ColorRow(section, label, desc, get, set, hasAlpha, opts)
	local row = Row(section, label, desc, opts)
	Swatch(row, nil, get, set, hasAlpha)
	return row
end

-- A wide row with a button on the right, like Polestar's "Reset position".
local function ActionRow(section, label, desc, buttonText, onClick, opts)
	opts = opts or {}
	opts.full = true
	opts.reserve = 200
	local row = Row(section, label, desc, opts)
	local b = FlatButton(row, buttonText, 150, 32, onClick)
	b:SetPoint("RIGHT", -18, 0)
	row.controls[#row.controls + 1] = b
	return row
end

-- Compact "Label [----o--] 80%" control for the window header.
local function HeaderSlider(parent, label, get, set, min, max, step, onRelease)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(300, 20)
	local value = Label(f, FONT_BOLD, 12, TEXT)
	value:SetPoint("RIGHT")
	value:SetWidth(42)
	value:SetJustifyH("RIGHT")
	local slider = CreateFrame("Slider", nil, f)
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(130, 16)
	slider:SetPoint("RIGHT", value, "LEFT", -10, 0)
	slider:SetMinMaxValues(min, max)
	slider:SetValueStep(step)
	if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
	local track = Fill(slider, "BACKGROUND", 1, 1, 1, 0.14)
	track:SetHeight(3)
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")
	local thumb = slider:CreateTexture(nil, "OVERLAY")
	thumb:SetSize(10, 16)
	slider:SetThumbTexture(thumb)
	local fill = slider:CreateTexture(nil, "ARTWORK")
	fill:SetHeight(3)
	fill:SetPoint("LEFT")
	fill:SetPoint("RIGHT", thumb, "CENTER")
	local text = Label(f, FONT_BOLD, 12, MUTED, label)
	text:SetPoint("RIGHT", slider, "LEFT", -12, 0)
	local updating
	slider:SetScript("OnValueChanged", function(_, v)
		if updating then return end
		v = math.floor(v / step + 0.5) * step
		if v ~= get() then
			set(v)
			value:SetText(math.floor(v * 100 + 0.5) .. "%")
			if not onRelease then Changed() end
		end
	end)
	if onRelease then
		slider:SetScript("OnMouseUp", function() onRelease() RefreshWidgets() end)
	end
	widgets[#widgets + 1] = function()
		updating = true
		slider:SetValue(get())
		updating = false
		value:SetText(math.floor(get() * 100 + 0.5) .. "%")
		local a = Accent()
		thumb:SetColorTexture(a[1], a[2], a[3], 1)
		fill:SetColorTexture(a[1], a[2], a[3], 0.8)
	end
	return f
end

------------------------------------------------------------------------------
-- Scrolling tab pages
------------------------------------------------------------------------------

local function NewView(content)
	local scroll = CreateFrame("ScrollFrame", nil, content)
	scroll:SetPoint("TOPLEFT", PAD, -22)
	scroll:SetPoint("BOTTOMRIGHT", -PAD + 12, 14)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)
	local thumb = Fill(scroll, "ARTWORK", 1, 1, 1, 0.22)
	thumb:SetWidth(3)

	local view = { scroll = scroll, child = child, sections = {} }

	function view:UpdateScroll()
		local height, total = scroll:GetHeight(), child:GetHeight()
		local maxScroll = math.max(0, total - height)
		if scroll:GetVerticalScroll() > maxScroll then scroll:SetVerticalScroll(maxScroll) end
		if maxScroll <= 0 then thumb:Hide() return end
		local h = math.max(30, height * height / total)
		thumb:SetHeight(h)
		thumb:ClearAllPoints()
		thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, -(scroll:GetVerticalScroll() / maxScroll) * (height - h))
		thumb:Show()
	end

	-- Stack the visible sections; rows go two to a line unless full width.
	function view:Relayout()
		local width = child:GetWidth()
		if width < 10 then return end
		local half = (width - GAP) / 2
		local y = 0
		for _, s in ipairs(self.sections) do
			local visible = not s.shown or s.shown()
			s:SetShown(visible)
			if visible then
				s:ClearAllPoints()
				s:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
				s:SetWidth(width)
				local ry, col = 24, 0
				for _, row in ipairs(s.rows) do
					row:ClearAllPoints()
					if row.full then
						if col == 1 then ry, col = ry + ROW_H + GAP, 0 end
						row:SetPoint("TOPLEFT", s, "TOPLEFT", 0, -ry)
						row:SetSize(width, ROW_H)
						ry = ry + ROW_H + GAP
					else
						row:SetPoint("TOPLEFT", s, "TOPLEFT", col * (half + GAP), -ry)
						row:SetSize(half, ROW_H)
						if col == 1 then ry, col = ry + ROW_H + GAP, 0 else col = 1 end
					end
				end
				if col == 1 then ry = ry + ROW_H + GAP end
				s:SetHeight(ry)
				y = y + ry + 26
			end
		end
		child:SetHeight(math.max(1, y))
		self:UpdateScroll()
	end

	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		CloseMenu()
		local maxScroll = math.max(0, child:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 60)))
		view:UpdateScroll()
	end)
	scroll:SetScript("OnSizeChanged", function(_, w)
		child:SetWidth(w - 14)
		view:Relayout()
	end)
	views[#views + 1] = view
	return view
end

------------------------------------------------------------------------------
-- Choices
------------------------------------------------------------------------------

local VISIBILITY = {
	{ value = "always", text = "Always" },
	{ value = "combat", text = "In combat" },
	{ value = "nocombat", text = "Out of combat" },
	{ value = "target", text = "With a target" },
	{ value = "mouseover", text = "On mouseover" },
}

local MENU_VISIBILITY = {
	{ value = "always", text = "Always" },
	{ value = "mouseover", text = "On mouseover" },
	{ value = "combat", text = "In combat" },
	{ value = "nocombat", text = "Out of combat" },
	{ value = "target", text = "With a target" },
	{ value = "hidden", text = "Hidden" },
}

local STRENGTHS = {
	{ value = "off", text = "Off" },
	{ value = "light", text = "Light" },
	{ value = "medium", text = "Medium" },
	{ value = "strong", text = "Strong" },
}

local POSITIONS = {
	{ value = "TOPRIGHT", text = "Top right" },
	{ value = "TOPLEFT", text = "Top left" },
	{ value = "TOP", text = "Top" },
	{ value = "CENTER", text = "Center" },
	{ value = "BOTTOMRIGHT", text = "Bottom right" },
	{ value = "BOTTOMLEFT", text = "Bottom left" },
}

local function FontChoices()
	local list = {}
	for _, font in ipairs(ns.AllFonts()) do
		list[#list + 1] = { value = font.key, text = font.name, font = font.path }
	end
	return list
end

local function BarChoices()
	local list = {
		{ value = "keyzen", text = "Keyzen" },
		{ value = "naga", text = "Naga" },
		{ value = "stance", text = "Stances" },
	}
	for n in ipairs(DB.extra) do
		list[#list + 1] = { value = "extra" .. n, text = ns.ExtraBarName(n) }
	end
	return list
end

local function PageChoices()
	local list = {}
	for page = 1, 10 do
		list[#list + 1] = { value = page, text = format("Page %d  (slots %d-%d)", page, (page - 1) * 12 + 1, page * 12) }
	end
	return list
end

------------------------------------------------------------------------------
-- Pages
------------------------------------------------------------------------------

local function Bar()
	local cfg = ns.BarDB(selectedBar)
	if not cfg then
		selectedBar = "keyzen"
		cfg = ns.BarDB(selectedBar)
	end
	return cfg
end
local function ExtraIndex() return tonumber(selectedBar:match("^extra(%d+)$")) end

local function GeneralBehavior(view)
	local s = Section(view, "Moving things")
	Toggle(s, "Lock bar positions", "Unlock to drag bars around.",
		function() return DB.lockFrames end, function(v) DB.lockFrames = v end)
	Toggle(s, "Lock buttons", "Locked: hold Shift to drag spells off.",
		function() return DB.lockButtons end, function(v) DB.lockButtons = v end)
	Toggle(s, "Mouse clicks cast while unlocked", "Off: clicks only move spells. Keys always cast.",
		function() return DB.clickWhenUnlocked end, function(v) DB.clickWhenUnlocked = v end,
		{ disabled = function() return DB.lockButtons end })

	s = Section(view, "Casting")
	Toggle(s, "Cast on key down", "Keys fire on press, not release. Mouse clicks unaffected.",
		function() return GetCVarBool("ActionButtonUseKeyDown") end,
		function(v) SetCVar("ActionButtonUseKeyDown", v and "1" or "0") end)
	Toggle(s, "Mouseover casting", "Casts on the unit under your mouse.",
		function() return GetCVarBool("enableMouseoverCast") end,
		function(v) SetCVar("enableMouseoverCast", v and "1" or "0") end,
		{ disabled = function() return GetCVar("enableMouseoverCast") == nil end })

	s = Section(view, "Paging")
	Toggle(s, "Block Shift page switching", "Stops Shift+1-6 and Shift+wheel.",
		function() return DB.blockShiftPaging end, function(v) DB.blockShiftPaging = v end)
	Toggle(s, "Disable form paging", "Stances and stealth won't swap the main keys.",
		function() return DB.disableFormPaging end, function(v) DB.disableFormPaging = v end)

	s = Section(view, "Spells")
	Toggle(s, "Add new spells to bars", "Fills the first empty button when you learn one.",
		function() return DB.autoAddSpells end, function(v) DB.autoAddSpells = v ns.ApplyAutoSpells() end)

	s = Section(view, "Blizzard")
	Toggle(s, "Hide Blizzard action bars", "Takes effect after a reload.",
		function() return DB.hideBlizzard end, function(v) DB.hideBlizzard = v end)
end

local function GeneralKeybinds(view)
	local s = Section(view, "Binding")
	ActionRow(s, "Bind keys", "Hover a button and press the key your Azeron or Naga sends. Delete clears it, Esc stops.",
		"Start binding", function() window:Hide() ns.SetBindMode(true) end)
	ActionRow(s, "Reset keys", "Puts every Keyzen and Naga key back to the plan. Extra bars keep theirs.",
		"Reset keys", function() ns.ResetKeys() end)
	s = Section(view, "Labels")
	Toggle(s, "Finger names", "F2, B1, D4... Off shows the key.",
		function() return DB.fingerNames end, function(v) DB.fingerNames = v end)
end

local function GeneralWindow(view)
	local s = Section(view, "This window")
	Slider(s, "Window size", "Size of the whole window.", function() return DB.optWindowSize or 1 end,
		function(v) DB.optWindowSize = v end, 0.5, 1.5, 0.05, { percent = true, reserve = 260 })
	Slider(s, "Window scale", "Size of everything inside.", function() return DB.optContentScale end,
		function(v) DB.optContentScale = v end, 0.5, 1.2, 0.05, { percent = true, reserve = 260 })
	Dropdown(s, "Theme", "The window's background.", ThemeChoices, function() return DB.optTheme end,
		function(v) DB.optTheme = v end, { width = 190 })
	Toggle(s, "Class color accent", "Highlights in your class color.", function() return DB.optClassAccent end,
		function(v) DB.optClassAccent = v end)
	ColorRow(s, "Accent color", "Used when class color accent is off.", function() return DB.optAccent end,
		function(c) DB.optAccent = c end, nil, { disabled = function() return DB.optClassAccent end })
	-- Only the Sylvanas theme has art, so the slider only shows in copies with it.
	if ns.HAS_SYLVANAS then
		Slider(s, "Background image", "How much of the art shows.", function() return DB.optArtAlpha end,
			function(v) DB.optArtAlpha = v end, 0, 1, 0.05, { percent = true, reserve = 260 })
	end
	Slider(s, "Panel darkness", "Lower lets more world through.", function() return DB.optTint end,
		function(v) DB.optTint = v end, 0, 1, 0.05, { percent = true, reserve = 260 })
end

local function BarsDisplay(view)
	local s = Section(view, "Bar")
	Dropdown(s, "Bar to edit", "Pick a bar, then change it below.", BarChoices,
		function() Bar() return selectedBar end, function(v) selectedBar = v end, { full = true, width = 260 })
	local row = Row(s, "Add or remove bars", "Bag bars sit along the bottom for hearthstones and potions.",
		{ full = true, reserve = 440 })
	local remove = FlatButton(row, "Remove this bar", 150, 32, function()
		local n = ExtraIndex()
		if not n then return end
		ns.RemoveExtraBar(n)
		selectedBar = #DB.extra > 0 and ("extra" .. math.min(n, #DB.extra)) or "keyzen"
		Changed()
	end)
	remove:SetPoint("RIGHT", -18, 0)
	local addBag = FlatButton(row, "+ Bag bar", 120, 32, function()
		local n = ns.AddExtraBar("bag")
		if n then selectedBar = "extra" .. n end
		Changed()
	end)
	addBag:SetPoint("RIGHT", remove, "LEFT", -8, 0)
	local add = FlatButton(row, "+ Bar", 100, 32, function()
		local n = ns.AddExtraBar()
		if n then selectedBar = "extra" .. n end
		Changed()
	end)
	add:SetPoint("RIGHT", addBag, "LEFT", -8, 0)
	widgets[#widgets + 1] = function()
		local n = ExtraIndex()
		remove:SetAlpha(n and 1 or 0.35)
		remove:EnableMouse(n ~= nil)
	end

	s = Section(view, "Visibility")
	Toggle(s, "Show this bar", nil, function() return Bar().show end, function(v) Bar().show = v end)
	Dropdown(s, "Visibility", "When it shows.", VISIBILITY,
		function() return Bar().visibility end, function(v) Bar().visibility = v end, { width = 170 })
	Slider(s, "Bar opacity", nil, function() return Bar().alpha end, function(v) Bar().alpha = v end,
		0.1, 1, 0.05, { percent = true })

	s = Section(view, "Layout")
	Slider(s, "Button size", nil, function() return Bar().size end, function(v) Bar().size = v end, 16, 64, 1)
	Slider(s, "Button spacing", nil, function() return Bar().spacing end, function(v) Bar().spacing = v end, 0, 12, 1)
	Slider(s, "Scale", nil, function() return Bar().scale end, function(v) Bar().scale = v end,
		0.5, 2, 0.05, { percent = true })

	s = Section(view, "Keyzen keys", function() return selectedBar == "keyzen" end)
	Toggle(s, "Main keys", "The 12 plain keys.",
		function() return DB.keyzen.showMain end, function(v) DB.keyzen.showMain = v end)
	Toggle(s, "Reach keys", "The Alt keys. Off frees them.",
		function() return DB.keyzen.showReach end, function(v) DB.keyzen.showReach = v end)
	Toggle(s, "Far row (U1, U2, U3)", "Off frees them for panels.",
		function() return DB.keyzen.showFar end, function(v) DB.keyzen.showFar = v end)
	Toggle(s, "Thumb keys (T1, T2)", nil,
		function() return DB.keyzen.showThumb end, function(v) DB.keyzen.showThumb = v end)
	Toggle(s, "Tab and Esc labels", nil,
		function() return DB.keyzen.showFixed end, function(v) DB.keyzen.showFixed = v end)

	-- Getters fall back to defaults because these widgets refresh even while
	-- a non-extra bar is selected and the section is hidden.
	s = Section(view, "Buttons on this bar", function() return ExtraIndex() ~= nil end)
	Dropdown(s, "Action page", "Pages 2, 3 and 5 are free.", PageChoices,
		function() return Bar().page or 2 end, function(v) Bar().page = v end, { width = 200 })
	Slider(s, "Number of buttons", nil, function() return Bar().count or 12 end,
		function(v) Bar().count = v end, 1, 12, 1)
	Slider(s, "Buttons per row", nil, function() return Bar().perRow or 12 end,
		function(v) Bar().perRow = v end, 1, 12, 1)
end

local function ButtonsIcons(view)
	local s = Section(view, "Icons")
	Slider(s, "Border size", nil, function() return DB.borderSize end, function(v) DB.borderSize = v end,
		0, 4, 1, { width = 120, color = { function() return DB.borderColor end, function(c) DB.borderColor = c end, true } })
	Slider(s, "Icon zoom", nil, function() return DB.iconZoom end, function(v) DB.iconZoom = v end,
		0, 0.2, 0.01, { percent = true })
	Toggle(s, "Button background", "Off leaves only the outline.",
		function() return DB.showBackground end, function(v) DB.showBackground = v end,
		{ color = { function() return DB.bgColor end, function(c) DB.bgColor = c end, true } })
	Toggle(s, "Hide empty buttons", "They return while you drag a spell.",
		function() return DB.hideEmpty end, function(v) DB.hideEmpty = v end)

	s = Section(view, "Cooldowns")
	Toggle(s, "Cooldown numbers", nil, function() return DB.cooldownNumbers end, function(v) DB.cooldownNumbers = v end)
	Slider(s, "Cooldown text size", nil, function() return DB.cooldownFontSize end,
		function(v) DB.cooldownFontSize = v end, 8, 24, 1, { disabled = function() return not DB.cooldownNumbers end })
	Slider(s, "Swipe darkness", nil, function() return DB.swipeAlpha end, function(v) DB.swipeAlpha = v end,
		0, 1, 0.05, { percent = true })

	s = Section(view, "State")
	Toggle(s, "Out of range coloring", nil, function() return DB.rangeColoring end, function(v) DB.rangeColoring = v end,
		{ color = { function() return DB.rangeColor end, function(c) DB.rangeColor = c end } })
	Toggle(s, "Equipped item outline", "Trinkets and other worn items.",
		function() return DB.showEquipped end, function(v) DB.showEquipped = v end,
		{ color = { function() return DB.equippedColor end, function(c) DB.equippedColor = c end } })
end

local function TextPage(view)
	local s = Section(view, "Keybind text")
	Toggle(s, "Show keybind text", nil, function() return DB.showKeybind end, function(v) DB.showKeybind = v end,
		{ color = { function() return DB.keyColor end, function(c) DB.keyColor = c end } })
	Toggle(s, "Finger names", "F2, B1, D4... Off shows the key.",
		function() return DB.fingerNames end, function(v) DB.fingerNames = v end)
	Dropdown(s, "Keybind font", nil, FontChoices, function() return DB.keyFont end, function(v) DB.keyFont = v end)
	Slider(s, "Keybind text size", nil, function() return DB.keyFontSize end, function(v) DB.keyFontSize = v end, 6, 24, 1)
	Dropdown(s, "Keybind position", nil, POSITIONS, function() return DB.keyPosition end,
		function(v) DB.keyPosition = v end, { width = 170 })

	s = Section(view, "Macro, charges and cooldowns")
	Dropdown(s, "Font", "Macro names, charges, cooldowns.", FontChoices,
		function() return DB.textFont end, function(v) DB.textFont = v end)
	Toggle(s, "Show macro names", nil, function() return DB.showMacro end, function(v) DB.showMacro = v end)
	Slider(s, "Macro text size", nil, function() return DB.macroFontSize end, function(v) DB.macroFontSize = v end,
		6, 20, 1, { disabled = function() return not DB.showMacro end })
	Slider(s, "Charges text size", nil, function() return DB.countFontSize end, function(v) DB.countFontSize = v end, 6, 24, 1)
end

local function AnimationsPage(view)
	local s = Section(view, "Interactions")
	Toggle(s, "Flash when pressed", nil, function() return DB.flash end, function(v) DB.flash = v end)
	ColorRow(s, "Interaction color", "Tint for press and hover.",
		function() return DB.interactionColor end, function(c) DB.interactionColor = c end)
	Dropdown(s, "Pushed", nil, STRENGTHS, function() return DB.pushedStyle end,
		function(v) DB.pushedStyle = v end, { width = 150 })
	Dropdown(s, "Hover highlight", nil, STRENGTHS, function() return DB.highlightStyle end,
		function(v) DB.highlightStyle = v end, { width = 150 })

	Toggle(s, "Highlight active stance", "Colors your current stance or form, plus auto attack.",
		function() return DB.activeHighlight end, function(v) DB.activeHighlight = v end,
		{ color = { function() return DB.activeColor end, function(c) DB.activeColor = c end } })

	s = Section(view, "Proc glow")
	Toggle(s, "Proc glow", "Pulses when a spell lights up.", function() return DB.procGlow end,
		function(v) DB.procGlow = v end,
		{ color = { function() return DB.glowColor end, function(c) DB.glowColor = c end } })
end

local ORIENTATIONS = {
	{ value = "horizontal", text = "Horizontal" },
	{ value = "vertical", text = "Vertical" },
}

local function MenuPage(view)
	local s = Section(view, "Window buttons")
	local note = Row(s, "Put a window on a button",
		"Click Pick up, then drop it on any button. Each one uses one of your account macros.", { full = true, reserve = 18 })
	note:EnableMouse(false)
	for _, w in ipairs(ns.WindowList and ns.WindowList() or {}) do
		local row = Row(s, w.text)
		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetSize(28, 28)
		icon:SetPoint("LEFT", 18, 0)
		if not ns.WindowArt(icon, w) then
			icon:SetTexture("Interface\\Icons\\" .. w.icon)
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
		row.text:ClearAllPoints()
		row.text:SetPoint("LEFT", icon, "RIGHT", 12, 0)
		local b = FlatButton(row, "Pick up", 110, 32, function() ns.PickupWindow(w) end)
		b:SetPoint("RIGHT", -18, 0)
		row.controls[#row.controls + 1] = b
	end

	s = Section(view, "Takeover")
	Toggle(s, "Move Blizzard's menu and bags", "Off leaves them to Edit Mode. Reload after changing.",
		function() return DB.ownMenus end, function(v) DB.ownMenus = v end, { full = true, reserve = 120 })
	for _, entry in ipairs({ { "menu", "Micro menu" }, { "bags", "Bag bar" } }) do
		local key = entry[1]
		local function Cfg() return DB.bars[key] end
		local function Off() return not (DB.ownMenus and ns.MenuAvailable and ns.MenuAvailable(key)) end
		s = Section(view, entry[2])
		Toggle(s, "Show", nil, function() return Cfg().show end, function(v) Cfg().show = v end, { disabled = Off })
		Dropdown(s, "Visibility", "Hidden also stops clicks.", MENU_VISIBILITY,
			function() return Cfg().visibility end, function(v) Cfg().visibility = v end,
			{ width = 170, disabled = Off })
		Dropdown(s, "Orientation", nil, ORIENTATIONS, function() return Cfg().orientation end,
			function(v) Cfg().orientation = v end, { width = 170, disabled = Off })
		Slider(s, "Buttons per row", nil, function() return Cfg().perRow end, function(v) Cfg().perRow = v end,
			1, 16, 1, { disabled = Off })
		Slider(s, "Size", nil, function() return Cfg().scale end, function(v) Cfg().scale = v end,
			0.4, 2, 0.05, { percent = true, disabled = Off })
		Slider(s, "Spacing", nil, function() return Cfg().spacing end, function(v) Cfg().spacing = v end,
			0, 12, 1, { disabled = Off })
		Slider(s, "Opacity", nil, function() return Cfg().alpha end, function(v) Cfg().alpha = v end,
			0.1, 1, 0.05, { percent = true, disabled = Off })
		if key == "bags" then
			Toggle(s, "Keyring button", "WoW Forever's keyring, beside the reagent bag.",
				function() return Cfg().showKeyring ~= false end, function(v) Cfg().showKeyring = v end,
				{ disabled = function() return Off() or not _G.KeyRingButton end })
		end
	end
end

local function XPPage(view)
	local function Cfg() return DB.bars.xp end
	local function Get(k) return function() return Cfg()[k] end end
	local function Set(k) return function(v) Cfg()[k] = v end end
	local s = Section(view, "Bar")
	Toggle(s, "Show", nil, Get("show"), Set("show"))
	Dropdown(s, "Visibility", nil, MENU_VISIBILITY, Get("visibility"), Set("visibility"), { width = 170 })
	Slider(s, "Width", nil, Get("width"), Set("width"), 100, 1600, 1)
	Slider(s, "Height", nil, Get("height"), Set("height"), 4, 60, 1)
	Slider(s, "Size", nil, Get("scale"), Set("scale"), 0.4, 2, 0.05, { percent = true })
	Slider(s, "Opacity", nil, Get("alpha"), Set("alpha"), 0.1, 1, 0.05, { percent = true })
	Toggle(s, "Show at max level", nil, Get("showAtMax"), Set("showAtMax"))
	Toggle(s, "Hide Blizzard's XP bar", nil, Get("hideBlizzard"), Set("hideBlizzard"))

	s = Section(view, "Look")
	Dropdown(s, "Texture", nil, ns.XP_TEXTURES, Get("texture"), Set("texture"), { width = 170 })
	Toggle(s, "Class gradient", "Deep to bright in your class color. Off uses the color here.", Get("classColor"), Set("classColor"),
		{ color = { Get("color"), Set("color") } })
	Slider(s, "Track darkness", nil, Get("trackAlpha"), Set("trackAlpha"), 0, 1, 0.05, { percent = true })
	Toggle(s, "Black outline", nil, Get("border"), Set("border"))
	Toggle(s, "Completed quest XP", "Orange, ahead of the fill.", Get("questOverlay"), Set("questOverlay"))
	Toggle(s, "Rested XP", "Blue, past the quest XP.", Get("restedOverlay"), Set("restedOverlay"))

	s = Section(view, "Text")
	Dropdown(s, "Font", nil, FontChoices, Get("font"), Set("font"))
	Dropdown(s, "Text style", "Smooth uses the sharp 4K renderer.", ns.TEXT_STYLES, Get("textStyle"), Set("textStyle"), { width = 190 })
	Slider(s, "Bar text size", nil, Get("fontSize"), Set("fontSize"), 6, 24, 1)
	Slider(s, "Line text size", "The lines above and below.", Get("lineFontSize"), Set("lineFontSize"), 6, 24, 1)
	Toggle(s, "Times above", "This level, played and session.", Get("showTimes"), Set("showTimes"))
	Toggle(s, "Rate below", "Time to level, XP per hour, quests and rested.", Get("showRate"), Set("showRate"))
	Toggle(s, "Kills to level", "How many more gains like your last one.", Get("showLastGain"), Set("showLastGain"))
end

-- Yes/No prompt above the options window.
StaticPopupDialogs.KEYZENBARS_CONFIRM = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function(self) if self.data then self.data() end end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}
local function Confirm(text, onYes)
	local dialog = StaticPopup_Show("KEYZENBARS_CONFIRM", text)
	if dialog then
		dialog.data = onYes
		dialog:SetFrameStrata("FULLSCREEN_DIALOG")
	end
end

local function InputRow(section, label, desc, buttonText, onClick)
	local row = Row(section, label, desc, { full = true, reserve = 430 })
	local b = FlatButton(row, buttonText, 150, 32)
	b:SetPoint("RIGHT", -18, 0)
	local box = CreateFrame("EditBox", nil, row)
	box:SetSize(230, 30)
	box:SetPoint("RIGHT", b, "LEFT", -12, 0)
	box:SetAutoFocus(false)
	box:SetFont(FONT_MED, 12, "")
	box:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
	box:SetTextInsets(10, 10, 0, 0)
	box:SetMaxLetters(40)
	Fill(box, "BACKGROUND", 0, 0, 0, 0.55):SetAllPoints()
	Outline(box, 1, 1, 1, 0.14)
	local function Go()
		local text = strtrim(box:GetText() or "")
		if text ~= "" then onClick(text, box) end
		box:ClearFocus()
	end
	b:SetScript("OnClick", Go)
	box:SetScript("OnEnterPressed", Go)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	row.controls[#row.controls + 1] = b
	row.controls[#row.controls + 1] = box
	return row
end

local profileOther
local profileChosen = {}

local function ProfileChoices(skipCurrent)
	return function()
		local list = {}
		for _, name in ipairs(ns.ProfileNames()) do
			if not (skipCurrent and name == ns.CurrentProfile()) then
				list[#list + 1] = { value = name, text = name }
			end
		end
		if #list == 0 then list[1] = { value = "", text = "No other profiles" } end
		return list
	end
end

local function OtherProfile()
	local cur = ns.CurrentProfile()
	if profileOther and profileOther ~= cur and KeyzenBarsDB.profiles[profileOther] then return profileOther end
	for _, name in ipairs(ns.ProfileNames()) do
		if name ~= cur then return name end
	end
end

local function ProfilesPage(view)
	local s = Section(view, "Profile")
	Dropdown(s, "Current profile", "Used by this character. Switching reloads the UI.", ProfileChoices(false),
		function() return ns.CurrentProfile() end,
		function(v)
			if v == ns.CurrentProfile() then return end
			Confirm("Switch this character to the \"" .. v .. "\" profile? The UI will reload.", function() ns.SetProfile(v) end)
		end, { width = 220, full = true, reserve = 260 })
	InputRow(s, "New profile", "Starts from the defaults.", "Create", function(name, box)
		if KeyzenBarsDB.profiles[name] then ns.Print("A profile called " .. name .. " already exists.") return end
		Confirm("Create \"" .. name .. "\" and switch to it? The UI will reload.", function() ns.NewProfile(name, false) end)
		box:SetText("")
	end)
	InputRow(s, "Save a copy", "A new profile with everything this one has.", "Copy", function(name, box)
		if KeyzenBarsDB.profiles[name] then ns.Print("A profile called " .. name .. " already exists.") return end
		Confirm("Copy this profile to \"" .. name .. "\" and switch to it? The UI will reload.", function() ns.NewProfile(name, true) end)
		box:SetText("")
	end)
	ActionRow(s, "Reset profile", "Puts every setting in this profile back to the defaults, keybinds included.", "Reset", function()
		Confirm("Reset every setting in \"" .. ns.CurrentProfile() .. "\"? The UI will reload.", ns.ResetProfile)
	end)

	s = Section(view, "Other profiles")
	Dropdown(s, "Profile", "Pick one to copy from, copy to or delete.", ProfileChoices(true),
		function() return OtherProfile() or "" end, function(v) if v ~= "" then profileOther = v end end,
		{ width = 220, full = true, reserve = 260 })
	ActionRow(s, "Copy everything from it", "Overwrites this profile with that one.", "Copy all", function()
		local other = OtherProfile()
		if not other then return end
		Confirm("Overwrite \"" .. ns.CurrentProfile() .. "\" with everything from \"" .. other .. "\"? The UI will reload.",
			function() ns.CopyProfile(other) end)
	end)
	ActionRow(s, "Delete it", "Characters using it go back to Default.", "Delete", function()
		local other = OtherProfile()
		if not other then return end
		local users = ns.ProfileUsers(other)
		local note = users > 0 and string.format(" %d character%s use%s it.", users, users == 1 and "" or "s", users == 1 and "s" or "") or ""
		Confirm("Delete the \"" .. other .. "\" profile?" .. note, function()
			ns.DeleteProfile(other)
			profileOther = nil
			Changed()
		end)
	end)

	s = Section(view, "Module copy")
	local note = Row(s, "Copy only some settings", "Pick the modules, then copy them from or to the profile above.",
		{ full = true, reserve = 18 })
	note:EnableMouse(false)
	for _, module in ipairs(ns.PROFILE_MODULES) do
		if profileChosen[module.key] == nil then profileChosen[module.key] = module.key ~= "keys" end
		Toggle(s, module.text, module.desc, function() return profileChosen[module.key] end,
			function(v) profileChosen[module.key] = v end)
	end
	local function Names()
		local list = {}
		for _, module in ipairs(ns.PROFILE_MODULES) do
			if profileChosen[module.key] then list[#list + 1] = module.text end
		end
		return table.concat(list, ", ")
	end
	ActionRow(s, "Copy from the other profile", "Brings the picked modules into this one. The UI will reload.", "Copy here",
		function()
			local other = OtherProfile()
			if not other or Names() == "" then return end
			Confirm(string.format("Copy %s from \"%s\" into \"%s\"? The UI will reload.", Names(), other, ns.CurrentProfile()),
				function() ns.CopyModules(other, profileChosen, "import") end)
		end)
	ActionRow(s, "Copy to the other profile", "Sends this profile's picked modules to that one.", "Copy there",
		function()
			local other = OtherProfile()
			if not other or Names() == "" then return end
			Confirm(string.format("Copy %s from \"%s\" to \"%s\"?", Names(), ns.CurrentProfile(), other),
				function()
					ns.CopyModules(other, profileChosen, "export")
					ns.Print("Copied to " .. other .. ".")
				end)
		end)
end

local PAGES = {
	{ nav = "General", title = "General", subtitle = "How the bars behave and how you bind them.",
		tabs = { { "Behavior", GeneralBehavior }, { "Keybinds", GeneralKeybinds }, { "Window", GeneralWindow } } },
	{ nav = "Bars", title = "Bar Display", subtitle = "Show, size and fade each bar, and add new ones.",
		tabs = { { "Bars", BarsDisplay } } },
	{ nav = "Buttons", title = "Buttons", subtitle = "Outlines, backgrounds and cooldowns on every button.",
		tabs = { { "Icons", ButtonsIcons } } },
	{ nav = "Text", title = "Text", subtitle = "Keybind labels, macro names and charges.",
		tabs = { { "Text", TextPage } } },
	{ nav = "Animations", title = "Animations", subtitle = "Press, hover and proc effects.",
		tabs = { { "Animations", AnimationsPage } } },
	{ nav = "Menu & Bags", title = "Menu & Bags", subtitle = "Blizzard's micro menu and bag buttons, as movable bars.",
		tabs = { { "Menu & Bags", MenuPage } } },
	{ nav = "Experience", title = "Experience", subtitle = "Your XP bar, with times, rate and quest XP.",
		tabs = { { "Experience", XPPage } } },
	{ nav = "Profiles", title = "Profiles", subtitle = "Save setups, share them between characters, copy single modules.",
		tabs = { { "Profiles", ProfilesPage } } },
}

------------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------------

local function AddonVersion()
	local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	return get and get("KeyzenBars", "Version") or ""
end

local function CreateWindow()
	DB = ns.DB
	window = CreateFrame("Frame", "KeyzenBarsOptions", UIParent)
	window:SetSize(WIDTH, HEIGHT)
	window:SetPoint("CENTER")
	window:SetFrameStrata("DIALOG")
	window:SetToplevel(true)
	window:SetMovable(true)
	window:EnableMouse(true)
	window:SetClampedToScreen(true)
	tinsert(UISpecialFrames, "KeyzenBarsOptions") -- Esc closes it

	-- The window keeps its size on screen; the content scale shrinks or grows
	-- what's inside it, like EllesmereUI's Window Scale.
	root = CreateFrame("Frame", nil, window)
	root:SetPoint("TOPLEFT")
	local function ApplyContentScale()
		local scale = DB.optContentScale
		root:SetScale(scale)
		root:SetSize(WIDTH / scale, HEIGHT / scale)
	end
	ApplyContentScale()
	-- Window size scales the whole window, frame and contents together.
	local function ApplyWindowSize()
		window:SetScale(DB.optWindowSize or 1)
	end
	ApplyWindowSize()

	-- Background: a dark tint, then the art cropped to the root's shape so
	-- it isn't stretched. Both opacities are settings.
	local tint = Fill(root, "BACKGROUND", 0.02, 0.02, 0.04, 1, -8)
	tint:SetAllPoints()
	local art = root:CreateTexture(nil, "BACKGROUND", nil, -7)
	art:SetAllPoints()
	local wash = root:CreateTexture(nil, "BACKGROUND", nil, -6)
	wash:SetAllPoints()
	wash:SetTexture("Interface\\Buttons\\WHITE8x8")
	-- A faint tiled grain over the gradients breaks up the banding dark
	-- gradients get on 8-bit color, which reads as low resolution.
	local grain = root:CreateTexture(nil, "BACKGROUND", nil, -5)
	grain:SetAllPoints()
	grain:SetTexture(ns.MEDIA .. "Textures\\Noise.tga", "REPEAT", "REPEAT")
	grain:SetHorizTile(true)
	grain:SetVertTile(true)
	grain:SetBlendMode("ADD")
	grain:SetAlpha(0.025)
	Outline(root, 0, 0, 0, 1)

	-- A picture cropped to the window's shape so it isn't stretched.
	local function Crop(file, w, h, l, r, t, b, topBias)
		art:SetTexture(file)
		local want, have = WIDTH / HEIGHT, w / h
		if have > want then
			local cut = (r - l) * (1 - want / have) / 2
			art:SetTexCoord(l + cut, r - cut, t, b)
		else
			local keep = (b - t) * have / want
			local top = t + ((b - t) - keep) * (topBias or 0.5)
			art:SetTexCoord(l, r, top, top + keep)
		end
	end
	local function Gradient(r1, g1, b1, a1, r2, g2, b2, a2)
		wash:Show()
		wash:SetVertexColor(1, 1, 1, 1)
		wash:SetGradient("VERTICAL", CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
	end
	local appliedTheme
	local function ApplyTheme()
		local theme = DB.optTheme
		if theme == "class" or (theme == "sylvanas" and not ns.HAS_SYLVANAS) then theme = "classcolor" end
		if theme == appliedTheme then return end
		appliedTheme = theme
		art:Show()
		wash:Hide()
		grain:SetShown(theme ~= "sylvanas")
		local cr, cg, cb = ClassRGB()
		cr, cg, cb = cr or 0.5, cg or 0.5, cb or 0.5
		if theme == "sylvanas" then
			Crop(SYLVANAS, ART_W, ART_H, 0, 1, 0, 1, 0.06 / (1 - (ART_W / WIDTH * HEIGHT) / ART_H))
		elseif theme == "classcolor" then
			art:Hide()
			Gradient(cr * 0.04, cg * 0.04, cb * 0.04, 1, cr * 0.32, cg * 0.32, cb * 0.32, 1)
		elseif theme == "midnight" then
			art:Hide()
			Gradient(0.01, 0.01, 0.04, 1, 0.07, 0.08, 0.2, 1)
		else
			art:Hide()
			Gradient(0.03, 0.03, 0.03, 1, 0.08, 0.08, 0.09, 1)
		end
	end
	ApplyTheme()

	-- Sidebar
	local side = CreateFrame("Frame", nil, root)
	side:SetPoint("TOPLEFT")
	side:SetPoint("BOTTOMLEFT")
	side:SetWidth(SIDEBAR)
	Fill(side, "BACKGROUND", 0, 0, 0, 0.5):SetAllPoints()
	local edge = Fill(side, "ARTWORK", 1, 1, 1, 0.07)
	edge:SetPoint("TOPRIGHT")
	edge:SetPoint("BOTTOMRIGHT")
	edge:SetWidth(1)
	local logo = Label(side, ns.FontPath("mbold"), 28, TEXT, "Keyzen Bars")
	logo:SetPoint("TOPLEFT", 24, -30)
	logo:SetPoint("RIGHT", side, "RIGHT", -12, 0)
	logo:SetWordWrap(false)
	local tagline = Label(side, FONT_MED, 11, MUTED, "Azeron Keyzen action bars")
	tagline:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 1, -8)
	tagline:SetPoint("RIGHT", side, "RIGHT", -12, 0)
	tagline:SetWordWrap(false)
	local logoRule = Fill(side, "ARTWORK", 1, 1, 1, 0.08)
	logoRule:SetHeight(1)
	logoRule:SetPoint("TOPLEFT", 20, -HEADER + 4)
	logoRule:SetPoint("TOPRIGHT", -20, -HEADER + 4)
	local version = Label(side, FONT_MED, 11, MUTED, "v" .. AddonVersion() .. "   /kz")
	version:SetPoint("BOTTOMLEFT", 26, 24)

	-- Header (also the drag handle) and tabs
	local drag = CreateFrame("Frame", nil, root)
	drag:SetPoint("TOPLEFT")
	drag:SetPoint("TOPRIGHT")
	drag:SetHeight(HEADER)
	drag:EnableMouse(true)
	drag:RegisterForDrag("LeftButton")
	drag:SetScript("OnDragStart", function() window:StartMoving() end)
	drag:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
	local title = Label(root, FONT_BOLD, 30, TEXT)
	title:SetPoint("TOPLEFT", SIDEBAR + PAD, -30)
	local subtitle = Label(root, FONT_MED, 13, MUTED)
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -8)
	local close = FlatButton(root, "X", 34, 34, function() window:Hide() end)
	close:SetPoint("TOPRIGHT", -18, -18)
	close:SetFrameLevel(drag:GetFrameLevel() + 2)
	local tabRule = Fill(root, "ARTWORK", 1, 1, 1, 0.07)
	tabRule:SetHeight(1)
	tabRule:SetPoint("TOPLEFT", SIDEBAR, -(HEADER + TABS))
	tabRule:SetPoint("TOPRIGHT", 0, -(HEADER + TABS))

	-- Content and footer
	local content = CreateFrame("Frame", nil, root)
	content:SetPoint("TOPLEFT", SIDEBAR, -(HEADER + TABS))
	content:SetPoint("BOTTOMRIGHT", 0, FOOTER)
	local footRule = Fill(root, "ARTWORK", 1, 1, 1, 0.07)
	footRule:SetHeight(1)
	footRule:SetPoint("BOTTOMLEFT", SIDEBAR, FOOTER)
	footRule:SetPoint("BOTTOMRIGHT", 0, FOOTER)
	local reload = FlatButton(root, "Reload UI", 170, 38, function() ReloadUI() end)
	reload:SetPoint("BOTTOMLEFT", SIDEBAR + PAD, 14)
	local bind = FlatButton(root, "Bind keys", 150, 38, function() window:Hide() ns.SetBindMode(true) end)
	bind:SetPoint("LEFT", reload, "RIGHT", 10, 0)
	local done = FlatButton(root, "Close", 170, 38, function() window:Hide() end, true)
	done:SetPoint("BOTTOMRIGHT", -PAD, 14)

	-- Build every page's tabs up front.
	for _, page in ipairs(PAGES) do
		for _, tab in ipairs(page.tabs) do
			tab.view = NewView(content)
			tab[2](tab.view)
			tab.view.scroll:Hide()
		end
	end

	local navButtons, tabButtons = {}, {}
	local currentPage = 1

	local function ShowPage(index, tabIndex)
		CloseMenu()
		currentPage = index
		local page = PAGES[index]
		tabIndex = tabIndex or page.lastTab or 1
		page.lastTab = tabIndex
		title:SetText(page.title)
		subtitle:SetText(page.subtitle)
		for _, p in ipairs(PAGES) do
			for _, tab in ipairs(p.tabs) do tab.view.scroll:Hide() end
		end
		local view = page.tabs[tabIndex].view
		view.scroll:Show()
		view.scroll:SetVerticalScroll(0)
		local x = SIDEBAR + PAD - 14
		for i, tb in ipairs(tabButtons) do
			local tab = page.tabs[i]
			tb:SetShown(tab ~= nil)
			tb.selected = i == tabIndex
			if tab then
				tb.text:SetText(tab[1])
				tb:SetWidth(tb.text:GetStringWidth() + 28)
				tb:ClearAllPoints()
				tb:SetPoint("BOTTOMLEFT", root, "TOPLEFT", x, -(HEADER + TABS))
				x = x + tb:GetWidth() + 6
			end
		end
		for i, nb in ipairs(navButtons) do nb.selected = i == index end
		RefreshWidgets()
	end

	for i = 1, 4 do
		local tb = CreateFrame("Button", nil, root)
		tb:SetHeight(TABS)
		tb.text = Label(tb, FONT_BOLD, 15, TEXT)
		tb.text:SetPoint("CENTER", 0, -2)
		local line = Fill(tb, "ARTWORK", 1, 1, 1, 1)
		line:SetHeight(3)
		line:SetPoint("BOTTOMLEFT", 8, 0)
		line:SetPoint("BOTTOMRIGHT", -8, 0)
		local function Paint()
			local a = Accent()
			line:SetColorTexture(a[1], a[2], a[3], 1)
			line:SetShown(tb.selected)
			local c = (tb.selected or tb:IsMouseOver()) and TEXT or MUTED
			tb.text:SetTextColor(c[1], c[2], c[3])
		end
		tb:SetScript("OnClick", function() ShowPage(currentPage, i) end)
		tb:SetScript("OnEnter", Paint)
		tb:SetScript("OnLeave", Paint)
		widgets[#widgets + 1] = Paint
		tabButtons[i] = tb
	end

	for i, page in ipairs(PAGES) do
		local nb = CreateFrame("Button", nil, side)
		nb:SetHeight(44)
		nb:SetPoint("TOPLEFT", 0, -HEADER - 14 - (i - 1) * 46)
		nb:SetPoint("TOPRIGHT", -1, -HEADER - 14 - (i - 1) * 46)
		local sel = Fill(nb, "BACKGROUND", 1, 1, 1, 0.07)
		sel:SetAllPoints()
		local hl = Fill(nb, "HIGHLIGHT", 1, 1, 1, 0.04)
		hl:SetAllPoints()
		local bar = Fill(nb, "ARTWORK", 1, 1, 1, 1)
		bar:SetPoint("TOPLEFT")
		bar:SetPoint("BOTTOMLEFT")
		bar:SetWidth(3)
		local text = Label(nb, FONT_BOLD, 15, TEXT, page.nav)
		text:SetPoint("LEFT", 26, 0)
		nb:SetScript("OnClick", function() ShowPage(i) end)
		widgets[#widgets + 1] = function()
			local a = Accent()
			sel:SetShown(nb.selected)
			bar:SetShown(nb.selected)
			bar:SetColorTexture(a[1], a[2], a[3], 1)
			local c = nb.selected and TEXT or MUTED
			text:SetTextColor(c[1], c[2], c[3])
		end
		navButtons[i] = nb
	end

	-- Header controls, like EllesmereUI's: window size, content scale and the art's opacity.
	-- Scale applies when the slider is let go, so it doesn't move under the
	-- mouse mid-drag.
	local sizeSlider = HeaderSlider(root, "Window Size", function() return DB.optWindowSize or 1 end,
		function(v) DB.optWindowSize = v end, 0.5, 1.5, 0.05, ApplyWindowSize)
	sizeSlider:SetPoint("TOPRIGHT", close, "TOPLEFT", -18, 0)
	sizeSlider:SetFrameLevel(drag:GetFrameLevel() + 2)
	local scaleSlider = HeaderSlider(root, "Window Scale", function() return DB.optContentScale end,
		function(v) DB.optContentScale = v end, 0.5, 1.2, 0.05, ApplyContentScale)
	scaleSlider:SetPoint("TOPRIGHT", sizeSlider, "BOTTOMRIGHT", 0, -6)
	scaleSlider:SetFrameLevel(drag:GetFrameLevel() + 2)
	if ns.HAS_SYLVANAS then
		local artSlider = HeaderSlider(root, "Background", function() return DB.optArtAlpha end,
			function(v) DB.optArtAlpha = v end, 0, 1, 0.05)
		artSlider:SetPoint("TOPRIGHT", scaleSlider, "BOTTOMRIGHT", 0, -6)
		artSlider:SetFrameLevel(drag:GetFrameLevel() + 2)
	end

	widgets[#widgets + 1] = function()
		if root:GetScale() ~= DB.optContentScale and not scaleSlider:IsMouseOver() then ApplyContentScale() end
		if window:GetScale() ~= (DB.optWindowSize or 1) and not sizeSlider:IsMouseOver() then ApplyWindowSize() end
		ApplyTheme()
		tint:SetAlpha(DB.optTint)
		art:SetAlpha(DB.optArtAlpha)
		-- Without a picture the wash is the panel, so it follows Panel darkness.
		wash:SetAlpha(art:IsShown() and 1 or DB.optTint)
	end

	root:SetScript("OnShow", function() ShowPage(currentPage) end)
	root:SetScript("OnHide", CloseMenu)
	window:Hide()
end

function ns.ToggleOptions()
	if not window then CreateWindow() end
	if window:IsShown() then
		window:Hide()
	else
		if ns.InBindMode() then ns.SetBindMode(false) end
		window:Show()
	end
end

function ns.HideOptions()
	if window then window:Hide() end
end

function ns.OptionsShown()
	return window ~= nil and window:IsShown()
end
