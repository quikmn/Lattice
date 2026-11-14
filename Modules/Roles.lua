-- Lattice: who is the tank?
--
-- Most Forever groups have no assigned roles (UnitGroupRolesAssigned says
-- "NONE"), so Lattice guesses the tank from things it can see:
--   * the raid's main tank flag (and, weaker, main assist)
--   * Defensive Stance, Bear / Dire Bear Form, Righteous Fury
--   * in a group of exactly five: the single most likely player, or the only
--     Warrior when nothing else tells them apart
-- Assigned roles always win, and a per-player choice made by the user beats
-- everything (Ctrl+Alt+Right-click a frame, or /lattice tank <name>).
--
-- Everything is event driven. Aura reads only happen out of combat (they are
-- not allowed for addons in combat); the last result is kept meanwhile. The
-- player's own stance and a druid's rage bar still update in combat.
local _, ns = ...
local S = ns.Secret
local R = {}
ns.Roles = R

-- Points per signal. A non-assigned player needs STANCE points to count as a
-- tank in raids; in a 5-player group the single highest scorer wins.
R.SCORE = { mainTank = 60, stance = 40, mainAssist = 10 }

-- Tank auras and the class that has them.
R.TANK_AURAS = {
	[71]    = "WARRIOR", -- Defensive Stance
	[5487]  = "DRUID",   -- Bear Form
	[9634]  = "DRUID",   -- Dire Bear Form
	[25780] = "PALADIN", -- Righteous Fury
}
local TANK_CLASS = { WARRIOR = 3, DRUID = 2, PALADIN = 1 } -- tie-break order

R.tanks = {}            -- key (GUID) -> reason, for every player counted as a tank
local auraSeen = {}     -- key -> true/false from the last aura scan
local dirtyUnits = {}   -- unit -> true: rescan its auras when allowed
local allDirty = true
local pending = false

------------------------------------------------------------------------
-- Small readers (all guarded: values may be secret or APIs missing)
------------------------------------------------------------------------
local function Key(unit)
	local g = UnitGUID and S.Plain(UnitGUID(unit), nil)
	return g or unit
end
R.Key = Key

local function ClassOf(unit)
	local _, class = UnitClass(unit)
	return S.Plain(class, nil)
end

local function Assigned(unit)
	return S.Plain(UnitGroupRolesAssigned(unit), "NONE") or "NONE"
end

local function Flag(kind, unit)
	if not GetPartyAssignment then return false end
	local ok, v = pcall(GetPartyAssignment, kind, unit)
	return ok and S.Plain(v, false) and true or false
end

local function PowerToken(unit)
	local _, token = UnitPowerType(unit)
	return S.Plain(token, nil)
end

local function AurasReadable()
	if InCombatLockdown() then return false end
	if C_Secrets and C_Secrets.ShouldAurasBeSecret then
		local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
		if not ok or S.IsSecret(secret) or secret then return false end
	end
	return true
end
R.AurasReadable = AurasReadable

-- The player's own stance/form, readable in combat too.
local function PlayerForm()
	if not (GetShapeshiftForm and GetShapeshiftFormInfo) then return nil end
	local idx = GetShapeshiftForm()
	if not idx or idx == 0 then return false end
	local _, _, _, spellID = GetShapeshiftFormInfo(idx)
	return spellID and R.TANK_AURAS[spellID] ~= nil or false
end

-- true / false, or nil when this client can't tell.
local function HasTankAura(unit, class)
	if not C_UnitAuras then return nil end
	local byID = C_UnitAuras.GetUnitAuraBySpellID
	if byID then
		for id, c in pairs(R.TANK_AURAS) do
			if c == class then
				local ok, data = pcall(byID, unit, id)
				if ok and data then return true end
			end
		end
		return false
	end
	local byIndex = C_UnitAuras.GetAuraDataByIndex
	if not byIndex then return nil end
	for i = 1, 40 do
		local ok, data = pcall(byIndex, unit, i, "HELPFUL")
		if not ok or type(data) ~= "table" then break end
		local id = S.Plain(data.spellId, nil)
		if id and R.TANK_AURAS[id] == class then return true end
	end
	return false
