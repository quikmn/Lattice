-- Lattice: unit button visuals and updates.
--
-- Secure buttons (from the headers) only carry click attributes. Everything
-- visible lives on `btn.visual`, a plain child frame, so range fading
-- (a secret-driven alpha) never touches the protected button itself.
local _, ns = ...
local U, S = ns.Util, ns.Secret
local B = {}
ns.Buttons = B

B.all = {}       -- every real (secure) unit button
B.byUnit = {}    -- unit token -> { [btn] = true }

local issecret = S.IsSecret

local TEXTURES = {
	flat     = "Interface\\Buttons\\WHITE8X8",
	smooth   = "Interface\\TargetingFrame\\UI-StatusBar",
	raid     = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
}
B.TEXTURES = TEXTURES

local ROLE_TEX = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local ROLE_COORDS = {
	TANK    = { 0, 19 / 64, 22 / 64, 41 / 64 },
	HEALER  = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
	DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}
local READY_TEX = {
	ready    = "Interface\\RaidFrame\\ReadyCheck-Ready",
	notready = "Interface\\RaidFrame\\ReadyCheck-NotReady",
	waiting  = "Interface\\RaidFrame\\ReadyCheck-Waiting",
}

local function Appearance() return ns.db.appearance end

------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------
local function Utf8Sub(s, n)
	if not n or n <= 0 then return s end
	local count, i = 0, 1
	local len = #s
	while i <= len do
		count = count + 1
		if count > n then return s:sub(1, i - 1) end
		local c = s:byte(i)
		if c >= 240 then i = i + 4 elseif c >= 224 then i = i + 3 elseif c >= 192 then i = i + 2 else i = i + 1 end
	end
	return s
end

-- Show/hide a region from a value that may be a secret boolean.
local function ShowBool(region, value)
	if issecret(value) then
		region:Show()
		region:SetAlpha(S.PickNumber(value, 1, 0))
	else
		region:SetAlpha(1)
		region:SetShown(value and true or false)
	end
end
B.ShowBool = ShowBool

local function NewBar(parent, layer)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetStatusBarTexture(TEXTURES.flat)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	if layer then bar:SetFrameLevel(parent:GetFrameLevel() + layer) end
	return bar
end

local function NewBorderFrame(parent, level)
	local f = CreateFrame("Frame", nil, parent)
	f:SetAllPoints()
	f:SetFrameLevel(parent:GetFrameLevel() + (level or 5))
	f.border = U.Border(f, 1, 1, 1, 1, 1, "OVERLAY")
	f:Hide()
	return f
end

------------------------------------------------------------------------
-- Construction (shared by real and preview buttons)
------------------------------------------------------------------------
function B:Build(btn)
	local v = CreateFrame("Frame", nil, btn)
	v:SetAllPoints()
	btn.visual = v

	v.bg = U.Solid(v, "BACKGROUND", 0.06, 0.06, 0.07, 0.9)
	v.bg:SetAllPoints()

	-- Health + prediction overlays
	local health = NewBar(v, 1)
	health:SetClipsChildren(true)
	v.health = health

	v.healBar = NewBar(health, 1)
	v.healBar:SetStatusBarColor(0.30, 0.95, 0.55, 0.45)
	v.absorbBar = NewBar(health, 2)
	v.absorbBar:SetStatusBarColor(0.80, 0.90, 1.00, 0.55)
	v.healAbsorbBar = NewBar(health, 3)
	v.healAbsorbBar:SetStatusBarColor(0.55, 0.05, 0.10, 0.65)
	if v.healAbsorbBar.SetReverseFill then v.healAbsorbBar:SetReverseFill(true) end

	-- Power
	v.power = NewBar(v, 1)
	v.powerBg = U.Solid(v.power, "BACKGROUND", 0, 0, 0, 0.6)
	v.powerBg:SetAllPoints()

	-- Text + icons sit above the bars
	local over = CreateFrame("Frame", nil, v)
	over:SetAllPoints()
	over:SetFrameLevel(v:GetFrameLevel() + 6)
	v.over = over

	v.name = over:CreateFontString(nil, "OVERLAY")
	v.name:SetWordWrap(false)
	v.status = over:CreateFontString(nil, "OVERLAY")
	v.healthText = over:CreateFontString(nil, "OVERLAY")

	v.role = over:CreateTexture(nil, "OVERLAY")
	v.role:SetTexture(ROLE_TEX)
	v.leader = over:CreateTexture(nil, "OVERLAY")
	v.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
	v.raidIcon = over:CreateTexture(nil, "OVERLAY")
	v.raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	v.ready = over:CreateTexture(nil, "OVERLAY")
	v.ready:Hide()
	v.rez = over:CreateTexture(nil, "OVERLAY")
	v.rez:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
	v.rez:Hide()

	-- Borders: base, aggro, target, mouseover (dispel border is owned by Auras)
	v.baseBorder = U.Border(v, 1, 0, 0, 0, 1, "BORDER")
	v.aggro = NewBorderFrame(v, 7)
	v.aggro.border:SetColor(1, 0.25, 0.2, 1)
	v.target = NewBorderFrame(v, 8)
	v.hover = NewBorderFrame(v, 9)
	v.hover.border:SetColor(1, 1, 1, 0.35)

	if ns.Auras then ns.Auras:Build(btn) end
