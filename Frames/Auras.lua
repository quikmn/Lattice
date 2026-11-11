-- Lattice: aura indicators via Blizzard's CustomAuraContainer (Forever 1.60.1).
--
-- In combat, addon code may not read aura data at all. Blizzard's AuraContainer
-- lets us *declare* what to show (filter strings + candidate filters) and gives
-- it our own icon/cooldown/text regions; secure code fills them in, in combat too.
--
-- Constraints honoured here:
--  * All per-button styling happens inside initializeFrame (buttons get locked after).
--  * Containers can't be restyled later, so a style change builds fresh containers
--    (out of combat) and disables the old ones.
--  * Spell-ID matching works for helpful auras on group members (HoTs/buffs),
--    not for debuffs on friendly units (Blizzard blocks that on purpose).
local _, ns = ...
local U, S = ns.Util, ns.Secret
local A = {}
ns.Auras = A

A.rev = 1 -- bump to force containers to be rebuilt

local DISPEL_TYPES = { "Magic", "Curse", "Poison", "Disease", "Bleed" }
A.DISPEL_TYPES = DISPEL_TYPES

ns.Defaults.auras = {
	enabled = true,
	tooltips = false,          -- aura icons capture the mouse if on (blocks click-casting under them)

	debuffs = { enabled = true, max = 3, size = 16, point = "BOTTOMLEFT", x = 2, y = 2, grow = "RIGHT",
		onlyDispellable = false, swipe = true, stacks = true },
	buffs   = { enabled = true, max = 3, size = 14, point = "TOPRIGHT", x = -2, y = -2, grow = "LEFT",
		source = "mine", swipe = true, stacks = true },  -- mine = my HoTs/buffs, all = raid buffs
	boss    = { enabled = true, size = 20, point = "CENTER", x = 0, y = 0 },
	defensive = { enabled = true, size = 16, point = "LEFT", x = 2, y = 0 },
	dispel  = { enabled = true, style = "border", onlyMine = true, thickness = 2,
		colors = {
			Magic   = { 0.20, 0.60, 1.00, 1 },
			Curse   = { 0.60, 0.00, 1.00, 1 },
			Poison  = { 0.00, 0.70, 0.20, 1 },
			Disease = { 0.70, 0.45, 0.00, 1 },
			Bleed   = { 0.90, 0.10, 0.10, 1 },
		} },
	-- Grid2-style spell indicators: { name, spells = {ids}, mine, point, size, style = square|icon, color, swipe }
	indicators = {},
}

------------------------------------------------------------------------
-- Availability
------------------------------------------------------------------------
function A:Available()
	if self.available ~= nil then return self.available end
	local ok = pcall(function()
		local probe = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
		assert(probe and probe.AddAuraSlot)
		probe:Hide()
		self.probe = probe
	end)
	self.available = ok
	if not ok and ns.db.debug then ns:Print("Aura containers unavailable on this client; aura indicators disabled.") end
	return ok
end

------------------------------------------------------------------------
-- Frame initializers (run once per aura button, before Blizzard locks it)
------------------------------------------------------------------------
local function NoMouse(b)
	if not ns.db.auras.tooltips then
		pcall(b.EnableMouse, b, false)
	end
end

local function AddCooldown(b, reverse)
	local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	cd:SetAllPoints()
	cd:SetReverse(reverse and true or false)
	cd:SetDrawEdge(false)
	if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
	b:SetDurationCooldown(cd)
	return cd
end

local function AddStacks(b, size)
	local n = b:CreateFontString(nil, "OVERLAY")
	U.SetFont(n, math.max(8, math.floor(size * 0.6)), "OUTLINE")
	n:SetPoint("BOTTOMRIGHT", 2, -1)
	b:SetApplicationCount(n)
end

local function IconInit(size, swipe, stacks)
	return function(b)
		b:SetSize(size, size)
		NoMouse(b)
		local bg = b:CreateTexture(nil, "BACKGROUND")
		bg:SetTexture(U.WHITE)
		bg:SetVertexColor(0, 0, 0, 1)
		bg:SetPoint("TOPLEFT", -1, 1)
		bg:SetPoint("BOTTOMRIGHT", 1, -1)
		local icon = b:CreateTexture(nil, "ARTWORK")
		icon:SetAllPoints()
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		b:SetIcon(icon)
		if swipe then AddCooldown(b, true) end
		if stacks then AddStacks(b, size) end
	end
