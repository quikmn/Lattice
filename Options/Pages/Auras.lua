local _, ns = ...
local W, O, U, T = ns.Widgets, ns.Options, ns.Util, ns.Theme
local Bind = O.Bind

local GROW_ITEMS = { { value = "RIGHT", text = "Right" }, { value = "LEFT", text = "Left" }, { value = "UP", text = "Up" }, { value = "DOWN", text = "Down" } }

local function Pos(s, prefix, withGrow)
	W.Dropdown(s, Bind(prefix .. ".point", "auras", { label = "Position", items = O.POINT_ITEMS }))
	if withGrow then
		W.Dropdown(s, Bind(prefix .. ".grow", "auras", { label = "Grow towards", items = GROW_ITEMS }))
	end
	W.Slider(s, Bind(prefix .. ".x", "auras", { label = "Nudge left / right", min = -30, max = 30, step = 1 }))
	W.Slider(s, Bind(prefix .. ".y", "auras", { label = "Nudge down / up", min = -30, max = 30, step = 1 }))
end

local function IndicatorEditor(s, index)
	local ind = ns.db.auras.indicators[index]
	if not ind then return end
	local base = "auras.indicators." .. index
	local names = {}
	for _, id in ipairs(ind.spells) do names[#names + 1] = tostring(id) end
	W.Header(s, ind.name or ("Indicator " .. index), "Spell IDs: " .. table.concat(names, ", "))
	W.Toggle(s, Bind(base .. ".enabled", "auras", { label = "Enabled" }))
	W.Toggle(s, Bind(base .. ".mine", "auras", { label = "Only when cast by me" }))
	W.Dropdown(s, Bind(base .. ".style", "auras", {
		label = "Style", items = { { value = "square", text = "Colored square" }, { value = "icon", text = "Spell icon" } },
	}))
	W.Color(s, Bind(base .. ".color", "auras", { label = "Square color" }))
	W.Slider(s, Bind(base .. ".size", "auras", { label = "Size", min = 4, max = 30, step = 1 }))
	W.Toggle(s, Bind(base .. ".swipe", "auras", { label = "Show time left as a swipe" }))
	Pos(s, base, false)
	local del = W.Button(nil, "Remove indicator", function()
		table.remove(ns.db.auras.indicators, index)
		ns.Auras:Refresh()
		O:RebuildPage("auras")
	end, 160, "danger")
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
			status:SetText("|cffef5d5dNo spell found. Use the spell ID for spells you don't know.|r")
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
	}))

	W.Header(s, "Dispel highlight", "Colors the frame when a player has a debuff you can remove.")
	W.Toggle(s, Bind("auras.dispel.enabled", "auras", { label = "Highlight dispellable debuffs" }))
	W.Toggle(s, Bind("auras.dispel.onlyMine", "auras", { label = "Only debuffs I can dispel myself" }))
	W.Dropdown(s, Bind("auras.dispel.style", "auras", {
		label = "Style",
		items = { { value = "border", text = "Colored border" }, { value = "both", text = "Border and a light tint" },
			{ value = "overlay", text = "Tint the whole frame" }, { value = "icon", text = "Small icon" } },
	}))
	W.Slider(s, Bind("auras.dispel.thickness", "auras", { label = "Border thickness", min = 1, max = 5, step = 1 }))
	for _, t in ipairs(ns.Auras.DISPEL_TYPES) do
		W.Color(s, Bind("auras.dispel.colors." .. t, "auras", { label = t }))
	end

	W.Header(s, "Debuffs")
	W.Toggle(s, Bind("auras.debuffs.enabled", "auras", { label = "Show debuff icons" }))
	W.Toggle(s, Bind("auras.debuffs.onlyDispellable", "auras", { label = "Only dispellable debuffs" }))
	W.Slider(s, Bind("auras.debuffs.max", "auras", { label = "How many", min = 1, max = 8, step = 1 }))
	W.Toggle(s, Bind("auras.debuffs.hideLong", "auras", { label = "Hide long debuffs nobody can dispel (over 10 min, like Boosted Rest)" }))
	W.Slider(s, Bind("auras.debuffs.size", "auras", { label = "Icon size", min = 8, max = 32, step = 1 }))
	W.Toggle(s, Bind("auras.debuffs.swipe", "auras", { label = "Time left swipe" }))
	W.Toggle(s, Bind("auras.debuffs.stacks", "auras", { label = "Stack count" }))
	Pos(s, "auras.debuffs", true)

	W.Header(s, "My buffs and HoTs")
	W.Toggle(s, Bind("auras.buffs.enabled", "auras", { label = "Show buff icons" }))
	W.Dropdown(s, Bind("auras.buffs.source", "auras", {
		label = "Which buffs",
		items = { { value = "mine", text = "Mine only (HoTs, shields)" }, { value = "all", text = "Everyone's raid buffs" } },
	}))
	W.Toggle(s, Bind("auras.buffs.hideLong", "auras", { label = "Hide other long buffs (over 5 min)" }))
	W.Slider(s, Bind("auras.buffs.max", "auras", { label = "How many", min = 1, max = 8, step = 1 }))
	W.Slider(s, Bind("auras.buffs.size", "auras", { label = "Icon size", min = 8, max = 32, step = 1 }))
	W.Toggle(s, Bind("auras.buffs.swipe", "auras", { label = "Time left swipe" }))
	Pos(s, "auras.buffs", true)

	W.Header(s, "Raid buffs", "Long buffs like Fortitude and Arcane Intellect in a row beside each frame, so you can see who needs a rebuff. In a party; in a raid only if you turn it on.")
	W.Toggle(s, Bind("auras.raidbuffs.enabled", "auras", { label = "Show raid buffs beside the frames" }))
	local function notPick() return ns.db.auras.raidbuffs.which ~= "pick" end
	W.Dropdown(s, {
		label = "Which buffs",
		desc = "Only the ones I can cast: what you can rebuff yourself (all of them for classes without one).",
		items = { { value = "mine", text = "Only the ones I can cast" }, { value = "all", text = "All raid buffs" },
			{ value = "pick", text = "Let me pick" } },
		get = function() return ns.db.auras.raidbuffs.which or "mine" end,
		set = function(v)
			ns.db.auras.raidbuffs.which = v
			ns:ApplySettings("auras")
			O:RebuildPage("auras")
		end,
	})
	for _, f in ipairs(ns.Auras.BUFF_FAMILY_INFO) do
		W.Toggle(s, Bind("auras.raidbuffs.pick." .. f.key, "auras", {
			label = f.label .. " |cff8c8c8c(" .. f.class .. ")|r", disabled = notPick,
		}))
	end
	RaidBuffExtras(s)
	W.Dropdown(s, Bind("auras.raidbuffs.side", "auras", {
		label = "Side",
		items = { { value = "RIGHT", text = "Right of the frame" }, { value = "LEFT", text = "Left of the frame" } },
	}))
	W.Toggle(s, Bind("auras.raidbuffs.inRaid", "auras", { label = "Also in raids" }))
	W.Toggle(s, Bind("auras.missingBuff", "auras", {
		label = "Mark players missing my buff",
		desc = "Priests: Fortitude. Mages: Arcane Intellect (mana users only). Druids: Mark of the Wild. A small icon with a red edge in the corner, in parties and raids. Worked out out of combat.",
	}))
	W.Slider(s, Bind("auras.raidbuffs.size", "auras", { label = "Icon size", min = 8, max = 24, step = 1 }))

	W.Header(s, "Boss debuff", "One big icon for the most important boss or role debuff.")
	W.Toggle(s, Bind("auras.boss.enabled", "auras", { label = "Show boss debuff" }))
	W.Slider(s, Bind("auras.boss.size", "auras", { label = "Icon size", min = 10, max = 40, step = 1 }))
	Pos(s, "auras.boss", false)

	W.Header(s, "Big defensives", "Shield Wall, Divine Shield, Evasion, Barkskin, Blessing of Protection and similar.")
	W.Toggle(s, Bind("auras.defensive.enabled", "auras", { label = "Show big defensive" }))
	W.Slider(s, Bind("auras.defensive.size", "auras", { label = "Icon size", min = 8, max = 32, step = 1 }))
	Pos(s, "auras.defensive", false)

	-- Spell indicators
	W.Header(s, "Spell indicators", "Grid-style markers for specific buffs, e.g. a green square in the corner while your Renew is up.")
	W.Note(s, "Type a spell name you know (all ranks are picked up from your spellbook) or spell IDs separated by commas. Works for buffs only: the game doesn't let addons pick out specific debuffs on friendly players.")

	local row = CreateFrame("Frame")
	local box = W.EditBox(row, 260, 24)
	box:SetPoint("LEFT")
	local status = W.Text(row, T.fontSmall + 1, T.muted)
	local add = W.Button(row, "Add indicator", function()
		local text = box:GetText()
		local ids = ns.Auras:ResolveSpells(text)
		if #ids == 0 then
			status:SetText("|cffff7070No spell found. Check the name, or use spell IDs.|r")
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
