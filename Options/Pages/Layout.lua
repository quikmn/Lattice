local _, ns = ...
local W, O = ns.Widgets, ns.Options

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
	W.Header(s, "Layout", "Size and arrangement. Party, raid and large raid each have their own layout and switch automatically.")

	local dependents = {}
	W.Dropdown(s, {
		label = "Editing layout",
		items = { { value = "party", text = "Party" }, { value = "raid", text = "Raid" }, { value = "raid40", text = "Large raid" } },
		get = function() return editing end,
		set = function(v)
			editing = v
			s:RefreshAll()
			if ns.TestMode:IsActive() then ns.TestMode:SetSize(PREVIEW_SIZE[v]) end
		end,
		after = function()
			if not ns.TestMode:IsActive() then ns.TestMode.manual = true; ns.TestMode:Start(PREVIEW_SIZE[editing]) end
		end,
	})

	W.Header(s, "Frame size")
	W.Slider(s, L("width", { label = "Width", min = 30, max = 200, step = 1 }))
	W.Slider(s, L("height", { label = "Height", min = 16, max = 120, step = 1 }))
	W.Slider(s, L("spacing", { label = "Gap between frames", min = 0, max = 20, step = 1 }))
	W.Toggle(s, L("showPower", { label = "Show power bar" }))

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

	local function isParty() return editing == "party" end
	local function isRaid() return editing ~= "party" end

	-- Party only
	local t1 = W.Toggle(s, L("showPlayer", { label = "Show myself in party", disabled = function() return not isParty() end }))
	local t2 = W.Toggle(s, L("showSolo", { label = "Show frames when solo", disabled = function() return not isParty() end }))
	local g = W.Dropdown(s, L("groupBy", {
		label = "Party grouping",
		items = { { value = "NONE", text = "None" }, { value = "ROLE", text = "Tank, healer, damage" }, { value = "CLASS", text = "Class" } },
		disabled = function() return not isParty() end,
	}))
	dependents[#dependents + 1] = t1
	dependents[#dependents + 1] = t2

	W.Header(s, "Raid arrangement")
	W.Note(s, "Only used by the Raid and Large raid layouts.")
	W.Dropdown(s, L("mode", {
		label = "Raid style",
		items = { { value = "groups", text = "One column per raid group" }, { value = "combined", text = "All players in one grid" } },
		width = 300,
	}))
	W.Slider(s, L("groupSpacing", { label = "Gap between groups", min = 0, max = 40, step = 1 }))
	W.Slider(s, L("groupsPerLine", { label = "Groups before wrapping", min = 1, max = 8, step = 1 }))
	W.Toggle(s, L("collapseEmptyGroups", { label = "Close gaps left by empty groups" }))
	W.Slider(s, L("unitsPerColumn", { label = "Players per column (grid style)", min = 1, max = 40, step = 1 }))
	W.Dropdown(s, {
		label = "Grid grouping",
		items = { { value = "NONE", text = "None" }, { value = "GROUP", text = "Raid group" }, { value = "ROLE", text = "Tank, healer, damage" }, { value = "CLASS", text = "Class" } },
		get = function() return ns.db.layouts[editing].groupBy end,
		set = function(v) ns.db.layouts[editing].groupBy = v; ns:ApplySettings("layout") end,
	})

	W.Header(s, "Position")
	W.Note(s, "Use |cffffffffUnlock frames|r at the bottom left to drag party and raid frames separately.")
	local reset = W.Button(nil, "Reset positions", function()
		ns.db.positions = ns.Util.CopyTable(ns.Defaults.positions)
		ns.Mover:RestoreAll()
	end, 160)
	s:Add(reset, 26)
end)
