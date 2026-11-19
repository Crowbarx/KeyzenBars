local ADDON, ns = ...

------------------------------------------------------------------------------
-- Bars per spec. With dual spec, each spec keeps its own buttons: what you
-- put on your bars in one spec comes back when you swap to it again, and the
-- other spec's buttons go back where you left them.
--
-- Every action slot is copied to KeyzenBarsDB.specBars["Name - Realm"][spec]
-- a moment after it changes. On a spec swap the new spec's copy is put back,
-- slot by slot, skipping slots that already match. If the game swaps bars by
-- itself, everything already matches and nothing moves. A spec seen for the
-- first time starts from the bars you had.
--
-- Retail swaps bars per spec on its own, so this only runs on Classic clients.
------------------------------------------------------------------------------

local MAX_SLOT = 120
local SAVE_DELAY = 1

local restoring = false
local saveTimer
local savePending
local pendingRestore

local function Enabled()
	return ns.DB and ns.DB.specBars ~= false
end

local function ActiveGroup()
	if C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup then
		local ok, group = pcall(C_SpecializationInfo.GetActiveSpecGroup)
		if ok and group then return group end
	end
	if GetActiveTalentGroup then
		local ok, group = pcall(GetActiveTalentGroup)
		if ok and group then return group end
	end
	return 1
end

local function Supported()
	if WOW_PROJECT_ID and WOW_PROJECT_MAINLINE and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then return false end
	return GetActiveTalentGroup ~= nil
		or (C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup ~= nil)
end
ns.SpecBarsSupported = Supported

local function Store()
	local root = KeyzenBarsDB
	if not root then return end
	root.specBars = root.specBars or {}
	local key = (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
	root.specBars[key] = root.specBars[key] or {}
	return root.specBars[key]
end

local function MacroName(index)
	if not (GetMacroInfo and index) then return end
	local name = GetMacroInfo(index)
	return name
end

-- One slot as plain data, or false when it is empty.
local function Read(slot)
	if not HasAction(slot) then return false end
	local kind, id, sub = GetActionInfo(slot)
	if not kind then return false end
	local entry = { kind = kind, id = id, sub = sub }
	if kind == "macro" then entry.name = MacroName(id) end
	return entry
end

local function Same(a, b)
	if not a or not b then return not a and not b end
	if a.kind ~= b.kind then return false end
	if a.kind == "macro" and a.name and b.name then return a.name == b.name end
	return a.id == b.id
end

local function Snapshot()
	local bars = {}
	local any = false
	for slot = 1, MAX_SLOT do
		local entry = Read(slot)
		bars[slot] = entry
		if entry then any = true end
	end
	return bars, any
end

local function Save(group)
	if restoring or not Enabled() or not Supported() then return end
	local store = Store()
	if not store then return end
	local bars, any = Snapshot()
	-- Bars that read as all empty usually mean the game hasn't loaded them yet.
	if not any and store[group] then return end
	store[group] = bars
end

local function QueueSave()
	if restoring or not Enabled() then return end
	local group = ActiveGroup()
	savePending = group
	if saveTimer then saveTimer:Cancel() end
	saveTimer = C_Timer.NewTimer(SAVE_DELAY, function()
		saveTimer = nil
		local wanted = savePending
		savePending = nil
		-- A spec swap since the change means these slots belong to the new spec.
		if wanted and wanted == ActiveGroup() then Save(wanted) end
	end)
end

local function CancelSave()
	if saveTimer then saveTimer:Cancel() saveTimer = nil end
	savePending = nil
end

local function Pickup(entry)
	local kind, id = entry.kind, entry.id
	if kind == "spell" then
		local known = IsSpellKnown and IsSpellKnown(id)
		if not known and IsPlayerSpell then known = IsPlayerSpell(id) end
		if known or not GetSpellInfo then
			if C_Spell and C_Spell.PickupSpell then C_Spell.PickupSpell(id) else PickupSpell(id) end
		else
			-- A rank we no longer have: take the spell by name, its best rank.
			local name = GetSpellInfo(id)
			if name then PickupSpell(name) end
		end
	elseif kind == "macro" then
		local index = entry.name and GetMacroIndexByName and GetMacroIndexByName(entry.name)
		if index and index > 0 then PickupMacro(index) end
	elseif kind == "item" then
		if C_Item and C_Item.PickupItem then C_Item.PickupItem(id) elseif PickupItem then PickupItem(id) end
	elseif kind == "companion" then
		if PickupCompanion and entry.sub then PickupCompanion(entry.sub, id) end
	elseif kind == "equipmentset" then
		if C_EquipmentSet and C_EquipmentSet.PickupEquipmentSet then
			pcall(C_EquipmentSet.PickupEquipmentSet, id)
		elseif PickupEquipmentSetByName then
			pcall(PickupEquipmentSetByName, id)
		end
	end
end

local function Restore(group)
	if not Enabled() or not Supported() then return end
	if InCombatLockdown() then pendingRestore = group return end
	-- Never drop whatever the player is holding.
	if GetCursorInfo() then
		C_Timer.After(0.5, function() Restore(group) end)
		return
	end
	local store = Store()
	if not store then return end
	local bars = store[group]
	if not bars then
		-- First time in this spec: start from the bars as they are.
		Save(group)
		return
	end
	restoring = true
	for slot = 1, MAX_SLOT do
		local want = bars[slot] or false
		if not Same(Read(slot), want) then
			if want then
				pcall(Pickup, want)
				if GetCursorInfo() then PlaceAction(slot) end
			else
				PickupAction(slot)
			end
			ClearCursor()
		end
	end
	restoring = false
	-- Read back what landed, so a spell this spec can't use doesn't stay stale.
	C_Timer.After(SAVE_DELAY, function()
		if ActiveGroup() == group then Save(group) end
	end)
end

local currentGroup

local function OnSpecChanged()
	local group = ActiveGroup()
	if group == currentGroup then return end
	CancelSave()
	currentGroup = group
	ns.lastSpecSwap = GetTime()
	-- Let the game finish its own swap first.
	C_Timer.After(0.3, function()
		if ActiveGroup() == group then Restore(group) end
	end)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED",
	"PLAYER_TALENT_UPDATE", "PLAYER_REGEN_ENABLED", "UPDATE_MACROS" }) do
	pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
	if not Supported() then return end
	if event == "PLAYER_ENTERING_WORLD" then
		if not currentGroup then
			currentGroup = ActiveGroup()
			-- Bars load a moment after login.
			C_Timer.After(3, function()
				if Enabled() and ActiveGroup() == currentGroup then Save(currentGroup) end
			end)
		end
	elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_MACROS" then
		if currentGroup and ActiveGroup() == currentGroup then QueueSave() end
	elseif event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
		if currentGroup then OnSpecChanged() end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pendingRestore then
			local group = pendingRestore
			pendingRestore = nil
			if ActiveGroup() == group then Restore(group) end
		end
	end
end)
