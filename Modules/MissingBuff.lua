-- Lattice: marks players who are missing your class's long buff (a priest's Fortitude, a mage's Arcane Intellect, a
-- druid's Mark of the Wild): that buff's icon with a red edge in the frame's bottom-right corner.
-- Other players' auras can only be read out of combat on Forever, so the marks are worked out then and kept in combat.
local _, ns = ...
local MB = {}
ns.MissingBuff = MB
local S = ns.Secret

-- per class: the spell you cast (you must know it), which buff family counts, and whether only mana users need it
MB.BUFFS = {
	PRIEST = { cast = "Power Word: Fortitude", family = "fortitude" },
	MAGE   = { cast = "Arcane Intellect", family = "intellect", manaOnly = true },
	DRUID  = { cast = "Mark of the Wild", family = "wild" },
}

local mine -- { set, list, icon, manaOnly }, or false: your class has no such buff or you don't know it yet
local function Mine()
	if mine ~= nil then return mine end
	mine = false
	local _, class = UnitClass("player")
	local def = MB.BUFFS[class]
	local list = def and ns.Auras.BUFF_FAMILIES[def.family]
	if list then
		local known = ns.Auras:ResolveSpells(def.cast, true)
		if #known > 0 then
			local set = {}
			for _, id in ipairs(list) do set[id] = true end
			local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(known[1])
			mine = { set = set, list = list, icon = icon, manaOnly = def.manaOnly }
		end
	end
	return mine
end
MB.Mine = Mine

-- true / false, or nil when this client can't tell
function MB.HasBuff(unit, m)
	local byID = C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID
	if byID then
		for _, id in ipairs(m.list) do
			local ok, data = pcall(byID, unit, id)
			if ok and data ~= nil and not S.IsSecret(data) then return true end
		end
		return false
	end
	local byIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	if not byIndex then return nil end
	for i = 1, 40 do
		local ok, data = pcall(byIndex, unit, i, "HELPFUL")
		if not ok or type(data) ~= "table" then break end
		local id = S.Plain(data.spellId, nil)
		if id and m.set[id] then return true end
	end
	return false
end

local function Marker(btn)
	local v = btn.visual
	if v.missing then return v.missing end
	local f = CreateFrame("Frame", nil, v.over)
	f:SetSize(12, 12)
	f:SetPoint("BOTTOMRIGHT", v.health, "BOTTOMRIGHT", -2, 2)
	local edge = f:CreateTexture(nil, "BACKGROUND")
	edge:SetAllPoints()
	edge:SetColorTexture(0.9, 0.15, 0.15, 1)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetPoint("TOPLEFT", 1, -1)
	f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f:Hide()
	v.missing = f
	return f
end

function MB:Update(btn)
	if btn.fake or btn.tankTarget or not btn.visual then return end
	local m = ns.db.auras.missingBuff ~= false and Mine()
	local f = btn.visual.missing or (m and Marker(btn))
	if not f then return end
	local unit = btn.unit
	if not m or not unit or not UnitExists(unit) then f:Hide(); f.unit = nil; return end
	if not ns.Roles.AurasReadable() then
		-- in combat: keep the last answer, unless the button now shows someone else
		if f.unit ~= unit then f:Hide() end
		return
	end
	f.unit = unit
	local show = false
	if UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) and (not UnitIsVisible or UnitIsVisible(unit)) then
		local _, token = UnitPowerType(unit)
		if not m.manaOnly or S.Plain(token, nil) == "MANA" then
			show = MB.HasBuff(unit, m) == false
		end
	end
	if show then f.icon:SetTexture(m.icon) end
	f:SetShown(show)
end

function MB:UpdateAll()
	if not ns.Buttons then return end
	for _, btn in ipairs(ns.Buttons.all) do
		if btn.unit and btn:IsVisible() then self:Update(btn) end
	end
end

local function GroupUnit(unit)
	return unit == "player" or (unit and (unit:match("^party%d") or unit:match("^raid%d"))) and true or false
end

ns:RegisterEvent("UNIT_AURA", function(_, unit)
	if not GroupUnit(unit) or InCombatLockdown() or not ns.Buttons then return end
	local set = ns.Buttons.byUnit[unit]
	if not set then return end
	for btn in pairs(set) do
		if btn.unit == unit then MB:Update(btn) end
	end
end)
ns:RegisterEvent("PLAYER_REGEN_ENABLED", function() MB:UpdateAll() end)
ns:RegisterEvent("SPELLS_CHANGED", function()
	local had = mine
	mine = nil
	if had ~= Mine() and not (had and Mine()) then MB:UpdateAll() end
end)
