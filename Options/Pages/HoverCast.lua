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
	W.Note(s, "It never casts on you by accident. If nobody friendly is under the mouse it uses your friendly target (if you allow it below), otherwise it does nothing. The key no longer does what it did before while it's bound here, so pick keys you don't need for anything else.")
	if InCombatLockdown() then
		W.Note(s, "|cffffcc66You're in combat. Changes apply when combat ends.|r")
	end

	local list = HC:List()
	if #list == 0 then W.Note(s, "No hover-cast keys yet. Add one below.") end
	for i, h in ipairs(list) do
		local row = CreateFrame("Frame")
		local bg = U.Solid(row, "BACKGROUND", rgba(T.surface))
		bg:SetAllPoints()
		local key = W.Text(row, T.font, T.accent)
		key:SetPoint("LEFT", 10, 0)
		key:SetWidth(120)
		key:SetWordWrap(false)
		key:SetText(HC.Describe(h.key))
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
			desc = desc .. (h.fallback ~= false and "  |cff888888(mouseover, then target)|r" or "  |cff888888(mouseover only)|r")
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
	local draft = { key = nil, action = "spell", value = nil, fallback = true, macro = "" }

	local keyRow = CreateFrame("Frame")
	local keyLabel = W.Text(keyRow, T.font, T.text)
	keyLabel:SetPoint("TOPLEFT")
	keyLabel:SetText("Key")
	local capture = KeyCapture(function(combo) draft.key = combo end)
	capture:SetParent(keyRow)
	capture:SetPoint("TOPLEFT", 0, -18)
	s:Add(keyRow, 46)

	W.Dropdown(s, { label = "Spell (from your spellbook)", items = O.HelpfulSpells, width = 300,
		get = function() return draft.value end,
		set = function(v) draft.value = v; draft.action = "spell" end })

	local spellRow = CreateFrame("Frame")
	local spellLabel = W.Text(spellRow, T.font, T.text)
	spellLabel:SetPoint("TOPLEFT")
	spellLabel:SetText("...or type a spell name or ID")
	local spellBox = W.EditBox(spellRow, 300, 24)
	spellBox:SetPoint("TOPLEFT", 0, -18)
	spellBox:SetScript("OnEnterPressed", function(self)
		local ids = ns.Auras:ResolveSpells(self:GetText())
		if ids[1] then
			draft.value = ids[#ids]
			draft.action = "spell"
			s:RefreshAll()
		end
		self:ClearFocus()
	end)
	s:Add(spellRow, 44)

	W.Toggle(s, { label = "If nobody is under the mouse, cast on my friendly target",
		get = function() return draft.fallback end, set = function(v) draft.fallback = v end })

	local feedback
	local add = W.Button(nil, "Add hover-cast key", function()
		if not draft.key then
			feedback.text:SetText("|cffff7070Click the key box and press a key first.|r")
			return
		end
		if not draft.value then
			feedback.text:SetText("|cffff7070Pick or type a spell first.|r")
			return
		end
		HC:Add({ key = draft.key, action = "spell", value = draft.value, fallback = draft.fallback })
		O:RebuildPage("hovercast")
	end, 170, "accent")
	s:Add(add, 26)
	feedback = W.Note(s, " ")
end)
