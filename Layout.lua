local _, ns = ...

-- The Keyzen pad as a grid. Columns 1-6 are the finger keys (1 = pinky outer
-- side, 2 pinky, 3 ring, 4 middle, 5 index, 6 index inner side), column 7 is a
-- gap, columns 8-10 are the thumb cluster. Rows run from far forward (1) to
-- pressed down (6). `id` is the key number the Azeron software shows.

-- Main bar: plain keys, action slots 1-12 (pages with stance/form like the
-- default main bar). `i` is the main bar button index.
-- Reach bar: Alt + key, fixed action slots 61-72 (the bottom-left bar).
-- `name` is the label shown on screen: finger number (1 index .. 4 pinky)
-- plus motion (F push forward, B pull back, D press down, U far forward),
-- S1-S3 for the index side keys, P for the outer pinky key, T for thumb.
ns.KEYS = {
	{ id = 2,  c = 2, r = 4, bar = "main", i = 1,  key = "4", name = "4" },
	{ id = 1,  c = 2, r = 5, bar = "main", i = 2,  key = "8", name = "B4" },
	{ id = 37, c = 2, r = 6, bar = "main", i = 3,  key = "=", name = "D4" },
	{ id = 6,  c = 3, r = 4, bar = "main", i = 4,  key = "3", name = "3" },
	{ id = 5,  c = 3, r = 5, bar = "main", i = 5,  key = "7", name = "B3" },
	{ id = 38, c = 3, r = 6, bar = "main", i = 6,  key = "-", name = "D3" },
	{ id = 10, c = 4, r = 4, bar = "main", i = 7,  key = "2", name = "2" },
	{ id = 9,  c = 4, r = 5, bar = "main", i = 8,  key = "6", name = "B2" },
	{ id = 13, c = 4, r = 6, bar = "main", i = 9,  key = "0", name = "D2" },
	{ id = 15, c = 5, r = 4, bar = "main", i = 10, key = "1", name = "1" },
	{ id = 14, c = 5, r = 5, bar = "main", i = 11, key = "5", name = "B1" },
	{ id = 4,  c = 1, r = 4, bar = "main", i = 12, key = "9", name = "P" },

	{ id = 19, c = 6,  r = 3, bar = "reach", slot = 61, key = "ALT-9", name = "S1" },
	{ id = 7,  c = 3,  r = 3, bar = "reach", slot = 62, key = "ALT-3", name = "F3" },
	{ id = 11, c = 4,  r = 3, bar = "reach", slot = 63, key = "ALT-2", name = "F2" },
	{ id = 16, c = 5,  r = 3, bar = "reach", slot = 64, key = "ALT-1", name = "F1" },
	{ id = 3,  c = 2,  r = 3, bar = "reach", slot = 65, key = "ALT-4", name = "F4" },
	{ id = 8,  c = 3,  r = 2, bar = "reach", slot = 66, key = "ALT-7", name = "U3", group = "far" },
	{ id = 12, c = 4,  r = 2, bar = "reach", slot = 67, key = "ALT-6", name = "U2", group = "far" },
	{ id = 17, c = 5,  r = 2, bar = "reach", slot = 68, key = "ALT-5", name = "U1", group = "far" },
	{ id = 20, c = 10, r = 4, bar = "reach", slot = 69, key = "ALT-8", name = "T1", group = "thumb" },
	{ id = 42, c = 6,  r = 4, bar = "reach", slot = 70, key = "ALT-0", name = "S2" },
	{ id = 43, c = 6,  r = 5, bar = "reach", slot = 71, key = "ALT--", name = "S3" },
	{ id = 23, c = 8,  r = 6, bar = "reach", slot = 72, key = "ALT-=", name = "T2", group = "thumb" },
}

-- Keys that keep their normal WoW job. Drawn as labels so the shape on screen
-- matches the pad; the addon never binds them.
ns.FIXED = {
	{ id = 36, c = 1,  r = 5, label = "Tab" },
	{ id = 18, c = 5,  r = 6, label = "", faint = true }, -- Jump (Space)
	-- R, K, M, C, B (thumb cross) are hidden until the design pass.
	{ id = 41, c = 10, r = 5, label = "Esc" },
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
