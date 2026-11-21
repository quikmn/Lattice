-- Which realm you are on. The same small helper sits in each EverlookDB addon (they don't depend on each other).
--
-- Since the WoW Forever client update of 2026-11-21 (1.60.1, build 71037) GetRealmName() and GetNormalizedRealmName()
-- return "", GetRealmID() can return 0, and UnitFullName("player")'s second value is the character's surname, not the
-- realm (the client has regional unique names on). The realm ID is still in the character's GUID ("Player-6946-...").
-- So the realm is read in this order:
--   id    GetRealmID() when it is above 0, else the ID in UnitGUID("player")
--   name  GetRealmName() when it says something (remembered for its ID), else the name this addon saved for the ID
--   key   the name, else "realm:<id>" (an ID-only key), else nil while nothing says it
-- A name is never guessed: without a saved one the ID-only key is used, and put right once the name is known.
local _, ns = ...

local R = {}
ns.Realm = R

local function call(f, ...)
	if type(f) ~= "function" then return nil end
	local ok, v = pcall(f, ...)
	if ok then return v end
end

local function plain(v)
	if v ~= nil and issecretvalue and issecretvalue(v) then return nil end
	return v
end

-- v when it is a string with something in it, else nil
local function text(v)
	v = plain(v)
	return type(v) == "string" and v ~= "" and v or nil
end
R.text = text

-- the realm ID in a player GUID ("Player-6946-07376D91" -> 6946), or nil
function R.idOf(guid)
	guid = text(guid)
	local n = guid and tonumber(guid:match("^Player%-(%d+)%-"))
	return n and n > 0 and n or nil
end

-- this realm's ID, or nil while neither the game nor the GUID says it
function R.id()
	local id = plain(call(GetRealmID))
	if type(id) == "number" and id > 0 then return id end
	return R.idOf(call(UnitGUID, "player"))
end

-- GetRealmName() when it says something, else nil
function R.apiName() return text(call(GetRealmName)) end

-- the ID-only key for a realm ID ("realm:6946"), and back
function R.idKey(id) return id and ("realm:" .. id) or nil end
function R.keyID(key) return type(key) == "string" and tonumber(key:match("^realm:(%d+)$")) or nil end

-- a realm name in a saved record that names nothing: nil, "", "?" or an ID-only key
function R.blank(name) return text(name) == nil or name == "?" or R.keyID(name) ~= nil end

-- names compared the way "Name-Realm" writes them: no spaces, hyphens or apostrophes, any case
function R.squash(s) return text(s) and (s:gsub("[%s%-']", ""):lower()) or nil end

-- key, name, id. names = { [realmID] = name } in the addon's saved variables (may be nil): the game's name is
-- remembered there, and read back from there when the game says nothing.
function R.read(names)
	local name, id = R.apiName(), R.id()
	if id and type(names) == "table" then
		if name then names[id] = name elseif text(names[id]) then name = names[id] end
	end
	return name or R.idKey(id), name, id
end