end

------------------------------------------------------------------------
-- Real secure buttons
------------------------------------------------------------------------
function B:Setup(btn)
	if btn.latticeReady then return end
	btn.latticeReady = true
	self:Build(btn)

	btn:RegisterForClicks("AnyUp")
	btn:HookScript("OnAttributeChanged", function(self, name, value)
		if name == "unit" then B:SetUnit(self, value) end
	end)
	btn:HookScript("OnEnter", function(self)
		local v = self.visual
		if Appearance().mouseoverHighlight then v.hover:Show() end
		if self.unit and not InCombatLockdown() and ns.db.general.tooltips ~= false then
			GameTooltip_SetDefaultAnchor(GameTooltip, self)
			GameTooltip:SetUnit(self.unit)
			GameTooltip:Show()
		end
	end)
	btn:HookScript("OnLeave", function(self)
		self.visual.hover:Hide()
		GameTooltip:Hide()
	end)
	btn:HookScript("OnShow", function(self) B:UpdateAll(self) end)

	ns.ClickCast:ApplyTo(btn)
	B.all[#B.all + 1] = btn
	self:ApplyLayout(btn)
	self:SetUnit(btn, btn:GetAttribute("unit"))
end

function B:SetUnit(btn, unit)
	local old = btn.unit
	if old and B.byUnit[old] then B.byUnit[old][btn] = nil end
	btn.unit = unit
	if unit then
		B.byUnit[unit] = B.byUnit[unit] or {}
		B.byUnit[unit][btn] = true
		btn.calc = btn.calc or S.NewCalculator()
		self:UpdateAll(btn)
	end
end

------------------------------------------------------------------------
-- Layout (sizes, fonts, anchors) - safe to call any time (visuals aren't protected)
------------------------------------------------------------------------
function B:ApplyLayout(btn)
	local A = Appearance()
	local L = btn.latticeLayout or ns.db.layouts.party
	local v = btn.visual
	local w, h = L.width, L.height
	local bs = A.borderSize
	local tex = TEXTURES[A.texture] or TEXTURES.flat

	v.bg:SetVertexColor(unpack(A.backgroundColor))
	v.baseBorder:SetColor(unpack(A.borderColor))
	v.baseBorder:SetSize(bs)
	v.baseBorder:SetShown(bs > 0)

	local showPower = L.showPower and A.powerHeight > 0
	local ph = showPower and A.powerHeight or 0
	local inner = bs
	v.health:ClearAllPoints()
	v.health:SetPoint("TOPLEFT", inner, -inner)
	v.health:SetPoint("BOTTOMRIGHT", -inner, inner + (showPower and ph + 1 or 0))
	v.health:SetStatusBarTexture(tex)
	v.power:ClearAllPoints()
	v.power:SetPoint("BOTTOMLEFT", inner, inner)
	v.power:SetPoint("BOTTOMRIGHT", -inner, inner)
	v.power:SetHeight(math.max(1, ph))
	v.power:SetStatusBarTexture(tex)
	v.power:SetShown(showPower)

	-- Prediction overlays start where the health fill ends.
	local healthW = math.max(1, w - 2 * inner)
	local fill = v.health:GetStatusBarTexture()
	local function overlay(bar, anchorTex)
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", anchorTex, "TOPRIGHT")
		bar:SetPoint("BOTTOMLEFT", anchorTex, "BOTTOMRIGHT")
		bar:SetWidth(healthW)
		bar:SetStatusBarTexture(tex)
	end
	overlay(v.healBar, fill)
	overlay(v.absorbBar, v.healBar:GetStatusBarTexture())
	v.healAbsorbBar:ClearAllPoints()
	v.healAbsorbBar:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
	v.healAbsorbBar:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
	v.healAbsorbBar:SetWidth(healthW)
	v.healAbsorbBar:SetStatusBarTexture(tex)

	-- Text
	local outline = A.nameOutline and "OUTLINE" or ""
	U.SetFont(v.name, A.nameSize, outline)
	v.name:ClearAllPoints()
	v.name:SetPoint(A.namePoint, v.health, A.namePoint, 0, A.namePoint == "CENTER" and (A.statusText ~= "none" and 5 or 0) or 0)
	v.name:SetWidth(w - 6)
	v.name:SetJustifyH(A.namePoint:find("LEFT") and "LEFT" or (A.namePoint:find("RIGHT") and "RIGHT" or "CENTER"))
	U.SetFont(v.status, A.statusSize, "OUTLINE")
	v.status:ClearAllPoints()
	v.status:SetPoint("CENTER", v.health, "CENTER", 0, -6)
	U.SetFont(v.healthText, A.statusSize, "OUTLINE")
	v.healthText:ClearAllPoints()
	v.healthText:SetPoint("CENTER", v.health, "CENTER", 0, -6)

	-- Icons
	local rs = A.roleIconSize
	v.role:SetSize(rs, rs)
	v.role:ClearAllPoints()
	v.role:SetPoint(A.roleIconPoint, v.health, A.roleIconPoint, A.roleIconPoint:find("LEFT") and 2 or -2, A.roleIconPoint:find("TOP") and -2 or 2)
	v.leader:SetSize(rs, rs)
	v.leader:ClearAllPoints()
	v.leader:SetPoint("BOTTOMLEFT", v.role, "TOPLEFT", 0, -rs / 2)
	v.raidIcon:SetSize(A.raidIconSize, A.raidIconSize)
	v.raidIcon:ClearAllPoints()
	v.raidIcon:SetPoint(A.raidIconPoint, v.health, A.raidIconPoint, 0, A.raidIconPoint:find("TOP") and 2 or 0)
	local rc = math.min(w, h) * 0.6
	v.ready:SetSize(rc, rc)
	v.ready:ClearAllPoints()
	v.ready:SetPoint("CENTER", v.health)
	v.rez:SetSize(rc, rc)
	v.rez:ClearAllPoints()
	v.rez:SetPoint("CENTER", v.health)

	v.target.border:SetColor(unpack(A.targetHighlightColor))
	v.target.border:SetSize(math.max(1, bs + 1))
	v.aggro.border:SetSize(math.max(1, bs + 1))

	if ns.Auras then ns.Auras:Layout(btn) end
end

function B:ApplyLayoutAll()
	for _, btn in ipairs(self.all) do self:ApplyLayout(btn) end
	if ns.TestMode then ns.TestMode:Relayout() end
end

------------------------------------------------------------------------
-- Element updates (real units)
------------------------------------------------------------------------
local function IsGone(unit)
	return not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit)
end

function B:UpdateHealthColor(btn)
	local unit, v, A = btn.unit, btn.visual, Appearance()
	if not unit then return end
	local _, class = UnitClass(unit)
	class = S.Plain(class, nil)
	local r, g, b = U.ClassColor(class)

	if not UnitIsConnected(unit) then
		v.health:SetStatusBarColor(0.35, 0.35, 0.35)
	elseif A.healthColor == "custom" then
		local c = A.customHealthColor
		v.health:SetStatusBarColor(c[1], c[2], c[3])
	elseif A.healthColor == "gradient" then
		local curve = S.HealthGradientCurve()
		local ok = curve and S.Try("health-gradient", function()
			local color = UnitHealthPercent(unit, true, curve)
			v.health:SetStatusBarColor(color:GetRGB())
		end)
		if not ok then v.health:SetStatusBarColor(r, g, b) end
	else
		v.health:SetStatusBarColor(r, g, b)
	end

	if A.backgroundMode == "class" then
		v.bg:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, A.backgroundColor[4])
	else
		v.bg:SetVertexColor(unpack(A.backgroundColor))
	end