end

-- Debuff icons also get a thin dispel-coloured frame.
local function DebuffInit(size, swipe, stacks)
	local base = IconInit(size, swipe, stacks)
	return function(b)
		base(b)
		if b.AddDispelTypeTexture then
			local edge = b:CreateTexture(nil, "BORDER")
			edge:SetTexture(U.WHITE)
			edge:SetPoint("TOPLEFT", -1, 1)
			edge:SetPoint("BOTTOMRIGHT", 1, -1)
			pcall(b.AddDispelTypeTexture, b, edge, A:DispelTextureOptions(true))
		end
	end
end

local function SquareInit(size, color, swipe)
	return function(b)
		b:SetSize(size, size)
		NoMouse(b)
		local border = b:CreateTexture(nil, "BACKGROUND")
		border:SetTexture(U.WHITE)
		border:SetVertexColor(0, 0, 0, 1)
		border:SetPoint("TOPLEFT", -1, 1)
		border:SetPoint("BOTTOMRIGHT", 1, -1)
		local sq = b:CreateTexture(nil, "ARTWORK")
		sq:SetTexture(U.WHITE)
		sq:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
		sq:SetAllPoints()
		if swipe then AddCooldown(b, true) end
	end
end

function A:DispelTextureOptions(forIcon)
	local map = {}
	for _, t in ipairs(DISPEL_TYPES) do
		local c = ns.db.auras.dispel.colors[t]
		if c then map[t] = CreateColor(c[1], c[2], c[3], c[4] or 1) end
	end
	map.None = CreateColor(0, 0, 0, forIcon and 1 or 0)
	local style = Enum.CustomAuraButtonDispelTypeTextureStyle
	return {
		style = style and style.PreserveAsset or nil,
		showWhenHarmful = true,
		customDispelColorMap = map,
	}
end

-- Dispel highlight: the slot frame covers the health bar; its textures are
-- recoloured by the secure code according to the debuff's dispel type.
local function DispelInit(btnVisual)
	local D = ns.db.auras.dispel
	return function(b)
		NoMouse(b)
		b:ClearAllPoints()
		b:SetAllPoints(btnVisual)
		local opts = A:DispelTextureOptions(false)
		local function tex(layer)
			local t = b:CreateTexture(nil, layer or "OVERLAY")
			t:SetTexture(U.WHITE)
			pcall(b.AddDispelTypeTexture, b, t, opts)
			return t
		end
		if D.style == "overlay" then
			local t = tex("ARTWORK")
			t:SetAllPoints()
			t:SetAlpha(0.35)
		elseif D.style == "icon" then
			b:ClearAllPoints()
			b:SetSize(14, 14)
			b:SetPoint("TOPRIGHT", btnVisual, "TOPRIGHT", -2, -2)
			local t = tex("ARTWORK")
			t:SetAllPoints()
		else -- border
			local th = D.thickness
			local top = tex(); top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(th)
			local bot = tex(); bot:SetPoint("BOTTOMLEFT"); bot:SetPoint("BOTTOMRIGHT"); bot:SetHeight(th)
			local lft = tex(); lft:SetPoint("TOPLEFT"); lft:SetPoint("BOTTOMLEFT"); lft:SetWidth(th)
			local rgt = tex(); rgt:SetPoint("TOPRIGHT"); rgt:SetPoint("BOTTOMRIGHT"); rgt:SetWidth(th)
		end
	end
end

------------------------------------------------------------------------
-- Container construction
------------------------------------------------------------------------
local GROW = {
	RIGHT = { 1, -1, 0 }, LEFT = { -1, -1, 0 },   -- horizontal axis
	UP    = { 1, 1, 1 },  DOWN = { 1, -1, 1 },    -- vertical axis
}

local function NewContainer(btn)
	local c = CreateFrame("AuraContainer", nil, btn.visual.over, "CustomAuraContainerTemplate")
	if c.SetEditModePreviewEnabled then pcall(c.SetEditModePreviewEnabled, c, false) end
	return c
end

