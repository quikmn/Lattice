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
	countdown = false,         -- seconds left as numbers on buff, debuff, boss and defensive icons

	debuffs = { enabled = true, max = 3, size = 16, point = "BOTTOMLEFT", x = 2, y = 2, grow = "AUTO",
		onlyDispellable = false, swipe = true, stacks = true,
		hideLong = true },  -- skip long debuffs nobody can dispel (Boosted Rest, an hour-long lockout); dispellable ones always show
	buffs   = { enabled = true, max = 3, size = 14, point = "TOPRIGHT", x = -2, y = -2, grow = "AUTO",
		source = "mine", swipe = true, stacks = true,  -- mine = my HoTs/buffs, all = raid buffs
		hideLong = true },  -- skip buffs that last over LONG_BUFF seconds (Fortitude, Mark of the Wild): HoTs and shields stay
	-- the long class buffs (Fortitude, Mark of the Wild...) in their own row beside the frame, from anyone; party only
	-- unless inRaid. side = RIGHT | LEFT (outside the frame).
	-- which: "mine" (buffs you can cast) | "all" | "pick" (the families ticked in pick); extra = more spell IDs
	raidbuffs = { enabled = true, side = "LEFT", size = 18, max = 6, inRaid = false, which = "mine",
		pick = { fortitude = true, spirit = true, shadow = true, wild = true, intellect = true,
			might = true, wisdom = true, kings = true, light = true },
		extra = {} },
	missingBuff = true, -- mark players missing your class's long buff (Modules/MissingBuff.lua)
	boss    = { enabled = true, size = 20, point = "CENTER", x = 0, y = 0 },
	defensive = { enabled = true, size = 16, point = "LEFT", x = 2, y = 0 },
	-- icon: a big icon of the debuff you can dispel in the middle of the frame, edged in its type's colour, pulsing
	dispel  = { enabled = true, style = "border", onlyMine = true, thickness = 2,
		icon = true, iconSize = 24, iconPulse = true,
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
		[6346] = "show", -- Fear Ward (10 minutes: "Hide long buffs" would drop it from the buff row)
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
		-- Never show: tracking (it shows on everyone who has it on)
		[2383] = "hide", [8387] = "hide", -- Find Herbs
		[2580] = "hide", [8388] = "hide", -- Find Minerals
		[2481] = "hide", -- Find Treasure
		[43308] = "hide", -- Find Fish
		[1494] = "hide", [1284017] = "hide", -- Track Beasts
		[5225] = "hide", [19883] = "hide", -- Track Humanoids
		[5500] = "hide", -- Sense Demons
		[5502] = "hide", [5503] = "hide", [1241115] = "hide", -- Sense Undead
		-- Never show: WoW Forever world buffs and lockouts
		[460939] = "hide", [460940] = "hide", [1304678] = "hide", -- Might of Stormwind
		[1229451] = "hide", -- Boosted Rest (camp tent lockout)
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

-- countdown: the client draws the seconds left (the duration itself is hidden from us in combat), sized to the icon.
local function AddCooldown(b, reverse, countdown, size)
	local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	cd:SetAllPoints()
	cd:SetReverse(reverse and true or false)
	cd:SetDrawEdge(false)
	if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(not countdown) end
	if countdown and cd.GetCountdownFontString then pcall(function()
		local fs = cd:GetCountdownFontString()
		if fs then U.SetFont(fs, math.max(8, math.floor((size or 16) * 0.55)), "OUTLINE") end
	end) end
	b:SetDurationCooldown(cd)
	return cd
end

local function AddStacks(b, size)
	local n = b:CreateFontString(nil, "OVERLAY")
	U.SetFont(n, math.max(8, math.floor(size * 0.6)), "OUTLINE")
	n:SetPoint("BOTTOMRIGHT", 2, -1)
	b:SetApplicationCount(n)
end

local function IconInit(size, swipe, stacks, countdown)
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
		if swipe or countdown then
			local cd = AddCooldown(b, true, countdown, size)
			if not swipe and cd.SetDrawSwipe then cd:SetDrawSwipe(false) end
		end
		if stacks then AddStacks(b, size) end
	end
end

-- Raid buff icons sit outside the frame, so they never block click-casting: they always take the mouse (tooltip
-- with the time left) and a clock sweep for the time left.
local function RaidBuffInit(size)
	return function(b)
		b:SetSize(size, size)
		pcall(b.EnableMouse, b, true)
		if b.SetMouseClickEnabled then pcall(b.SetMouseClickEnabled, b, false) end
		if b.SetTooltipAnchorPoint then pcall(b.SetTooltipAnchorPoint, b, "ANCHOR_BOTTOMLEFT") end
		local bg = b:CreateTexture(nil, "BACKGROUND")
		bg:SetTexture(U.WHITE)
		bg:SetVertexColor(0, 0, 0, 1)
		bg:SetPoint("TOPLEFT", -1, 1)
		bg:SetPoint("BOTTOMRIGHT", 1, -1)
		local icon = b:CreateTexture(nil, "ARTWORK")
		icon:SetAllPoints()
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		b:SetIcon(icon)
		-- clock sweep over the icon: how much of the buff is used up, nearly black so it reads at this size
		local cd = AddCooldown(b, true)
		if cd.SetSwipeColor then pcall(cd.SetSwipeColor, cd, 0, 0, 0, 0.92) end
	end
end

-- Debuff icons also get a thin dispel-coloured frame.
local function DebuffInit(size, swipe, stacks, countdown)
	local base = IconInit(size, swipe, stacks, countdown)
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

-- Big dispel icon: the debuff's icon with a thick edge in its dispel colour, and a soft pulse around it so it
-- catches the eye. The colours come from the client (the debuff's type is hidden from us in combat).
local function DispelIconInit(health, size, pulse)
	return function(b)
		b:SetSize(size, size)
		NoMouse(b)
		b:ClearAllPoints()
		b:SetPoint("CENTER", health, "CENTER", 0, 0)
		if b.SetFrameLevel then b:SetFrameLevel(b:GetFrameLevel() + 6) end
		local opts = A:DispelTextureOptions(true)
		local edge = b:CreateTexture(nil, "BACKGROUND")
		edge:SetTexture(U.WHITE)
		edge:SetPoint("TOPLEFT", -2, 2)
		edge:SetPoint("BOTTOMRIGHT", 2, -2)
		local icon = b:CreateTexture(nil, "ARTWORK")
		icon:SetAllPoints()
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		b:SetIcon(icon)
		if b.AddDispelTypeTexture then pcall(b.AddDispelTypeTexture, b, edge, opts) end
		AddCooldown(b, true)
		if pulse then pcall(function()
			-- the glow lives on its own frame so its alpha can be animated
			local holder = CreateFrame("Frame", nil, b)
			holder:SetPoint("TOPLEFT", -6, 6)
			holder:SetPoint("BOTTOMRIGHT", 6, -6)
			holder:SetFrameLevel(math.max(0, b:GetFrameLevel() - 1))
			local glow = holder:CreateTexture(nil, "BACKGROUND")
			glow:SetTexture(U.WHITE)
			glow:SetAllPoints()
			if b.AddDispelTypeTexture then pcall(b.AddDispelTypeTexture, b, glow, opts) end
			local ag = holder:CreateAnimationGroup()
			ag:SetLooping("BOUNCE")
			local a = ag:CreateAnimation("Alpha")
			a:SetFromAlpha(0.15)
			a:SetToAlpha(0.65)
			a:SetDuration(0.6)
			a:SetSmoothing("IN_OUT")
			holder:SetAlpha(0.15)
			ag:Play()
		end) end
	end
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
		if D.style == "overlay" or D.style == "both" then
			local t = tex("ARTWORK")
			t:SetAllPoints()
			t:SetAlpha(D.style == "both" and 0.22 or 0.35)
		end
		if D.style == "overlay" then
			return
		elseif D.style == "icon" then
			b:ClearAllPoints()
			b:SetSize(14, 14)
			b:SetPoint("TOPRIGHT", btnVisual, "TOPRIGHT", -2, -2)
			local t = tex("ARTWORK")
			t:SetAllPoints()
		else -- border (and "both")
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

-- grow "AUTO" (the default): icons in a corner grow into the frame: a left corner grows right, a right corner left. Growing the other way puts
-- them outside the frame, under the raid buff row (left) or off to the side, where they can't be seen.
function A.InwardGrow(point)
	return point and point:find("RIGHT") and "LEFT" or "RIGHT"
end

local function ConfigureFlow(c, point, grow)
	local g = GROW[(grow == nil or grow == "AUTO") and A.InwardGrow(point) or grow] or GROW.RIGHT
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
local LONG_BUFF = 601   -- 10 minutes: Thorns, Inner Fire and Fear Ward stay; hour-long buffs (Fortitude, Mark) go

-- Big defensives (Classic): the game's BIG_DEFENSIVE flag lets ordinary buffs through on Forever (Arcane Intellect,
-- Find Herbs), so the slot only shows these. Spells the game won't let addons check by ID simply don't show.
local BIG_DEFENSIVES = {}
for _, id in ipairs({
	871, -- Shield Wall
	12975, 12976, -- Last Stand
	5277, -- Evasion
	642, 1020, -- Divine Shield
	498, 5573, -- Divine Protection
	1022, 5599, 10278, -- Blessing of Protection
	11958, -- Ice Block
	19263, -- Deterrence
	22812, -- Barkskin
	22842, 22845, -- Frenzied Regeneration
}) do BIG_DEFENSIVES[id] = true end
A.BIG_DEFENSIVES = BIG_DEFENSIVES
local LONG_DEBUFF = 600

-- The long class buffs, every rank in the Forever client (EverlookDB spells table: Fortitude, Prayer of Fortitude,
-- Divine Spirit, Prayer of Spirit, Shadow Protection, Prayer of Shadow Protection, Mark and Gift of the Wild, Arcane
-- Intellect and Brilliance, the Blessings and Greater Blessings; item and NPC versions included).
A.BUFF_FAMILIES = {
	fortitude = { 1243, 1244, 1245, 2791, 10937, 10938, 10939, 10940, 13864, 23947, 23948, -- Power Word: Fortitude
		21562, 21564, 450086 }, -- Prayer of Fortitude
	spirit    = { 14752, 14818, 14819, 16875, 27841, 27681 }, -- Divine Spirit, Prayer of Spirit
	shadow    = { 976, 977, 1279, 7235, 7241, 7242, 7243, 7244, 10957, 10958, 16874, 17548, 27683 }, -- Shadow Protection
	wild      = { 1126, 5232, 5234, 5286, 5287, 6756, 8907, 8908, 9884, 9885, 16878, 24752, 364163, 1291335, 1310503,
		21849, 21850 }, -- Mark of the Wild, Gift of the Wild
	intellect = { 1459, 1460, 1461, 10156, 10157, 13326, 16876, 364161, 23028 }, -- Arcane Intellect, Arcane Brilliance
	might     = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 25782, 25916 }, -- Blessing of Might, Greater
	wisdom    = { 19742, 19850, 19852, 19853, 19854, 25290, 25894, 25918 }, -- Blessing of Wisdom, Greater
	kings     = { 20217, 1213408, 25898 }, -- Blessing of Kings, Greater
	light     = { 26650 }, -- Blessing of Light
}
-- in the order the options list them; cast = the spell that tells us you can give it
A.BUFF_FAMILY_INFO = {
	{ key = "fortitude", label = "Fortitude", class = "Priest", cast = "Power Word: Fortitude" },
	{ key = "spirit",    label = "Divine Spirit", class = "Priest", cast = "Divine Spirit" },
	{ key = "shadow",    label = "Shadow Protection", class = "Priest", cast = "Shadow Protection" },
	{ key = "wild",      label = "Mark of the Wild", class = "Druid", cast = "Mark of the Wild" },
	{ key = "intellect", label = "Arcane Intellect", class = "Mage", cast = "Arcane Intellect" },
	{ key = "might",     label = "Blessing of Might", class = "Paladin", cast = "Blessing of Might" },
	{ key = "wisdom",    label = "Blessing of Wisdom", class = "Paladin", cast = "Blessing of Wisdom" },
	{ key = "kings",     label = "Blessing of Kings", class = "Paladin", cast = "Blessing of Kings" },
	{ key = "light",     label = "Blessing of Light", class = "Paladin", cast = "Blessing of Light" },
}
local RAID_BUFFS = {}
for _, list in pairs(A.BUFF_FAMILIES) do
	for _, id in ipairs(list) do RAID_BUFFS[id] = true end