end

function B:UpdateHealth(btn)
	local unit, v = btn.unit, btn.visual
	if not unit then return end
	local maxHP = UnitHealthMax(unit)
	v.health:SetMinMaxValues(0, maxHP)
	if UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then
		v.health:SetValue(0)
	else
		S.SetBar(v.health, UnitHealth(unit), true)
	end
	if Appearance().healthColor == "gradient" then self:UpdateHealthColor(btn) end
	self:UpdateHealthText(btn)
	self:UpdatePrediction(btn)
end

function B:UpdatePrediction(btn)
	local unit, v, A = btn.unit, btn.visual, Appearance()
	if not unit then return end
	if (not A.healPrediction and not A.absorbs) or IsGone(unit) then
		v.healBar:Hide(); v.absorbBar:Hide(); v.healAbsorbBar:Hide()
		return
	end
	local maxHP = UnitHealthMax(unit)
	local heals, absorbs, healAbsorbs = S.HealPrediction(btn.calc, unit)
	v.healBar:SetMinMaxValues(0, maxHP)
	v.absorbBar:SetMinMaxValues(0, maxHP)
	v.healAbsorbBar:SetMinMaxValues(0, maxHP)
	v.healBar:SetValue(heals or 0)
	v.absorbBar:SetValue(absorbs or 0)
	v.healAbsorbBar:SetValue(healAbsorbs or 0)
	v.healBar:SetShown(A.healPrediction)
	v.absorbBar:SetShown(A.absorbs)
	v.healAbsorbBar:SetShown(A.absorbs)
