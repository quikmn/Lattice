local _, ns = ...
local W, O, U = ns.Widgets, ns.Options, ns.Util
local Bind = O.Bind

local POINT_ITEMS = {}
for _, p in ipairs(U.POINTS) do
	POINT_ITEMS[#POINT_ITEMS + 1] = { value = p, text = p:sub(1, 1) .. p:sub(2):lower():gsub("left", " left"):gsub("right", " right") }
end
ns.Options.POINT_ITEMS = POINT_ITEMS

O:RegisterPage("appearance", "Appearance", nil, function(s)
	local A = function() return ns.db.appearance end

	W.Header(s, "Health bar")
	W.Dropdown(s, Bind("appearance.healthColor", "appearance", {
		label = "Health bar color",
		items = { { value = "class", text = "Class color" }, { value = "custom", text = "One color for everyone" }, { value = "gradient", text = "By health (green to red)" } },
	}))
	W.Color(s, Bind("appearance.customHealthColor", "appearance", {
		label = "The one color",
		disabled = function() return A().healthColor ~= "custom" end,
	}))
	W.Dropdown(s, Bind("appearance.backgroundMode", "appearance", {
		label = "Missing health shows as", keywords = { "background", "deficit", "lost health" },
		desc = "The part of the bar a player's health no longer fills.",
		items = { { value = "dark", text = "Background color" }, { value = "class", text = "Dim class color" } },
	}))
	W.Color(s, Bind("appearance.backgroundColor", "appearance", {
		label = "Background color", hasAlpha = true,
		desc = "Its opacity is used in both modes.",
	}))
	W.Dropdown(s, Bind("appearance.texture", "appearance", {
		label = "Bar texture", keywords = { "statusbar", "style", "look" },
		items = { { value = "lattice", text = "Lattice (soft shade)" }, { value = "flat", text = "Flat" }, { value = "smooth", text = "Smooth" }, { value = "raid", text = "Blizzard raid" } },
	}))
	W.Toggle(s, Bind("appearance.healPrediction", "appearance", { label = "Show incoming heals", desc = "A light green bar past the health: heals being cast on that player." }))
	W.Toggle(s, Bind("appearance.absorbs", "appearance", { label = "Show shields and heal absorbs", desc = "Power Word: Shield and the like in white; effects that soak up healing in dark red." }))
	W.Toggle(s, Bind("appearance.lowHealth", "appearance", {
		label = "Warn when health is low",
		desc = "The missing part of the bar turns red below the threshold, so players in danger stand out.",
	}))
	W.Slider(s, Bind("appearance.lowHealthThreshold", "appearance", {
		label = "Low health below this % of health", min = 10, max = 60, step = 5,
		disabled = function() return not A().lowHealth end,
	}))

	W.Header(s, "Power bar")
	W.Note(s, "The Layout page turns power bars on or off for each layout.")
	W.Slider(s, Bind("appearance.powerHeight", "layout", { label = "Power bar height", min = 1, max = 12, step = 1 }))
	W.Toggle(s, Bind("appearance.powerColorByType", "appearance", { label = "Color by power type (mana, rage, energy)", desc = "Off: every power bar is blue." }))
	W.Note(s, "Who gets a power bar. Druids switch as they shift form. Tanks include guessed tanks (General page); healers count only when the group has roles set.")
	local RULES = { { value = "always", text = "Everyone" }, { value = "tankheal", text = "Tanks and healers only" },
		{ value = "tank", text = "Tanks only" }, { value = "never", text = "Nobody" } }
	W.Dropdown(s, Bind("appearance.powerRules.MANA", "appearance", { label = "Mana (casters, hunters, druids in caster form)", items = RULES, width = 300 }))
	W.Dropdown(s, Bind("appearance.powerRules.RAGE", "appearance", { label = "Rage (warriors, druids in Bear Form)", items = RULES, width = 300 }))
	W.Dropdown(s, Bind("appearance.powerRules.ENERGY", "appearance", { label = "Energy (rogues, druids in Cat Form)", items = RULES, width = 300 }))

	W.Header(s, "Border and highlights")
	W.Slider(s, Bind("appearance.borderSize", "appearance", { label = "Border thickness", min = 0, max = 4, step = 1 }))
	W.Color(s, Bind("appearance.borderColor", "appearance", {
		label = "Border color", hasAlpha = true,
		disabled = function() return A().borderSize <= 0 end,
	}))
	W.Toggle(s, Bind("appearance.targetHighlight", "appearance", { label = "Highlight my target" }))
	W.Color(s, Bind("appearance.targetHighlightColor", "appearance", {
		label = "Target highlight color", hasAlpha = true,
		disabled = function() return not A().targetHighlight end,
	}))
	W.Toggle(s, Bind("appearance.mouseoverHighlight", "appearance", { label = "Highlight the frame under the mouse", keywords = { "mouseover", "hover" } }))
	W.Toggle(s, Bind("appearance.aggroBorder", "appearance", {
		label = "Red border when a player has aggro", keywords = { "threat" },
		desc = "Red while a monster is attacking them; orange when it is but someone else is about to pull it off.",
	}))
	W.Toggle(s, Bind("appearance.aggroSkipTanks", "appearance", {
		label = "No aggro border on tanks",
		desc = "Tanks are meant to have aggro. Includes guessed tanks.",
		disabled = function() return not A().aggroBorder end,
	}))

	W.Header(s, "Name")
	W.Slider(s, Bind("appearance.nameSize", "appearance", { label = "Font size", min = 7, max = 20, step = 1 }))
	W.Slider(s, Bind("appearance.nameLength", "appearance", { label = "Letters shown (0 = whole name)", keywords = { "name length", "truncate", "shorten", "characters" }, min = 0, max = 20, step = 1 }))
	W.Dropdown(s, Bind("appearance.namePoint", "appearance", { label = "Position", items = POINT_ITEMS }))
	W.Toggle(s, Bind("appearance.nameOutline", "appearance", { label = "Outline" }))
	W.Toggle(s, Bind("appearance.nameClassColor", "appearance", { label = "Class colored names" }))

	W.Header(s, "Health text")
	W.Dropdown(s, Bind("appearance.statusText", "appearance", {
		label = "Show",
		items = { { value = "none", text = "Nothing" }, { value = "percent", text = "Health %" }, { value = "deficit", text = "Missing health" } },
	}))
	W.Slider(s, Bind("appearance.statusSize", "appearance", {
		label = "Font size", min = 7, max = 18, step = 1,
		desc = "Also used for Dead, Offline and AFK.",
	}))

	W.Header(s, "Icons")
	local function noRole() return not A().roleIcon end
	local function noMarker() return not A().raidIcon end
	W.Toggle(s, Bind("appearance.roleIcon", "appearance", { label = "Role icon", desc = "Assigned roles, and the guessed tank." }))
	W.Toggle(s, Bind("appearance.hideDamagerIcon", "appearance", { label = "No icon for damage dealers (less clutter)", disabled = noRole }))
	W.Dropdown(s, Bind("appearance.roleIconPoint", "appearance", { label = "Role icon position", items = POINT_ITEMS, disabled = noRole }))
	W.Slider(s, Bind("appearance.roleIconSize", "appearance", { label = "Role icon size", min = 6, max = 24, step = 1, disabled = noRole }))
	W.Toggle(s, Bind("appearance.leaderIcon", "appearance", { label = "Leader and assist icon" }))
	W.Toggle(s, Bind("appearance.raidIcon", "appearance", { label = "Raid marker (skull, cross, ...)" }))
	W.Dropdown(s, Bind("appearance.raidIconPoint", "appearance", { label = "Raid marker position", items = POINT_ITEMS, disabled = noMarker }))
	W.Slider(s, Bind("appearance.raidIconSize", "appearance", { label = "Raid marker size", min = 8, max = 32, step = 1, disabled = noMarker }))
	W.Toggle(s, Bind("appearance.readyCheck", "appearance", { label = "Ready check icons" }))
	W.Toggle(s, Bind("appearance.summonIcon", "appearance", { label = "Incoming summon icon" }))
	W.Toggle(s, Bind("appearance.dimWhenGone", "appearance", { label = "Grey out offline players and tint dead players red" }))
end)
