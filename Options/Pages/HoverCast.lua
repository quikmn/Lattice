local _, ns = ...
local W, O, U, T = ns.Widgets, ns.Options, ns.Util, ns.Theme
local HC, CC = ns.HoverCast, ns.ClickCast

local function rgba(c) return c[1], c[2], c[3], c[4] or 1 end

local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true }

-- A button that records the next key press (with modifiers) as a binding string.
local function KeyCapture(onKey)
	local b = W.Button(nil, "Click, then press a key", nil, 220)
	local capturing = false
	local function stop(text)
		capturing = false
		b:EnableKeyboard(false)
		b:SetScript("OnKeyDown", nil)
		b:SetText(text or "Click, then press a key")
	end
	b:SetScript("OnClick", function()
		if InCombatLockdown() then return end
		capturing = true
		b:SetText("|cffffd100Press a key (Esc cancels)|r")
		b:EnableKeyboard(true)
		b:SetPropagateKeyboardInput(false)
		b:SetScript("OnKeyDown", function(_, key)
			if not capturing or MODIFIER_KEYS[key] then return end
			if key == "ESCAPE" then stop() return end
			local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
				.. (IsShiftKeyDown() and "SHIFT-" or "") .. key
			stop(HC.Describe(combo))
			onKey(combo)
		end)
	end)
	b:SetScript("OnHide", function() if capturing then stop() end end)
	return b
end

O:RegisterPage("hovercast", "Hover-casting", nil, function(s)
	W.Header(s, "Hover-casting", "Press a key to cast on whoever your mouse is over: a Lattice frame, another unit frame, or the player in the world. Saved per character.")
	W.Note(s, "For each key you choose who the spell is for (a friend, an enemy or either) and what happens when nobody fitting is under the mouse: use your target, use yourself, or do nothing. The key no longer does what it did before while it's bound here, so pick keys you don't need for anything else.")
	if InCombatLockdown() then
		W.Note(s, "|cffffcc66You're in combat. Changes apply when combat ends.|r")
	end

	local list = HC:List()
	if #list == 0 then W.Note(s, "No hover-cast keys yet. Add one below.") end
	for i, h in ipairs(list) do
		local row = CreateFrame("Frame")
		local bg = U.Solid(row, "BACKGROUND", rgba(T.surface))
		bg:SetAllPoints()
		local keyText = W.Text(row, T.font, T.accent)
		keyText:SetPoint("LEFT", 10, 0)
		keyText:SetWidth(120)
		keyText:SetWordWrap(false)
		keyText:SetText(HC.Describe(h.key))
		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetSize(18, 18)
		icon:SetPoint("LEFT", 134, 0)
		icon:SetTexture(h.action == "spell" and CC.SpellIcon(h.value) or "Interface\\Icons\\INV_Misc_QuestionMark")
		icon:SetShown(h.action == "spell")
		local what = W.Text(row, T.font, T.text)
		what:SetPoint("LEFT", 158, 0)
		what:SetPoint("RIGHT", -90, 0)
		what:SetWordWrap(false)
		local desc = h.action == "spell" and (CC.SpellName(h.value) or ("Spell #" .. tostring(h.value))) or "Macro"
		if h.action == "spell" then
			local chain = { (h.side == "harm" and "enemy" or h.side == "any" and "anyone" or "friend") .. " under the mouse" }
			if h.fallback ~= false then chain[#chain + 1] = "target" end
			if h.self and h.side ~= "harm" then chain[#chain + 1] = "you" end
			desc = desc .. "  |cff888888(" .. table.concat(chain, ", then ") .. ")|r"
		end
		what:SetText(desc)
		local del = W.Button(row, "Remove", function()
			HC:Remove(i)
			O:RebuildPage("hovercast")
		end, 76, "danger")
		del:SetHeight(22)
		del:SetPoint("RIGHT", -6, 0)
		s:Add(row, 32, 4)
	end

	W.Header(s, "Add a hover-cast key")
	local draft = { key = nil, action = "spell", value = nil, fallback = true, side = "help", self = false, macro = "" }

	local keyRow = CreateFrame("Frame")
	local keyLabel = W.Text(keyRow, T.font, T.text)
	keyLabel:SetPoint("TOPLEFT")
	keyLabel:SetText("Key")
	local capture = KeyCapture(function(combo) draft.key = combo end)
	capture:SetParent(keyRow)
	capture:SetPoint("TOPLEFT", 0, -18)
	s:Add(keyRow, 46)

	W.Dropdown(s, { label = "Who it's for",
		desc = "Friend for heals and buffs, enemy for damage, either for spells that do both (Penance, Dispel Magic).",
		items = { { value = "help", text = "A friend" }, { value = "harm", text = "An enemy" }, { value = "any", text = "Friend or enemy" } },
		get = function() return draft.side end,
		set = function(v)
			draft.side = v
			-- a spell picked for the other side (a heal on an enemy key) would never cast: clear it
			if draft.value and v ~= "any" then
				local fits = false
				for _, it in ipairs(O.SpellbookSpells(v)) do
					if it.value == draft.value then fits = true break end
				end
				if not fits then draft.value = nil end
			end
			s:RefreshAll()
		end })
	W.Dropdown(s, { label = "Spell (from your spellbook)", items = function() return O.SpellbookSpells(draft.side) end, width = 300,
		format = CC.SpellName,
		get = function() return draft.value end,
		set = function(v) draft.value = v; draft.action = "spell" end })

	local feedback -- the line under the add button (made below)
	local spellRow = CreateFrame("Frame")
	local spellLabel = W.Text(spellRow, T.font, T.text)
	spellLabel:SetPoint("TOPLEFT")
	spellLabel:SetText("...or type a spell name or ID and press Enter")
	local spellBox = W.EditBox(spellRow, 300, 24)
	spellBox:SetPoint("TOPLEFT", 0, -18)
	spellBox:SetScript("OnEnterPressed", function(self)
		local ids = ns.Auras:ResolveSpells(self:GetText())
		if ids[1] then
			draft.value = ids[#ids]
			draft.action = "spell"
			feedback.text:SetText(" ")
			s:RefreshAll()
		else
			feedback.text:SetText("|cffff7070No spell found. Type a spell you know, like Flash Heal, or its ID, like 2061.|r")
		end
		self:ClearFocus()
	end)
	s:Add(spellRow, 44)

	W.Toggle(s, { label = "If nobody fitting is under the mouse, cast on my target",
		get = function() return draft.fallback end, set = function(v) draft.fallback = v end })
	W.Toggle(s, { label = "If there's still nobody, cast on me (friendly spells only)",
		disabled = function() return draft.side == "harm" end,
		get = function() return draft.self and draft.side ~= "harm" end, set = function(v) draft.self = v end })

	local add = W.Button(nil, "Add hover-cast key", function()
		if not draft.key then
			feedback.text:SetText("|cffff7070Click the key box and press a key first.|r")
			return
		end
		if not draft.value then
			feedback.text:SetText("|cffff7070Pick or type a spell first.|r")
			return
		end
		HC:Add({ key = draft.key, action = "spell", value = draft.value, fallback = draft.fallback, side = draft.side,
			self = draft.self and draft.side ~= "harm" })
		O:RebuildPage("hovercast")
	end, 170, "accent")
	s:Add(add, 26)
	feedback = W.Note(s, " ")
end)