end
A.RAID_BUFFS = RAID_BUFFS

-- The families you can cast yourself (from your spellbook). Empty for classes without a raid buff.
function A:MyBuffFamilies()
	local mine = {}
	for _, f in ipairs(A.BUFF_FAMILY_INFO) do
		if #self:ResolveSpells(f.cast, true) > 0 then mine[f.key] = true end
	end
	return mine
end

-- The spell IDs the raid buff row shows, per the "which" setting. Classes with no raid buff of their own see all
-- of them under "mine". Extra IDs are always added; the Aura filters' never-show list still hides spells.
function A:RaidBuffSet()
	local cfg = ns.db.auras.raidbuffs
	local which = cfg.which or "mine"
	local families
	if which == "pick" then
		families = cfg.pick or {}
	elseif which == "mine" then
		families = self:MyBuffFamilies()
		if not next(families) then which = "all" end
	end
	local set = {}
	for key, list in pairs(A.BUFF_FAMILIES) do
		if which == "all" or families[key] then
			for _, id in ipairs(list) do set[id] = true end
		end
	end
	for _, id in ipairs(cfg.extra or {}) do
		if tonumber(id) then set[tonumber(id)] = true end
	end
	return set
end

-- Learning a buff (or a new rank) changes "mine": rebuild then, not on every SPELLS_CHANGED.
local mineKey
ns:RegisterEvent("SPELLS_CHANGED", function()
	if not ns.db or (ns.db.auras.raidbuffs.which or "mine") ~= "mine" then return end
	local keys = {}
	for key in pairs(A:MyBuffFamilies()) do keys[#keys + 1] = key end
	table.sort(keys)
	local k = table.concat(keys, ",")
	if mineKey ~= nil and k ~= mineKey then A:Refresh() end
	mineKey = k
end)

-- The raid buff row shows in a party (and solo); in a raid only when asked to.
function A.RaidBuffsShown()
	local cfg = ns.db.auras.raidbuffs
	return cfg and cfg.enabled and (cfg.inRaid or not IsInRaid()) and true or false
end

local function AddGroupContainer(btn, key, filter, cfg, init, sortMethod, lists, listedFilter, mainExtra)
	local c = NewContainer(btn)
	c:ClearAllPoints()
	c:SetPoint(cfg.point, btn.visual.health, cfg.point, cfg.x or 0, cfg.y or 0)
	ConfigureFlow(c, cfg.point, cfg.grow)
	if lists.show then
		AddGroup(c, key .. "Listed", listedFilter, cfg.max, init, sortMethod, { includeSpellIDs = lists.show }, 1)
	end
	local candidate = mainExtra or {}
	if lists.skip then candidate.excludeSpellIDs = lists.skip end
	AddGroup(c, key, filter, cfg.max, init, sortMethod, next(candidate) and candidate or nil, 2)
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
		-- The game doesn't let addons filter other players' debuffs by spell, so long lockouts can't be listed away.
		-- Instead: dispellable debuffs always show; the rest only when they last LONG_DEBUFF seconds or less.
		local typed = {}
		for _, t in ipairs(DISPEL_TYPES) do typed[t] = true end
		local init = DebuffInit(cfg.size, cfg.swipe, cfg.stacks, D.countdown)
		local c = AddGroupContainer(btn, "debuffs", "HARMFUL", cfg, init,
			AuraContainerSortMethod.UnitFrameDebuff, lists, "HARMFUL",
			cfg.hideLong and { excludeDispelTypes = typed, maxDuration = LONG_DEBUFF } or nil)
		if cfg.hideLong then
			AddGroup(c, "debuffsDispel", "HARMFUL", cfg.max, init, AuraContainerSortMethod.UnitFrameDebuff,
				hidden({ includeDispelTypes = typed }), 2)
		end
		if cfg.onlyDispellable and c.SetAuraProcessingPolicy and CustomAuraContainerAuraProcessingPolicy then
			c:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.ProcessAura, { displayOnlyDispellableDebuffs = true })
		end
		set[#set + 1] = c
	end

	local rbSet = D.raidbuffs and D.raidbuffs.enabled and self:RaidBuffSet() or nil
	if rbSet and not next(rbSet) then rbSet = nil end
	if rbSet then
		local cfg = D.raidbuffs
		local c = NewContainer(btn)
		c:ClearAllPoints()
		local left = cfg.side == "LEFT"
		if left then c:SetPoint("TOPRIGHT", btn, "TOPLEFT", -2, 0) else c:SetPoint("TOPLEFT", btn, "TOPRIGHT", 2, 0) end
		ConfigureFlow(c, left and "TOPRIGHT" or "TOPLEFT", left and "LEFT" or "RIGHT")
		-- sorted by name: the same buff sits in the same column on every frame, and nothing shifts as timers run
		AddGroup(c, "raidbuffs", "HELPFUL", cfg.max, RaidBuffInit(cfg.size),
			AuraContainerSortMethod.NameOnly or AuraContainerSortMethod.Default,
			hidden({ includeSpellIDs = rbSet }), 1)
		c:SetShown(A.RaidBuffsShown())
		btn.raidBuffs = c
		set[#set + 1] = c
	else
		btn.raidBuffs = nil
	end

	if D.buffs.enabled then
		local cfg = D.buffs
		-- RAID_IN_COMBAT relies on a per-spell "show on raid frames" flag that classic-era
		-- spells (Renew, Rejuvenation) may not carry on Forever, so it hid them.
		local filter = cfg.source == "all" and "HELPFUL" or "HELPFUL|PLAYER"
		-- long buffs (30-minute raid buffs) hidden by default; the "always show" list still shows them
		-- the raid buff row has those: keep them out of this row while it shows
		local own = lists
		if rbSet then
			local skip = {}
			for id in pairs(lists.skip or {}) do skip[id] = true end
			for id in pairs(rbSet) do skip[id] = true end
			own = { show = lists.show, hide = lists.hide, skip = skip }
		end
		set[#set + 1] = AddGroupContainer(btn, "buffs", filter, cfg, IconInit(cfg.size, cfg.swipe, cfg.stacks, D.countdown),
			AuraContainerSortMethod.ExpirationOnly, own, "HELPFUL", cfg.hideLong and { maxDuration = LONG_BUFF } or nil)
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
	-- the big icon follows the same "who can dispel it" choice; it works even with the highlight off
	if D.dispel.icon then
		local filter = D.dispel.onlyMine and "HARMFUL|RAID" or "HARMFUL|RAID_PLAYER_DISPELLABLE"
		slots:AddAuraSlot("dispelIcon", filter, {
			initializeFrame = DispelIconInit(v.health, D.dispel.iconSize or 24, D.dispel.iconPulse ~= false),
			candidateFilters = hidden(),
			sortMethod = AuraContainerSortMethod.UnitFrameDebuff,
		})
		anySlot = true
	end

	if D.boss.enabled then
		local cfg = D.boss
		slots:AddAuraSlot("boss", "HARMFUL", {
			candidateFilters = hidden({ isBossOrRoleAura = true }),
			sortMethod = AuraContainerSortMethod.UnitFrameDebuff,
			initializeFrame = function(b)
				IconInit(cfg.size, true, true, D.countdown)(b)
				b:ClearAllPoints()
				b:SetPoint(cfg.point, v.health, cfg.point, cfg.x, cfg.y)
			end,
		})
		anySlot = true
	end

	if D.defensive.enabled then
		local cfg = D.defensive
		local ids = {}
		for id in pairs(BIG_DEFENSIVES) do if not (lists.hide and lists.hide[id]) then ids[id] = true end end
		slots:AddAuraSlot("defensive", "HELPFUL", {
			sortMethod = AuraContainerSortMethod.BigDefensive,
			candidateFilters = { includeSpellIDs = ids },
			initializeFrame = function(b)
				IconInit(cfg.size, true, false, D.countdown)(b)
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
			-- harmful = a debuff marker (Weakened Soul, Forbearance); it shows only if the game lets addons pick it by ID
			local filter = ind.harmful and "HARMFUL" or ind.mine and "HELPFUL|PLAYER" or "HELPFUL"
			slots:AddAuraSlot("ind" .. i, filter, {
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

-- Joining or leaving a raid shows or hides the raid buff rows (plain frames: fine in combat too).
ns:RegisterEvent("GROUP_ROSTER_UPDATE", function()
	if not ns.Buttons then return end
	local shown = A.RaidBuffsShown()
	for _, btn in ipairs(ns.Buttons.all) do
		if btn.raidBuffs then btn.raidBuffs:SetShown(shown) end
	end
end)

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

-- Classic spells only. A table entry is a spell you don't cast yourself (a debuff from your own spell): its IDs are
-- given, and harmful markers show from anyone.
A.PRESETS = {
	PRIEST  = { "Renew", "Power Word: Shield", { name = "Weakened Soul", ids = { 6788 }, harmful = true,
		color = { 1.00, 0.30, 0.30, 1 } }, "Fear Ward" },
	DRUID   = { "Rejuvenation", "Regrowth", "Abolish Poison" },
	SHAMAN  = { { name = "Ancestral Fortitude", ids = { 16177 }, any = true } },
	PALADIN = { "Blessing of Protection", "Blessing of Freedom", "Blessing of Sacrifice",
		{ name = "Forbearance", ids = { 25771 }, harmful = true, color = { 1.00, 0.30, 0.30, 1 } } },
}

-- Returns the names added and the names skipped (not in your spellbook).
function A:AddClassPresets()
	local _, class = UnitClass("player")
	local names = self.PRESETS[class]
	if not names then return {}, {} end
	local have, taken = {}, {}
	for _, ind in ipairs(ns.db.auras.indicators) do
		if ind.name then have[ind.name:lower()] = true end
		taken[(ind.point or "") .. ":" .. (ind.x or 0) .. ":" .. (ind.y or 0)] = true
	end
	-- the next preset spot no indicator sits on yet (clicking again later adds new presets beside the old ones)
	local slot = 0
	local function nextSlot()
		repeat
			slot = slot + 1
			local p = PRESET_SLOTS[slot]
			if p and not taken[p.point .. ":" .. p.x .. ":" .. p.y] then return p end
		until not p
	end
	local added, skipped = {}, {}
	for _, entry in ipairs(names) do
		local fixed = type(entry) == "table" and entry or nil
		local name = fixed and fixed.name or entry
		if not have[name:lower()] then
			local ids = fixed and fixed.ids or self:ResolveSpells(name, true)
			local p = #ids > 0 and nextSlot()
			if p then
				self:AddIndicator(name, ids, { point = p.point, x = p.x, y = p.y, color = fixed and fixed.color or p.color,
					harmful = fixed and fixed.harmful or nil, mine = not (fixed and (fixed.harmful or fixed.any)) }, true)
				added[#added + 1] = name
			else
				skipped[#skipped + 1] = name
			end
		end
	end
	if #added > 0 then self:Refresh() end
	return added, skipped
end
