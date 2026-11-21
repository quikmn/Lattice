-- Lattice: saved variables layout.
--
-- LatticeDB = {
--   schema   = 1,
--   profiles = { [name] = <profile, stored without default values> },
--   chars    = { ["Name-Realm"] = { profile = "Default", specProfiles = { [specIndex] = name },
--                                    bindings = { <click-cast bindings> } } },
--   tankOverrides = { [playerGUID] = { role = "tank" | "notank", name = "Name" } },
-- }
--
-- At runtime ns.db is the active profile with defaults filled in;
-- ns.char is the per-character table (click-cast bindings live there,
-- because spells differ per class).
local _, ns = ...
local U = ns.Util
local DB = {}
ns.Database = DB

local SCHEMA = 4
DB.DEFAULT_PROFILE = "Default"
DB.SCHEMA = SCHEMA

-- Saved-variable upgrades. MIGRATIONS[n] turns schema n-1 data into schema n.
-- Profiles only store values that differ from the defaults, so changing a
-- default changes it for every profile that never set it; to keep the old
-- behaviour for existing players, a migration writes the old value in.
local MIGRATIONS = {
	[2] = function(sv)
		-- 0.2.0: hover-cast keys are stored per character.
		for _, char in pairs(sv.chars or {}) do
			char.hover = char.hover or {}
		end
	end,
	[3] = function(sv)
		-- 0.4.0: per-player tank choices (account-wide).
		sv.tankOverrides = sv.tankOverrides or {}
	end,
	[4] = function(sv)
		-- after 0.7.2: new hover-cast keys "cast on me" by default. Profiles saved before keep it off, as it was.
		for _, p in pairs(sv.profiles or {}) do
			if type(p) == "table" then
				if type(p.general) ~= "table" then p.general = {} end
				if p.general.hoverCastSelf == nil then p.general.hoverCastSelf = false end
			end
		end
	end,
}
DB.MIGRATIONS = MIGRATIONS

function DB:Migrate(sv)
	local from = sv.schema or SCHEMA
	for v = from + 1, SCHEMA do
		local fn = MIGRATIONS[v]
		if fn then
			local ok, err = pcall(fn, sv)
			if not ok then
				ns:Print("Settings upgrade to version " .. v .. " failed: " .. tostring(err))
				break
			end
		end
		sv.schema = v
	end
	sv.schema = math.max(sv.schema or SCHEMA, from)
end

-- "Name-Second": UnitFullName's second value (the realm, or on WoW Forever with regional unique names the surname; the
-- key is the same as it always was there). When the game gives no second value: the realm's name, else the realm ID
-- from the GUID ("Name-realm:6946"), never "Name-" (GetRealmName() returns "" since client build 71037).
function DB:CharKey(sv)
	local R = ns.Realm
	local name, second = UnitFullName("player")
	name = R.text(name) or R.text(UnitName("player")) or "?"
	second = R.text(second)
	if second then second = second:gsub("%s", "") end
	if not second then
		if sv and type(sv.realmNames) ~= "table" then sv.realmNames = {} end
		local key = R.read(sv and sv.realmNames)
		second = key and (key:gsub("%s", "")) or "?"
	end
	return name .. "-" .. second, name
end

-- A character saved as "Name-" (the realm left out while the game said nothing) is this character when no other
-- "Name-..." is saved; else it is left as it is and /lattice status says so. Returns the old key left, or nil.
function DB:AdoptNameless(sv, key, name)
	local old = name .. "-"
	if key == old or type(sv.chars[old]) ~= "table" then return nil end
	if sv.chars[key] then return old end
	for k in pairs(sv.chars) do
		if k ~= old and k:sub(1, #old) == old then return old end
	end
	sv.chars[key], sv.chars[old] = sv.chars[old], nil
	return nil
end

function DB:Initialize()
	LatticeDB = LatticeDB or {}
	local sv = LatticeDB
	local fresh = sv.schema == nil and sv.profiles == nil
	sv.profiles = sv.profiles or {}
	sv.chars = sv.chars or {}
	sv.tankOverrides = sv.tankOverrides or {}
	if fresh then sv.schema = SCHEMA end
	sv.schema = sv.schema or 1
	self:Migrate(sv)

	local key, name = self:CharKey(sv)
	DB.namelessLeft = self:AdoptNameless(sv, key, name)
	sv.chars[key] = sv.chars[key] or {}
	local char = sv.chars[key]
	char.profile = char.profile or DB.DEFAULT_PROFILE
	char.specProfiles = char.specProfiles or {}
	char.bindings = char.bindings or U.CopyTable(ns.DefaultBindings())
	char.hover = char.hover or {}

	if not sv.profiles[char.profile] then
		sv.profiles[char.profile] = {}
	end

	self.sv = sv
	ns.char = char
	self:Activate(char.profile)

	-- Strip defaults on logout so SavedVariables only contain real changes.
	ns:RegisterEvent("PLAYER_LOGOUT", function()
		for _, p in pairs(sv.profiles) do
			U.StripDefaults(p, ns.Defaults)
		end
	end)
end

function DB:Activate(name)
	local p = self.sv.profiles[name]
	if not p then return false end
	U.FillDefaults(p, ns.Defaults)
	ns.db = p
	ns.char.profile = name
	return true
end

function DB:ActiveName()
	return ns.char and ns.char.profile
end