local function ConfigureFlow(c, point, grow)
	local g = GROW[grow] or GROW.RIGHT
	local FD = AnchorUtil and AnchorUtil.FlowDirection
	local FA = AnchorUtil and AnchorUtil.FlowLayoutAxis
	if FA then c:SetFlowLayoutAxis(g[3] == 1 and FA.Vertical or FA.Horizontal) end
	c:SetFlowLayoutAnchorPoint(point)
	if FD then
		local h = g[1] == 1 and FD.Right or FD.Left
		local v = g[2] == 1 and FD.Up or FD.Down
		c:SetFlowLayoutGrowthDirection(h, v)
	end
end

local function AddGroupContainer(btn, key, filter, cfg, init, sortMethod, candidate)
	local c = NewContainer(btn)
	c:ClearAllPoints()
	c:SetPoint(cfg.point, btn.visual.health, cfg.point, cfg.x or 0, cfg.y or 0)
	ConfigureFlow(c, cfg.point, cfg.grow)
	c:AddAuraGroup(key, filter, {
		maxFrameCount = cfg.max,
		initializeFrame = init,
		sortMethod = sortMethod or AuraContainerSortMethod.Default,
		candidateFilters = candidate,
		layout = { elementSpacing = 1, lineSpacing = 1 },
	})
	return c
end

