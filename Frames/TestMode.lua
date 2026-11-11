-- Lattice: preview frames with fake data, so layouts can be tuned while solo.
-- Uses plain (non-secure) buttons with the same visuals as the real ones.
local _, ns = ...
local U = ns.Util
local T = {}
ns.TestMode = T

local active = false
local holder
local fakes = {}
T.size = 5 -- 5, 10, 20, 25 or 40

local CLASSES = { "WARRIOR", "PRIEST", "MAGE", "DRUID", "ROGUE", "PALADIN", "HUNTER", "WARLOCK", "SHAMAN" }
local NAMES = { "Thrall", "Jaina", "Anduin", "Malfurion", "Valeera", "Uther", "Rexxar", "Gul'dan", "Drek'thar",
	"Varian", "Tyrande", "Velen", "Garrosh", "Sylvanas", "Cairne", "Muradin", "Kael", "Illidan", "Vol'jin", "Baine" }
local ROLES = { "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER" }
local DISPELS = { nil, "Magic", nil, nil, "Poison", nil, "Curse", nil, nil, "Disease" }

local function FakeData(i)
	return {
		name = NAMES[(i - 1) % #NAMES + 1],
		class = CLASSES[(i - 1) % #CLASSES + 1],
		role = ROLES[(i - 1) % #ROLES + 1],
		hp = (i % 7 == 0) and 0 or (35 + (i * 37) % 66),
		power = 40 + (i * 13) % 60,
		dead = (i % 7 == 0),
		offline = (i == 12),
		outOfRange = (i % 6 == 4),
		dispel = DISPELS[(i - 1) % #DISPELS + 1],
		absorb = (i % 4 == 1) and 15 or 0,
		heal = (i % 3 == 0) and 12 or 0,
		hot = (i % 2 == 0),
		debuff = (i % 5 == 2),
		leader = (i == 1),
		group = math.floor((i - 1) / 5) + 1,
	}
end

local function MakeFake(i)
	local btn = CreateFrame("Button", nil, holder)
	btn.fake = true
	ns.Buttons:Build(btn)
	local v = btn.visual
	-- Fake aura icons (preview only)
	v.fakeDebuff = v.over:CreateTexture(nil, "OVERLAY")
	v.fakeDebuff:SetTexture("Interface\\Icons\\Spell_Shadow_ShadowWordPain")
	v.fakeDebuff:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	v.fakeHot = v.over:CreateTexture(nil, "OVERLAY")
	v.fakeHot:SetTexture("Interface\\Icons\\Spell_Nature_Rejuvenation")
	v.fakeHot:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	v.fakeDispel = U.Border(v.over, 2, 1, 1, 1, 1, "OVERLAY")
	btn.data = FakeData(i)
	fakes[i] = btn
	return btn
end

local function Render(btn)
	local d, v, A = btn.data, btn.visual, ns.db.appearance
	local r, g, b = U.ClassColor(d.class)

	v.health:SetMinMaxValues(0, 100)
	v.health:SetValue(d.dead and 0 or d.hp)
	if d.offline then
		v.health:SetStatusBarColor(0.35, 0.35, 0.35)
	elseif A.healthColor == "custom" then
		v.health:SetStatusBarColor(A.customHealthColor[1], A.customHealthColor[2], A.customHealthColor[3])
	elseif A.healthColor == "gradient" then
		local p = d.hp / 100
		if p < 0.5 then v.health:SetStatusBarColor(0.9, 0.2 + 1.2 * p, 0.2) else v.health:SetStatusBarColor(0.95 - 1.5 * (p - 0.5), 0.8, 0.2 + 0.3 * (p - 0.5)) end
	else
		v.health:SetStatusBarColor(r, g, b)
	end
	if A.dimWhenGone and d.offline then
		v.bg:SetVertexColor(0.18, 0.18, 0.18, A.backgroundColor[4])
	elseif A.dimWhenGone and d.dead then
		v.bg:SetVertexColor(0.30, 0.07, 0.07, A.backgroundColor[4])
	elseif A.backgroundMode == "class" then
		v.bg:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, A.backgroundColor[4])
	else
		v.bg:SetVertexColor(unpack(A.backgroundColor))
	end

	for _, bar in ipairs({ v.healBar, v.absorbBar, v.healAbsorbBar }) do bar:SetMinMaxValues(0, 100) end
	v.healBar:SetValue(math.min(d.heal, 100 - d.hp))
	v.absorbBar:SetValue(math.min(d.absorb, math.max(0, 100 - d.hp - d.heal)))
	v.healAbsorbBar:SetValue(0)
	v.healBar:SetShown(A.healPrediction and not d.dead)
	v.absorbBar:SetShown(A.absorbs and not d.dead)

	v.power:SetMinMaxValues(0, 100)
	v.power:SetValue(d.power)
	local pc = d.class == "WARRIOR" and { r = 0.78, g = 0.25, b = 0.25 } or (d.class == "ROGUE" and { r = 1, g = 0.96, b = 0.41 } or { r = 0, g = 0.55, b = 1 })
	v.power:SetStatusBarColor(pc.r, pc.g, pc.b)

	v.name:SetText(d.name:sub(1, A.nameLength))
	local dim = A.dimWhenGone and (d.dead or d.offline) and 0.55 or 1
	if A.nameClassColor then v.name:SetTextColor(r * dim, g * dim, b * dim) else v.name:SetTextColor(dim, dim, dim) end

	if d.offline then
		v.status:SetText(PLAYER_OFFLINE or "Offline"); v.status:Show(); v.healthText:Hide()
	elseif d.dead then
		v.status:SetText(DEAD or "Dead"); v.status:Show(); v.healthText:Hide()
	else
		v.status:Hide()
		if A.statusText == "percent" then
			v.healthText:SetFormattedText("%d%%", d.hp); v.healthText:Show(); v.healthText:SetAlpha(1)
		elseif A.statusText == "deficit" and d.hp < 100 then
			v.healthText:SetFormattedText("-%.1fk", (100 - d.hp) * 0.12); v.healthText:Show(); v.healthText:SetAlpha(1)
		else
			v.healthText:Hide()
		end
	end

	v:SetAlpha((ns.db.general.rangeFade and (d.outOfRange or d.offline)) and ns.db.general.rangeAlpha or 1)

	local coords = { TANK = { 0, 19 / 64, 22 / 64, 41 / 64 }, HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 }, DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 } }
	local c = coords[d.role]
	if A.roleIcon and c and not (d.role == "DAMAGER" and A.hideDamagerIcon) then
		v.role:SetTexCoord(c[1], c[2], c[3], c[4]); v.role:Show()
	else
		v.role:Hide()
	end
	v.leader:SetShown(A.leaderIcon and d.leader)
	v.raidIcon:SetShown(false)
	v.target:SetShown(false)
	v.aggro:SetShown(A.aggroBorder and d.role == "TANK")

	-- Fake auras following the aura settings
	local D = ns.db.auras
	local deb = D.debuffs
	v.fakeDebuff:SetSize(deb.size, deb.size)
	v.fakeDebuff:ClearAllPoints()
	v.fakeDebuff:SetPoint(deb.point, v.health, deb.point, deb.x, deb.y)
	v.fakeDebuff:SetShown(D.enabled and deb.enabled and d.debuff and not d.dead)
	local hot = D.buffs
	v.fakeHot:SetSize(hot.size, hot.size)
	v.fakeHot:ClearAllPoints()
	v.fakeHot:SetPoint(hot.point, v.health, hot.point, hot.x, hot.y)
	v.fakeHot:SetShown(D.enabled and hot.enabled and d.hot and not d.dead)
	local showDispel = D.enabled and D.dispel.enabled and d.dispel and not d.dead
	v.fakeDispel:SetShown(showDispel and true or false)
	if showDispel then
		local col = D.dispel.colors[d.dispel] or { 1, 1, 1, 1 }
		v.fakeDispel:SetColor(col[1], col[2], col[3], 1)
		v.fakeDispel:SetSize(D.dispel.thickness)
	end
end

-- Arrange fakes the same way the headers would.
local function Arrange()
	local raid = T.size > 5
	local key = raid and ((ns.db.general.largeRaidLayout and T.size > ns.db.general.largeRaidThreshold) and "raid40" or "raid") or "party"
	local L = ns.db.layouts[key]
	local anchor = ns.Mover:GetAnchor(raid and "raid" or "party")
	holder:ClearAllPoints()
	holder:SetPoint("TOPLEFT", anchor, "TOPLEFT")
	local horizontal = L.orientation == "HORIZONTAL"
	local perLine = (raid and L.mode == "groups") and 5 or (raid and (L.unitsPerColumn or 5) or 5)
	local groupGap = raid and L.groupSpacing or L.spacing
	local groupsPerLine = (raid and L.mode == "groups") and math.max(1, L.groupsPerLine or 8) or 99

	for i = 1, 40 do
		local btn = fakes[i] or MakeFake(i)
		if i <= T.size then
			btn.latticeLayout = L
			btn:SetSize(L.width, L.height)
			ns.Buttons:ApplyLayout(btn)
			local idx = i - 1
			local col = math.floor(idx / perLine)   -- which column (group)
			local row = idx % perLine               -- position inside it
			local line = math.floor(col / groupsPerLine)
			col = col % groupsPerLine
			local x, y
			if horizontal then
				x = row * (L.width + L.spacing) + line * (perLine * (L.width + L.spacing) + groupGap)
				y = -col * (L.height + groupGap)
			else
				x = col * (L.width + groupGap)
				y = -row * (L.height + L.spacing) - line * (perLine * (L.height + L.spacing) + groupGap)
			end
			btn:ClearAllPoints()
			btn:SetPoint("TOPLEFT", holder, "TOPLEFT", x, y)
			Render(btn)
			btn:Show()
		else
			btn:Hide()
		end
	end
end

function T:IsActive() return active end

function T:Start(size)
	if size then self.size = size end
	if not holder then
		holder = CreateFrame("Frame", nil, UIParent)
		holder:SetSize(1, 1)
		holder:SetFrameStrata("MEDIUM")
	end
	active = true
	holder:Show()
	Arrange()
	-- Hide the real frames while previewing so they don't overlap.
	ns.Headers:SetPreviewHidden(true)
end

function T:Stop()
	active = false
	self.manual = false
	if holder then holder:Hide() end
	ns.Headers:SetPreviewHidden(false)
end

function T:Toggle()
	if active then self:Stop() else self.manual = true; self:Start() end
end

function T:SetSize(n)
	self.size = n
	if active then Arrange() end
end

function T:Relayout()
	if active then Arrange() end
end
