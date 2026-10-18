local _, ns = ...

-- A vehicle exit button. Blizzard's own leave button lives on the main bar
-- that Keyzen Bars hides, so this one takes its place: it shows while you can
-- leave a vehicle or land a flight early, and moves and fades like the other
-- bars. Leaving a vehicle and landing early aren't protected, so a plain
-- button does it and can show and hide in combat. Blizzard's Leave Vehicle
-- keybind keeps working on its own.

local ICON = "Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up"
local ICON_DOWN = "Interface\\Vehicles\\UI-Vehicles-Button-Exit-Down"

local holder, button, border
local landing -- an early landing was asked for on this flight

local function OnTaxi()
	return UnitOnTaxi and UnitOnTaxi("player")
end

local function Usable()
	if OnTaxi() then return TaxiRequestEarlyLanding ~= nil and not landing end
	return CanExitVehicle and CanExitVehicle() or false
end

local function Update()
	if not button then return end
	if not OnTaxi() then landing = nil end
	-- Unlocked, it shows so there's something to see while moving it.
	button:SetShown(Usable() or not ns.DB.lockFrames)
end

function ns.LayoutVehicleExit()
	if not button then return end
	local cfg = ns.BarDB("vehicle")
	local size = cfg.size or 36
	button:SetSize(size, size)
	holder:SetSize(size, size)
	local db = ns.DB
	border:SetThickness(db.borderSize or 1)
	border:SetColorTexture(unpack(db.borderColor or { 0, 0, 0, 1 }))
	Update()
end

function ns.CreateVehicleExit()
	holder = ns.CreateHolder("vehicle", "Leave")
	button = CreateFrame("Button", "KeyzenBarsVehicleExit", holder)
	button:SetPoint("CENTER")
	button:RegisterForClicks("AnyUp")
	button:SetNormalTexture(ICON)
	button:SetPushedTexture(ICON_DOWN)
	-- The art has a round frame around the arrow; the crop keeps the arrow.
	for _, tex in ipairs({ button:GetNormalTexture(), button:GetPushedTexture() }) do
		tex:SetTexCoord(0.14, 0.86, 0.14, 0.86)
	end
	local hl = button:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.15)
	border = ns.AddBorder(button, { 0, 0, 0 }, 0.06)
	button:SetScript("OnClick", function()
		if OnTaxi() then
			TaxiRequestEarlyLanding()
			landing = true
		elseif CanExitVehicle and CanExitVehicle() then
			VehicleExit()
		end
		Update()
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(OnTaxi() and "Request early landing" or (_G.LEAVE_VEHICLE or "Leave vehicle"))
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)

	local events = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE",
		"VEHICLE_UPDATE", "UPDATE_VEHICLE_ACTIONBAR", "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_POSSESS_BAR",
		"PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "TAXIMAP_CLOSED" }) do
		pcall(events.RegisterEvent, events, event) -- not every client has every event
	end
	events:SetScript("OnEvent", function(_, event, unit)
		if (event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and unit ~= "player" then return end
		Update()
		-- A flight counts as one a moment after control is lost.
		if event == "PLAYER_CONTROL_LOST" then C_Timer.After(0.5, Update) end
	end)
	ns.LayoutVehicleExit()
end
