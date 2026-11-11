-- Lattice: saved variables layout.
--
-- LatticeDB = {
--   schema   = 1,
--   profiles = { [name] = <profile, stored without default values> },
--   chars    = { ["Name-Realm"] = { profile = "Default", specProfiles = { [specIndex] = name },
--                                    bindings = { <click-cast bindings> } } },
-- }
--
-- At runtime ns.db is the active profile with defaults filled in;
-- ns.char is the per-character table (click-cast bindings live there,
-- because spells differ per class).
local _, ns = ...
local U = ns.Util
local DB = {}
ns.Database = DB

local SCHEMA = 2
DB.DEFAULT_PROFILE = "Default"
DB.SCHEMA = SCHEMA

-- Saved-variable upgrades. MIGRATIONS[n] turns schema n-1 data into schema n.
-- Profiles only store values that differ from the defaults, so changing a
-- default needs no migration; renaming or reshaping a setting does.
local MIGRATIONS = {
	[2] = function(sv)
		-- 0.2.0: hover-cast keys are stored per character.
		for _, char in pairs(sv.chars or {}) do
			char.hover = char.hover or {}
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

function DB:CharKey()
	local name, realm = UnitFullName("player")
	realm = realm or GetRealmName() or "?"
	return (name or "?") .. "-" .. realm:gsub("%s", "")
end

function DB:Initialize()
	LatticeDB = LatticeDB or {}
	local sv = LatticeDB
	local fresh = sv.schema == nil and sv.profiles == nil
	sv.profiles = sv.profiles or {}
	sv.chars = sv.chars or {}
	if fresh then sv.schema = SCHEMA end
	sv.schema = sv.schema or 1
	self:Migrate(sv)

	local key = self:CharKey()
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
