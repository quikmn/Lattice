-- Lattice: click-casting via secure unit button attributes.
--
-- Bindings are stored per character (ns.char.bindings) as a list of
--   { button = 1..5, mods = "" | "shift" | "ctrl" | "alt" | "alt-ctrl" | ..., action = ACTION, value = ... }
-- ACTION: "target" | "menu" | "focus" | "assist" | "spell" (value = spellID) | "macro" (value = macro text)
--
-- Attributes use the secure template's modifier prefix format, always in
-- the order alt-ctrl-shift (that's how SecureButton_GetModifierPrefix builds it):
--   ["shift-type1"] = "spell", ["shift-spell1"] = 2061
local _, ns = ...
local CC = {}
ns.ClickCast = CC

CC.ACTIONS = {
	{ value = "target", text = "Target unit" },
	{ value = "menu",   text = "Open unit menu" },
	{ value = "spell",  text = "Cast spell" },
	{ value = "macro",  text = "Run macro" },
	{ value = "focus",  text = "Set focus" },
	{ value = "assist", text = "Assist" },
}

CC.BUTTONS = {
	{ value = 1, text = "Left click" },
	{ value = 2, text = "Right click" },
	{ value = 3, text = "Middle click" },
	{ value = 4, text = "Mouse button 4" },
	{ value = 5, text = "Mouse button 5" },
}

CC.MODS = { "", "shift", "ctrl", "alt", "ctrl-shift", "alt-shift", "alt-ctrl", "alt-ctrl-shift" }

function ns.DefaultBindings()
	return {
		{ button = 1, mods = "", action = "target" },
		{ button = 2, mods = "", action = "menu" },
	}
end

-- Normalise any user/old modifier string into canonical alt-ctrl-shift order.
function CC.NormalizeMods(mods)
	mods = (mods or ""):lower()
	local out = {}
	if mods:find("alt") then out[#out + 1] = "alt" end
	if mods:find("ctrl") then out[#out + 1] = "ctrl" end
	if mods:find("shift") then out[#out + 1] = "shift" end
	return table.concat(out, "-")
end

function CC.Describe(b)
	local parts = {}
	for m in (b.mods or ""):gmatch("[^-]+") do
		parts[#parts + 1] = m:sub(1, 1):upper() .. m:sub(2)
	end
	local btn = CC.BUTTONS[b.button] and CC.BUTTONS[b.button].text or ("Button " .. tostring(b.button))
	parts[#parts + 1] = btn
	return table.concat(parts, " + ")
end

function CC.SpellName(id)
	if not id then return nil end
	if C_Spell and C_Spell.GetSpellName then
		local n = C_Spell.GetSpellName(id)
		if n then return n end
	end
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(id)
		if info then return info.name end
	end
	return nil
end

function CC.SpellIcon(id)
	if not id then return nil end
	if C_Spell and C_Spell.GetSpellTexture then
		return C_Spell.GetSpellTexture(id)
	end
end

function CC.DescribeAction(b)
	if b.action == "spell" then
		return CC.SpellName(b.value) or ("Spell #" .. tostring(b.value))
	elseif b.action == "macro" then
		local first = (b.value or ""):match("[^\n]+") or ""
		return "Macro: " .. first
	end
	for _, a in ipairs(CC.ACTIONS) do
		if a.value == b.action then return a.text end
	end
	return b.action
end

local function Prefix(mods)
	mods = CC.NormalizeMods(mods)
	return mods ~= "" and (mods .. "-") or ""
end

-- Every attribute name we might have set, so re-applying wipes old bindings.
local ALL_ATTRS = {}
do
	for _, m in ipairs(CC.MODS) do
		local p = m ~= "" and (m .. "-") or ""
		for b = 1, 5 do
			for _, k in ipairs({ "type", "spell", "macrotext", "macro" }) do
				ALL_ATTRS[#ALL_ATTRS + 1] = p .. k .. b
			end
		end
	end
end

-- Apply bindings to one secure unit button. Caller guarantees no combat lockdown.
function CC:ApplyTo(button)
	for i = 1, #ALL_ATTRS do
		button:SetAttribute(ALL_ATTRS[i], nil)
	end
	for _, b in ipairs(ns.char.bindings) do
		local p, n = Prefix(b.mods), b.button
		if b.action == "target" then
			button:SetAttribute(p .. "type" .. n, "target")
		elseif b.action == "menu" then
			button:SetAttribute(p .. "type" .. n, "togglemenu")
		elseif b.action == "focus" then
			button:SetAttribute(p .. "type" .. n, "focus")
		elseif b.action == "assist" then
			button:SetAttribute(p .. "type" .. n, "assist")
		elseif b.action == "spell" and b.value then
			-- Cast by name so the highest known rank is used; fall back to the ID.
			button:SetAttribute(p .. "type" .. n, "spell")
			button:SetAttribute(p .. "spell" .. n, CC.SpellName(b.value) or b.value)
		elseif b.action == "macro" and b.value and b.value ~= "" then
			button:SetAttribute(p .. "type" .. n, "macro")
			button:SetAttribute(p .. "macrotext" .. n, b.value)
		end
	end
end

function CC:ApplyAll()
	ns:RunOutOfCombat("clickcast-apply", function()
		for _, button in ipairs(ns.Buttons.all) do
			self:ApplyTo(button)
		end
	end)
end

-- Validation used by the options page.
function CC:FindConflict(button, mods, ignoreIndex)
	mods = CC.NormalizeMods(mods)
	for i, b in ipairs(ns.char.bindings) do
		if i ~= ignoreIndex and b.button == button and CC.NormalizeMods(b.mods) == mods then
			return i
		end
	end
end

function CC:Add(binding)
	binding.mods = CC.NormalizeMods(binding.mods)
	local existing = self:FindConflict(binding.button, binding.mods)
	if existing then
		ns.char.bindings[existing] = binding
	else
		table.insert(ns.char.bindings, binding)
	end
	self:Sort()
	self:ApplyAll()
end

function CC:Remove(index)
	table.remove(ns.char.bindings, index)
	self:ApplyAll()
end

function CC:Sort()
	local order = {}
	for i, m in ipairs(CC.MODS) do order[m] = i end
	table.sort(ns.char.bindings, function(a, b)
		local ma, mb = order[a.mods] or 99, order[b.mods] or 99
		if ma ~= mb then return ma < mb end
		return a.button < b.button
	end)
end
