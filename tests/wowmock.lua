-- Minimal World of Warcraft API mock for offline testing of Lattice.
-- Goal: load every file in TOC order, run login/roster/combat flows, and
-- catch the classic Forever bug: doing math / comparisons on secret values.
--
-- Secret values are tables with a locked metatable: arithmetic, ordering,
-- concatenation-by-..? (allowed in game), length and indexing all throw.
-- Widget methods that the game lets accept secrets are whitelisted
-- (SECRET_OK); every other widget method throws if handed a secret.

MOCK = { log = {}, errors = {}, combat = false, time = 1000, secretsOn = true }

local SecretMT = {}
local function secretError(what)
	error("SECRET VALUE MISUSE: attempted " .. what .. " on a secret value", 2)
end
SecretMT.__add = function() secretError("arithmetic (+)") end
SecretMT.__sub = function() secretError("arithmetic (-)") end
SecretMT.__mul = function() secretError("arithmetic (*)") end
SecretMT.__div = function() secretError("arithmetic (/)") end
SecretMT.__mod = function() secretError("arithmetic (%)") end
SecretMT.__pow = function() secretError("arithmetic (^)") end
SecretMT.__unm = function() secretError("negation") end
SecretMT.__lt = function() secretError("comparison (<)") end
SecretMT.__le = function() secretError("comparison (<=)") end
SecretMT.__len = function() secretError("length (#)") end
SecretMT.__index = function() secretError("indexing") end
SecretMT.__newindex = function() secretError("index assignment") end
SecretMT.__call = function() secretError("call") end
SecretMT.__concat = function(a, b) return "<secret>" end -- allowed in game
SecretMT.__tostring = function() return "<secret>" end
SecretMT.__metatable = "secret"

function MOCK.Secret(real)
	local s = setmetatable({}, SecretMT)
	rawset(s, "__real", real) -- rawset bypasses __newindex
	return s
end
local function isSecret(v) return type(v) == "table" and getmetatable(v) == "secret" end
MOCK.isSecret = isSecret

function issecretvalue(v) return isSecret(v) end
function canaccessvalue(v) return not isSecret(v) end
function issecrettable(t) return false end

-- Wrap a value as secret when secrets are active (always on Forever for most unit data).
local function S(v) if MOCK.secretsOn then return MOCK.Secret(v) end return v end
MOCK.S = S

------------------------------------------------------------------------
-- Widgets
------------------------------------------------------------------------
-- Methods that accept secret arguments in game (verified from API docs).
SECRET_OK = {
	SetValue = true, SetMinMaxValues = true, SetText = true, SetFormattedText = true,
	SetAlpha = true, SetShown = true, SetVertexColor = true, SetStatusBarColor = true,
	SetTexture = true, SetCooldownFromDurationObject = true, SetAlphaFromBoolean = true,
	SetVertexColorFromBoolean = true, SetTimerDuration = true, SetToTargetValue = true,
	SetColorTexture = true, SetDesaturated = true, SetTextColor = true, SetSpriteSheetCell = true, SetAtlas = true,
}

local Widget = {}
local widgetCount = 0
local allWidgets = {}
MOCK.widgets = allWidgets

-- Colour setters take numbers (or a colour table as the only argument); the
-- real client throws "bad argument" on anything else, e.g. a layer name.
local COLOR_SETTERS = {
	SetVertexColor = true, SetStatusBarColor = true, SetColorTexture = true,
	SetTextColor = true, SetShadowColor = true, SetBackdropColor = true, SetBackdropBorderColor = true,
}

local function checkArgs(name, ...)
	if COLOR_SETTERS[name] then
		local n = select("#", ...)
		if not (n == 1 and type((...)) == "table") then
			for i = 1, n do
				local v = select(i, ...)
				if v ~= nil and type(v) ~= "number" and not isSecret(v) then
					error("bad argument #" .. i .. " to '" .. name .. "' (number expected, got " .. type(v) .. ")", 3)
				end
			end
		end
	end
	if SECRET_OK[name] then return end
	for i = 1, select("#", ...) do
		if isSecret((select(i, ...))) then
			error("SECRET VALUE MISUSE: passed a secret to widget method " .. name .. " (not allowed)", 3)
		end
	end