end

------------------------------------------------------------------------
-- Per-player choices (saved account-wide, by GUID)
------------------------------------------------------------------------
local function Overrides()
	local sv = ns.Database and ns.Database.sv
	if not sv then return {} end
	sv.tankOverrides = sv.tankOverrides or {}
	return sv.tankOverrides
end

function R:Override(key)
	local o = key and Overrides()[key]
	return o and o.role or nil
end

-- value: "tank" | "notank" | nil (guess again)
function R:SetOverride(unit, value)
	local key = Key(unit)
	if not key then return false end
	if value == "tank" or value == "notank" then
		local name = S.Plain(UnitName(unit), nil)
		Overrides()[key] = { role = value, name = name }
	else
		Overrides()[key] = nil
	end
	self:Update()
	return true
end

------------------------------------------------------------------------
-- Decision (pure: tested offline)
------------------------------------------------------------------------
-- member = { key, class, assigned, override, mainTank, mainAssist, stance }
function R.Score(m)
	local s = 0
	if m.mainTank then s = s + R.SCORE.mainTank end
	if m.stance then s = s + R.SCORE.stance end
	if m.mainAssist then s = s + R.SCORE.mainAssist end
	return s
end

local function Reason(m)
	if m.mainTank then return "main tank" end
	if m.stance then return "stance or form" end
	if m.mainAssist then return "main assist" end
	return "guess"
end

