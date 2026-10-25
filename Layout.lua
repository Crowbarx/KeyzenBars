local _, ns = ...

-- The Keyzen pad as a grid. Columns 1-6 are the finger keys (1 = pinky outer
-- side, 2 pinky, 3 ring, 4 middle, 5 index, 6 index inner side), column 7 is a
-- gap, columns 8-10 are the thumb cluster. Rows run from far forward (1) to
-- pressed down (6). `id` is the key number the Azeron software shows.

-- Main bar: plain keys, action slots 1-12 (pages with stance/form like the
-- default main bar). `i` is the main bar button index.
-- Reach bar: the secondary Azeron keys, on action slots 61-72.
-- `name` is the default keyboard label shown on the button.
ns.KEYZEN_KEYS = {
	{ id = 5,  c = 3, r = 5, bar = "main", i = 1,  key = "V", name = "V" },
	{ id = 6,  c = 3, r = 4, bar = "main", i = 2,  key = "C", name = "C" },
	{ id = 10, c = 4, r = 4, bar = "main", i = 3,  key = "X", name = "X" },
	{ id = 15, c = 5, r = 4, bar = "main", i = 4,  key = ";", name = ";" },
	{ id = 14, c = 5, r = 5, bar = "main", i = 5,  key = "SPACE", name = "Space" },
	{ id = 37, c = 2, r = 6, bar = "main", i = 6,  key = "O", name = "O" },
	{ id = 38, c = 3, r = 6, bar = "main", i = 7,  key = "E", name = "E" },
	{ id = 13, c = 4, r = 6, bar = "main", i = 8,  key = "J", name = "J" },
	{ id = 4,  c = 2, r = 2, bar = "main", i = 9,  key = "SPACE", name = "Space" },
	{ id = 8,  c = 3, r = 2, bar = "main", i = 10, key = "F", name = "F" },
	{ id = 12, c = 4, r = 2, bar = "main", i = 11, key = "H", name = "H" },
	{ id = 17, c = 5, r = 2, bar = "main", i = 12, key = ".", name = "." },

	{ id = 9,  c = 4, r = 5, bar = "reach", slot = 61, key = "I", name = "I" },
	{ id = 7,  c = 3, r = 3, bar = "reach", slot = 62, key = "Q", name = "Q" },
	{ id = 11, c = 4, r = 3, bar = "reach", slot = 63, key = "R", name = "R" },
	{ id = 16, c = 5, r = 3, bar = "reach", slot = 64, key = "Z", name = "Z" },
	{ id = 19, c = 6, r = 4, bar = "reach", slot = 65, key = "G", name = "G" },
	{ id = 20, c = 10, r = 5, bar = "reach", slot = 66, key = "N", name = "N" },
	{ id = 22, c = 8, r = 2, bar = "reach", slot = 67, key = "L", name = "L" },
	{ id = 23, c = 8, r = 6, bar = "reach", slot = 68, key = "[", name = "[" },
	{ id = 28, c = 8, r = 1, bar = "reach", slot = 69, key = "", name = "" },
	{ id = 29, c = 6, r = 2, bar = "reach", slot = 70, key = "K", name = "K" },
	{ id = 31, c = 10, r = 2, bar = "reach", slot = 71, key = "P", name = "P" },
	{ id = 41, c = 10, r = 4, bar = "reach", slot = 72, key = "M", name = "M" },

	-- Optional Keyzen side keys remain available but off in the default view.
	{ id = 42, c = 6, r = 5, bar = "reach", slot = 73, key = "", name = "S2", group = "far" },
	{ id = 43, c = 6, r = 6, bar = "reach", slot = 74, key = "", name = "S3", group = "far" },
}

-- Keys that keep their normal WoW job. Drawn as labels so the shape on screen
-- matches the pad; the addon never binds them.
ns.KEYZEN_FIXED = {
	{ id = 1,  c = 2,  r = 5, label = "Ctrl" },
	{ id = 2,  c = 2,  r = 4, label = "Shift" },
	{ id = 3,  c = 2,  r = 3, label = "Alt" },
	{ id = 18, c = 5,  r = 6, label = "Space+T" },
	{ id = 24, c = 8,  r = 4, label = "Stick" },
	{ id = 30, c = 10, r = 3, label = "Esc" },
	{ id = 36, c = 1,  r = 4, label = "Tab" },
}

