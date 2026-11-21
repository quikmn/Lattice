local _, ns = ...
local W, O, U, T = ns.Widgets, ns.Options, ns.Util, ns.Theme
local Bind = O.Bind

local GROW_ITEMS = { { value = "AUTO", text = "Into the frame" }, { value = "RIGHT", text = "Right" }, { value = "LEFT", text = "Left" }, { value = "UP", text = "Up" }, { value = "DOWN", text = "Down" } }

local function Pos(s, prefix, withGrow, disabled)
	W.Dropdown(s, Bind(prefix .. ".point", "auras", { label = "Position", items = O.POINT_ITEMS, disabled = disabled }))
	if withGrow then
		W.Dropdown(s, Bind(prefix .. ".grow", "auras", { label = "Grow towards", items = GROW_ITEMS, disabled = disabled }))
	end
	W.Slider(s, Bind(prefix .. ".x", "auras", { label = "Nudge left / right", min = -30, max = 30, step = 1, disabled = disabled }))
	W.Slider(s, Bind(prefix .. ".y", "auras", { label = "Nudge down / up", min = -30, max = 30, step = 1, disabled = disabled }))
end

-- Greys out a section's settings while auras, or that section, are turned off.
local function Off(section)
	return function()
		local D = ns.db.auras
		return not D.enabled or (section and not U.Get(D, section)) or false
	end
end