end

local function newWidget(kind, name, parent)
	widgetCount = widgetCount + 1
	local w = {
		__kind = kind, __name = name, __parent = parent, __shown = true,
		__attrs = {}, __scripts = {}, __points = {}, __w = 0, __h = 0,
		__value = 0, __min = 0, __max = 1, __children = {}, __events = {},
		__text = "", __alpha = 1, __level = 1,
	}
	setmetatable(w, Widget)
	allWidgets[#allWidgets + 1] = w
	if name then _G[name] = w end
	if parent and parent.__children then table.insert(parent.__children, w) end
	return w
end

-- Specific behaviour; anything else falls through to a no-op.
local impl = {}
function impl:GetName() return self.__name end
function impl:GetParent() return self.__parent end
function impl:SetParent(p) self.__parent = p end
function impl:Show() self.__shown = true; local s = self.__scripts.OnShow; if s then s(self) end end
function impl:Hide() local was = self.__shown; self.__shown = false; local s = self.__scripts.OnHide; if s and was then s(self) end end
function impl:SetShown(v) if v then self:Show() else self:Hide() end end
function impl:IsShown() return self.__shown end
function impl:IsVisible()
	local f = self
	while f do
		if not f.__shown then return false end
		f = f.__parent
	end
	return true
end
function impl:SetSize(w, h) self.__w, self.__h = w, h end
function impl:SetWidth(w) self.__w = w end
function impl:SetHeight(h) self.__h = h end
function impl:GetWidth() return self.__w end
function impl:GetHeight() return self.__h end
function impl:GetSize() return self.__w, self.__h end
function impl:GetStringHeight() return 12 end
function impl:GetStringWidth() return 40 end
function impl:SetScript(k, fn) self.__scripts[k] = fn end
function impl:GetScript(k) return self.__scripts[k] end
function impl:HookScript(k, fn)
	local old = self.__scripts[k]
	self.__scripts[k] = function(...) if old then old(...) end fn(...) end
end
function impl:SetAttribute(k, v)
	if MOCK.combat and self.__protected then error("ADDON_ACTION_BLOCKED: SetAttribute on protected frame in combat", 2) end
	self.__attrs[k] = v
	local s = self.__scripts.OnAttributeChanged
	if s then s(self, k, v) end
end
function impl:GetAttribute(k) return self.__attrs[k] end
function impl:RegisterEvent(e) self.__events[e] = true end
function impl:RegisterUnitEvent(e) self.__events[e] = true end
function impl:UnregisterEvent(e) self.__events[e] = nil end
function impl:UnregisterAllEvents() self.__events = {} end
function impl:IsEventRegistered(e) return self.__events[e] end
function impl:CreateTexture(name) return newWidget("Texture", name, self) end
function impl:CreateFontString(name) return newWidget("FontString", name, self) end
function impl:CreateAnimationGroup() return newWidget("AnimationGroup", nil, self) end
function impl:CreateAnimation() return newWidget("Animation", nil, self) end
function impl:SetFont() return true end
function impl:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function impl:SetText(t) self.__text = t end
function impl:GetText() return self.__text end
function impl:SetValue(v) self.__value = v end
function impl:GetValue() return self.__value end
function impl:SetMinMaxValues(a, b) self.__min, self.__max = a, b end
function impl:GetMinMaxValues() return self.__min, self.__max end
function impl:GetVerticalScroll() return 0 end
function impl:GetFrameLevel() return self.__level end
function impl:SetFrameLevel(l) self.__level = l end
function impl:GetEffectiveScale() return 1 end
function impl:GetScale() return 1 end
function impl:GetLeft() return 100 end
function impl:GetTop() return 500 end
function impl:GetBottom() return 400 end
function impl:GetRight() return 300 end
function impl:GetCenter() return 200, 450 end
function impl:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function impl:GetNumPoints() return 1 end
function impl:SetAlpha(a) self.__alpha = a end
function impl:GetAlpha() return self.__alpha end
function impl:GetStatusBarTexture() if not self.__sbt then self.__sbt = newWidget("Texture", nil, self) end return self.__sbt end
function impl:IsProtected() return self.__protected end
function impl:GetChildren() return unpack(self.__children) end
function impl:GetObjectType() return self.__kind end
function impl:IsObjectType(t) return self.__kind == t end
function impl:GetID() return self.__id or 0 end
function impl:SetID(id) self.__id = id end
function impl:IsMouseOver() return false end
function impl:GetStatusBarColor() return 1, 1, 1, 1 end
function impl:GetVertexColor() return 1, 1, 1, 1 end
function impl:Play() end
function impl:IsPlaying() return false end
function impl:GetRegions() return end
function impl:SetSmoothedValue(v) self.__value = v end

Widget.__index = function(self, key)
	local f = impl[key]
	if f then
		return function(s, ...)
			checkArgs(key, ...)
			return f(s, ...)
		end
	end
	if type(key) == "string" and key:match("^[A-Z]") then
		return function(s, ...)
			checkArgs(key, ...)
			return nil
		end
	end
	return nil
end

local secureTemplates = { SecureUnitButtonTemplate = true, SecureGroupHeaderTemplate = true,
	SecureRaidGroupHeaderTemplate = true, SecurePartyHeaderTemplate = true, SecureHandlerStateTemplate = true,
	SecureHandlerBaseTemplate = true, SecureHandlerAttributeTemplate = true, SecureActionButtonTemplate = true,
	SecureGroupPetHeaderTemplate = true }

secureTemplates.LatticeUnitButtonTemplate = true

-- Simplified SecureGroupHeader_Update: enough to create children and assign units.
local function HeaderUnits(h)
	local a = h.__attrs
	local units = {}
	local raid = MOCK.raid
	local kind
	if raid and a.showRaid then kind = "RAID"
	elseif MOCK.groupSize > 1 and not raid and a.showParty then kind = "PARTY"
	elseif a.showSolo then kind = "SOLO" end
	if not kind then return units end
	if h.__template and h.__template:find("Pet") then
		-- Pet header: one entry per existing pet.
		if kind == "RAID" then
			for i = 1, MOCK.groupSize do
				if MOCK.units["raidpet" .. i] then units[#units + 1] = "raidpet" .. i end
			end
		else
			if (kind == "SOLO" or a.showPlayer) and MOCK.units.pet then units[#units + 1] = "pet" end
			if kind == "PARTY" then
				for i = 1, MOCK.groupSize - 1 do
					if MOCK.units["partypet" .. i] then units[#units + 1] = "partypet" .. i end
				end
			end
		end
		return units
	end
	local filter = a.groupFilter
	if kind == "RAID" then
		for i = 1, MOCK.groupSize do
			local grp = math.floor((i - 1) / 5) + 1
			if not filter or (","..filter..","):find(","..grp..",", 1, true) then units[#units + 1] = "raid" .. i end
		end
	else
		if kind == "SOLO" or a.showPlayer then units[#units + 1] = "player" end
		if kind == "PARTY" then for i = 1, MOCK.groupSize - 1 do units[#units + 1] = "party" .. i end end
	end
	return units
end

function MOCK.UpdateHeader(h)
	if h.__attrs._ignore or not h:IsVisible() then return end
	local units = HeaderUnits(h)
	local start = h.__attrs.startingIndex or 1
	local need = math.max(1, #units - (start - 1))
	for i = 1, need do
		if not h.__attrs["child" .. i] then
			local child = CreateFrame("Button", nil, h, h.__attrs.template)
			child.__w, child.__h = 72, 36
			h.__attrs["child" .. i] = child
		end
	end
	-- Secure code sets unit attributes even in combat (bypasses the lockdown check).
	local function secureSet(child, k, v)
		child.__attrs[k] = v
		local s = child.__scripts.OnAttributeChanged
		if s then s(child, k, v) end
	end
	local i = 1
	for idx = start, #units do
		local child = h.__attrs["child" .. i]
		if child then child.__shown = true; secureSet(child, "unit", units[idx]) end
		i = i + 1
	end
	while h.__attrs["child" .. i] do
		local child = h.__attrs["child" .. i]
		child.__shown = false
		secureSet(child, "unit", nil)
		i = i + 1
	end
end

function CreateFrame(kind, name, parent, template)
	if kind == "AuraContainer" then
		local c = newWidget("AuraContainer", name, parent)
		c.__slots, c.__groups = {}, {}
		function c:AddAuraSlot(key, filter, opts)
			assert(type(key) == "string" and key ~= "", "slot key")
			assert(not self.__slots[key], "duplicate slot " .. key)
			local b = newWidget("Button", nil, self)
			for _, m in ipairs({ "SetIcon", "SetDurationCooldown", "SetApplicationCount", "AddDispelTypeTexture" }) do b[m] = function() end end
			if opts and opts.initializeFrame then opts.initializeFrame(b) end
			self.__slots[key] = { filter = filter, opts = opts }
			return b
		end
		function c:AddAuraGroup(key, filter, opts)
			assert(not self.__groups[key], "duplicate group " .. key)
			local b = newWidget("Button", nil, self)
			for _, m in ipairs({ "SetIcon", "SetDurationCooldown", "SetApplicationCount", "AddDispelTypeTexture" }) do b[m] = function() end end
			if opts and opts.initializeFrame then opts.initializeFrame(b) end
			self.__groups[key] = { filter = filter, opts = opts }
		end
		function c:SetUnit(u) self.__unit = u end
		function c:SetEnabled(e) self.__enabled = e end
		MOCK.containers = MOCK.containers or {}
		table.insert(MOCK.containers, c)
		return c
	end
	local w = newWidget(kind, name, parent)
	w.__template = template
	if template then
		for t in string.gmatch(template, "[^,%s]+") do
			if secureTemplates[t] then w.__protected = true end
		end
	end
	if template and template:find("Header") then
		MOCK.headers = MOCK.headers or {}
		table.insert(MOCK.headers, w)
		w.__scripts.OnAttributeChanged = function(self, k)
			-- Mirrors SecureGroupHeader_OnAttributeChanged: skip _ignore changes and while ignored.
			if k == "_ignore" or self.__attrs._ignore then return end
			MOCK.UpdateHeader(self)
		end
	end
	return w
end

function MOCK.UpdateAllHeaders()
	for _, h in ipairs(MOCK.headers or {}) do MOCK.UpdateHeader(h) end
end

UIParent = newWidget("Frame", "UIParent")
UIParent.__w, UIParent.__h = 1920, 1080
WorldFrame = newWidget("Frame", "WorldFrame")
GameTooltip = newWidget("GameTooltip", "GameTooltip")
DEFAULT_CHAT_FRAME = newWidget("Frame", "DEFAULT_CHAT_FRAME")
function DEFAULT_CHAT_FRAME:AddMessage(msg) table.insert(MOCK.log, msg) end
ColorPickerFrame = newWidget("Frame", "ColorPickerFrame")
GameFontHighlightSmall = newWidget("Font", "GameFontHighlightSmall")
GameFontNormal = newWidget("Font", "GameFontNormal")
UISpecialFrames = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
CompactRaidFrameContainer = newWidget("Frame", "CompactRaidFrameContainer")
CompactPartyFrame = newWidget("Frame", "CompactPartyFrame")
PartyFrame = newWidget("Frame", "PartyFrame")

------------------------------------------------------------------------
-- Lua/WoW globals
------------------------------------------------------------------------
tinsert, tremove, wipe = table.insert, table.remove, function(t) for k in pairs(t) do t[k] = nil end return t end
strsplit = function(sep, s, n)
	local out, pattern = {}, "([^" .. sep .. "]*)"
	for piece in string.gmatch(s, pattern) do out[#out + 1] = piece end
	return unpack(out)
end
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
format = string.format
Mixin = function(o, ...) for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do o[k] = v end end return o end
CreateFromMixins = function(...) return Mixin({}, ...) end
hooksecurefunc = function(t, k, fn)
	if type(t) == "string" then t, k, fn = _G, t, k end
	local old = t[k]
	t[k] = function(...) local r = { old(...) } fn(...) return unpack(r) end
end
securecallfunction = function(fn, ...) return fn(...) end
debugstack = function() return "" end
geterrorhandler = function() return function(e) table.insert(MOCK.errors, e) end end
GetTime = function() return MOCK.time end
GetLocale = function() return "enUS" end
GetRealmName = function() return "Mock Realm" end
GetCVar = function() return "0" end
GetCVarBool = function() return false end
InCombatLockdown = function() return MOCK.combat end
IsInGroup = function() return MOCK.groupSize > 1 end
IsInRaid = function() return MOCK.raid end
GetNumGroupMembers = function() return MOCK.groupSize > 1 and MOCK.groupSize or 0 end
IsShiftKeyDown = function() return false end
IsControlKeyDown = function() return false end
IsAltKeyDown = function() return false end
GetBindingKey = function() return nil end
ReloadUI = function() end
C_Timer = {
	After = function(_, fn) table.insert(MOCK.timers, fn) end,
	NewTicker = function(_, fn) local t = { Cancel = function() end, IsCancelled = function() return false end }; table.insert(MOCK.tickers, fn); return t end,
	NewTimer = function(_, fn) table.insert(MOCK.timers, fn); return { Cancel = function() end } end,
}
MOCK.timers, MOCK.tickers = {}, {}
C_AddOns = { GetAddOnMetadata = function(_, k) if k == "Version" then return "0.1.0-test" end end, IsAddOnLoaded = function() return false end }
SlashCmdList = {}
RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 0.5, g = 0.8, b = 0.3, colorStr = "ff80cc4d" } end })
CLASS_ICON_TCOORDS = setmetatable({}, { __index = function() return { 0, 1, 0, 1 } end })
DEAD, PLAYER_OFFLINE = "Dead", "Offline"
Enum = setmetatable({}, { __index = function(t, k) local e = setmetatable({}, { __index = function(_, kk) return kk end }); rawset(t, k, e); return e end })

------------------------------------------------------------------------
-- Units. MOCK.units[unit] = { name, class, role, hp, maxhp, ... }
------------------------------------------------------------------------
MOCK.units = {}
MOCK.groupSize = 1
MOCK.raid = false

local function U(unit)
	if not unit then return nil end
	return MOCK.units[unit]
end

function MOCK.SetGroup(n, raid)
	MOCK.units = {}
	MOCK.groupSize = n
	MOCK.raid = raid
	local classes = { "PRIEST", "WARRIOR", "MAGE", "DRUID", "ROGUE", "PALADIN", "HUNTER", "WARLOCK", "SHAMAN" }
	local function mk(i)
		return { name = "Member" .. i, class = classes[(i - 1) % #classes + 1], role = i == 1 and "HEALER" or (i == 2 and "TANK" or "DAMAGER"),
			hp = 800 + i, maxhp = 1000, power = 50, maxpower = 100, connected = true, dead = false }
	end
	MOCK.units.player = mk(1)
	MOCK.units.player.name = "Tester"
	MOCK.units.pet = { name = "Wolfie", class = "WARRIOR", role = "NONE", hp = 300, maxhp = 400, power = 10, maxpower = 100, connected = true, dead = false }
	if raid then
		for i = 1, n do MOCK.units["raid" .. i] = i == 1 and MOCK.units.player or mk(i) end
		MOCK.units.raidpet1 = MOCK.units.pet
		if n >= 3 then MOCK.units.raidpet3 = { name = "Imp", class = "WARRIOR", role = "NONE", hp = 200, maxhp = 300, power = 10, maxpower = 100, connected = true, dead = false } end
	else
		for i = 1, n - 1 do MOCK.units["party" .. i] = mk(i + 1) end
	end
end
MOCK.SetGroup(1, false)

UnitExists = function(u) return U(u) ~= nil end
UnitGUID = function(u) local d = U(u); return d and ("Player-1-" .. d.name) end
UnitName = function(u) local d = U(u); if d then return S(d.name), nil end end
UnitFullName = function(u) local d = U(u); if d then return d.name, "MockRealm" end end
GetUnitName = function(u) local d = U(u); return d and S(d.name) end
UnitClass = function(u) local d = U(u); if d then return d.class, d.class, 1 end end
UnitClassBase = function(u) local d = U(u); if d then return d.class, 1 end end
UnitGroupRolesAssigned = function(u) local d = U(u); return d and d.role or "NONE" end
UnitHealth = function(u) local d = U(u); return S(d and d.hp or 0) end
UnitHealthMax = function(u) local d = U(u); return S(d and d.maxhp or 1) end
UnitHealthPercent = function(u, _, curve)
	local d = U(u)
	if type(curve) == "table" and curve.isColor then
		return { GetRGB = function() return S(1), S(0.5), S(0) end, GetRGBA = function() return S(1), S(0.5), S(0), S(1) end }
	end
	return S(d and d.hp / d.maxhp or 0)
end
UnitHealthMissing = function(u) local d = U(u); return S(d and d.maxhp - d.hp or 0) end
UnitPower = function(u) local d = U(u); return S(d and d.power or 0) end
UnitPowerMax = function(u) local d = U(u); return S(d and d.maxpower or 1) end
UnitPowerType = function() return 0, "MANA" end
UnitGetIncomingHeals = function() return S(0) end
UnitGetTotalAbsorbs = function() return S(0) end
UnitGetTotalHealAbsorbs = function() return S(0) end
UnitIsConnected = function(u) local d = U(u); return d and d.connected end
UnitIsDeadOrGhost = function(u) local d = U(u); return d and d.dead end
UnitIsDead = UnitIsDeadOrGhost
UnitIsGhost = function() return false end
UnitIsAFK = function() return false end
UnitIsPlayer = function(u) return U(u) ~= nil end
UnitIsUnit = function(a, b) return a == b or (U(a) ~= nil and U(a) == U(b)) end
UnitInRange = function(u) return S(true), true end
UnitIsVisible = function(u) return U(u) ~= nil end
UnitIsGroupLeader = function(u) return u == "player" end
UnitIsGroupAssistant = function() return false end
UnitInParty = function(u) return U(u) ~= nil end
UnitInRaid = function(u) return MOCK.raid and 1 or nil end
UnitThreatSituation = function() return S(0) end
UnitHasIncomingResurrection = function() return false end
UnitPhaseReason = function() return nil end
UnitIsCharmed = function() return false end
UnitCanAttack = function() return false end
UnitAffectingCombat = function() return MOCK.combat end
GetRaidTargetIndex = function() return S(nil) end
GetReadyCheckStatus = function() return nil end
GetRaidRosterInfo = function(i) local d = U("raid" .. i); if d then return d.name, 0, math.floor((i - 1) / 5) + 1, 60, d.class, d.class, "", true, false, d.role end end
SetRaidTargetIconTexture = function() end
GetSpecialization = nil
C_Secrets = { ShouldAurasBeSecret = function() return MOCK.secretsOn end, HasSecretRestrictions = function() return MOCK.secretsOn end }
C_PartyInfo = {}
C_Spell = {
	GetSpellInfo = function(id) return { name = "Spell" .. tostring(id), iconID = 136000 + (tonumber(id) or 0), spellID = id } end,
	GetSpellTexture = function(id) return 136000 end,
	GetSpellName = function(id) return "Spell" .. tostring(id) end,
	IsSpellInRange = function() return S(true) end,
	DoesSpellExist = function() return true end,
}
C_SpellBook = { }
C_UnitAuras = {
	GetAuraDataByIndex = function() return nil end,
	GetUnitAuras = function() return {} end,
	GetAuraSlots = function() return nil end,
	GetAuraDataByAuraInstanceID = function() return nil end,
	IsAuraFilteredOutByInstanceID = function() return S(true) end,
}
C_CurveUtil = {
	CreateCurve = function() return { AddPoint = function() end, SetType = function() end, Evaluate = function() return S(0) end } end,
	CreateColorCurve = function()
		return { isColor = true, AddPoint = function() end, SetType = function() end, Evaluate = function() return { GetRGBA = function() return S(1), S(1), S(1), S(1) end, GetRGB = function() return S(1), S(1), S(1) end } end }
	end,
}
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 1, GetRGB = function(s) return s.r, s.g, s.b end, GetRGBA = function(s) return s.r, s.g, s.b, s.a end } end
C_EncodingUtil = {
	SerializeCBOR = function(v) MOCK.lastSerialized = v; return "cbor" end,
	DeserializeCBOR = function() return MOCK.lastSerialized end,
	CompressString = function(s) return s end,
	DecompressString = function(s) return s end,
	EncodeBase64 = function(s) return "QkFTRTY0" end,
	DecodeBase64 = function(s) return "cbor" end,
}
GameTooltip_SetDefaultAnchor = function() end
PowerBarColor = { MANA = { r = 0, g = 0, b = 1 } }
AbbreviateNumbers = function(n) return n end
CurveConstants = { ScaleTo100 = { curve = "ScaleTo100" }, ZeroToOne = {} }
AnchorUtil = { FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 }, FlowLayoutAxis = { Horizontal = 0, Vertical = 1 } }
AuraContainerSortMethod = { Default = 0, BigDefensive = 1, UnitFrameDebuff = 2, ImportantOnly = 3, Expiration = 4, ExpirationOnly = 5 }
CustomAuraContainerAuraProcessingPolicy = { None = 0, ProcessAura = 1 }
GetNumSubgroupMembers = function() return MOCK.raid and 0 or math.max(0, MOCK.groupSize - 1) end
CreateUnitHealPredictionCalculator = function()
	local c = {}
	for _, m in ipairs({ "SetDamageAbsorbClampMode", "SetIncomingHealClampMode", "SetIncomingHealOverflowPercent", "SetHealAbsorbClampMode" }) do c[m] = function() end end
	c.GetIncomingHeals = function() return S(10), S(5), S(5), S(false) end
	c.GetDamageAbsorbs = function() return S(20), S(false) end
	c.GetHealAbsorbs = function() return S(0), S(false) end
	return c
end
UnitGetDetailedHealPrediction = function() end
C_SpellBook = {
	GetNumSpellBookSkillLines = function() return 1 end,
	GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 3 } end,
	GetSpellBookItemInfo = function(slot)
		local data = { { 774, "Rejuvenation" }, { 1058, "Rejuvenation" }, { 5185, "Healing Touch" } }
		local d = data[slot]
		return d and { spellID = d[1], name = d[2], isPassive = false }
	end,
	IsSpellBookItemHelpful = function() return true end,
}
RegisterAttributeDriver = function(f, k, v) f.__attrs[k] = v end
UnregisterAttributeDriver = function() end
RegisterStateDriver = function() end
UnregisterStateDriver = function() end
C_CurveUtil.EvaluateColorValueFromBoolean = function(b, t, f)
	if MOCK.isSecret(b) or MOCK.isSecret(t) or MOCK.isSecret(f) then return S(1) end
	if b then return t end
	return f
end

-- Fire an event at every frame registered for it.
function MOCK.Fire(event, ...)
	for _, w in ipairs(allWidgets) do
		if w.__events[event] and w.__scripts.OnEvent then
			w.__scripts.OnEvent(w, event, ...)
		end
	end
end

function MOCK.RunTimers()
	local t = MOCK.timers
	MOCK.timers = {}
	for _, fn in ipairs(t) do fn() end
	for _, fn in ipairs(MOCK.tickers) do fn() end
end
RegisterUnitWatch = function(f) f.__unitwatch = true end
UnregisterUnitWatch = function() end
SecureHandlerSetFrameRef = function() end
MOCK.bindings = {}
ClearOverrideBindings = function() wipe(MOCK.bindings) end
SetOverrideBindingClick = function(_, _, key, buttonName)
	if MOCK.combat then error("ADDON_ACTION_BLOCKED: SetOverrideBindingClick in combat", 2) end
	MOCK.bindings[key] = buttonName
end
MOCK.summons = {}
C_IncomingSummon = {
	HasIncomingSummon = function(u) return MOCK.summons[u] ~= nil end,
	IncomingSummonStatus = function(u) return MOCK.summons[u] or 0 end,
}
