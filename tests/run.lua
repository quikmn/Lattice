-- Offline test run for Lattice. Loads the addon in TOC order against wowmock.lua
-- and drives login, group changes, combat, options pages, preview and profiles.
local ROOT = ...
local ADDON = "Lattice"
local ns = {}
local failures, passes = {}, 0

local function step(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passes = passes + 1
		print("  ok   " .. name)
	else
		failures[#failures + 1] = name .. ": " .. tostring(err)
		print("  FAIL " .. name .. "\n         " .. tostring(err))
	end
end

local function check(cond, msg) if not cond then error(msg, 2) end end

-- Taint guard: every global the addon assigns (at load or later) is recorded, and
-- Blizzard's party/raid frames record any :Hide() call. Addon code must not write
-- Blizzard globals or run Blizzard Lua on Blizzard frames (in WoW Forever that taints
-- Blizzard's UI and its secret-value checks fail, e.g. closing the character sheet).
local globalWrites = {}
local addonEnv = setmetatable({}, {
	__index = _G,
	__newindex = function(_, k, v) globalWrites[k] = true; _G[k] = v end,
})
local BLIZZARD_FRAMES = { "PartyFrame", "CompactPartyFrame", "CompactRaidFrameContainer" }
local blizzardHides = {}
for _, name in ipairs(BLIZZARD_FRAMES) do
	local f = _G[name]
	f:SetParent(UIParent)
	f.Hide = function() blizzardHides[#blizzardHides + 1] = name end
end

-- Load files listed in the TOC
step("load TOC files", function()
	local toc = assert(io.open(ROOT .. "/LatticePartyRaidFrames.toc")):read("*a")
	for line in toc:gmatch("[^\r\n]+") do
		if not line:match("^%s*#") and line:match("%.lua%s*$") then
			local path = ROOT .. "/" .. line:gsub("\\", "/"):gsub("%s+$", "")
			local chunk, err = loadfile(path)
			if not chunk then error("syntax: " .. err) end
			setfenv(chunk, addonEnv)
			chunk(ADDON, ns)
		end
	end
end)

step("ADDON_LOADED + PLAYER_LOGIN", function()
	MOCK.Fire("ADDON_LOADED", ADDON)
	check(ns.db and ns.char, "db not initialised")
	ns.db.debug = true
	MOCK.Fire("PLAYER_LOGIN")
	MOCK.Fire("PLAYER_ENTERING_WORLD")
	MOCK.RunTimers()
	check(#ns.Buttons.all >= 5 + 40 + 40, "expected pre-created buttons, got " .. #ns.Buttons.all)
end)

local function shownUnits()
	local n, units = 0, {}
	for _, b in ipairs(ns.Buttons.all) do
		if b.unit then n = n + 1; units[#units + 1] = b.unit end
	end
	return n, units
end

step("solo shows nothing by default", function()
	MOCK.UpdateAllHeaders()
	local n, units = shownUnits()
	-- party header has showSolo=false by default
	check(n == 0, "solo should show 0 units, got " .. n .. " (" .. table.concat(units, ",") .. ")")
end)

step("party of 5", function()
	MOCK.SetGroup(5, false)
	MOCK.Fire("GROUP_ROSTER_UPDATE")
	MOCK.UpdateAllHeaders()
	MOCK.RunTimers()
	local n = shownUnits()
	check(n == 5, "party should show 5 units, got " .. n)
end)

step("unit events in party (secret values)", function()
	for _, u in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
		for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_HEAL_PREDICTION",
			"UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_CONNECTION", "UNIT_NAME_UPDATE", "UNIT_FLAGS", "UNIT_IN_RANGE_UPDATE",
			"UNIT_THREAT_SITUATION_UPDATE", "UNIT_DISPLAYPOWER" }) do
			MOCK.Fire(e, u)
		end
	end
	MOCK.Fire("PLAYER_TARGET_CHANGED")
	MOCK.Fire("RAID_TARGET_UPDATE")
	MOCK.Fire("PARTY_LEADER_CHANGED")
	MOCK.RunTimers()
end)

step("all appearance modes render without touching secrets", function()
	for _, mode in ipairs({ "class", "custom", "gradient" }) do
		ns.db.appearance.healthColor = mode
		for _, st in ipairs({ "none", "percent", "deficit" }) do
			ns.db.appearance.statusText = st
			ns.Buttons:UpdateAllButtons()
		end
	end
end)

step("raid of 40 out of combat", function()
	MOCK.SetGroup(40, true)
	MOCK.Fire("GROUP_ROSTER_UPDATE")
	MOCK.RunTimers()
	MOCK.UpdateAllHeaders()
	local n = shownUnits()
	check(n >= 40, "raid should show 40 units, got " .. n)
	check(ns.Headers.activeLayout == "raid40", "expected large raid layout, got " .. tostring(ns.Headers.activeLayout))
end)

step("combat: roster change + events without protected calls", function()
	MOCK.Fire("PLAYER_REGEN_DISABLED")
	MOCK.combat = true
	MOCK.SetGroup(20, true)
	MOCK.Fire("GROUP_ROSTER_UPDATE") -- our handler must defer layout work
	MOCK.UpdateAllHeaders()          -- secure header reassigns units
	for i = 1, 20 do MOCK.Fire("UNIT_HEALTH", "raid" .. i) end
	MOCK.Fire("READY_CHECK", "Leader", 30)
	MOCK.Fire("READY_CHECK_CONFIRM", "raid2", true)
	MOCK.Fire("READY_CHECK_FINISHED", false)
	ns:ApplySettings("layout") -- queued
	MOCK.RunTimers()
	MOCK.combat = false
	MOCK.Fire("PLAYER_REGEN_ENABLED")
	MOCK.RunTimers()
	check(ns.Headers.activeLayout == "raid", "after combat expected raid layout, got " .. tostring(ns.Headers.activeLayout))
end)

step("click-cast bindings set attributes", function()
	ns.ClickCast:Add({ button = 1, mods = "shift", action = "spell", value = 774 })
	ns.ClickCast:Add({ button = 2, mods = "ctrl", action = "macro", value = "/cast [@mouseover] Renew" })
	MOCK.RunTimers()
	local b = ns.Buttons.all[1]
	check(b:GetAttribute("shift-type1") == "spell", "shift-type1 not set")
	check(b:GetAttribute("shift-spell1") == "Spell774", "shift-spell1 = " .. tostring(b:GetAttribute("shift-spell1")))
	check(b:GetAttribute("ctrl-type2") == "macro", "ctrl-type2 not set")
	check(b:GetAttribute("type1") == "target", "type1 should stay target")
	ns.ClickCast:Remove(1)
end)

step("aura containers + indicator by spell name", function()
	local ids = ns.Auras:ResolveSpells("Rejuvenation")
	check(#ids >= 2, "expected both Rejuvenation ranks, got " .. #ids)
	ns.Auras:AddIndicator("Rejuvenation", ids)
	MOCK.RunTimers()
	local b = ns.Buttons.all[1]
	check(b.auraContainers and #b.auraContainers >= 3, "expected aura containers on buttons")
	for _, style in ipairs({ "border", "both", "overlay", "icon" }) do
		ns.db.auras.dispel.style = style
		ns.Auras:Refresh()
	end
	ns.db.auras.debuffs.onlyDispellable = true
	ns.Auras:Refresh()
end)

step("pet frames follow the group", function()
	ns.db.general.showPets = true
	MOCK.SetGroup(3, false)
	MOCK.units.partypet2 = { name = "Imp", class = "WARRIOR", role = "NONE", hp = 100, maxhp = 200, power = 1, maxpower = 1, connected = true }
	ns:ApplySettingsNow("layout")
	MOCK.RunTimers()
	MOCK.UpdateAllHeaders()
	local found = {}
	for child in ns.Headers.Children(ns.Headers.pets) do
		local u = child:GetAttribute("unit")
		if u and child.__shown then found[u] = true end
		check(child.latticeReady, "pet button not decorated (created late?)")
	end
	check(found.pet and found.partypet2, "expected pet and partypet2 frames")
	for _, b in ipairs(ns.Buttons.all) do
		if b.unit == "pet" then ns.Buttons:UpdateAll(b) end
	end
	ns.db.general.showPets = false
	ns:ApplySettingsNow("layout")
	MOCK.RunTimers()
end)

step("hover-cast keys", function()
	local HC = ns.HoverCast
	check(HC:Add({ key = "shift-1", action = "spell", value = 139, fallback = true }), "add failed")
	check(HC:Add({ key = "CTRL-SHIFT-2", action = "spell", value = 2061, fallback = false }), "add 2 failed")
	MOCK.RunTimers()
	check(MOCK.bindings["SHIFT-1"] == "LatticeHoverCast2" or MOCK.bindings["SHIFT-1"] == "LatticeHoverCast1", "SHIFT-1 not bound")
	local function textFor(key)
		local b = _G[MOCK.bindings[key]]
		return b and b:GetAttribute("macrotext") or ""
	end
	check(textFor("SHIFT-1"):find("[@mouseover,help,nodead][help,nodead]", 1, true), "fallback macro wrong: " .. textFor("SHIFT-1"))
	check(not textFor("CTRL-SHIFT-2"):find("[help,nodead]", 1, true), "no-fallback macro wrong: " .. textFor("CTRL-SHIFT-2"))
	check(not textFor("SHIFT-1"):find("@player", 1, true), "self fallback without asking")
	check(HC.MacroText({ action = "spell", value = 139, side = "harm", fallback = true, self = true }):find("[@mouseover,harm,nodead][harm,nodead] ", 1, true)
		and not HC.MacroText({ action = "spell", value = 139, side = "harm", self = true }):find("@player", 1, true), "enemy key")
	check(HC.MacroText({ action = "spell", value = 139, side = "help", fallback = true, self = true }):find("[help,nodead][@player] ", 1, true), "self fallback when asked")
	check(HC.MacroText({ action = "spell", value = 139, side = "any", fallback = false }):find("/cast [@mouseover,exists,nodead] ", 1, true), "either side")
	check(not textFor("SHIFT-1"):find("@player", 1, true), "must never target self")
	-- in combat: changes queue, no protected calls
	MOCK.combat = true
	HC:Remove(1)
	MOCK.RunTimers()
	MOCK.combat = false
	MOCK.Fire("PLAYER_REGEN_ENABLED")
	MOCK.RunTimers()
	local n = 0
	for _ in pairs(MOCK.bindings) do n = n + 1 end
	check(n == 1, "expected 1 binding after removal, got " .. n)
	HC:Remove(1)
	MOCK.RunTimers()
end)

step("summon and dead states", function()
	MOCK.SetGroup(5, false)
	MOCK.Fire("GROUP_ROSTER_UPDATE")
	MOCK.UpdateAllHeaders()
	MOCK.RunTimers()
	MOCK.summons.party1 = Enum.SummonStatus.Pending
	MOCK.units.party2.dead = true
	MOCK.units.party3.connected = false
	for _, u in ipairs({ "party1", "party2", "party3" }) do
		MOCK.Fire("INCOMING_SUMMON_CHANGED", u)
		MOCK.Fire("UNIT_HEALTH", u)
	end
	local shown
	for _, b in ipairs(ns.Buttons.all) do
		if b.unit == "party1" and b.visual.summon:IsShown() then shown = true end
	end
	check(shown, "summon icon not shown")
	for _, b in ipairs(ns.Buttons.all) do
		if b.unit == "party2" then check(b.visual.status:IsShown() and b.visual.status:GetText() == "Dead", "dead text not shown") end
	end
	MOCK.units.party2.dead = false
	MOCK.Fire("UNIT_HEALTH", "party2")
	for _, b in ipairs(ns.Buttons.all) do
		if b.unit == "party2" then check(not b.visual.status:IsShown(), "dead text should clear on resurrect") end
	end
	-- a new ready check must survive the previous one's clean-up timer
	MOCK.Fire("READY_CHECK", "Leader", 30)
	MOCK.Fire("READY_CHECK_FINISHED", false)
	MOCK.Fire("READY_CHECK", "Leader", 30)
	MOCK.RunTimers()
	check(ns.Buttons.readyState.party1 == "waiting", "old ready check timer wiped the new check")
	MOCK.Fire("READY_CHECK_FINISHED", false)
	MOCK.RunTimers()
	MOCK.summons.party1 = nil
end)

step("tank guessing: rules", function()
	local D = ns.Roles.Decide
	local function m(key, class, t) t = t or {}; t.key = key; t.class = class; t.assigned = t.assigned or "NONE"; return t end
	local function only(out, key)
		local n = 0
		for _ in pairs(out) do n = n + 1 end
		return n == 1 and out[key] ~= nil
	end
	-- five players, nothing to go on: the only warrior
	check(only(D({ m("p", "PRIEST"), m("w", "WARRIOR"), m("m", "MAGE"), m("r", "ROGUE"), m("h", "HUNTER") }, 5), "w"), "lone warrior")
	-- two warriors and no signal: no guess
	check(next(D({ m("w1", "WARRIOR"), m("w2", "WARRIOR"), m("p", "PRIEST"), m("m", "MAGE"), m("r", "ROGUE") }, 5)) == nil, "two warriors should not guess")
	-- a bear beats a warrior in battle stance
	check(only(D({ m("w", "WARRIOR"), m("d", "DRUID", { stance = true }), m("p", "PRIEST"), m("m", "MAGE"), m("r", "ROGUE") }, 5), "d"), "bear form")
	-- equal signals: warrior before paladin; two warriors in defensive stance: no guess
	check(only(D({ m("pa", "PALADIN", { stance = true }), m("w", "WARRIOR", { stance = true }), m("p", "PRIEST"), m("m", "MAGE"), m("r", "ROGUE") }, 5), "w"), "class tie-break")
	check(next(D({ m("w1", "WARRIOR", { stance = true }), m("w2", "WARRIOR", { stance = true }), m("p", "PRIEST"), m("m", "MAGE"), m("r", "ROGUE") }, 5)) == nil, "real tie")
	-- main tank flag beats a stance
	check(only(D({ m("w", "WARRIOR", { stance = true }), m("x", "PRIEST", { mainTank = true }), m("p", "PRIEST"), m("m", "MAGE"), m("r", "ROGUE") }, 5), "x"), "main tank")
	-- an assigned tank or a user choice stops guessing in five-player groups
	check(only(D({ m("w", "WARRIOR"), m("t", "PALADIN", { assigned = "TANK" }), m("p", "PRIEST"), m("m", "MAGE"), m("r", "ROGUE") }, 5), "t"), "assigned tank")
	check(only(D({ m("w", "WARRIOR"), m("x", "MAGE", { override = "tank" }), m("p", "PRIEST"), m("m", "MAGE"), m("r", "ROGUE") }, 5), "x"), "override tank")
	check(next(D({ m("w", "WARRIOR", { override = "notank" }), m("p", "PRIEST"), m("m", "MAGE"), m("r", "ROGUE"), m("h", "HUNTER") }, 5)) == nil, "override notank")
	-- assigned dps is trusted even in defensive stance
	check(next(D({ m("w", "WARRIOR", { stance = true, assigned = "DAMAGER" }), m("p", "PRIEST"), m("m", "MAGE"), m("r", "ROGUE"), m("h", "HUNTER") }, 5)) == nil, "assigned dps")
	-- raids: every stance/form/main tank counts, main assist alone doesn't, class alone doesn't
	local raid = D({ m("w1", "WARRIOR", { stance = true }), m("d", "DRUID", { stance = true }), m("mt", "PRIEST", { mainTank = true }),
		m("ma", "WARRIOR", { mainAssist = true }), m("w2", "WARRIOR") }, 20)
	check(raid.w1 and raid.d and raid.mt and not raid.ma and not raid.w2, "raid rules")
end)

step("tank guessing: in a party", function()
	MOCK.SetGroup(5, false)
	for _, u in ipairs({ "player", "party1", "party2", "party3", "party4" }) do MOCK.units[u].role = "NONE" end
	-- classes: player PRIEST, party1 WARRIOR, party2 MAGE, party3 DRUID, party4 ROGUE
	MOCK.Fire("GROUP_ROSTER_UPDATE")
	MOCK.UpdateAllHeaders()
	MOCK.RunTimers()
	local R = ns.Roles
	check(R:IsTank("party1"), "lone warrior should be the tank")
	local function roleShown(unit)
		for _, b in ipairs(ns.Buttons.all) do
			if b.unit == unit and b:IsVisible() then return b.visual.role:IsShown() end
		end
	end
	check(roleShown("party1"), "guessed tank should get a role icon")
	-- druid shifts to bear: rage bar, works in combat too
	MOCK.combat = true
	MOCK.units.party3.ptype = "RAGE"
	MOCK.Fire("UNIT_DISPLAYPOWER", "party3")
	MOCK.RunTimers()
	MOCK.combat = false
	MOCK.Fire("PLAYER_REGEN_ENABLED")
	MOCK.RunTimers()
	check(R:IsTank("party3") and not R:IsTank("party1"), "bear should take over")
	-- the user says the druid is not a tank
	SlashCmdList.LATTICE("notank party3")
	MOCK.RunTimers()
	check(not R:IsTank("party3") and R:IsTank("party1"), "notank override ignored")
	SlashCmdList.LATTICE("autotank party3")
	MOCK.units.party3.ptype = "MANA"
	MOCK.Fire("UNIT_DISPLAYPOWER", "party3")
	MOCK.RunTimers()
	-- defensive stance seen on the warrior's auras (read out of combat only)
	MOCK.units.party4.class = "WARRIOR"
	MOCK.auras.party1 = { { spellId = 71, name = "Defensive Stance" } }
	MOCK.Fire("UNIT_AURA", "party1")
	MOCK.RunTimers()
	check(R:IsTank("party1") and not R:IsTank("party4"), "defensive stance should pick party1")
	MOCK.combat = true
	MOCK.auras.party1 = nil
	MOCK.Fire("UNIT_AURA", "party1") -- unreadable in combat: keep the last answer
	MOCK.RunTimers()
	check(R:IsTank("party1"), "combat should keep the last answer")
	MOCK.combat = false
	MOCK.Fire("PLAYER_REGEN_ENABLED")
	MOCK.RunTimers()
	check(not R:IsTank("party1"), "stance gone after combat: two warriors, no guess")
	SlashCmdList.LATTICE("tanks")
	-- raid main tank flag
	MOCK.SetGroup(20, true)
	MOCK.assignments.raid7 = "MAINTANK"
	MOCK.Fire("GROUP_ROSTER_UPDATE")
	MOCK.RunTimers()
	check(not R:IsTank("raid7"), "assigned damage role should win over the main tank flag")
	MOCK.units.raid7.role = "NONE"
	MOCK.Fire("PLAYER_ROLES_ASSIGNED")
	MOCK.RunTimers()
	check(R:IsTank("raid7"), "main tank flag")
	MOCK.assignments = {}
	MOCK.auras = {}
end)

step("power bar: rules per power type and role", function()
	local allows = ns.Buttons.PowerRuleAllows
	local rules = ns.db.appearance.powerRules
	check(allows(rules, "MANA", "NONE") and allows(rules, "MANA", "DAMAGER"), "mana should show")
	check(not allows(rules, "ENERGY", "NONE") and not allows(rules, "ENERGY", "TANK"), "energy should hide")
	check(allows(rules, "RAGE", "TANK") and not allows(rules, "RAGE", "NONE"), "rage only for tanks")
	check(allows(rules, "FOCUS", "NONE"), "other power types show")
	check(allows({ MANA = "tankheal" }, "MANA", "HEALER") and not allows({ MANA = "tankheal" }, "MANA", "DAMAGER"), "tankheal")

	MOCK.SetGroup(5, false)
	for _, u in ipairs({ "player", "party1", "party2", "party3", "party4" }) do MOCK.units[u].role = "NONE" end
	MOCK.units.party1.ptype = "RAGE"   -- warrior
	MOCK.units.party3.ptype = "ENERGY" -- druid in cat form
	MOCK.units.party4.ptype = "ENERGY" -- rogue
	MOCK.Fire("GROUP_ROSTER_UPDATE")
	MOCK.UpdateAllHeaders()
	MOCK.RunTimers()
	local function shown(unit)
		for _, b in ipairs(ns.Buttons.all) do
			if b.unit == unit and b:IsVisible() then return b.visual.power:IsShown() end
		end
		error("no button for " .. unit)
	end
	check(shown("player") and shown("party2"), "mana users should have a power bar")
	check(shown("party1"), "lone warrior is the tank: rage shown")
	check(not shown("party4"), "rogue energy should be hidden")
	check(not shown("party3"), "cat form energy should be hidden")
	-- druid leaves cat form (mana), then goes bear in combat (rage, takes the tank spot)
	MOCK.units.party3.ptype = "MANA"
	MOCK.Fire("UNIT_DISPLAYPOWER", "party3")
	check(shown("party3"), "caster form should show mana")
	MOCK.combat = true
	MOCK.units.party3.ptype = "RAGE"
	MOCK.Fire("UNIT_DISPLAYPOWER", "party3")
	MOCK.RunTimers()
	check(shown("party3") and not shown("party1"), "bear should show rage, the warrior no longer tanks")
	MOCK.combat = false
	MOCK.Fire("PLAYER_REGEN_ENABLED")
	MOCK.RunTimers()
	-- the layout switch still turns everything off
	ns.db.layouts.party.showPower = false
	ns:ApplySettingsNow("layout")
	MOCK.RunTimers()
	check(not shown("player"), "layout switch should hide every power bar")
	ns.db.layouts.party.showPower = true
	ns:ApplySettingsNow("layout")
	MOCK.RunTimers()
end)

step("aura filters: lists reach the containers", function()
	local A = ns.Auras
	local sets = A.ListSets(ns.db.auras.lists)
	check(sets.show[10060] and sets.hide[12966], "defaults missing")
	check(sets.skip[10060] and sets.skip[12966], "skip should hold both lists")
	check(A.ListSets({}).show == nil and A.ListSets({ [5] = false }).skip == nil, "empty and removed entries")
	check(A.RAID_BUFFS[10938] and A.RAID_BUFFS[21564] and A.RAID_BUFFS[9885], "raid buffs: Fortitude, Prayer of Fortitude, Mark of the Wild")
	check(A.RaidBuffsShown() == not IsInRaid(), "raid buff row: party yes, raid no by default")
	local rb = ns.db.auras.raidbuffs
	local old = { which = rb.which, pick = rb.pick, extra = rb.extra }
	rb.which = "all"
	check(A:RaidBuffSet()[10938] and A:RaidBuffSet()[19740], "raid buffs: all")
	rb.which = "pick"; rb.pick = { intellect = true }
	check(A:RaidBuffSet()[10156] and not A:RaidBuffSet()[10938], "raid buffs: picked only")
	rb.extra = { 467 }
	check(A:RaidBuffSet()[467], "raid buffs: extra spells")
	rb.which, rb.pick, rb.extra = old.which, old.pick, old.extra
	check(ns.MissingBuff and ns.MissingBuff.HasBuff, "missing-buff module loaded")
	for _, entry in ipairs(A.PRESETS.PRIEST) do
		local name = type(entry) == "table" and entry.name or entry
		check(name ~= "Prayer of Mending", "presets are Classic spells only")
	end
	check(ns.Headers.tanks and ns.Headers.tankTargets, "tank headers made")
	check(ns.Headers.tankTargets:GetAttribute("unitsuffix") == "target", "tank target header shows targets")
	check(ns.Buttons.RangeSpell, "range spell lookup")
	MOCK.SetGroup(5, false)
	MOCK.Fire("GROUP_ROSTER_UPDATE")
	MOCK.UpdateAllHeaders()
	MOCK.RunTimers()
	A:SetListMode(774, "show")
	MOCK.RunTimers()
	local b
	for _, btn in ipairs(ns.Buttons.all) do if btn.unit == "party1" then b = btn end end
	local groups, slots = {}, {}
	for _, c in ipairs(b.auraContainers) do
		for k, g in pairs(c.__groups) do groups[k] = g end
		for k, sl in pairs(c.__slots) do slots[k] = sl end
	end
	local bl, bn = groups.buffsListed, groups.buffs
	check(bl and bl.filter == "HELPFUL" and bl.opts.candidateFilters.includeSpellIDs[774], "listed buff group")
	check(bl.opts.layout.layoutIndex < bn.opts.layout.layoutIndex, "listed buffs should come first")
	local ex = bn.opts.candidateFilters.excludeSpellIDs
	check(ex[774] and ex[12966] and bn.filter == "HELPFUL|PLAYER", "normal buff group should skip listed and hidden")
	check(groups.debuffsListed and groups.debuffs.opts.candidateFilters.excludeSpellIDs[11196], "debuff groups")
	check(slots.boss.opts.candidateFilters.isBossOrRoleAura and slots.boss.opts.candidateFilters.excludeSpellIDs[12966], "boss slot")
	check(slots.dispel.opts.candidateFilters.excludeSpellIDs[15007], "dispel slot")
	local def = slots.defensive.opts.candidateFilters.includeSpellIDs
	check(def and def[871] and not def[774] and slots.defensive.filter == "HELPFUL", "defensive slot shows only the defensive list")
	check(groups.debuffsDispel and groups.debuffsDispel.opts.candidateFilters.includeDispelTypes.Magic
		and groups.debuffs.opts.candidateFilters.maxDuration and groups.debuffs.opts.candidateFilters.excludeDispelTypes.Curse,
		"long debuffs nobody can dispel are skipped, dispellable ones kept")
	check(not slots.dispel.opts.candidateFilters.excludeSpellIDs[774], "an always-show spell must not be hidden")

	-- removing a default sticks through logout/login
	A:SetListMode(12966, nil)
	check(ns.db.auras.lists[12966] == false, "removed default should be stored as false")
	A:SetListMode(774, nil)
	check(ns.db.auras.lists[774] == nil, "removed own entry should vanish")
	local p = ns.Util.CopyTable(ns.db)
	ns.Util.StripDefaults(p, ns.Defaults)
	check(p.auras.lists[12966] == false and p.auras.lists[10060] == nil, "strip should keep only changes")
	ns.Util.FillDefaults(p, ns.Defaults)
	check(p.auras.lists[12966] == false and p.auras.lists[10060] == "show", "fill should not bring back a removed default")
	check(not A.ListSets(p.auras.lists).skip[12966], "removed default still applied")
	check(not A:SetListMode("abc", "hide") and not A:SetListMode(0, "hide"), "bad ids accepted")
end)

step("aura filters: text import and export", function()
	local A = ns.Auras
	local text = A:ExportLists()
	check(text:find("show 10060", 1, true) and text:find("hide 11196", 1, true), "export missing lines: " .. text)
	check(not text:find("12966", 1, true), "removed default exported")
	local n, bad = A:ImportLists("# my list\nshow 774 Rejuvenation\nhide Healing Touch\nnever 9999\nbogus line\nhide NoSuchSpellAnywhere", true)
	check(n == 3 and #bad == 2 and bad[1] == "bogus line", "import counts: " .. n .. " / " .. #bad)
	check(A:ListMode(774) == "show" and A:ListMode(5185) == "hide" and A:ListMode(9999) == "hide", "imported modes")
	check(A:ListMode(10060) == nil and ns.db.auras.lists[10060] == false, "replace should drop defaults")
	A:ImportLists(text, true)
	check(A:ListMode(10060) == "show" and A:ListMode(774) == nil, "round trip")
	A:ResetLists()
	check(A:ListMode(12966) == "hide", "reset to defaults")
	MOCK.RunTimers()
end)

step("frame menu: Ctrl+Alt+Right-click", function()
	local W, M = ns.Widgets, ns.UnitMenu
	local b
	for _, btn in ipairs(ns.Buttons.all) do if btn.unit == "party1" then b = btn end end
	check(b:GetAttribute("alt-ctrl-type2") == M.TYPE, "menu click should be a no-op for the secure button")
	local real, last = W.OpenPopup, nil
	W.OpenPopup = function(_, items, current, onPick) last = { items = items, current = current, pick = onPick } end
	b.__scripts.PostClick(b, "RightButton")
	check(last == nil, "menu opened without modifiers")
	MOCK.mods = { ctrl = true, alt = true }
	b.__scripts.PostClick(b, "RightButton")
	check(last and last.items[1].title and last.current == "auto", "menu not opened")
	last.pick("notank")
	check(ns.Roles:Override(ns.Roles.Key("party1")) == "notank", "notank from menu")
	b.__scripts.PostClick(b, "RightButton")
	check(last.current == "notank", "menu should show the current choice")
	last.pick("auto")
	check(ns.Roles:Override(ns.Roles.Key("party1")) == nil, "auto from menu")
	-- aura picker
	MOCK.auras.party1 = { { spellId = 23170, name = "Brood Affliction: Bronze", harmful = true }, { spellId = 1243, name = "Power Word: Fortitude" } }
	b.__scripts.PostClick(b, "RightButton")
	last.pick("auras")
	check(#last.items == 3, "picker should list two auras")
	local fort
	for _, it in ipairs(last.items) do if it.text and it.text:find("Fortitude") then fort = it.value end end
	last.pick(fort)
	last.pick("hide")
	check(ns.Auras:ListMode(1243) == "hide", "picked aura not hidden")
	-- no picker in combat
	MOCK.combat = true
	b.__scripts.PostClick(b, "RightButton")
	local before = last
	last.pick("auras")
	check(last == before, "picker opened in combat")
	MOCK.combat = false
	MOCK.Fire("PLAYER_REGEN_ENABLED")
	MOCK.mods = {}
	W.OpenPopup = real
	ns.Auras:SetListMode(1243, nil)
	MOCK.auras = {}
	-- a user binding on that click wins
	ns.ClickCast:Add({ button = 2, mods = "alt-ctrl", action = "spell", value = 774 })
	MOCK.RunTimers()
	check(b:GetAttribute("alt-ctrl-type2") == "spell" and not M:Enabled(), "user binding should replace the menu")
	ns.ClickCast:Remove(ns.ClickCast:FindConflict(2, "alt-ctrl"))
	MOCK.RunTimers()
	check(b:GetAttribute("alt-ctrl-type2") == M.TYPE, "menu should come back")
	MOCK.RunTimers()
end)

step("class presets add only known spells", function()
	local realClass = UnitClass
	UnitClass = function(u) if u == "player" then return "Druid", "DRUID", 11 end return realClass(u) end
	wipe(ns.db.auras.indicators)
	local before = 0
	local added, skipped = ns.Auras:AddClassPresets()
	UnitClass = realClass
	check(#added == 1 and added[1] == "Rejuvenation", "expected Rejuvenation only, got " .. table.concat(added, ","))
	check(#skipped >= 1, "expected unknown spells to be skipped")
	local ind = ns.db.auras.indicators[#ns.db.auras.indicators]
	check(#ind.spells >= 2, "expected every Rejuvenation rank")
	check(#ns.db.auras.indicators == before + 1, "wrong indicator count")
	MOCK.RunTimers()
	-- second press adds nothing
	UnitClass = function(u) if u == "player" then return "Druid", "DRUID", 11 end return realClass(u) end
	local again = ns.Auras:AddClassPresets()
	UnitClass = realClass
	check(#again == 0, "presets added twice")
end)

step("class presets skip spots already used", function()
	local realClass = UnitClass
	wipe(ns.db.auras.indicators)
	ns.Auras:AddIndicator("Renew", { 139 }, { point = "TOP", x = -12, y = -2 }, true)
	UnitClass = function(u) if u == "player" then return "Paladin", "PALADIN", 2 end return realClass(u) end
	local added = ns.Auras:AddClassPresets()
	UnitClass = realClass
	check(#added == 1 and added[1] == "Forbearance", "expected Forbearance, got " .. table.concat(added, ","))
	local ind = ns.db.auras.indicators[2]
	check(not (ind.point == "TOP" and ind.x == -12), "new preset placed on top of an existing indicator")
	wipe(ns.db.auras.indicators)
	ns.Auras:Refresh()
	MOCK.RunTimers()
end)

step("low health warning", function()
	MOCK.SetGroup(5, false)
	MOCK.Fire("GROUP_ROSTER_UPDATE")
	MOCK.UpdateAllHeaders()
	MOCK.RunTimers()
	local btn
	for _, b in ipairs(ns.Buttons.all) do if b.unit == "party1" then btn = b break end end
	check(btn, "no party1 button")
	ns.db.appearance.lowHealth = true
	ns.Buttons:UpdateAll(btn)
	check(btn.visual.low:IsShown(), "low health layer should show")
	ns.db.appearance.lowHealth = false
	ns.Buttons:UpdateAll(btn)
	check(not btn.visual.low:IsShown(), "low health layer should hide when off")
	ns.db.appearance.lowHealth = true
	MOCK.units.party1.dead = true
	ns.Buttons:UpdateAll(btn)
	check(not btn.visual.low:IsShown(), "no low health warning on the dead")
	MOCK.units.party1.dead = false
	ns.Buttons:UpdateAll(btn)
	check(ns.Secret.LowHealthCurve(0.3, 0.7) == ns.Secret.LowHealthCurve(0.3, 0.7), "curve should be cached")
end)

step("countdown numbers build", function()
	ns.db.auras.countdown = true
	ns.Auras:Refresh()
	MOCK.RunTimers()
	check(ns.Auras.lastError == nil, "aura build failed: " .. tostring(ns.Auras.lastError))
	ns.db.auras.countdown = false
	ns.Auras:Refresh()
	MOCK.RunTimers()
end)

step("options: dependents grey out at once, confirm buttons ask first", function()
	local W = ns.Widgets
	local holder = CreateFrame("Frame")
	local s = W.Stack(holder, 400)
	local parentOn = true
	local parent = W.Toggle(s, { label = "Parent", get = function() return parentOn end, set = function(v) parentOn = v end })
	local child = W.Toggle(s, { label = "Child", get = function() return false end, set = function() end,
		disabled = function() return not parentOn end })
	local color = W.Color(s, { label = "Color", get = function() return { 1, 1, 1, 1 } end, set = function() end,
		disabled = function() return not parentOn end })
	check(child:GetAlpha() == 1, "child should start enabled")
	parent:GetScript("OnClick")(parent)
	check(not parentOn, "parent toggle didn't change")
	check(child:GetAlpha() < 1 and color:GetAlpha() < 1, "dependents should grey out when the parent is turned off")
	local done = 0
	local b = W.ConfirmButton(holder, "Delete", function() done = done + 1 end)
	b:GetScript("OnClick")(b)
	check(done == 0, "confirm button acted on the first click")
	b:GetScript("OnClick")(b)
	check(done == 1, "confirm button didn't act on the second click")
end)

step("settings upgrade from schema 1", function()
	local sv = { schema = 1, profiles = { Default = {} }, chars = { ["A-B"] = { profile = "Default", bindings = {} } } }
	ns.Database:Migrate(sv)
	check(sv.schema == ns.Database.SCHEMA, "schema not bumped")
	check(type(sv.chars["A-B"].hover) == "table", "hover list not created")
end)

step("options window: every page builds", function()
	ns.Options:Open()
	for _, id in ipairs({ "general", "layout", "appearance", "auras", "aurafilters", "clickcast", "hovercast", "profiles" }) do
		ns.Options:ShowPage(id)
	end
	ns.Options:RebuildAll()
	ns.Options:ShowPage("auras")
	ns.Options:Toggle()
end)

step("settings: the wheel scrolls the page, text areas only while typing, sliders never", function()
	ns.Options:Open()
	ns.Options:ShowPage("profiles")
	local function patch(sf)
		sf.SetVerticalScroll = function(self, v) self.__vs = v end
		sf.GetVerticalScroll = function(self) return self.__vs or 0 end
	end
	local page
	for _, c in ipairs(LatticeOptionsWindow.content.__children) do
		if c.__kind == "ScrollFrame" and c:IsShown() then page = c end
	end
	check(page and page.track, "no page scroll with a bar")
	local inner
	for _, w in ipairs(MOCK.widgets) do
		if w.__kind == "ScrollFrame" and w ~= page then
			local p = w:GetParent()
			while p and p ~= page do p = p:GetParent() end
			if p then inner = w end
		end
	end
	check(inner, "no text area on the profiles page")
	patch(page); patch(inner)
	local box = inner.__children[1]
	local focus = false
	box.HasFocus = function() return focus end
	page.__h, page.child.__h = 400, 1500
	inner.__h, box.__h = 60, 200
	local wheel = inner:GetScript("OnMouseWheel")
	wheel(inner, -1)
	check(page:GetVerticalScroll() == 40 and inner:GetVerticalScroll() == 0, "wheel over a text area didn't scroll the page")
	focus = true
	wheel(inner, -1)
	check(inner:GetVerticalScroll() == 30 and page:GetVerticalScroll() == 40, "wheel while typing didn't scroll the text")
	inner.__vs = 140
	wheel(inner, -1)
	check(page:GetVerticalScroll() == 80, "text at its end didn't pass the wheel to the page")
	for _, w in ipairs(MOCK.widgets) do
		if w.__kind == "Slider" then check(not w.__scripts.OnMouseWheel, "a slider takes the mouse wheel") end
	end
	ns.Options:Toggle()
end)

step("preview mode all sizes", function()
	for _, n in ipairs({ 5, 10, 20, 25, 40 }) do
		ns.TestMode:Start(n)
		for _, mode in ipairs({ "class", "custom", "gradient" }) do
			ns.db.appearance.healthColor = mode
			ns.TestMode:Relayout()
		end
	end
	ns.TestMode:Stop()
end)

step("mover toggle", function()
	ns.Mover:Toggle()
	ns.Mover:Toggle()
end)

step("profiles: create, switch, export, import, delete", function()
	check(ns.Profiles:Create("Healer"), "create failed")
	ns.Profiles:Switch("Healer")
	check(ns.Database:ActiveName() == "Healer", "switch failed")
	ns.db.layouts.raid.width = 101
	local str = assert(ns.Profiles:Export())
	check(str:sub(1, 5) == "LAT1:", "bad export prefix")
	local ok, err = ns.Profiles:Import(str, "Imported")
	check(ok, "import failed: " .. tostring(err))
	check(ns.Database:ActiveName() == "Imported" and ns.db.layouts.raid.width == 101, "import switches to it")
	-- with click-casting, unnamed: gets a free name; same class takes the bindings
	ns.char.bindings[1].action = "menu"
	local withCast = assert(ns.Profiles:Export(nil, true))
	ns.char.bindings[1].action = "target"
	local ok2, name2, note = ns.Profiles:Import(withCast, nil, true)
	check(ok2 and name2 == "Imported 2", "free name: " .. tostring(name2))
	check(ns.char.bindings[1].action == "menu", "click-casting taken: " .. tostring(note))
	ns.char.bindings[1].action = "target"
	ns.Profiles:Switch("Default")
	check(ns.db.layouts.raid.width ~= 101, "profiles share data")
	check(ns.Profiles:Delete("Healer"), "delete failed")
end)

step("slash commands", function()
	SlashCmdList.LATTICE("")
	SlashCmdList.LATTICE("probe")
	SlashCmdList.LATTICE("status")
	SlashCmdList.LATTICE("preview 10")
	SlashCmdList.LATTICE("preview")
	SlashCmdList.LATTICE("hide 1243")
	assert(ns.Auras:ListMode(1243) == "hide", "slash hide")
	SlashCmdList.LATTICE("unlist 1243")
	assert(ns.Auras:ListMode(1243) == nil, "slash unlist")
	SlashCmdList.LATTICE("show nosuchspell")
	SlashCmdList.LATTICE("help")
end)

step("feedback link", function()
	SlashCmdList.LATTICE("feedback")
	local d = LatticeFeedbackWindow
	check(d and d:IsShown(), "feedback window not shown")
	check(d.box:GetText() == ns.FEEDBACK_URL, "feedback box doesn't hold the URL")
	d.box:SetText("typed over")
	d.box:GetScript("OnTextChanged")(d.box, true)
	check(d.box:GetText() == ns.FEEDBACK_URL, "feedback URL can be edited away")
	d.box:GetScript("OnEscapePressed")(d.box)
	check(not d:IsShown(), "escape in the box didn't close the window")
	ns.ShowFeedback()
	d:GetScript("OnKeyDown")(d, "ESCAPE")
	check(not d:IsShown(), "escape didn't close the window")
	check(next(MOCK.popups) == nil, "a Blizzard StaticPopup was used")
end)

step("options window closes on Escape without UISpecialFrames", function()
	ns.Options:Open()
	check(LatticeOptionsWindow:IsShown(), "options window not shown")
	LatticeOptionsWindow:GetScript("OnKeyDown")(LatticeOptionsWindow, "A")
	check(LatticeOptionsWindow:IsShown(), "a normal key closed the window")
	LatticeOptionsWindow:GetScript("OnKeyDown")(LatticeOptionsWindow, "ESCAPE")
	check(not LatticeOptionsWindow:IsShown(), "escape didn't close the window")
end)

step("no taint: Blizzard globals and frames left alone", function()
	local allowed = {
		LatticeDB = true, SLASH_LATTICE1 = true, SLASH_LATTICE2 = true,
		Lattice_OnCompartmentClick = true, Lattice_OnCompartmentEnter = true, Lattice_OnCompartmentLeave = true,
	}
	for k in pairs(globalWrites) do
		check(allowed[k], "addon assigned the global " .. tostring(k))
	end
	check(next(UISpecialFrames) == nil, "addon added to UISpecialFrames")
	check(next(StaticPopupDialogs) == nil, "addon added to StaticPopupDialogs")
	check(#blizzardHides == 0, "addon called :Hide() on Blizzard frame " .. tostring(blizzardHides[1]))
	for _, name in ipairs(BLIZZARD_FRAMES) do
		check(not _G[name]:IsVisible(), name .. " still visible with hideBlizzard on")
	end
end)

step("aura icons grow into the frame from any corner", function()
	local A = ns.Auras
	check(A.InwardGrow("TOPLEFT") == "RIGHT", "top-left buffs would grow out of the frame")
	check(A.InwardGrow("BOTTOMLEFT") == "RIGHT", "bottom-left would grow out of the frame")
	check(A.InwardGrow("TOPRIGHT") == "LEFT", "top-right would grow out of the frame")
	check(A.InwardGrow("RIGHT") == "LEFT", "right would grow out of the frame")
	check(A.InwardGrow("CENTER") == "RIGHT", "center should grow right")
end)

step("player tooltip on mouseover, in combat too unless turned off", function()
	local btn
	for _, b in ipairs(ns.Buttons.all) do if b.unit then btn = b; break end end
	check(btn, "no frame with a unit to hover")
	local shown
	rawset(GameTooltip, "SetUnit", function(_, u) shown = u end)
	local enter, leave = btn:GetScript("OnEnter"), btn:GetScript("OnLeave")
	MOCK.combat = true
	enter(btn); leave(btn)
	check(shown == btn.unit, "no tooltip in combat")
	shown = nil
	ns.db.general.tooltipsInCombat = false
	enter(btn); leave(btn)
	check(shown == nil, "tooltip shown in combat with Tooltip in combat too off")
	MOCK.combat = false
	enter(btn); leave(btn)
	check(shown == btn.unit, "no tooltip out of combat")
	ns.db.general.tooltipsInCombat = nil
	rawset(GameTooltip, "SetUnit", nil)
end)

step("Fear Ward is on Always show by default (Hide long buffs would drop it)", function()
	check(ns.Defaults.auras.lists[6346] == "show", "Fear Ward not on the default Always show list")
	local saved = ns.db.auras.lists
	ns.db.auras.lists = { [6346] = "show" }
	local sets = ns.Auras.ListSets(ns.db.auras.lists)
	check(sets.show and sets.show[6346], "Fear Ward not in the show set")
	ns.db.auras.lists = saved
end)

step("lock and unlock: explicit commands, chat line, combat drops a held box", function()
	local M = ns.Mover
	if M:IsUnlocked() then M:SetUnlocked(false, true) end
	local synced = 0
	ns:Listen("MoverChanged", function() synced = synced + 1 end)
	SlashCmdList.LATTICE("lock")
	check(not M:IsUnlocked(), "/lattice lock unlocked the frames")
	SlashCmdList.LATTICE("unlock")
	check(M:IsUnlocked(), "/lattice unlock didn't unlock")
	SlashCmdList.LATTICE("unlock")
	check(M:IsUnlocked(), "/lattice unlock twice locked again")
	check(synced == 1, "window not told about the change (" .. synced .. ")")
	local a = M:GetAnchor("party")
	local stopped = false
	rawset(a, "StopMovingOrSizing", function() stopped = true end)
	a.overlay:GetScript("OnDragStart")(a.overlay)
	check(a.moving, "drag didn't start")
	MOCK.Fire("PLAYER_REGEN_DISABLED")
	check(not M:IsUnlocked() and not a.moving and stopped, "combat didn't lock and drop the held box")
	check(not ns.TestMode:IsActive(), "preview from unlocking still up in combat")
	rawset(a, "StopMovingOrSizing", nil)
	MOCK.Fire("PLAYER_REGEN_ENABLED")
end)

step("preview stops when combat starts (it hides the real frames)", function()
	ns.TestMode:Toggle()
	check(ns.TestMode:IsActive(), "preview didn't start")
	MOCK.Fire("PLAYER_REGEN_DISABLED")
	check(not ns.TestMode:IsActive(), "preview still up in combat")
	MOCK.Fire("PLAYER_REGEN_ENABLED")
end)

step("imported click-casting and hover keys are cleaned", function()
	local b = ns.ClickCast.CleanBindings({
		{ button = 1, mods = "SHIFT", action = "spell", value = "774" },
		{ button = 9, action = "target" }, { button = 2, action = "explode" }, { button = 3, action = "spell" },
		{ button = 4, action = "macro", value = "" }, "junk", { action = "target" },
	})
	check(#b == 1 and b[1].mods == "shift" and b[1].value == 774, "bad bindings kept: " .. #b)
	local h = ns.HoverCast.CleanList({ { key = "shift-1", action = "spell", value = 2061 }, { key = "", action = "spell", value = 1 },
		{ key = "F", action = "nuke" }, 5 })
	check(#h == 1 and h[1].key == "SHIFT-1", "bad hover keys kept: " .. #h)
	check(#ns.ClickCast.CleanBindings(nil) == 0 and #ns.HoverCast.CleanList("x") == 0, "non-tables not handled")
end)

step("blank profile names are refused; chat escapes typed text", function()
	check(not ns.Profiles:Create("   "), "blank profile name accepted")
	check(not ns.Profiles:Rename(ns.Database:ActiveName(), ""), "blank rename accepted")
	check(ns.Escape("a|cffb") == "a||cffb", "| not escaped")
	SlashCmdList.LATTICE("hide |cffnothing")
	SlashCmdList.LATTICE("show")
end)

step("logout strips defaults", function()
	MOCK.Fire("PLAYER_LOGOUT")
	local p = LatticeDB.profiles.Default
	check(p.general == nil or next(p.general) == nil, "defaults not stripped from general")
end)

-- Guarded calls (S.Try / pcall) report failures to chat in debug mode; treat those as failures too.
for _, line in ipairs(MOCK.log) do
	if line:find("failed") or line:find("unavailable") then
		failures[#failures + 1] = "swallowed error: " .. line
		print("  FAIL swallowed: " .. line)
	end
end

print(string.format("\n%d passed, %d failed", passes, #failures))
if #MOCK.errors > 0 then
	print("error handler captured:")
	for _, e in ipairs(MOCK.errors) do print("  " .. tostring(e)) end
end
return #failures