end

function B:UpdateHealthText(btn)
	local unit, v, A = btn.unit, btn.visual, Appearance()
	local mode = A.statusText
	if not unit or mode == "none" or IsGone(unit) then
		v.healthText:Hide()
		return
	end
	local ok
	if mode == "percent" then
		local scale = S.PercentCurve()
		ok = scale and S.Try("health-percent", function()
			v.healthText:SetFormattedText("%d%%", UnitHealthPercent(unit, true, scale))
			v.healthText:SetAlpha(1)
		end)
	elseif mode == "deficit" then
		ok = S.Try("health-deficit", function()
			local missing = UnitHealthMissing(unit, true)
			if AbbreviateNumbers then
				v.healthText:SetFormattedText("-%s", AbbreviateNumbers(missing))
			else
				v.healthText:SetFormattedText("-%d", missing)
			end
			local notFull = S.NotFullCurve()
			v.healthText:SetAlpha(notFull and UnitHealthPercent(unit, true, notFull) or 1)
		end)
	end
	v.healthText:SetShown(ok and true or false)
end

function B:UpdatePower(btn)
	local unit, v = btn.unit, btn.visual
	if not unit or not v.power:IsShown() then return end
	local ptype = UnitPowerType(unit)
	v.power:SetMinMaxValues(0, UnitPowerMax(unit, ptype))
	S.SetBar(v.power, UnitPower(unit, ptype), true)
end

function B:UpdatePowerColor(btn)
	local unit, v = btn.unit, btn.visual
	if not unit then return end
	local ptype, token, ar, ag, ab = UnitPowerType(unit)
	local c = PowerBarColor and (PowerBarColor[token] or PowerBarColor[ptype])
	if not UnitIsConnected(unit) then
		v.power:SetStatusBarColor(0.35, 0.35, 0.35)
	elseif not Appearance().powerColorByType then
		v.power:SetStatusBarColor(0.30, 0.50, 0.85)
	elseif c then
		v.power:SetStatusBarColor(c.r, c.g, c.b)
	elseif ar then
		v.power:SetStatusBarColor(ar, ag, ab)
	else
		v.power:SetStatusBarColor(0.30, 0.50, 0.85)
	end
	self:UpdatePower(btn)
end

function B:UpdateName(btn)
	local unit, v, A = btn.unit, btn.visual, Appearance()
	if not unit then return end
	local name = UnitName(unit)
	if issecret(name) then
		v.name:SetText(name) -- can't shorten a secret string; display as-is
	else
		v.name:SetText(Utf8Sub(name or "?", A.nameLength))
	end
	if A.nameClassColor then
		local _, class = UnitClass(unit)
		v.name:SetTextColor(U.ClassColor(S.Plain(class, nil)))
	else
		v.name:SetTextColor(1, 1, 1)
	end
