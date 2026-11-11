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
	local toc = assert(io.open(ROOT .. "/Lattice.toc")):read("*a")
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
	for _, style in ipairs({ "border", "overlay", "icon" }) do
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
	MOCK.summons.party1 = nil
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
	for _, id in ipairs({ "general", "layout", "appearance", "auras", "clickcast", "hovercast", "profiles" }) do
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
