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
	-- Aura filters: [spellID] = "show" (always show, first) | "hide" (never show).
	-- A default the user removed is stored as false so it doesn't come back.
	lists = {
		-- Always show (from anyone): cooldowns a healer wants to see
		[10060] = "show", -- Power Infusion
		[29166] = "show", -- Innervate
		[1022] = "show", [5599] = "show", [10278] = "show", -- Blessing of Protection
		[20707] = "show", [20762] = "show", [20763] = "show", [20764] = "show", [20765] = "show", -- Soulstone Resurrection
		-- Always show: raid debuffs that need action (only where the game allows it, see CanFilterDebuff)
		[20475] = "show", -- Living Bomb (Baron Geddon)
		[18173] = "show", -- Burning Adrenaline (Vaelastrasz)
		[23170] = "show", -- Brood Affliction: Bronze (Chromaggus)
		[24328] = "show", -- Corrupted Blood (Hakkar)
		[28169] = "show", -- Mutating Injection (Grobbulus)
		[27808] = "show", -- Frost Blast (Kel'Thuzad)
		[28410] = "show", -- Chains of Kel'Thuzad
		[27819] = "show", -- Detonate Mana (Kel'Thuzad)
		-- Never show: short procs and noise
		[16870] = "hide", [12536] = "hide", [16246] = "hide", -- Clearcasting (druid, mage, shaman)
		[12966] = "hide", [16257] = "hide", -- Flurry (warrior, shaman)
		[12880] = "hide", -- Enrage (warrior talent)
		[15271] = "hide", -- Spirit Tap
		[16886] = "hide", -- Nature's Grace
		[14893] = "hide", -- Inspiration
		[16177] = "hide", -- Ancestral Fortitude
		[11196] = "hide", -- Recently Bandaged
		[15007] = "hide", -- Resurrection Sickness
	},
}

A.LIST_MODES = { show = "Always show", hide = "Never show" }

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

local function AddGroup(c, key, filter, max, init, sortMethod, candidate, order)
	c:AddAuraGroup(key, filter, {
		maxFrameCount = max,
		initializeFrame = init,
		sortMethod = sortMethod or AuraContainerSortMethod.Default,
		candidateFilters = candidate,
		layout = { elementSpacing = 1, lineSpacing = 1, layoutIndex = order },
	})
end

-- One flowing row of icons. Spells on the "always show" list come first (from
-- anyone); the normal group skips both listed and hidden spells.
local function AddGroupContainer(btn, key, filter, cfg, init, sortMethod, lists, listedFilter)
	local c = NewContainer(btn)
	c:ClearAllPoints()
	c:SetPoint(cfg.point, btn.visual.health, cfg.point, cfg.x or 0, cfg.y or 0)
	ConfigureFlow(c, cfg.point, cfg.grow)
	if lists.show then
		AddGroup(c, key .. "Listed", listedFilter, cfg.max, init, sortMethod, { includeSpellIDs = lists.show }, 1)
	end
	AddGroup(c, key, filter, cfg.max, init, sortMethod, lists.skip and { excludeSpellIDs = lists.skip } or nil, 2)
	return c
end

------------------------------------------------------------------------
-- Aura filters (always show / never show)
------------------------------------------------------------------------
-- Turn the saved list into the spell-ID sets the containers take.
-- Returns { show = {[id]=true} | nil, hide = ... | nil, skip = show+hide | nil }.
function A.ListSets(lists)
	local show, hide, skip = {}, {}, {}
	for key, mode in pairs(lists or {}) do
		local id = tonumber(key)
		if id and mode == "show" then show[id] = true; skip[id] = true end
		if id and mode == "hide" then hide[id] = true; skip[id] = true end
	end
	return { show = next(show) and show or nil, hide = next(hide) and hide or nil, skip = next(skip) and skip or nil }
end

function A:ListMode(id)
	local m = ns.db.auras.lists[tonumber(id) or id]
	return (m == "show" or m == "hide") and m or nil
end

-- mode: "show" | "hide" | nil (remove). Rebuilds containers out of combat.
function A:SetListMode(id, mode, noRefresh)
	id = tonumber(id)
	if not id or id < 1 or id ~= math.floor(id) then return false end
	local lists = ns.db.auras.lists
	if mode == "show" or mode == "hide" then
		lists[id] = mode
	elseif ns.Defaults.auras.lists[id] ~= nil then
		lists[id] = false -- remember that a default was removed
	else
		lists[id] = nil
	end
	if not noRefresh then self:Refresh() end
	return true
end

-- Sorted entries for the options page: { id, mode, name }.
function A:ListEntries(mode)
	local out = {}
	for id, m in pairs(ns.db.auras.lists) do
		if m == mode then
			out[#out + 1] = { id = id, mode = m, name = ns.ClickCast.SpellName(id) or ("Spell " .. id) }
		end
	end
	table.sort(out, function(a, b)
		if a.name ~= b.name then return a.name < b.name end
		return a.id < b.id
	end)
	return out
end

function A:ResetLists()
	ns.db.auras.lists = U.CopyTable(ns.Defaults.auras.lists)
	self:Refresh()
end

-- Debuffs on friendly players can only be filtered by spell ID when the game
-- marks the spell "never secret" (Blizzard's rule). true / false / nil (unknown).
function A:CanFilterDebuff(id)
	if not (C_Secrets and C_Secrets.GetSpellAuraSecrecy) then return nil end
	local ok, level = pcall(C_Secrets.GetSpellAuraSecrecy, id)
	if not ok or S.IsSecret(level) or level == nil then return nil end
	local never = Enum.SecrecyLevel and Enum.SecrecyLevel.NeverSecret or 0
	return level == never
end

-- Plain-text export: one "show <id> <name>" / "hide <id> <name>" per line.
function A:ExportLists()
	local lines = { "# Lattice aura filters: show = always show, hide = never show" }
	for _, mode in ipairs({ "show", "hide" }) do
		for _, e in ipairs(self:ListEntries(mode)) do
			lines[#lines + 1] = string.format("%s %d %s", mode, e.id, e.name)
		end
	end
	return table.concat(lines, "\n")
end

local MODE_WORDS = { show = "show", always = "show", whitelist = "show", hide = "hide", never = "hide", blacklist = "hide" }

-- Reads the export format back. Also accepts spell names ("hide Flurry") when
-- the name can be looked up. replace = start from an empty list.
-- Returns the number of entries read and the lines that couldn't be read.
function A:ImportLists(text, replace)
	local changes, bad = {}, {}
	for raw in (text or ""):gmatch("[^\r\n]+") do
		local line = raw:gsub("#.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
		if line ~= "" then
			local word, rest = line:match("^(%a+)%s+(.+)$")
			local mode = word and MODE_WORDS[word:lower()]
			local ids = {}
			if mode then
				local num = tonumber(rest:match("^(%d+)"))
				if num then ids = { num } else ids = self:ResolveSpells(rest) end
			end
			if mode and #ids > 0 then
				for _, id in ipairs(ids) do changes[#changes + 1] = { id, mode } end
			else
				bad[#bad + 1] = raw
			end
		end
	end
	if replace and #changes > 0 then
		local ids = {}
		for id in pairs(ns.db.auras.lists) do ids[#ids + 1] = id end
		for _, id in ipairs(ids) do self:SetListMode(id, nil, true) end
	end
	for _, c in ipairs(changes) do self:SetListMode(c[1], c[2], true) end
	self:Refresh()
	return #changes, bad
end

-- The auras a player has right now, for the picker. Out of combat only (addons
-- can't read auras in combat). Returns a list, or nil and a reason.
function A:CurrentAuras(unit)
	if not unit or not UnitExists(unit) then return nil, "Nobody to read auras from." end
	if not ns.Roles.AurasReadable() then return nil, "Auras can't be read in combat." end
	local byIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	if not byIndex then return nil, "This client can't list auras." end
	local out, seen = {}, {}
	for _, filter in ipairs({ "HARMFUL", "HELPFUL" }) do
		for i = 1, 40 do
			local ok, data = pcall(byIndex, unit, i, filter)
			if not ok or type(data) ~= "table" then break end
			local id = S.Plain(data.spellId, nil)
			if id and not seen[id] then
				seen[id] = true
				out[#out + 1] = {
					id = id, harmful = filter == "HARMFUL",
					name = S.Plain(data.name, nil) or ns.ClickCast.SpellName(id) or ("Spell " .. id),
					icon = S.Plain(data.icon, nil),
				}
			end
		end
	end
	return out
end

function A:BuildContainers(btn)
	local D = ns.db.auras
	local set = {}
	local v = btn.visual
	local lists = A.ListSets(D.lists)
	-- Hidden spells are skipped everywhere (boss slot, dispel highlight, defensives too).
	local function hidden(extra)
		if not lists.hide then return extra end
		extra = extra or {}
		extra.excludeSpellIDs = lists.hide
		return extra
	end

	if D.debuffs.enabled then
		local cfg = D.debuffs
		local c = AddGroupContainer(btn, "debuffs", "HARMFUL", cfg, DebuffInit(cfg.size, cfg.swipe, cfg.stacks),
			AuraContainerSortMethod.UnitFrameDebuff, lists, "HARMFUL")
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
			AuraContainerSortMethod.ExpirationOnly, lists, "HELPFUL")
	end

	-- One container for all manually-anchored slots.
	local slots = NewContainer(btn)
	slots:SetAllPoints(v.health)
	local anySlot = false

	if D.dispel.enabled then
		local filter = D.dispel.onlyMine and "HARMFUL|RAID" or "HARMFUL|RAID_PLAYER_DISPELLABLE"
		slots:AddAuraSlot("dispel", filter, { initializeFrame = DispelInit(v), candidateFilters = hidden() })
		anySlot = true
	end

	if D.boss.enabled then
		local cfg = D.boss
		slots:AddAuraSlot("boss", "HARMFUL", {
			candidateFilters = hidden({ isBossOrRoleAura = true }),
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
			candidateFilters = hidden(),
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
function A:ResolveSpells(text, knownOnly)
	local ids, seen = {}, {}
	local function add(id)
		if type(id) == "number" and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
	end
	for piece in (text or ""):gmatch("[^,;]+") do
		local token = piece:gsub("^%s+", ""):gsub("%s+$", "")
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
			if not knownOnly and C_Spell and C_Spell.GetSpellInfo then
				local info = C_Spell.GetSpellInfo(token)
				if info and info.spellID then add(info.spellID) end
			end
		end
	end
	return ids
end

function A:AddIndicator(name, spells, extra, noRefresh)
	local list = ns.db.auras.indicators
	local ind = {
		enabled = true, name = name, spells = spells, mine = true,
		point = "TOPLEFT", x = 2, y = -2, size = 8, style = "square",
		color = { 0.3, 1, 0.4, 1 }, swipe = false,
	}
	for k, v in pairs(extra or {}) do ind[k] = v end
	list[#list + 1] = ind
	if not noRefresh then self:Refresh() end
	return #list
end

------------------------------------------------------------------------
-- Class presets: the HoTs and shields a healer usually tracks, as small
-- coloured squares along the top edge. Only spells you know are added.
------------------------------------------------------------------------
local PRESET_SLOTS = {
	{ point = "TOP", x = -12, y = -2, color = { 0.30, 1.00, 0.40, 1 } },
	{ point = "TOP", x = 0,   y = -2, color = { 1.00, 0.85, 0.20, 1 } },
	{ point = "TOP", x = 12,  y = -2, color = { 0.35, 0.65, 1.00, 1 } },
	{ point = "TOP", x = 24,  y = -2, color = { 1.00, 0.45, 0.85, 1 } },
}

A.PRESETS = {
	PRIEST  = { "Renew", "Power Word: Shield", "Prayer of Mending", "Fear Ward" },
	DRUID   = { "Rejuvenation", "Regrowth", "Lifebloom", "Wild Growth" },
	SHAMAN  = { "Earth Shield", "Riptide", "Water Shield" },
	PALADIN = { "Beacon of Light", "Sacred Shield", "Blessing of Protection" },
	MONK    = { "Renewing Mist", "Enveloping Mist", "Soothing Mist" },
	EVOKER  = { "Reversion", "Echo", "Dream Breath" },
}

-- Returns the names added and the names skipped (not in your spellbook).
function A:AddClassPresets()
	local _, class = UnitClass("player")
	local names = self.PRESETS[class]
	if not names then return {}, {} end
	local have = {}
	for _, ind in ipairs(ns.db.auras.indicators) do
		if ind.name then have[ind.name:lower()] = true end
	end
	local added, skipped, slot = {}, {}, 0
	for _, name in ipairs(names) do
		if not have[name:lower()] then
			local ids = self:ResolveSpells(name, true)
			if #ids > 0 and slot < #PRESET_SLOTS then
				slot = slot + 1
				local p = PRESET_SLOTS[slot]
				self:AddIndicator(name, ids, { point = p.point, x = p.x, y = p.y, color = p.color }, true)
				added[#added + 1] = name
			else
				skipped[#skipped + 1] = name
			end
		end
	end
	if #added > 0 then self:Refresh() end
	return added, skipped
end