end

function B:UpdateStatus(btn)
	local unit, v = btn.unit, btn.visual
	if not unit then return end
	local text
	if not UnitIsConnected(unit) then
		text = PLAYER_OFFLINE or "Offline"
	elseif UnitIsGhost and UnitIsGhost(unit) then
		text = "Ghost"
	elseif UnitIsDead(unit) then
		text = DEAD or "Dead"
	else
		local afk = S.Plain(UnitIsAFK(unit), false)
		if afk then text = "AFK" end
	end
	if text then
		v.status:SetText(text)
		v.status:Show()
		v.healthText:Hide()
	else
		v.status:Hide()
	end
	local rez = UnitHasIncomingResurrection and S.Plain(UnitHasIncomingResurrection(unit), false)
	v.rez:SetShown(rez and UnitIsDeadOrGhost(unit) and true or false)
end

function B:UpdateRange(btn)
	local unit, v = btn.unit, btn.visual
	if not unit then return end
	local G = ns.db.general
	if not G.rangeFade then
		v:SetAlpha(1)
		return
	end
	if not UnitIsConnected(unit) then
		v:SetAlpha(G.rangeAlpha)
		return
	end
	S.Try("range", function()
		v:SetAlpha(S.RangeAlpha(unit, G.rangeAlpha))
	end)
end

function B:UpdateRole(btn)
	local unit, v, A = btn.unit, btn.visual, Appearance()
	if not unit or not A.roleIcon then v.role:Hide() return end
	local role = S.Plain(UnitGroupRolesAssigned(unit), "NONE")
	local coords = ROLE_COORDS[role]
	if not coords or (role == "DAMAGER" and A.hideDamagerIcon) then
		v.role:Hide()
		return
	end
	v.role:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	v.role:Show()
end

function B:UpdateLeader(btn)
	local unit, v = btn.unit, btn.visual
	if not unit or not Appearance().leaderIcon then v.leader:Hide() return end
	local leader = S.Plain(UnitIsGroupLeader(unit), false)
	local assist = S.Plain(UnitIsGroupAssistant(unit), false) and IsInRaid()
	if leader then
		v.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
		v.leader:Show()
	elseif assist then
		v.leader:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
		v.leader:Show()
	else
		v.leader:Hide()
	end
end

function B:UpdateRaidIcon(btn)
	local unit, v = btn.unit, btn.visual
	if not unit or not Appearance().raidIcon then v.raidIcon:Hide() return end
	v.raidIcon:Show()
	S.Try("raid-icon", S.SetRaidIcon, v.raidIcon, unit)
end

function B:UpdateTarget(btn)
	local unit, v = btn.unit, btn.visual
	if not unit or not Appearance().targetHighlight then v.target:Hide() return end
	ShowBool(v.target, UnitIsUnit(unit, "target"))
end

function B:UpdateAggro(btn)
	local unit, v = btn.unit, btn.visual
	if not unit or not Appearance().aggroBorder then v.aggro:Hide() return end
	local status = UnitThreatSituation(unit)
	if issecret(status) or not status or status < 2 then
		v.aggro:Hide()
		return
	end
	v.aggro.border:SetColor(status == 3 and 1 or 1, status == 3 and 0.15 or 0.6, 0.1, 1)
	v.aggro:Show()
end

-- Ready check state comes from event payloads (readable), cached per unit.
B.readyState = {}
function B:UpdateReady(btn)
	local unit, v = btn.unit, btn.visual
	local state = unit and B.readyState[unit]
	if not state or not Appearance().readyCheck then v.ready:Hide() return end
	v.ready:SetTexture(READY_TEX[state])
	v.ready:Show()
end

function B:UpdateAll(btn)
	if not btn.unit or not btn.visual then return end
	if not UnitExists(btn.unit) then return end
	self:UpdateHealthColor(btn)
	self:UpdateHealth(btn)
	self:UpdatePowerColor(btn)
	self:UpdateName(btn)
	self:UpdateStatus(btn)
	self:UpdateRange(btn)
	self:UpdateRole(btn)
	self:UpdateLeader(btn)
	self:UpdateRaidIcon(btn)
	self:UpdateTarget(btn)
	self:UpdateAggro(btn)
	self:UpdateReady(btn)
	if ns.Auras then ns.Auras:Update(btn) end
