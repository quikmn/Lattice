local _, ns = ...
local W, O, U = ns.Widgets, ns.Options, ns.Util
local Bind = O.Bind

local POINT_ITEMS = {}
for _, p in ipairs(U.POINTS) do
	POINT_ITEMS[#POINT_ITEMS + 1] = { value = p, text = p:sub(1, 1) .. p:sub(2):lower():gsub("left", " left"):gsub("right", " right") }
end
ns.Options.POINT_ITEMS = POINT_ITEMS

O:RegisterPage("appearance", "Appearance", nil, function(s)
	W.Header(s, "Health bar")
	W.Dropdown(s, Bind("appearance.healthColor", "appearance", {
		label = "Health color",
		items = { { value = "class", text = "Class color" }, { value = "custom", text = "One color" }, { value = "gradient", text = "By health (green to red)" } },
	}))
	W.Color(s, Bind("appearance.customHealthColor", "appearance", { label = "Health color (one color mode)" }))
	W.Dropdown(s, Bind("appearance.backgroundMode", "appearance", {
		label = "Missing health",
		items = { { value = "dark", text = "Dark background" }, { value = "class", text = "Dim class color" } },
	}))
	W.Color(s, Bind("appearance.backgroundColor", "appearance", { label = "Background color", hasAlpha = true }))
	W.Dropdown(s, Bind("appearance.texture", "appearance", {
		label = "Bar texture",
		items = { { value = "lattice", text = "Lattice (soft shade)" }, { value = "flat", text = "Flat" }, { value = "smooth", text = "Smooth" }, { value = "raid", text = "Blizzard raid" } },
	}))
	W.Toggle(s, Bind("appearance.healPrediction", "appearance", { label = "Show incoming heals" }))
	W.Toggle(s, Bind("appearance.absorbs", "appearance", { label = "Show shields and heal absorbs" }))

	W.Header(s, "Power bar")
	W.Slider(s, Bind("appearance.powerHeight", "layout", { label = "Power bar height", min = 1, max = 12, step = 1 }))
	W.Toggle(s, Bind("appearance.powerColorByType", "appearance", { label = "Color by power type (mana, rage, energy)" }))

	W.Header(s, "Border")
	W.Slider(s, Bind("appearance.borderSize", "appearance", { label = "Border thickness", min = 0, max = 4, step = 1 }))
	W.Color(s, Bind("appearance.borderColor", "appearance", { label = "Border color", hasAlpha = true }))
	W.Toggle(s, Bind("appearance.targetHighlight", "appearance", { label = "Highlight my target" }))
	W.Color(s, Bind("appearance.targetHighlightColor", "appearance", { label = "Target highlight color", hasAlpha = true }))
	W.Toggle(s, Bind("appearance.mouseoverHighlight", "appearance", { label = "Highlight on mouseover" }))
	W.Toggle(s, Bind("appearance.aggroBorder", "appearance", { label = "Red border when a player has aggro" }))

	W.Header(s, "Name")
	W.Slider(s, Bind("appearance.nameSize", "appearance", { label = "Font size", min = 7, max = 20, step = 1 }))
	W.Slider(s, Bind("appearance.nameLength", "appearance", { label = "Max letters (0 = no limit)", min = 0, max = 20, step = 1 }))
	W.Dropdown(s, Bind("appearance.namePoint", "appearance", { label = "Position", items = POINT_ITEMS }))
	W.Toggle(s, Bind("appearance.nameOutline", "appearance", { label = "Outline" }))
	W.Toggle(s, Bind("appearance.nameClassColor", "appearance", { label = "Class colored names" }))

	W.Header(s, "Health text")
	W.Dropdown(s, Bind("appearance.statusText", "appearance", {
		label = "Show",
		items = { { value = "none", text = "Nothing" }, { value = "percent", text = "Health %" }, { value = "deficit", text = "Missing health" } },
	}))
	W.Slider(s, Bind("appearance.statusSize", "appearance", { label = "Font size", min = 7, max = 18, step = 1 }))

	W.Header(s, "Icons")
	W.Toggle(s, Bind("appearance.roleIcon", "appearance", { label = "Role icon" }))
	W.Toggle(s, Bind("appearance.hideDamagerIcon", "appearance", { label = "Hide the damage role icon (less clutter)" }))
	W.Dropdown(s, Bind("appearance.roleIconPoint", "appearance", { label = "Role icon position", items = POINT_ITEMS }))
	W.Slider(s, Bind("appearance.roleIconSize", "appearance", { label = "Role icon size", min = 6, max = 24, step = 1 }))
	W.Toggle(s, Bind("appearance.leaderIcon", "appearance", { label = "Leader and assist icon" }))
	W.Toggle(s, Bind("appearance.raidIcon", "appearance", { label = "Raid marker" }))
	W.Dropdown(s, Bind("appearance.raidIconPoint", "appearance", { label = "Raid marker position", items = POINT_ITEMS }))
	W.Slider(s, Bind("appearance.raidIconSize", "appearance", { label = "Raid marker size", min = 8, max = 32, step = 1 }))
	W.Toggle(s, Bind("appearance.readyCheck", "appearance", { label = "Ready check icons" }))
	W.Toggle(s, Bind("appearance.summonIcon", "appearance", { label = "Incoming summon icon" }))
	W.Toggle(s, Bind("appearance.dimWhenGone", "appearance", { label = "Grey out offline and tint dead players red" }))
end)