function A:BuildContainers(btn)
	local D = ns.db.auras
	local set = {}
	local v = btn.visual

	if D.debuffs.enabled then
		local cfg = D.debuffs
		local c = AddGroupContainer(btn, "debuffs", "HARMFUL", cfg, DebuffInit(cfg.size, cfg.swipe, cfg.stacks),
			AuraContainerSortMethod.UnitFrameDebuff)
		if cfg.onlyDispellable and c.SetAuraProcessingPolicy and CustomAuraContainerAuraProcessingPolicy then
			c:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.ProcessAura, { displayOnlyDispellableDebuffs = true })
		end
		set[#set + 1] = c
	end

	if D.buffs.enabled then
		local cfg = D.buffs
		-- RAID_IN_COMBAT relies on a per-spell "show on raid frames" flag that classic-era
		-- spells (Renew, Rejuvenation) may not carry on Forever, so it hid them.
		local filter = cfg.source == "all" and "HELPFUL" or "HELPFUL|PLAYER"
		set[#set + 1] = AddGroupContainer(btn, "buffs", filter, cfg, IconInit(cfg.size, cfg.swipe, cfg.stacks),
			AuraContainerSortMethod.ExpirationOnly)
	end

	-- One container for all manually-anchored slots.
	local slots = NewContainer(btn)
	slots:SetAllPoints(v.health)
	local anySlot = false

	if D.dispel.enabled then
		local filter = D.dispel.onlyMine and "HARMFUL|RAID" or "HARMFUL|RAID_PLAYER_DISPELLABLE"
		slots:AddAuraSlot("dispel", filter, { initializeFrame = DispelInit(v) })
		anySlot = true
	end

	if D.boss.enabled then
		local cfg = D.boss
		slots:AddAuraSlot("boss", "HARMFUL", {
			candidateFilters = { isBossOrRoleAura = true },
			sortMethod = AuraContainerSortMethod.UnitFrameDebuff,
			initializeFrame = function(b)
				IconInit(cfg.size, true, true)(b)
				b:ClearAllPoints()
				b:SetPoint(cfg.point, v.health, cfg.point, cfg.x, cfg.y)
			end,
		})
		anySlot = true
	end

	if D.defensive.enabled then
		local cfg = D.defensive
		slots:AddAuraSlot("defensive", "HELPFUL|BIG_DEFENSIVE", {
			sortMethod = AuraContainerSortMethod.BigDefensive,
			initializeFrame = function(b)
				IconInit(cfg.size, true, false)(b)
				b:ClearAllPoints()
				b:SetPoint(cfg.point, v.health, cfg.point, cfg.x, cfg.y)
			end,
		})
		anySlot = true
	end

	for i, ind in ipairs(D.indicators) do
		if ind.enabled ~= false and ind.spells and #ind.spells > 0 then
			local ids = {}
			for _, id in ipairs(ind.spells) do ids[id] = true end
			local init = ind.style == "icon" and IconInit(ind.size, ind.swipe, true) or SquareInit(ind.size, ind.color, ind.swipe)
			slots:AddAuraSlot("ind" .. i, ind.mine and "HELPFUL|PLAYER" or "HELPFUL", {
				candidateFilters = { includeSpellIDs = ids },
				initializeFrame = function(b)
					init(b)
					b:ClearAllPoints()
					b:SetPoint(ind.point, v.health, ind.point, ind.x or 0, ind.y or 0)
				end,
			})
			anySlot = true
		end
	end

	if anySlot then
		set[#set + 1] = slots
	else
		slots:Hide()
	end
	return set
end

------------------------------------------------------------------------
-- Button hooks (called from Buttons)
------------------------------------------------------------------------
function A:Build(btn)
	btn.auraContainers = {}
end

local function DisableSet(set)
	for _, c in ipairs(set or {}) do
		pcall(c.SetEnabled, c, false)
		c:Hide()
	end
end

-- (Re)build this button's containers if settings changed. Out of combat only.
function A:Layout(btn)
	if btn.fake then return end
	if btn.auraRev == self.rev then return end
	if InCombatLockdown() then return end
	-- Built lazily: only buttons that actually show a player get containers.
	if not btn.unit and not btn.auraContainers[1] then return end
	if not ns.db.auras.enabled or not self:Available() then
		DisableSet(btn.auraContainers)
		btn.auraContainers = {}
		btn.auraRev = self.rev
		return
	end
	DisableSet(btn.auraContainers)
	local ok, set = pcall(self.BuildContainers, self, btn)
	if not ok then
		self.lastError = tostring(set)
		if ns.db.debug then ns:Print("Aura setup failed: " .. tostring(set)) end
		set = {}
	end
	btn.auraContainers = set
	btn.auraRev = self.rev
	self:SetUnit(btn, btn.unit)
end

function A:SetUnit(btn, unit)
	for _, c in ipairs(btn.auraContainers or {}) do
		pcall(function()
			if unit then
				c:SetUnit(unit)
				c:SetEnabled(true)
			else
				c:SetEnabled(false)
			end
		end)
	end
end

function A:Update(btn)
	if btn.fake then return end
	if btn.auraRev ~= self.rev and btn.unit and not InCombatLockdown() then
		self:Layout(btn) -- also sets the unit
		btn.auraUnit = btn.unit
		return
	end
	if btn.auraUnit ~= btn.unit then
		btn.auraUnit = btn.unit
		self:SetUnit(btn, btn.unit)
	end
end

-- Settings changed: rebuild every button's containers (deferred if in combat).
function A:Refresh()
	self.rev = self.rev + 1
	ns:RunOutOfCombat("auras-refresh", function()
		for _, btn in ipairs(ns.Buttons.all) do self:Layout(btn) end
		if ns.TestMode then ns.TestMode:Relayout() end
	end)
end

-- Buttons that got a player during combat build their containers afterwards.
ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if not ns.Buttons then return end
	for _, btn in ipairs(ns.Buttons.all) do
		if btn.unit and btn.auraRev ~= A.rev then A:Layout(btn) end
	end
end)

------------------------------------------------------------------------
-- Spell lookup for indicator setup (spell info is never secret)
------------------------------------------------------------------------
-- Accepts "774, 8936" or "Rejuvenation". For names, every rank in the player's
-- spellbook is included (Forever keeps separate IDs per rank).
function A:ResolveSpells(text)
	local ids, seen = {}, {}
	local function add(id)
		if id and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
	end
	for token in (text or ""):gmatch("[^,;]+") do
		token = token:gsub("^%s+", ""):gsub("%s+$", "")
		local num = tonumber(token)
		if num then
			add(num)
		elseif token ~= "" then
			local lower = token:lower()
			if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
				local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
				for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
					local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
					if info then
						for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
							local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
							if item and item.spellID and item.name and item.name:lower() == lower then
								add(item.spellID)
							end
						end
					end
				end
			end
			if C_Spell and C_Spell.GetSpellInfo then
				local info = C_Spell.GetSpellInfo(token)
				if info and info.spellID then add(info.spellID) end
			end
		end
	end
	return ids
end

function A:AddIndicator(name, spells)
	local list = ns.db.auras.indicators
	list[#list + 1] = {
		enabled = true, name = name, spells = spells, mine = true,
		point = "TOPLEFT", x = 2, y = -2, size = 8, style = "square",
		color = { 0.3, 1, 0.4, 1 }, swipe = false,
	}
	self:Refresh()
	return #list
end