end

function B:UpdateAllButtons()
	for _, btn in ipairs(self.all) do
		if btn:IsVisible() then self:UpdateAll(btn) end
	end
end
B.UpdateAll_ = B.UpdateAll

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local function ForUnit(unit, fn)
	local set = unit and B.byUnit[unit]
	if not set then return end
	for btn in pairs(set) do
		if btn.unit == unit then fn(B, btn) end
	end
end

local function ForAll(fn)
	for _, btn in ipairs(B.all) do
		if btn.unit and btn:IsVisible() then fn(B, btn) end
	end
end

local unitEvents = {
	UNIT_HEALTH = B.UpdateHealth,
	UNIT_MAXHEALTH = B.UpdateHealth,
	UNIT_HEAL_PREDICTION = B.UpdatePrediction,
	UNIT_ABSORB_AMOUNT_CHANGED = B.UpdatePrediction,
	UNIT_HEAL_ABSORB_AMOUNT_CHANGED = B.UpdatePrediction,
	UNIT_POWER_UPDATE = B.UpdatePower,
	UNIT_MAXPOWER = B.UpdatePower,
	UNIT_DISPLAYPOWER = B.UpdatePowerColor,
	UNIT_NAME_UPDATE = B.UpdateName,
	UNIT_CONNECTION = B.UpdateAll,
	UNIT_FLAGS = B.UpdateStatus,
	UNIT_THREAT_SITUATION_UPDATE = B.UpdateAggro,
	UNIT_IN_RANGE_UPDATE = B.UpdateRange,
	UNIT_PHASE = B.UpdateRange,
	INCOMING_RESURRECT_CHANGED = B.UpdateStatus,
	PLAYER_FLAGS_CHANGED = B.UpdateStatus,
}

function B:RegisterEvents()
	for event, fn in pairs(unitEvents) do
		ns:RegisterEvent(event, function(_, unit)
			ForUnit(unit, fn)
			if event == "UNIT_HEALTH" or event == "UNIT_CONNECTION" or event == "UNIT_FLAGS" then
				ForUnit(unit, B.UpdateStatus)
				ForUnit(unit, B.UpdateHealthColor)
			end
		end)
	end
	ns:RegisterEvent("PLAYER_TARGET_CHANGED", function() ForAll(B.UpdateTarget) end)
	ns:RegisterEvent("RAID_TARGET_UPDATE", function() ForAll(B.UpdateRaidIcon) end)
	ns:RegisterEvent("PARTY_LEADER_CHANGED", function() ForAll(B.UpdateLeader) end)
	ns:RegisterEvent("PLAYER_ROLES_ASSIGNED", function() ForAll(B.UpdateRole) end)
	ns:RegisterEvent("GROUP_ROSTER_UPDATE", function()
		ForAll(B.UpdateAll)
		ns.Headers:OnRosterChanged()
	end)
	ns:RegisterEvent("PLAYER_ENTERING_WORLD", function() ForAll(B.UpdateAll) end)

	-- Ready check (payloads are readable)
	ns:RegisterEvent("READY_CHECK", function()
		wipe(B.readyState)
		for unit in pairs(B.byUnit) do B.readyState[unit] = "waiting" end
		ForAll(B.UpdateReady)
	end)
	ns:RegisterEvent("READY_CHECK_CONFIRM", function(_, unit, isReady)
		if not unit or issecret(isReady) then return end
		B.readyState[unit] = isReady and "ready" or "notready"
		-- The payload may name the unit differently from our button (raidN vs player).
		for token in pairs(B.byUnit) do
			if token ~= unit and UnitIsUnit(token, unit) then B.readyState[token] = B.readyState[unit] end
		end
		ForAll(B.UpdateReady)
	end)
	ns:RegisterEvent("READY_CHECK_FINISHED", function()
		for unit, state in pairs(B.readyState) do
			if state == "waiting" then B.readyState[unit] = "notready" end
		end
		ForAll(B.UpdateReady)
		C_Timer.After(6, function()
			wipe(B.readyState)
			ForAll(B.UpdateReady)
		end)
	end)

	-- Range has no reliable push for every case; poll lightly as a backstop.
	C_Timer.NewTicker(0.5, function()
		if not ns.db.general.rangeFade then return end
		ForAll(B.UpdateRange)
	end)
end
