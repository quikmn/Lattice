-- Lattice: startup, settings-change plumbing, slash commands. Loaded last.
local ADDON, ns = ...

-- Options pages call this after changing a value. `scope` says what to rebuild.
--   "layout"     sizes/positions/sorting (secure: deferred out of combat)
--   "appearance" colours, fonts, icons (visual only: immediate)
--   "auras"      aura containers (deferred out of combat)
--   "clickcast"  button attributes (deferred out of combat)
--   "all"
local queued, timerRunning = {}, false

-- Coalesce rapid changes (slider drags) into one rebuild a moment later.
function ns:ApplySettings(scope)
	scope = scope or "all"
	if scope == "appearance" then
		ns:ApplySettingsNow(scope)
		return
	end
	queued[scope] = true
	if timerRunning then return end
	timerRunning = true
	C_Timer.After(0.15, function()
		timerRunning = false
		local scopes = queued
		queued = {}
		if scopes.all then
			ns:ApplySettingsNow("all")
		else
			for s in pairs(scopes) do ns:ApplySettingsNow(s) end
		end
	end)
end

function ns:ApplySettingsNow(scope)
	if scope == "layout" or scope == "all" then
		ns.Headers:ApplyAll()
	end
	if scope == "appearance" or scope == "layout" or scope == "all" then
		ns.Buttons:ApplyLayoutAll()
		ns.Buttons:UpdateAllButtons()
	end
	if scope == "auras" or scope == "all" then
		ns.Auras:Refresh()
	end
	if scope == "clickcast" or scope == "all" then
		ns.ClickCast:ApplyAll()
	end
	if ns.TestMode then ns.TestMode:Relayout() end
end

ns:Listen("ProfileChanged", function()
	ns.Mover:RestoreAll()
	ns:ApplySettingsNow("all")
	if ns.Options and ns.Options.RebuildAll then ns.Options:RebuildAll() end
end)

ns:RegisterEvent("ADDON_LOADED", function(_, name)
	if name ~= ADDON then return end
	ns.Database:Initialize()
	ns.ClickCast:Sort()
end)

ns:RegisterEvent("PLAYER_LOGIN", function()
	ns.Buttons:RegisterEvents()
	ns.Headers:Create()
	ns.Headers:HideBlizzard()
	ns.Profiles:ApplySpecProfile()
	if ns.Profiles:HasSpecs() then
		ns:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function(_, unit)
			if unit == "player" then ns.Profiles:ApplySpecProfile() end
		end)
	end
	-- Click-cast spells are stored by ID and cast by name; refresh names once spells load.
	ns:RegisterEvent("SPELLS_CHANGED", function() ns.ClickCast:ApplyAll() end)
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
local function Help()
	ns:Print("commands:")
	ns:Print("  /lattice            open settings")
	ns:Print("  /lattice unlock     move frames (again to lock)")
	ns:Print("  /lattice preview [5|10|20|25|40]   show fake frames")
	ns:Print("  /lattice probe      report which unit data is secret right now")
	ns:Print("  /lattice status     show why frames are or aren't visible")
	ns:Print("  /lattice debug      toggle debug messages")
end

SLASH_LATTICE1 = "/lattice"
SLASH_LATTICE2 = "/lat"
SlashCmdList.LATTICE = function(msg)
	local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
	if cmd == "" or cmd == "config" or cmd == "options" then
		ns.Options:Toggle()
	elseif cmd == "unlock" or cmd == "lock" or cmd == "move" then
		ns.Mover:Toggle()
	elseif cmd == "preview" or cmd == "test" then
		local n = tonumber(arg)
		if n then
			ns.TestMode.manual = true
			ns.TestMode:Start(n)
		else
			ns.TestMode:Toggle()
		end
	elseif cmd == "probe" then
		ns.Probe()
	elseif cmd == "status" then
		ns.Status()
	elseif cmd == "debug" then
		ns.db.debug = not ns.db.debug
		ns:Print("debug " .. (ns.db.debug and "on" or "off"))
	else
		Help()
	end
end

