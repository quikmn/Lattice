local _, ns = ...
local W, O = ns.Widgets, ns.Options
local Bind = O.Bind

O:RegisterPage("general", "General", nil, function(s)
	W.Header(s, "General", "The basics. Everything here is saved in the active profile.")

	local function off() return not ns.db.general.enabled end
	W.Toggle(s, Bind("general.enabled", "layout", {
		label = "Show Lattice frames", keywords = { "enable", "disable", "on", "off" },
		desc = "Turn off to hide all Lattice party and raid frames.",
	}))
	W.Toggle(s, {
		label = "Hide Blizzard's party and raid frames", keywords = { "default frames", "compact", "blizzard" },
		desc = "Turning this off brings Blizzard's frames back after a /reload.",
		get = function() return ns.db.general.hideBlizzard end,
		set = function(v)
			ns.db.general.hideBlizzard = v
			if v then ns.Headers:HideBlizzard() else ns:Print("Type /reload to get Blizzard's party and raid frames back.") end
		end,
	})
	W.Toggle(s, Bind("general.smoothBars", "appearance", {
		label = "Smooth health bars", keywords = { "animation", "animate" },
		desc = "Health slides to its new value instead of jumping.",
		disabled = off,
	}))
	W.Toggle(s, Bind("general.tooltips", "appearance", {
		label = "Player tooltip on mouseover",
		disabled = off,
	}))
	W.Toggle(s, Bind("general.tooltipsInCombat", "appearance", {
		label = "Tooltip in combat too",
		desc = "Off: the tooltip shows only out of combat, so it never covers anything mid-fight.",
		disabled = function() return off() or ns.db.general.tooltips == false end,
	}))

	W.Header(s, "Range")
	local function noFade() return not ns.db.general.rangeFade end
	W.Toggle(s, Bind("general.rangeFade", "appearance", { label = "Fade players who are out of range" }))
	W.Slider(s, Bind("general.rangeAlpha", "appearance", {
		label = "Opacity when out of range", keywords = { "alpha", "transparency", "fade" }, min = 0.1, max = 0.9, step = 0.05,
		desc = "Lower is fainter.",
		disabled = noFade,
	}))
	W.Toggle(s, Bind("general.rangeBySpell", "appearance", {
		label = "Use my heal's range (40 yards)", keywords = { "distance", "range check" },
		desc = "Priests, druids, shamans and paladins: fade by the range of a heal you know. Other classes use the game's rougher check.",
		disabled = noFade,
	}))

	W.Header(s, "Tanks", "Most groups here have no roles set, so Lattice guesses the tank.")
	W.Toggle(s, {
		label = "Guess the tank when no roles are set",
		desc = "Uses the raid's main tank mark, Defensive Stance, Bear Form and Righteous Fury. In a group of five it picks one player, or the only Warrior.",
		get = function() return ns.db.general.guessTank end,
		set = function(v) ns.db.general.guessTank = v; ns.Roles:Update() end,
	})
	local function noTankFrames() return not ns.db.general.tankFrames end
	W.Toggle(s, Bind("general.tankFrames", "layout", {
		label = "Tank frames in raids",
		desc = "Each tank in a small block of its own. Unlock frames to move it.",
	}))
	W.Toggle(s, Bind("general.tankTargets", "layout", {
		label = "Show what each tank is targeting", keywords = { "target of target", "tot", "main tank" },
		disabled = noTankFrames,
	}))
	W.Toggle(s, Bind("general.tankFramesInParty", "layout", {
		label = "Tank frames in a party too",
		disabled = noTankFrames,
	}))
	W.Note(s, "Wrong guess? |cffffffffCtrl+Alt+Right-click|r the player's frame, or type |cffffffff/lattice tank <name>|r, |cffffffff/lattice notank <name>|r or |cffffffff/lattice autotank <name>|r. |cffffffff/lattice tanks|r shows who counts as tank.")

	W.Header(s, "Preview")
	W.Note(s, "Preview shows made-up frames so you can try settings while solo. Pick a group size:")
	W.Dropdown(s, {
		label = "Preview group size", keywords = { "test mode", "fake", "preview" },
		items = { { value = 5, text = "Party (5)" }, { value = 10, text = "Raid (10)" }, { value = 20, text = "Raid (20)" },
			{ value = 25, text = "Raid (25)" }, { value = 40, text = "Raid (40)" } },
		get = function() return ns.TestMode.size end,
		set = function(v)
			ns.TestMode:SetSize(v)
			if not ns.TestMode:IsActive() then ns.TestMode.manual = true; ns.TestMode:Start(v) end
		end,
	})

	W.Header(s, "Troubleshooting", nil, { "status", "probe", "error", "bug" })
	W.Note(s, "|cffffffff/lattice status|r explains why frames or auras are or aren't showing. |cffffffff/lattice probe|r lists which values the game is hiding from addons right now; handy inside a dungeon or in combat.")
	W.Toggle(s, {
		label = "Debug messages in chat", keywords = { "logging", "verbose", "troubleshoot" },
		get = function() return ns.db.debug end,
		set = function(v) ns.db.debug = v end,
	})
end)
