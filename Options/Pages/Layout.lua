local _, ns = ...
local W, O = ns.Widgets, ns.Options
local Bind = O.Bind

local editing = "party"
local PREVIEW_SIZE = { party = 5, raid = 20, raid40 = 40 }

-- Bind to the layout currently being edited.
local function L(key, opt)
	opt = opt or {}
	opt.get = function() return ns.db.layouts[editing][key] end
	opt.set = function(v)
		ns.db.layouts[editing][key] = v
		ns:ApplySettings("layout")
	end
	return opt
end

O:RegisterPage("layout", "Layout", nil, function(s)
	W.Header(s, "Layout", "Size and arrangement. Party, raid and large raid each have their own layout; Lattice switches between them as your group changes.")

	W.Toggle(s, Bind("general.largeRaidLayout", "layout", {
		label = "Use the large raid layout in big raids",
		desc = "A separate, more compact layout for 40-player raids.",
	}))
	W.Slider(s, Bind("general.largeRaidThreshold", "layout", {
		label = "Large raid layout above this many players", min = 10, max = 39, step = 1,
		desc = "At 25, a 20-player raid uses the Raid layout and a 40-player raid the Large raid layout.",
		disabled = function() return not ns.db.general.largeRaidLayout end,
	}))

	W.Dropdown(s, {
		label = "Layout to edit",
		desc = "The settings below change only this layout. The preview switches to match.",
		items = { { value = "party", text = "Party" }, { value = "raid", text = "Raid" }, { value = "raid40", text = "Large raid" } },
		get = function() return editing end,
		set = function(v)
			editing = v
			if ns.TestMode:IsActive() then ns.TestMode:SetSize(PREVIEW_SIZE[v]) end
		end,
		after = function()
			if not ns.TestMode:IsActive() then ns.TestMode.manual = true; ns.TestMode:Start(PREVIEW_SIZE[editing]) end
		end,
	})

	W.Header(s, "Frame size")
	W.Slider(s, L("width", { label = "Width", min = 30, max = 200, step = 1 }))
	W.Slider(s, L("height", { label = "Height", min = 16, max = 120, step = 1 }))
	W.Slider(s, L("spacing", { label = "Gap between frames", keywords = { "spacing", "padding" }, min = 0, max = 20, step = 1 }))
	W.Toggle(s, L("showPower", { label = "Show power bar", desc = "Who gets one is set on the Appearance page." }))

	W.Header(s, "Arrangement")
	W.Dropdown(s, L("orientation", {
		label = "Direction",
		items = { { value = "VERTICAL", text = "Players top to bottom, groups side by side" },
			{ value = "HORIZONTAL", text = "Players left to right, groups stacked" } },
		width = 340,
	}))
	W.Dropdown(s, L("sortMethod", {
		label = "Sort players by",
		items = { { value = "INDEX", text = "Group order" }, { value = "NAME", text = "Name" } },
	}))

	local function notParty() return editing ~= "party" end
	local function notRaid() return editing == "party" end
	local function notGroups() return notRaid() or ns.db.layouts[editing].mode ~= "groups" end
	local function notGrid() return notRaid() or ns.db.layouts[editing].mode ~= "combined" end

	W.Header(s, "Party", "Only used by the Party layout.")
	W.Toggle(s, L("showPlayer", { label = "Show myself in the party frames", disabled = notParty }))
	W.Toggle(s, L("showSolo", { label = "Show my frame when I'm not in a group", disabled = notParty }))
	W.Dropdown(s, L("groupBy", {
		label = "Order the party by",
		desc = "Tank, healer, damage uses assigned roles; guessed tanks keep their place but get the tank icon.",
		items = { { value = "NONE", text = "Group order" }, { value = "ROLE", text = "Tank, healer, damage" }, { value = "CLASS", text = "Class" } },
		disabled = notParty,
	}))

	W.Header(s, "Raid", "Only used by the Raid and Large raid layouts.")
	W.Dropdown(s, L("mode", {
		label = "Raid style", keywords = { "groups", "grid", "layout" },
		items = { { value = "groups", text = "One column per raid group" }, { value = "combined", text = "All players in one grid" } },
		width = 300,
		disabled = notRaid,
	}))
	W.Slider(s, L("groupSpacing", { label = "Gap between groups", keywords = { "spacing", "padding" }, min = 0, max = 40, step = 1, disabled = notRaid }))
	W.Slider(s, L("groupsPerLine", { label = "Groups per row before wrapping", min = 1, max = 8, step = 1, disabled = notGroups }))
	W.Toggle(s, L("collapseEmptyGroups", { label = "Close gaps left by empty groups", disabled = notGroups }))
	W.Dropdown(s, L("innerSort", {
		label = "Order inside each group",
		desc = "Tank, healer, damage uses assigned roles (most groups here have none, so Class is the useful one).",
		items = { { value = "NONE", text = "Group order" }, { value = "CLASS", text = "Class" }, { value = "ROLE", text = "Tank, healer, damage" } },
		disabled = notGroups,
	}))
	W.Slider(s, L("unitsPerColumn", { label = "Players per column (one grid)", keywords = { "rows", "columns", "wrap" }, min = 1, max = 40, step = 1, disabled = notGrid }))
	W.Dropdown(s, L("groupBy", {
		label = "Group the grid by",
		items = { { value = "NONE", text = "Nothing" }, { value = "GROUP", text = "Raid group" }, { value = "ROLE", text = "Tank, healer, damage" }, { value = "CLASS", text = "Class" } },
		disabled = notGrid,
	}))

	W.Header(s, "Pets")
	W.Toggle(s, { label = "Show pet frames (hunter, warlock and other pets)",
		desc = "Pets get their own block. Unlock frames to move it.",
		get = function() return ns.db.general.showPets end,
		set = function(v) ns.db.general.showPets = v; ns:ApplySettings("layout") end })

	W.Header(s, "Position")
	W.Note(s, "Click |cffffffffUnlock frames|r at the bottom left, then drag the party, raid, pet and tank blocks where you want them.")
	local reset = W.ConfirmButton(nil, "Reset positions", function()
		ns.db.positions = ns.Util.CopyTable(ns.Defaults.positions)
		ns.Mover:RestoreAll()
	end, 180)
	s:Add(reset, 26)
end)
