-- Lattice: keyboard hover-casting.
--
-- Bind a key (with modifiers) to a spell. Pressing it casts on whatever friendly
-- unit is under the mouse: a Lattice frame, a Blizzard frame or the character
-- in the world. Optionally it falls back to the current friendly target. It
-- never falls back to yourself.
--
-- How: each binding is a hidden SecureActionButton running a /cast macro with
-- [@mouseover,help,nodead] conditionals, and the key is pointed at it with an
-- override binding. Both are set out of combat and keep working in combat; no
-- restricted snippets are needed.
--
-- Stored per character in ns.char.hover as
--   { key = "SHIFT-1", action = "spell" | "macro", value = spellID | macro text, fallback = true }
local _, ns = ...
local HC = {}
ns.HoverCast = HC

local owner = CreateFrame("Frame", "LatticeHoverCastOwner", UIParent)
HC.buttons = {}

local function Button(i)
	local b = HC.buttons[i]
	if not b then
		b = CreateFrame("Button", "LatticeHoverCast" .. i, UIParent, "SecureActionButtonTemplate")
		b:RegisterForClicks("AnyDown", "AnyUp")
		b:SetSize(1, 1)
		b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100) -- off screen, never clickable by mouse
		HC.buttons[i] = b
	end
	return b
end

function HC.MacroText(h)
	if h.action == "macro" then return h.value or "" end
	local name = ns.ClickCast.SpellName(h.value) or tostring(h.value)
	local cond = "[@mouseover,help,nodead]"
	if h.fallback ~= false then cond = cond .. "[help,nodead]" end
	return "/cast " .. cond .. " " .. name
end

-- Key strings use WoW's binding format: modifiers in ALT-CTRL-SHIFT order.
function HC.NormalizeKey(key)
	if not key or key == "" then return nil end
	local mods, base = {}, key
	local up = key:upper()
	for _, m in ipairs({ "ALT", "CTRL", "SHIFT" }) do
		if up:find("%f[%w]" .. m .. "%-") then mods[#mods + 1] = m end
	end
	base = up:gsub("ALT%-", ""):gsub("CTRL%-", ""):gsub("SHIFT%-", "")
	if base == "" then return nil end
	mods[#mods + 1] = base
	return table.concat(mods, "-")
end

function HC.Describe(key)
	return (key or "?"):gsub("%-", " + "):gsub("CTRL", "Ctrl"):gsub("SHIFT", "Shift"):gsub("ALT", "Alt")
end

function HC:List()
	ns.char.hover = ns.char.hover or {}
	return ns.char.hover
end

function HC:ApplyAll()
	ns:RunOutOfCombat("hovercast-apply", function()
		ClearOverrideBindings(owner)
		local list = self:List()
		for i, h in ipairs(list) do
			local b = Button(i)
			b:SetAttribute("type", "macro")
			b:SetAttribute("macrotext", HC.MacroText(h))
			if h.key then
				SetOverrideBindingClick(owner, true, h.key, b:GetName(), "LeftButton")
			end
		end
		for i = #list + 1, #self.buttons do
			self.buttons[i]:SetAttribute("type", nil)
			self.buttons[i]:SetAttribute("macrotext", nil)
		end
	end)
end

function HC:Find(key)
	for i, h in ipairs(self:List()) do
		if h.key == key then return i end
	end
end

function HC:Add(h)
	h.key = HC.NormalizeKey(h.key)
	if not h.key then return false end
	local list = self:List()
	local i = self:Find(h.key)
	if i then list[i] = h else list[#list + 1] = h end
	table.sort(list, function(a, b) return a.key < b.key end)
	self:ApplyAll()
	return true
end

function HC:Remove(index)
	table.remove(self:List(), index)
	self:ApplyAll()
end

-- Spell names change rank-to-rank and load late; rebuild when spells change.
ns:RegisterEvent("PLAYER_LOGIN", function()
	HC:ApplyAll()
	ns:RegisterEvent("SPELLS_CHANGED", function() HC:ApplyAll() end)
end)
