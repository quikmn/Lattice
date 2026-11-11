-- Lattice: default profile. Saved profiles only store differences from this.
local _, ns = ...

local function layout(o)
	local base = {
		width = 80, height = 42,
		spacing = 2, groupSpacing = 8,
		orientation = "VERTICAL",     -- units stack down; groups go side by side
		sortMethod = "INDEX",         -- INDEX | NAME
		groupBy = "NONE",             -- NONE | ROLE | CLASS | GROUP
		mode = "groups",              -- raid: groups (one column per group) | combined
		unitsPerColumn = 5,           -- combined mode
		groupsPerLine = 8,            -- groups mode: wrap after N groups
		collapseEmptyGroups = true,
		showPlayer = true, showSolo = false, -- party only
		showPower = true,
	}
	for k, v in pairs(o or {}) do base[k] = v end
	return base
end

ns.Defaults = {
	general = {
		enabled = true,
		hideBlizzard = true,
		largeRaidLayout = true,
		largeRaidThreshold = 25,
		rangeFade = true,
		rangeAlpha = 0.45,
		smoothBars = true,
		tooltips = true,
		minimapIcon = true,
	},

	layouts = {
		party  = layout({ width = 96, height = 48, groupBy = "ROLE", showSolo = false }),
		raid   = layout({ width = 80, height = 42 }),
		raid40 = layout({ width = 66, height = 34, showPower = false }),
	},

	positions = {
		party = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 30, y = -220 },
		raid  = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 30, y = -220 },
	},

	appearance = {
		texture = "flat",              -- flat | blizzard | gradient
		healthColor = "class",         -- class | custom | gradient (gradient = by health %, via color curve)
		customHealthColor = { 0.18, 0.80, 0.44, 1 },
		backgroundColor = { 0.06, 0.06, 0.07, 0.9 },
		backgroundMode = "dark",       -- dark | class (dim class color behind missing health)
		borderColor = { 0, 0, 0, 1 },
		borderSize = 1,
		powerHeight = 4,
		powerColorByType = true,

		nameSize = 11,
		nameOutline = true,
		nameClassColor = false,
		nameLength = 8,
		namePoint = "CENTER",

		statusText = "none",           -- none | percent | deficit (shown via secret-safe APIs only)
		statusSize = 10,

		targetHighlight = true,
		targetHighlightColor = { 1, 1, 1, 0.9 },
		mouseoverHighlight = true,
		aggroBorder = true,

		healPrediction = true,
		absorbs = true,

		roleIcon = true,  roleIconSize = 12, roleIconPoint = "TOPLEFT",
		leaderIcon = true,
		raidIcon = true,  raidIconSize = 14, raidIconPoint = "TOP",
		readyCheck = true,
		hideDamagerIcon = true,
	},

	auras = {}, -- filled in by Frames/Auras.lua (needs Forever aura API details)
}