-- Razer Naga side buttons, drawn 3 wide like the mouse. The keys stay on the
-- numpad; the label shows the button number printed on the Naga. Slots 37-48
-- are the bar the numpad was already bound to (MULTIACTIONBAR4).
ns.NAGA = {
	{ id = 101, n = 1,  c = 1, r = 1, key = "NUMPAD1",       slot = 37 },
	{ id = 102, n = 2,  c = 2, r = 1, key = "NUMPAD2",       slot = 41 },
	{ id = 103, n = 3,  c = 3, r = 1, key = "NUMPAD3",       slot = 45 },
	{ id = 104, n = 4,  c = 1, r = 2, key = "NUMPAD4",       slot = 38 },
	{ id = 105, n = 5,  c = 2, r = 2, key = "NUMPAD5",       slot = 42 },
	{ id = 106, n = 6,  c = 3, r = 2, key = "NUMPAD6",       slot = 46 },
	{ id = 107, n = 7,  c = 1, r = 3, key = "NUMPAD7",       slot = 39 },
	{ id = 108, n = 8,  c = 2, r = 3, key = "NUMPAD8",       slot = 43 },
	{ id = 109, n = 9,  c = 3, r = 3, key = "NUMPAD9",       slot = 47 },
	{ id = 110, n = 10, c = 1, r = 4, key = "NUMPAD0",       slot = 40 },
	{ id = 111, n = 11, c = 2, r = 4, key = "NUMPADDECIMAL", slot = 44 },
	{ id = 112, n = 12, c = 3, r = 4, key = "NUMPADPLUS",    slot = 48 },
}
for _, def in ipairs(ns.NAGA) do def.bar = "naga" end

local cyborgKeys = {}
local cyborgReach = 0
local function AddCyborgKey(joyLabel, c, r, mainIndex)
	local bar, index, slot
	if mainIndex then
		bar, index = "main", mainIndex
	else
		cyborgReach = cyborgReach + 1
		bar, slot = "reach", 60 + cyborgReach
	end
	cyborgKeys[#cyborgKeys + 1] = {
		id = 200 + #cyborgKeys + 1, c = c, r = r, bar = bar, i = index, slot = slot,
		key = "", name = joyLabel:gsub("^JOY ", ""),
		deviceName = "Cyborg II " .. joyLabel .. " (row " .. r .. ", column " .. c .. ")",
	}
end

-- Cyborg II locations and labels follow the Azeron profile layout.
AddCyborgKey("JOY 14", 2, 2)
AddCyborgKey("JOY 15", 3, 2)
AddCyborgKey("JOY 16", 4, 2)
AddCyborgKey("JOY 17", 5, 2)
AddCyborgKey("JOY UP", 8, 2)
AddCyborgKey("JOY 10", 2, 3, 10)
AddCyborgKey("JOY 11", 3, 3, 11)
AddCyborgKey("JOY 12", 4, 3, 12)
AddCyborgKey("JOY 13", 5, 3)
AddCyborgKey("JOY 23", 1, 4)
AddCyborgKey("JOY 6", 2, 4, 6)
AddCyborgKey("JOY 7", 3, 4, 7)
AddCyborgKey("JOY 8", 4, 4, 8)
AddCyborgKey("JOY 9", 5, 4, 9)
AddCyborgKey("JOY 5", 6, 4, 5)
AddCyborgKey("JOY LEFT", 7, 3)
AddCyborgKey("JOY 20", 8, 3)
AddCyborgKey("JOY RIGHT", 9, 3)
AddCyborgKey("JOY CTRL", 2, 5, 1)
AddCyborgKey("JOY SHIFT", 3, 5, 2)
AddCyborgKey("JOY ALT", 4, 5, 3)
AddCyborgKey("JOY SPACE", 5, 5, 4)
AddCyborgKey("JOY DOWN", 8, 4)
AddCyborgKey("JOY 25", 9, 5)
AddCyborgKey("JOY 24", 2, 6)
AddCyborgKey("JOY 25", 3, 6)
AddCyborgKey("JOY 18", 4, 6)
AddCyborgKey("JOY 19", 5, 6)
AddCyborgKey("JOY 22", 9, 6)
AddCyborgKey("JOY 21", 7, 6)

ns.KEYS = ns.KEYZEN_KEYS
ns.FIXED = ns.KEYZEN_FIXED
ns.DEVICE_LAYOUTS = {
	keyzen = { name = "Keyzen", keys = ns.KEYZEN_KEYS, fixed = ns.KEYZEN_FIXED, columns = 10, rows = 6 },
	cyborg2 = { name = "Cyborg II", keys = cyborgKeys, fixed = {}, columns = 9, rows = 6, halfGap = false },
}
