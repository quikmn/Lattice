-- Lattice: profile management, spec auto-switching, import/export strings.
local _, ns = ...
local U, DB = ns.Util, ns.Database
local P = {}
ns.Profiles = P

local EXPORT_PREFIX = "LAT1:"

local function SV() return DB.sv end

function P:List()
	return U.TableKeysSorted(SV().profiles)
end

function P:Exists(name)
	return SV().profiles[name] ~= nil
end

-- Switch the active profile and rebuild everything that depends on settings.
function P:Switch(name)
	if not self:Exists(name) or name == DB:ActiveName() then return end
	ns:RunOutOfCombat("profile-switch", function()
		DB:Activate(name)
		ns:Fire("ProfileChanged")
	end)
end

function P:Create(name, copyFrom)
	if not name or name == "" or self:Exists(name) then return false end
	if copyFrom and self:Exists(copyFrom) then
		SV().profiles[name] = U.CopyTable(SV().profiles[copyFrom])
	else
		SV().profiles[name] = {}
	end
	return true
end

function P:Delete(name)
	if name == DB:ActiveName() or not self:Exists(name) then return false end
	SV().profiles[name] = nil
	-- Characters using the deleted profile fall back to Default.
	for _, char in pairs(SV().chars) do
		if char.profile == name then char.profile = DB.DEFAULT_PROFILE end
		for spec, prof in pairs(char.specProfiles or {}) do
			if prof == name then char.specProfiles[spec] = nil end
		end
	end
	if not self:Exists(DB.DEFAULT_PROFILE) then SV().profiles[DB.DEFAULT_PROFILE] = {} end
	return true
end

function P:Rename(old, new)
	if not self:Exists(old) or self:Exists(new) or not new or new == "" then return false end
	SV().profiles[new] = SV().profiles[old]
	SV().profiles[old] = nil
	for _, char in pairs(SV().chars) do
		if char.profile == old then char.profile = new end
		for spec, prof in pairs(char.specProfiles or {}) do
			if prof == old then char.specProfiles[spec] = new end
		end
	end
	return true
end

function P:Reset()
	local name = DB:ActiveName()
	ns:RunOutOfCombat("profile-reset", function()
		SV().profiles[name] = {}
		DB:Activate(name)
		ns:Fire("ProfileChanged")
	end)
end

------------------------------------------------------------------------
-- Spec-based switching (only if the client has specializations)
------------------------------------------------------------------------
function P:HasSpecs()
	return type(GetSpecialization) == "function" and type(GetNumSpecializations) == "function"
		and (GetNumSpecializations() or 0) > 0
end

function P:CurrentSpec()
	if not self:HasSpecs() then return nil end
	return GetSpecialization()
end

function P:SpecName(index)
	if type(GetSpecializationInfo) == "function" then
		local _, name = GetSpecializationInfo(index)
		if name then return name end
	end
	return "Spec " .. index
end

function P:ApplySpecProfile()
	local spec = self:CurrentSpec()
	if not spec then return end
	local target = ns.char.specProfiles[spec]
	if target and self:Exists(target) and target ~= DB:ActiveName() then
		self:Switch(target)
	end
end

------------------------------------------------------------------------
-- Import / export
------------------------------------------------------------------------
local function Encoder()
	local E = C_EncodingUtil
	if E and E.SerializeCBOR and E.CompressString and E.EncodeBase64 then return E end
end

function P:Export(name)
	local E = Encoder()
	if not E then return nil, "This client has no encoding API." end
	local src = SV().profiles[name or DB:ActiveName()]
	if not src then return nil, "Profile not found." end
	local data = U.CopyTable(src)
	U.StripDefaults(data, ns.Defaults)
	local payload = { v = 1, addon = "Lattice", profile = data }
	local ok, out = pcall(function()
		return E.EncodeBase64(E.CompressString(E.SerializeCBOR(payload)))
	end)
	if not ok then return nil, "Could not encode profile." end
	return EXPORT_PREFIX .. out
end

function P:Decode(str)
	local E = Encoder()
	if not E then return nil, "This client has no encoding API." end
	str = (str or ""):gsub("%s", "")
	if str:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
		return nil, "That doesn't look like a Lattice profile string."
	end
	local ok, payload = pcall(function()
		return E.DeserializeCBOR(E.DecompressString(E.DecodeBase64(str:sub(#EXPORT_PREFIX + 1))))
	end)
	if not ok or type(payload) ~= "table" or payload.addon ~= "Lattice" or type(payload.profile) ~= "table" then
		return nil, "The profile string is damaged or incomplete."
	end
	return payload.profile
end

function P:Import(str, name)
	local data, err = self:Decode(str)
	if not data then return false, err end
	if not name or name == "" then return false, "Enter a name for the imported profile." end
	if self:Exists(name) then return false, "A profile with that name already exists." end
	SV().profiles[name] = data
	return true
end
