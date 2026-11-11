local _, ns = ...
local W, O, U, T = ns.Widgets, ns.Options, ns.Util, ns.Theme
local CC = ns.ClickCast

local function rgba(c) return c[1], c[2], c[3], c[4] or 1 end

-- Helpful, non-passive spells in the player's spellbook (highest rank per name).
local function HelpfulSpells()
	local out, seen = {}, {}
	if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return out end
	local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
	for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
		if info then
			for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
				local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
				if item and item.spellID and item.name and not item.isPassive and not seen[item.name] then
					local helpful = C_SpellBook.IsSpellBookItemHelpful and C_SpellBook.IsSpellBookItemHelpful(slot, bank)
					if helpful then
						seen[item.name] = true
						out[#out + 1] = { value = item.spellID, text = item.name }
					end
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.text < b.text end)
	if #out > 30 then for i = #out, 31, -1 do out[i] = nil end end
	return out
end

O.HelpfulSpells = HelpfulSpells

local MOD_ITEMS = {
	{ value = "", text = "No modifier" }, { value = "shift", text = "Shift" }, { value = "ctrl", text = "Ctrl" },
	{ value = "alt", text = "Alt" }, { value = "ctrl-shift", text = "Ctrl + Shift" }, { value = "alt-shift", text = "Alt + Shift" },
	{ value = "alt-ctrl", text = "Alt + Ctrl" },
}

O:RegisterPage("clickcast", "Click-casting", nil, function(s)
	W.Header(s, "Click-casting", "Click a frame to cast on that player. Bindings are saved per character.")
	if InCombatLockdown() then
		W.Note(s, "|cffffcc66You're in combat. Changes apply when combat ends.|r")
	end

	-- Current bindings
	local list = ns.char.bindings
	if #list == 0 then
		W.Note(s, "No bindings yet. Add one below.")
	end
	for i, b in ipairs(list) do
		local row = CreateFrame("Frame")
		local bg = U.Solid(row, "BACKGROUND", rgba(T.surface))
		bg:SetAllPoints()
		local key = W.Text(row, T.font, T.accent)
		key:SetPoint("LEFT", 10, 0)
		key:SetWidth(170)
		key:SetWordWrap(false)
		key:SetText(CC.Describe(b))
		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetSize(18, 18)
		icon:SetPoint("LEFT", 186, 0)
		local tex = b.action == "spell" and CC.SpellIcon(b.value)
		icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
		icon:SetShown(b.action == "spell")
		local what = W.Text(row, T.font, T.text)
		what:SetPoint("LEFT", 210, 0)
		what:SetPoint("RIGHT", -90, 0)
		what:SetWordWrap(false)
		what:SetText(CC.DescribeAction(b))
		local del = W.Button(row, "Remove", function()
			CC:Remove(i)
			O:RebuildPage("clickcast")
		end, 76, "danger")
		del:SetHeight(22)
		del:SetPoint("RIGHT", -6, 0)
		s:Add(row, 32, 4)
	end

	-- Add form
	W.Header(s, "Add a binding")
	local draft = { button = 1, mods = "", action = "spell", value = nil, macro = "" }

	W.Dropdown(s, { label = "Mouse button", items = CC.BUTTONS,
		get = function() return draft.button end, set = function(v) draft.button = v end })
	W.Dropdown(s, { label = "Modifier", items = MOD_ITEMS,
		get = function() return draft.mods end, set = function(v) draft.mods = v end })
	W.Dropdown(s, { label = "Action", items = CC.ACTIONS,
		get = function() return draft.action end, set = function(v) draft.action = v end })

	W.Dropdown(s, { label = "Spell (from your spellbook)", items = HelpfulSpells, width = 300,
		get = function() return draft.value end,
		set = function(v) draft.value = v; draft.action = "spell"; s:RefreshAll() end })

	local spellRow = CreateFrame("Frame")
	local spellLabel = W.Text(spellRow, T.font, T.text)
	spellLabel:SetPoint("TOPLEFT")
	spellLabel:SetText("...or type a spell name or ID")
	local spellBox = W.EditBox(spellRow, 300, 24)
	spellBox:SetPoint("TOPLEFT", 0, -18)
	spellBox:SetScript("OnEnterPressed", function(self)
		local ids = ns.Auras:ResolveSpells(self:GetText())
		if ids[1] then
			draft.value = ids[#ids] -- last match is usually the highest rank
			draft.action = "spell"
			s:RefreshAll()
		end
		self:ClearFocus()
	end)
	s:Add(spellRow, 44)

	local macroRow = CreateFrame("Frame")
	local macroLabel = W.Text(macroRow, T.font, T.text)
	macroLabel:SetPoint("TOPLEFT")
	macroLabel:SetText("Macro text (for 'Run macro'; use @mouseover to target the frame)")
	local macro = W.TextArea(macroRow, 420, 60)
	macro:SetPoint("TOPLEFT", 0, -18)
	macro.box:SetScript("OnTextChanged", function(self) draft.macro = self:GetText() end)
	s:Add(macroRow, 82)

	local feedback
	local addBtn = W.Button(nil, "Add binding", function()
		local binding = { button = draft.button, mods = draft.mods, action = draft.action }
		if draft.action == "spell" then
			if not draft.value then
				feedback.text:SetText("|cffff7070Pick or type a spell first.|r")
				return
			end
			binding.value = draft.value
		elseif draft.action == "macro" then
			if (draft.macro or "") == "" then
				feedback.text:SetText("|cffff7070Write the macro text first.|r")
				return
			end
			binding.value = draft.macro
		end
		CC:Add(binding)
		O:RebuildPage("clickcast")
	end, 140, "accent")
	s:Add(addBtn, 26)
	feedback = W.Note(s, " ")
	W.Note(s, "Adding a binding to a button and modifier that's already used replaces the old one.")
end)
