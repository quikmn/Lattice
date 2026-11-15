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

-- Load files listed in the TOC
step("load TOC files", function()
	local toc = assert(io.open(ROOT .. "/LatticePartyRaidFrames.toc")):read("*a")
	for line in toc:gmatch("[^\r\n]+") do
		if not line:match("^%s*#") and line:match("%.lua%s*$") then
			local path = ROOT .. "/" .. line:gsub("\\", "/"):gsub("%s+$", "")
			local chunk, err = loadfile(path)
			if not chunk then error("syntax: " .. err) end
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