-- Returns { [key] = reason } for every member counted as a tank.
function R.Decide(members, groupSize)
	local out, rest = {}, {}
	local known = false -- someone is already a tank by role or by the user's choice
	for _, m in ipairs(members) do
		if m.override == "tank" then
			out[m.key] = "set by you"; known = true
		elseif m.override == "notank" then
			-- never a tank
		elseif m.assigned == "TANK" then
			out[m.key] = "assigned role"; known = true
		elseif m.assigned ~= "HEALER" and m.assigned ~= "DAMAGER" then
			rest[#rest + 1] = m
		end
	end

	if groupSize == 5 then
		if known then return out end
		local best, bestScore, tie = nil, 0, false
		for _, m in ipairs(rest) do
			local s = R.Score(m)
			if s > bestScore then
				best, bestScore, tie = m, s, false
			elseif s == bestScore and s > 0 and best then
				local a, b = TANK_CLASS[m.class] or 0, TANK_CLASS[best.class] or 0
				if a > b then best = m; tie = false elseif a == b then tie = true end
			end
		end
		if best and bestScore >= R.SCORE.mainAssist and not tie then
			out[best.key] = Reason(best)
			return out
		end
		-- Nothing tells them apart: the only Warrior (plate) is the tank.
		local warrior, n = nil, 0
		for _, m in ipairs(rest) do
			if m.class == "WARRIOR" then warrior = m; n = n + 1 end
		end
		if n == 1 then out[warrior.key] = "only warrior" end
		return out
	end

	for _, m in ipairs(rest) do
		if R.Score(m) >= R.SCORE.stance then out[m.key] = Reason(m) end
	end
	return out
end

------------------------------------------------------------------------
-- Roster scan
------------------------------------------------------------------------
function R:Roster()
	local list = {}
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do list[#list + 1] = "raid" .. i end
	else
		list[1] = "player"
		local n = GetNumSubgroupMembers and GetNumSubgroupMembers() or math.max(0, GetNumGroupMembers() - 1)
		for i = 1, n do list[#list + 1] = "party" .. i end
	end
	return list
end

local function Member(unit, readable)
	local key, class = Key(unit), ClassOf(unit)
	local m = {
		key = key, unit = unit, class = class,
		assigned = Assigned(unit),
		override = R:Override(key),
		mainTank = Flag("MAINTANK", unit),
		mainAssist = Flag("MAINASSIST", unit),
	}
	if TANK_CLASS[class] then
		if readable and (allDirty or dirtyUnits[unit] or auraSeen[key] == nil) then
			auraSeen[key] = HasTankAura(unit, class) or false
		end
		local stance = auraSeen[key]
		if UnitIsUnit(unit, "player") then
			local form = PlayerForm()
			if form ~= nil and class ~= "PALADIN" then stance = form end
		end
		-- A druid on a rage bar is in Bear Form (works in combat too).
		if class == "DRUID" and PowerToken(unit) == "RAGE" then stance = true end
		m.stance = stance and true or false
	end
	return m
end

local function SameSet(a, b)
	for k, v in pairs(a) do if b[k] ~= v then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end

function R:Update()
	pending = false
	if not ns.db then return end
	local readable = AurasReadable()
	local members = {}
	for _, unit in ipairs(self:Roster()) do
		if UnitExists(unit) then members[#members + 1] = Member(unit, readable) end
	end
	if readable then
		allDirty = false
		wipe(dirtyUnits)
	end
	local result
	if ns.db.general.guessTank == false then
		-- Only roles and the user's own choices.
		for _, m in ipairs(members) do m.mainTank, m.mainAssist, m.stance = false, false, false end
		result = R.Decide(members, 0)
	else
		result = R.Decide(members, IsInGroup() and GetNumGroupMembers() or 1)
	end
	if not SameSet(result, self.tanks) then
		self.tanks = result
		ns:Fire("RolesChanged")
	end
end

function R:Schedule()
	if pending then return end
	pending = true
	C_Timer.After(0.25, function() R:Update() end)
end

------------------------------------------------------------------------
-- Lookups used by the frames
------------------------------------------------------------------------
-- Effective role for display: "TANK" | "HEALER" | "DAMAGER" | "NONE", plus true when guessed.
function R:Role(unit)
	if not unit then return "NONE" end
	local assigned = Assigned(unit)
	local key = Key(unit)
	local o = self:Override(key)
	if o == "tank" then return "TANK", assigned ~= "TANK" end
	if o == "notank" then return assigned == "TANK" and "NONE" or assigned end
	if assigned ~= "NONE" then return assigned end
	if self.tanks[key] then return "TANK", true end
	return "NONE"
end

function R:IsTank(unit)
	return (self:Role(unit)) == "TANK"
end

function R:Reason(unit)
	return self.tanks[Key(unit)]
end

-- Group unit from a name, "target", "mouseover" or a unit token.
function R:FindUnit(text)
	text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local probe = text ~= "" and text or "target"
	local roster = self:Roster()
	if UnitExists(probe) then
		for _, u in ipairs(roster) do
			if UnitIsUnit(u, probe) then return u end
		end
	end
	local lower = text:lower()
	if lower == "" then return nil end
	for _, u in ipairs(roster) do
		local name = S.Plain(UnitName(u), nil)
		if name and name:lower() == lower then return u end
	end
	return nil
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local function GroupUnit(unit)
	return unit == "player" or (unit and (unit:match("^party%d") or unit:match("^raid%d"))) and true or false
end

function R:Enable()
	local function full() allDirty = true; R:Schedule() end
	ns:RegisterEvent("GROUP_ROSTER_UPDATE", full)
	ns:RegisterEvent("PLAYER_ENTERING_WORLD", full)
	ns:RegisterEvent("PLAYER_ROLES_ASSIGNED", function() R:Schedule() end)
	ns:RegisterEvent("PLAYER_REGEN_ENABLED", function() R:Schedule() end)
	ns:RegisterEvent("UPDATE_SHAPESHIFT_FORM", function() dirtyUnits.player = true; R:Schedule() end)
	ns:RegisterEvent("UNIT_DISPLAYPOWER", function(_, unit)
		if GroupUnit(unit) and ClassOf(unit) == "DRUID" then R:Schedule() end
	end)
	ns:RegisterEvent("UNIT_AURA", function(_, unit)
		if not GroupUnit(unit) or not TANK_CLASS[ClassOf(unit)] then return end
		dirtyUnits[unit] = true
		-- In combat the auras can't be read anyway; PLAYER_REGEN_ENABLED picks this up.
		if not InCombatLockdown() then R:Schedule() end
	end)
	full()
end
