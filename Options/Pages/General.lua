local _, ns = ...
local W, O = ns.Widgets, ns.Options
local Bind = O.Bind

O:RegisterPage("general", "General", nil, function(s)
	W.Header(s, "General", "The basics. Everything here applies to the active profile.")

	W.Toggle(s, Bind("general.enabled", "layout", {
		label = "Enable Lattice frames",
		desc = "Turn off to hide all Lattice party and raid frames.",
	}))
	W.Toggle(s, Bind("general.hideBlizzard", "layout", {
		label = "Hide Blizzard party and raid frames",
		desc = "Takes effect after /reload when turning back on.",
	}))
	W.Toggle(s, Bind("general.smoothBars", "appearance", {
		label = "Smooth health bars",
		desc = "Animate health changes instead of jumping.",
	}))
	W.Toggle(s, Bind("general.tooltips", "appearance", {
		label = "Unit tooltip on mouseover",
		desc = "Shown out of combat only.",
	}))

	W.Header(s, "Range")
	W.Toggle(s, Bind("general.rangeFade", "appearance", { label = "Fade players out of range" }))
	W.Slider(s, Bind("general.rangeAlpha", "appearance", {
		label = "Out of range opacity", min = 0.1, max = 0.9, step = 0.05,
	}))

	W.Header(s, "Raid size", "Large raids can use a separate, more compact layout.")
	W.Toggle(s, Bind("general.largeRaidLayout", "layout", { label = "Use the large raid layout in big raids" }))
	W.Slider(s, Bind("general.largeRaidThreshold", "layout", {
		label = "Large raid starts above this many players", min = 10, max = 39, step = 1,
		disabled = function() return not ns.db.general.largeRaidLayout end,
	}))

	W.Header(s, "Preview")
	W.Note(s, "Preview shows fake frames so you can tune things while solo. Pick a group size:")
	W.Dropdown(s, {
		label = "Preview group size",
		items = { { value = 5, text = "Party (5)" }, { value = 10, text = "Raid (10)" }, { value = 20, text = "Raid (20)" },
			{ value = 25, text = "Raid (25)" }, { value = 40, text = "Raid (40)" } },
		get = function() return ns.TestMode.size end,
		set = function(v)
			ns.TestMode:SetSize(v)
			if not ns.TestMode:IsActive() then ns.TestMode.manual = true; ns.TestMode:Start(v) end
		end,
	})

	W.Header(s, "Troubleshooting")
	W.Note(s, "|cffffffff/lattice probe|r prints which unit values the game is hiding from addons right now. Handy inside a dungeon or in combat.")
	W.Toggle(s, {
		label = "Debug messages",
		get = function() return ns.db.debug end,
		set = function(v) ns.db.debug = v end,
	})
end)