local function IndicatorEditor(s, index)
	local ind = ns.db.auras.indicators[index]
	if not ind then return end
	local base = "auras.indicators." .. index
	local names = {}
	for _, id in ipairs(ind.spells) do names[#names + 1] = tostring(id) end
	local sub = "Spell IDs: " .. table.concat(names, ", ") .. (ind.harmful and " (a debuff, from anyone)" or "")
	W.Header(s, ind.name or ("Indicator " .. index), sub)
	local off = function() return not ns.db.auras.enabled or ind.enabled == false end
	W.Toggle(s, Bind(base .. ".enabled", "auras", { label = "Show this indicator", disabled = function() return not ns.db.auras.enabled end }))
	if not ind.harmful then
		W.Toggle(s, Bind(base .. ".mine", "auras", { label = "Only when cast by me", disabled = off }))
	end
	W.Dropdown(s, Bind(base .. ".style", "auras", {
		label = "Style", items = { { value = "square", text = "Colored square" }, { value = "icon", text = "Spell icon" } },
		disabled = off,
	}))
	W.Color(s, Bind(base .. ".color", "auras", { label = "Square color", disabled = function() return off() or ind.style == "icon" end }))
	W.Slider(s, Bind(base .. ".size", "auras", { label = "Size", min = 4, max = 30, step = 1, disabled = off }))
	W.Toggle(s, Bind(base .. ".swipe", "auras", { label = "Show time left as a swipe", keywords = { "cooldown", "spiral", "timer", "duration" }, disabled = off }))
	Pos(s, base, false, off)
	local del = W.ConfirmButton(nil, "Remove indicator", function()
		table.remove(ns.db.auras.indicators, index)
		ns.Auras:Refresh()
		O:RebuildPage("auras")
	end, 180)
	s:Add(del, 26)
end

-- Advanced: more spells by name or ID in the raid buff row. Hiding one is the Aura filters' "Never show".
local function RaidBuffExtras(s)
	local cfg = ns.db.auras.raidbuffs
	cfg.extra = cfg.extra or {}
	W.Note(s, "Want another buff in the row, like Thorns or Blessing of Sanctuary? Add it here. To keep one out, put it on |cffffffffNever show|r on the Aura filters page.", T.muted)
	local row = CreateFrame("Frame")
	local box = W.EditBox(row, 220, 24)
	box:SetPoint("LEFT")
	local status = W.Text(row, T.fontSmall + 1, T.muted)
	local add = W.Button(row, "Also show", function()
		local ids = ns.Auras:ResolveSpells(box:GetText())
		if #ids == 0 then
			status:SetText("|cffef5d5dNo spell found. Type a spell you know, or its ID, like 467 for Thorns.|r")
			return
		end
		local have = {}
		for _, id in ipairs(cfg.extra) do have[id] = true end
		for _, id in ipairs(ids) do if not have[id] then cfg.extra[#cfg.extra + 1] = id end end
		box:SetText("")
		ns:ApplySettings("auras")
		O:RebuildPage("auras")
	end, 100)
	add:SetPoint("LEFT", box, "RIGHT", 8, 0)
	status:SetPoint("LEFT", add, "RIGHT", 10, 0)
	box:SetScript("OnEnterPressed", function() add:Click() end)
	s:Add(row, 26)
	if #cfg.extra > 0 then
		local names = {}
		for _, id in ipairs(cfg.extra) do
			local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
			names[#names + 1] = (name or "Spell") .. " (" .. id .. ")"
		end
		local clearRow = CreateFrame("Frame")
		local text = W.Text(clearRow, T.fontSmall + 1, T.text)
		text:SetPoint("LEFT")
		text:SetText("Also shown: " .. table.concat(names, ", "))
		local clear = W.Button(clearRow, "Clear", function()
			wipe(cfg.extra)
			ns:ApplySettings("auras")
			O:RebuildPage("auras")
		end, 70, "danger")
		clear:SetPoint("RIGHT", -6, 0)
		text:SetPoint("RIGHT", clear, "LEFT", -8, 0)
		text:SetJustifyH("LEFT")
		s:Add(clearRow, 24)
	end
end

O:RegisterPage("auras", "Auras", nil, function(s)
	W.Header(s, "Auras", "Buffs, debuffs and dispel highlights. Blizzard draws these for us, so they keep working in combat.")
	W.Toggle(s, Bind("auras.enabled", "auras", { label = "Show auras on frames" }))
	W.Note(s, "Hide or pin specific buffs and debuffs on the |cffffffffAura filters|r page.")
	W.Toggle(s, Bind("auras.tooltips", "auras", {
		label = "Aura tooltips on mouseover",
		desc = "When on, aura icons catch the mouse, so clicking an icon won't click-cast on that player.",
		disabled = Off(),
	}))
	W.Toggle(s, Bind("auras.countdown", "auras", {
		label = "Seconds left on buff and debuff icons", keywords = { "timer", "countdown", "duration" },
		desc = "Numbers counting down on the icons. Raid buffs keep just the clock sweep.",
		disabled = Off(),
	}))

	W.Header(s, "Dispel highlight", "Shows when a player has a debuff that can be removed.")
	local noDispel = function() local D = ns.db.auras; return not D.enabled or not D.dispel.enabled end
	local noDispelAny = function() local D = ns.db.auras; return not D.enabled or not (D.dispel.enabled or D.dispel.icon) end
	local noIcon = Off("dispel.icon")
	W.Toggle(s, Bind("auras.dispel.onlyMine", "auras", {
		label = "Only debuffs I can remove myself",
		desc = "Off: also debuffs someone else in the group can remove.",
		disabled = noDispelAny,
	}))
	W.Toggle(s, Bind("auras.dispel.icon", "auras", {
		label = "Big icon in the middle of the frame",
		desc = "The debuff itself, large, edged in its type's color (blue Magic, purple Curse, green Poison, brown Disease).",
		disabled = Off(),
	}))
	W.Toggle(s, Bind("auras.dispel.iconPulse", "auras", { label = "Pulse around the big icon", keywords = { "glow", "animation" }, disabled = noIcon }))
	W.Slider(s, Bind("auras.dispel.iconSize", "auras", { label = "Big icon size", min = 14, max = 40, step = 1, disabled = noIcon }))
	W.Toggle(s, Bind("auras.dispel.enabled", "auras", { label = "Color the frame too", keywords = { "dispel", "highlight", "colour" }, disabled = Off() }))
	W.Dropdown(s, Bind("auras.dispel.style", "auras", {
		label = "Frame color style", keywords = { "how" },
		items = { { value = "border", text = "Colored border" }, { value = "both", text = "Border and a light tint" },
			{ value = "overlay", text = "Tint the whole frame" }, { value = "icon", text = "Small square in the corner" } },
		disabled = noDispel,
	}))
	W.Slider(s, Bind("auras.dispel.thickness", "auras", {
		label = "Border thickness", min = 1, max = 5, step = 1,
		disabled = function()
			local st = ns.db.auras.dispel.style
			return noDispel() or (st ~= "border" and st ~= "both")
		end,
	}))
	-- Bleed can't be removed in Classic, so its color isn't offered.
	for _, t in ipairs(ns.Auras.DISPEL_TYPES) do
		if t ~= "Bleed" then
			W.Color(s, Bind("auras.dispel.colors." .. t, "auras", { label = t .. " color", disabled = noDispelAny }))
		end
	end

	W.Header(s, "Debuffs")
	local noDebuffs = Off("debuffs.enabled")
	W.Toggle(s, Bind("auras.debuffs.enabled", "auras", { label = "Show debuff icons", disabled = Off() }))
	W.Toggle(s, Bind("auras.debuffs.onlyDispellable", "auras", { label = "Only debuffs that can be removed", disabled = noDebuffs }))
	W.Toggle(s, Bind("auras.debuffs.hideLong", "auras", {
		label = "Hide long debuffs nobody can remove",
		desc = "Over 10 minutes, like Boosted Rest. Magic, curses, poisons and diseases always show.",
		disabled = noDebuffs,
	}))
	W.Slider(s, Bind("auras.debuffs.max", "auras", { label = "How many", min = 1, max = 8, step = 1, disabled = noDebuffs }))
	W.Slider(s, Bind("auras.debuffs.size", "auras", { label = "Icon size", min = 8, max = 32, step = 1, disabled = noDebuffs }))
	W.Toggle(s, Bind("auras.debuffs.swipe", "auras", { label = "Time left as a swipe", keywords = { "cooldown", "spiral", "timer", "duration" }, disabled = noDebuffs }))
	W.Toggle(s, Bind("auras.debuffs.stacks", "auras", { label = "Stack count", keywords = { "stacks", "charges" }, disabled = noDebuffs }))
	Pos(s, "auras.debuffs", true, noDebuffs)

	W.Header(s, "Buffs", "Your HoTs and shields, on the frame.")
	local noBuffs = Off("buffs.enabled")
	W.Toggle(s, Bind("auras.buffs.enabled", "auras", { label = "Show buff icons", disabled = Off() }))
	W.Dropdown(s, Bind("auras.buffs.source", "auras", {
		label = "Whose buffs",
		items = { { value = "mine", text = "Mine only (HoTs, shields)" }, { value = "all", text = "Anyone's" } },
		disabled = noBuffs,
	}))
	W.Toggle(s, Bind("auras.buffs.hideLong", "auras", {
		label = "Hide long buffs (over 10 minutes)",
		desc = "Fortitude, Mark of the Wild and the like, so HoTs and shields stand out. Spells on Always show still show.",
		disabled = noBuffs,
	}))
	W.Slider(s, Bind("auras.buffs.max", "auras", { label = "How many", min = 1, max = 8, step = 1, disabled = noBuffs }))
	W.Slider(s, Bind("auras.buffs.size", "auras", { label = "Icon size", min = 8, max = 32, step = 1, disabled = noBuffs }))
	W.Toggle(s, Bind("auras.buffs.swipe", "auras", { label = "Time left as a swipe", keywords = { "cooldown", "spiral", "timer", "duration" }, disabled = noBuffs }))
	Pos(s, "auras.buffs", true, noBuffs)

	W.Header(s, "Raid buffs", "Long buffs like Fortitude and Arcane Intellect in a row beside each frame, so you can see who needs a rebuff. In a party; in a raid only if you turn it on.")
	local noRaidBuffs = Off("raidbuffs.enabled")
	W.Toggle(s, Bind("auras.raidbuffs.enabled", "auras", { label = "Show raid buffs beside the frames", disabled = Off() }))
	W.Toggle(s, Bind("auras.raidbuffs.inRaid", "auras", {
		label = "Also in raids",
		desc = "With one column per group the row can cover the next group; widen the gap between groups on the Layout page.",
		disabled = noRaidBuffs,
	}))
	W.Dropdown(s, Bind("auras.raidbuffs.side", "auras", {
		label = "Side",
		items = { { value = "RIGHT", text = "Right of the frame" }, { value = "LEFT", text = "Left of the frame" } },
		disabled = noRaidBuffs,
	}))
	W.Slider(s, Bind("auras.raidbuffs.size", "auras", { label = "Icon size", min = 8, max = 24, step = 1, disabled = noRaidBuffs }))
	local function notPick() return noRaidBuffs() or ns.db.auras.raidbuffs.which ~= "pick" end
	W.Dropdown(s, {
		label = "Which buffs", key = "auras.raidbuffs.which",
		desc = "Only the ones I can cast: what you can rebuff yourself (all of them for classes without one).",
		items = { { value = "mine", text = "Only the ones I can cast" }, { value = "all", text = "All raid buffs" },
			{ value = "pick", text = "Let me pick" } },
		get = function() return ns.db.auras.raidbuffs.which or "mine" end,
		set = function(v)
			ns.db.auras.raidbuffs.which = v
			ns:ApplySettings("auras")
		end,
		disabled = noRaidBuffs,
	})
	for _, f in ipairs(ns.Auras.BUFF_FAMILY_INFO) do
		W.Toggle(s, Bind("auras.raidbuffs.pick." .. f.key, "auras", {
			label = f.label .. " |cff8c8c8c(" .. f.class .. ")|r", disabled = notPick,
		}))
	end
	RaidBuffExtras(s)

	W.Header(s, "Missing buff mark")
	W.Toggle(s, Bind("auras.missingBuff", "auras", {
		label = "Mark players missing my buff",
		desc = "Priests: Fortitude. Mages: Arcane Intellect (mana users only). Druids: Mark of the Wild. A small icon with a red edge in the bottom right corner, in parties and raids. Worked out out of combat, then kept during a fight.",
	}))

	W.Header(s, "Boss debuff", "One big icon for the most important boss debuff.")
	local noBoss = Off("boss.enabled")
	W.Toggle(s, Bind("auras.boss.enabled", "auras", { label = "Show boss debuff", keywords = { "raid debuff", "dungeon" }, disabled = Off() }))
	W.Slider(s, Bind("auras.boss.size", "auras", { label = "Icon size", min = 10, max = 40, step = 1, disabled = noBoss }))
	Pos(s, "auras.boss", false, noBoss)

	W.Header(s, "Big defensives", "Shield Wall, Divine Shield, Evasion, Barkskin, Blessing of Protection and similar.")
	local noDef = Off("defensive.enabled")
	W.Toggle(s, Bind("auras.defensive.enabled", "auras", { label = "Show big defensive", keywords = { "cooldown", "shield wall", "defensive" }, disabled = Off() }))
	W.Slider(s, Bind("auras.defensive.size", "auras", { label = "Icon size", min = 8, max = 32, step = 1, disabled = noDef }))
	Pos(s, "auras.defensive", false, noDef)

	-- Spell indicators
	W.Header(s, "Spell indicators", "Grid-style markers for specific buffs, e.g. a green square in the corner while your Renew is up.",
		{ "indicator", "preset", "class", "hot", "square", "marker", "renew" })
	W.Note(s, "Type a spell name you know (all ranks are picked up from your spellbook) or spell IDs separated by commas. Works for buffs only: the game doesn't let addons pick out specific debuffs on friendly players.")

	local row = CreateFrame("Frame")
	local box = W.EditBox(row, 260, 24)
	box:SetPoint("LEFT")
	local status = W.Text(row, T.fontSmall + 1, T.muted)
	local add = W.Button(row, "Add indicator", function()
		local text = box:GetText()
		local ids = ns.Auras:ResolveSpells(text)
		if #ids == 0 then
			status:SetText("|cffff7070No spell found. Type a spell you know, like Renew, or its ID, like 139.|r")
			return
		end
		local name = tonumber((text:match("^%s*([^,]+)") or "")) and ("Spell " .. ids[1]) or text:match("^%s*([^,]+)")
		ns.Auras:AddIndicator(name, ids)
		box:SetText("")
		O:RebuildPage("auras")
	end, 130, "accent")
	add:SetPoint("LEFT", box, "RIGHT", 8, 0)
	status:SetPoint("LEFT", add, "RIGHT", 10, 0)
	box:SetScript("OnEnterPressed", function() add:Click() end)
	s:Add(row, 26)

	local _, class = UnitClass("player")
	if ns.Auras.PRESETS[class] then
		local presetRow = CreateFrame("Frame")
		local presetStatus = W.Text(presetRow, T.fontSmall + 1, T.muted)
		local preset = W.Button(presetRow, "Add my class's HoTs and shields", function()
			local added, skipped = ns.Auras:AddClassPresets()
			if #added == 0 then
				presetStatus:SetText("|cffffcc66Nothing new to add (already added, or not learned yet).|r")
				return
			end
			O:RebuildPage("auras")
		end, 240)
		preset:SetPoint("LEFT")
		presetStatus:SetPoint("LEFT", preset, "RIGHT", 10, 0)
		local names = {}
		for _, entry in ipairs(ns.Auras.PRESETS[class]) do names[#names + 1] = type(entry) == "table" and entry.name or entry end
		presetStatus:SetText(table.concat(names, ", "))
		s:Add(presetRow, 26)
	end

	for i = 1, #ns.db.auras.indicators do
		IndicatorEditor(s, i)
	end
end)
