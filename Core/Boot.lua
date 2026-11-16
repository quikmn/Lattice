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
		if ns.MissingBuff then ns.MissingBuff:UpdateAll() end
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

-- The folder used to be called "Lattice"; another CurseForge addon has that name, so it is now LatticePartyRaidFrames.
-- If the old folder is still installed it loads first (same code): stay idle this session so there is only one set
-- of frames, turn the old copy off for next time, and say so. LatticeDB is shared, so its settings are kept.
local OLD = "Lattice"
local function oldCopyLoaded()
	if ADDON == OLD or not C_AddOns or not C_AddOns.IsAddOnLoaded then return false end
	return C_AddOns.IsAddOnLoaded(OLD)
end

ns:RegisterEvent("ADDON_LOADED", function(_, name)
	if name ~= ADDON then return end
	if oldCopyLoaded() then
		ns.oldCopy = true
		pcall(C_AddOns.DisableAddOn, OLD)
		return
	end
	ns.Database:Initialize()
	ns.ClickCast:Sort()
end)

ns:RegisterEvent("PLAYER_LOGIN", function()
	if ns.oldCopy then
		ns:Print("An old copy in the AddOns folder \"Lattice\" was found and turned off. Type /reload, then delete that folder. Your settings are kept.")
		return
	end
	ns.Buttons:RegisterEvents()
	ns.Roles:Enable()
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
-- Feedback link. Addons can't open a browser, so show the link selected in a box to copy.
-- Our own small window, not a StaticPopup: StaticPopupDialogs and the popup frames
-- are Blizzard's, and touching them from an addon taints Blizzard's own dialogs and
-- windows (secret-value errors when closing the character sheet and the like).
ns.FEEDBACK_URL = "https://everlookdb.com/lattice.html#feedback"
local feedback

local function FeedbackWindow()
	local W, T, U = ns.Widgets, ns.Theme, ns.Util
	local function rgba(c) return c[1], c[2], c[3], c[4] or 1 end
	local f = CreateFrame("Frame", "LatticeFeedbackWindow", UIParent)
	f:SetSize(380, 132)
	f:SetPoint("TOP", 0, -160)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:Hide()
	U.Solid(f, "BACKGROUND", rgba(T.bg)):SetAllPoints()
	U.Border(f, 1, rgba(T.border))

	local text = W.Text(f, T.font, T.text)
	text:SetPoint("TOPLEFT", 16, -14)
	text:SetPoint("TOPRIGHT", -16, -14)
	text:SetJustifyH("CENTER")
	text:SetText("Report a bug or suggest an idea.\nPress Ctrl+C to copy the link, then paste it in your browser.")

	local box = W.EditBox(f, 348, 24)
	box:SetPoint("TOP", 0, -54)
	box:SetScript("OnTextChanged", function(self)
		if self:GetText() ~= ns.FEEDBACK_URL then
			self:SetText(ns.FEEDBACK_URL)
			self:HighlightText()
		end
	end)
	box:SetScript("OnEnterPressed", function() f:Hide() end)
	box:SetScript("OnEscapePressed", function() f:Hide() end)
	f.box = box

	local close = W.Button(f, CLOSE or "Close", function() f:Hide() end, 100)
	close:SetPoint("BOTTOM", 0, 14)

	f:SetScript("OnShow", function()
		box:SetText(ns.FEEDBACK_URL)
		box:SetFocus()
		box:HighlightText()
	end)
	f:SetScript("OnHide", function() box:ClearFocus() end)
	W.CloseOnEscape(f)
	return f
end

function ns.ShowFeedback()
	feedback = feedback or FeedbackWindow()
	feedback:Show()
	return feedback
end

local function Help()
	ns:Print("commands:")
	ns:Print("  /lattice            open settings")
	ns:Print("  /lattice unlock     move frames (again to lock)")
	ns:Print("  /lattice preview [5|10|20|25|40]   show fake frames")
	ns:Print("  /lattice probe      report which unit data is secret right now")
	ns:Print("  /lattice status     show why frames are or aren't visible")
	ns:Print("  /lattice tank [name]      mark a player as tank (no name = your target)")
	ns:Print("  /lattice notank [name]    never treat a player as tank")
	ns:Print("  /lattice autotank [name]  guess again for that player")
	ns:Print("  /lattice tanks      list who counts as tank and why")
	ns:Print("  /lattice show|hide <spell>   always / never show an aura (name or ID)")
	ns:Print("  /lattice unlist <spell>      take an aura off the filters")
	ns:Print("  Ctrl+Alt+Right-click a frame: tank choice and aura picker")
	ns:Print("  /lattice debug      toggle debug messages")
	ns:Print("  /lattice feedback   link for reporting bugs and ideas")
end

SLASH_LATTICE1 = "/lattice"
SLASH_LATTICE2 = "/lat"
SlashCmdList.LATTICE = function(msg)
	if ns.oldCopy then ns:Print("Type /reload first: the old \"Lattice\" folder was just turned off.") return end
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
	elseif cmd == "tank" or cmd == "notank" or cmd == "autotank" then
		ns.TankCommand(cmd, arg)
	elseif cmd == "tanks" then
		ns.ListTanks()
	elseif cmd == "show" or cmd == "hide" or cmd == "unlist" then
		local ids = ns.Auras:ResolveSpells(arg)
		if #ids == 0 then ns:Print("No spell found for \"" .. arg .. "\". Spell IDs always work.") return end
		for _, id in ipairs(ids) do ns.Auras:SetListMode(id, cmd ~= "unlist" and cmd or nil, true) end
		ns.Auras:Refresh()
		if ns.Options:IsShown() then ns.Options:RebuildPage("aurafilters") end
		ns:Printf("%s: %s", table.concat(ids, ", "), cmd == "unlist" and "off the filters" or ns.Auras.LIST_MODES[cmd]:lower())
	elseif cmd == "feedback" or cmd == "bug" then
		ns.ShowFeedback()
	elseif cmd == "debug" then
		ns.db.debug = not ns.db.debug
		ns:Print("debug " .. (ns.db.debug and "on" or "off"))
	else
		Help()
	end
end

-- /lattice tank, notank or autotank [name]. Names match without case; no name = target.
function ns.TankCommand(cmd, arg)
	local unit = ns.Roles:FindUnit(arg)
	if not unit then
		ns:Print(arg ~= "" and ("No group member called " .. arg .. ".") or "Target a group member or give a name.")
		return
	end
	local value = (cmd == "tank" and "tank") or (cmd == "notank" and "notank") or nil
	ns.Roles:SetOverride(unit, value)
	local name = ns.Secret.Plain(UnitName(unit), unit)
	ns:Print(name .. ": " .. (value == "tank" and "always tank" or value == "notank" and "never tank" or "guessed again"))
end

function ns.ListTanks()
	local any = false
	for _, unit in ipairs(ns.Roles:Roster()) do
		if UnitExists(unit) and ns.Roles:IsTank(unit) then
			any = true
			local why = ns.Roles:Override(ns.Roles.Key(unit)) and "set by you" or ns.Roles:Reason(unit) or "assigned role"
			ns:Print("  " .. tostring(ns.Secret.Plain(UnitName(unit), unit)) .. " (" .. why .. ")")
		end
	end
	if not any then ns:Print("No tank found. /lattice tank <name> sets one.") end
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
