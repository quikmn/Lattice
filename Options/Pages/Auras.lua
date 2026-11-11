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

O:RegisterPage("auras", "Auras", nil, function(s)
	W.Header(s, "Auras", "Buffs, debuffs and dispel highlights. Blizzard draws these for us, so they keep working in combat.")
	W.Toggle(s, Bind("auras.enabled", "auras", { label = "Show auras on frames" }))
	W.Toggle(s, Bind("auras.tooltips", "auras", {
		label = "Aura tooltips on mouseover",
		desc = "When on, aura icons catch the mouse, so clicking an icon won't click-cast on that player.",
	}))

	W.Header(s, "Dispel highlight", "Colors the frame when a player has a debuff you can remove.")
	W.Toggle(s, Bind("auras.dispel.enabled", "auras", { label = "Highlight dispellable debuffs" }))
	W.Toggle(s, Bind("auras.dispel.onlyMine", "auras", { label = "Only debuffs I can dispel myself" }))
	W.Dropdown(s, Bind("auras.dispel.style", "auras", {
		label = "Style",
		items = { { value = "border", text = "Colored border" }, { value = "overlay", text = "Tint the whole frame" }, { value = "icon", text = "Small icon" } },
	}))
	W.Slider(s, Bind("auras.dispel.thickness", "auras", { label = "Border thickness", min = 1, max = 5, step = 1 }))
	for _, t in ipairs(ns.Auras.DISPEL_TYPES) do
		W.Color(s, Bind("auras.dispel.colors." .. t, "auras", { label = t }))
	end

	W.Header(s, "Debuffs")
	W.Toggle(s, Bind("auras.debuffs.enabled", "auras", { label = "Show debuff icons" }))
	W.Toggle(s, Bind("auras.debuffs.onlyDispellable", "auras", { label = "Only dispellable debuffs" }))
	W.Slider(s, Bind("auras.debuffs.max", "auras", { label = "How many", min = 1, max = 8, step = 1 }))
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
	W.Slider(s, Bind("auras.buffs.max", "auras", { label = "How many", min = 1, max = 8, step = 1 }))
	W.Slider(s, Bind("auras.buffs.size", "auras", { label = "Icon size", min = 8, max = 32, step = 1 }))
	W.Toggle(s, Bind("auras.buffs.swipe", "auras", { label = "Time left swipe" }))
	Pos(s, "auras.buffs", true)

	W.Header(s, "Boss debuff", "One big icon for the most important boss or role debuff.")
	W.Toggle(s, Bind("auras.boss.enabled", "auras", { label = "Show boss debuff" }))
	W.Slider(s, Bind("auras.boss.size", "auras", { label = "Icon size", min = 10, max = 40, step = 1 }))
	Pos(s, "auras.boss", false)

	W.Header(s, "Big defensives", "Shield Wall, Pain Suppression and similar.")
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

	for i = 1, #ns.db.auras.indicators do
		IndicatorEditor(s, i)
	end
end)