-- Why aren't frames showing? Dumps header and button state.
function ns.Status()
	local H = ns.Headers
	ns:Printf("status: inGroup=%s inRaid=%s members=%s layout=%s buttons=%d preview=%s",
		tostring(IsInGroup()), tostring(IsInRaid()), tostring(GetNumGroupMembers()),
		tostring(H.activeLayout), #ns.Buttons.all, tostring(ns.TestMode:IsActive()))
	local function dump(label, hdr)
		if not hdr then ns:Print("  " .. label .. ": NOT CREATED") return end
		local units, n = {}, 0
		for child in H.Children(hdr) do
			n = n + 1
			local u = child:GetAttribute("unit")
			if u and child:IsShown() then units[#units + 1] = u end
		end
		local p = hdr:GetParent()
		ns:Printf("  %s: shown=%s visible=%s alpha=%.2f parent=%s children=%d units=[%s] size=%dx%d",
			label, tostring(hdr:IsShown()), tostring(hdr:IsVisible()), hdr:GetAlpha(),
			p and (p:GetName() or "?") or "nil", n, table.concat(units, ","),
			hdr:GetWidth() or 0, hdr:GetHeight() or 0)
	end
	dump("party", H.party)
	dump("raid combined", H.raidCombined)
	local b = ns.Buttons.all[1]
	if b then
		ns:Printf("  button1: unit=%s shown=%s visual=%s alpha=%.2f",
			tostring(b:GetAttribute("unit")), tostring(b:IsShown()), tostring(b.visual and b.visual:IsShown()),
			b.visual and b.visual:GetAlpha() or -1)
	end
	ns:Printf("  auras: enabled=%s containersAvailable=%s rev=%d", tostring(ns.db.auras.enabled),
		tostring(ns.Auras:Available()), ns.Auras.rev)
	for _, btn in ipairs(ns.Buttons.all) do
		if btn.unit and btn:IsVisible() then
			local shown = 0
			for _, c in ipairs(btn.auraContainers or {}) do
				if c:IsShown() then shown = shown + 1 end
			end
			ns:Printf("    %s: containers=%d shown=%d built=%s", btn.unit, #(btn.auraContainers or {}), shown,
				tostring(btn.auraRev == ns.Auras.rev))
		end
	end
	if ns.Auras.lastError then ns:Print("  last aura error: " .. ns.Auras.lastError) end
end

-- In-game check of the assumptions this addon is built on.
function ns.Probe()
	local function s(v) return issecretvalue and issecretvalue(v) and "|cffff8080secret|r" or ("|cff80ff80" .. tostring(v) .. "|r") end
	local u = IsInRaid() and "raid1" or (IsInGroup() and "party1" or "player")
	ns:Printf("probe on %s (in combat: %s)", u, tostring(InCombatLockdown()))
	ns:Print("  UnitHealth", s(UnitHealth(u)), " UnitHealthMax", s(UnitHealthMax(u)))
	local inR, chk = UnitInRange(u)
	ns:Print("  UnitInRange", s(inR), s(chk), " GetRaidTargetIndex", s(GetRaidTargetIndex(u)))
	ns:Print("  UnitName", s((UnitName(u))), " role", s(UnitGroupRolesAssigned(u)), " threat", s(UnitThreatSituation(u)))
	if IsInRaid() then
		local _, _, sub = GetRaidRosterInfo(1)
		ns:Print("  GetRaidRosterInfo subgroup", s(sub))
	end
	if C_Secrets then
		ns:Print("  ShouldAurasBeSecret", tostring(C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()))
	end
	ns:Print("  aura containers available:", tostring(ns.Auras:Available()))
	ns:Print("  heal calculator:", tostring(type(CreateUnitHealPredictionCalculator) == "function"))
end

------------------------------------------------------------------------
-- Addon compartment (minimap addon list)
------------------------------------------------------------------------
function Lattice_OnCompartmentClick(_, button)
	if button == "RightButton" then
		ns.Mover:Toggle()
	else
		ns.Options:Toggle()
	end
end

function Lattice_OnCompartmentEnter(_, frame)
	GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
	GameTooltip:AddLine("Lattice")
	GameTooltip:AddLine("|cffffffffClick|r settings   |cffffffffRight-click|r unlock frames", 0.8, 0.8, 0.8)
	GameTooltip:Show()
end

function Lattice_OnCompartmentLeave()
	GameTooltip:Hide()
end
