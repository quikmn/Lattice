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
		-- idle: the other modules' handlers would run with no settings loaded
		ns:StandDown("PLAYER_LOGIN", function()
			ns:Print("An old copy in the AddOns folder \"Lattice\" was found and turned off. Type /reload, then delete that folder. Your settings are kept.")
		end)
		return
	end
	ns.Database:Initialize()
	ns.ClickCast:Sort()
end)

ns:RegisterEvent("PLAYER_LOGIN", function()
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

-- /lattice (also /lat): the chat-command pattern every EverlookDB addon shares, from EverlookUI. Lattice keeps its own
-- settings window (Options/Window.lua), so the app's window calls go there.
local EUI = LibStub and LibStub("EverlookUI-1", true)
local app = EUI:NewApp({
	name = "Lattice", addon = ADDON, slash = "/lattice", aliases = { "/lat" },
	tagline = "Party and raid frames. Ctrl+Alt+Right-click a frame: tank choice and aura picker.",
	aiAbout = "Lattice draws party and raid frames for WoW Forever: health, power, auras and dispel highlights, click-casting "
		.. "and hover-casting, tank frames and profiles. Its settings window opens with /lattice; every setting below can also be "
		.. "changed with a chat command.",
	siteURL = "https://everlookdb.com/lattice.html", feedbackURL = ns.FEEDBACK_URL,
	accent = { 0.353, 0.663, 1.0 }, settingsPanel = false,
})
ns.app = app
-- AI help and chat know the settings window's settings (Options/AIHelp.lua); changes made in combat wait for it to end.
app:ProvideSettings(function() return ns.AIHelp.Settings() end, { combat = "queue" })
app:AiExtra(function() return ns.AIHelp.Extra() end)
function app:Refresh() if ns.Options:IsShown() then ns.Options:RefreshCurrent() end end
function app:Toggle() ns.Options:Toggle() end
function app:Open() ns.Options:Open() end
function app:Close() if ns.Options:IsShown() then ns.Options:Toggle() end end
function app:IsShown() return ns.Options:IsShown() and true or false end
function app:OpenSearch(text) ns.Options:OpenSearch(text) end

app:Movable({ what = "the frames", get = function() return not ns.Mover:IsUnlocked() end,
	set = function(locked) ns.Mover:SetUnlocked(not locked) end })
app:StatusLines(function() ns.Status() end) -- why frames are or aren't visible

local function auraList(cmd, arg)
	local ids = ns.Auras:ResolveSpells(arg)
	if arg == "" then ns:Print("Name a spell, like /lattice " .. cmd .. " flurry, or give its ID, like /lattice " .. cmd .. " 12966.") return end
	if #ids == 0 then ns:Print("No spell found for \"" .. ns.Escape(arg) .. "\". Use a spell you know, or its ID, like /lattice " .. cmd .. " 12966.") return end
	for _, id in ipairs(ids) do ns.Auras:SetListMode(id, cmd ~= "unlist" and cmd or nil, true) end
	ns.Auras:Refresh()
	if ns.Options:IsShown() then ns.Options:RebuildPage("aurafilters") end
	ns:Printf("%s: %s", table.concat(ids, ", "), cmd == "unlist" and "off the filters" or ns.Auras.LIST_MODES[cmd]:lower())
end

app:Command("preview", "preview [5|10|20|25|40]", "show fake frames", function(arg)
	local n = tonumber(arg)
	if n then
		ns.TestMode.manual = true
		ns.TestMode:Start(n)
	else
		ns.TestMode:Toggle()
	end
end, { "test" })
app:Command("probe", "probe", "which unit data is secret right now", function() ns.Probe() end)
app:Command("tank", "tank [name]", "mark a player as tank (no name: your target)", function(arg) ns.TankCommand("tank", arg) end)
app:Command("notank", "notank [name]", "never treat a player as tank", function(arg) ns.TankCommand("notank", arg) end)
app:Command("autotank", "autotank [name]", "guess again for that player", function(arg) ns.TankCommand("autotank", arg) end)
app:Command("tanks", "tanks", "who counts as tank, and why", function() ns.ListTanks() end)
app:Command("show", "show <spell>", "always show an aura (name or ID)", function(arg) auraList("show", arg) end)
app:Command("hide", "hide <spell>", "never show an aura", function(arg) auraList("hide", arg) end)
app:Command("unlist", "unlist <spell>", "take an aura off the filters", function(arg) auraList("unlist", arg) end)
app:Command("debug", "debug", "debug messages on or off", function()
	ns.db.debug = not ns.db.debug
	ns:Print("debug " .. (ns.db.debug and "on" or "off"))
end)
app:Command("feedback", "feedback", "a link for bugs and ideas", function() ns.ShowFeedback() end, { "bug" })

SLASH_LATTICE1 = "/lattice"
SLASH_LATTICE2 = "/lat"
SlashCmdList.LATTICE = function(msg)
	if ns.oldCopy then ns:Print("Type /reload first: the old \"Lattice\" folder was just turned off.") return end
	app:HandleSlash((msg or ""):lower()) -- names and spells match without case
end

-- /lattice tank, notank or autotank [name]. Names match without case; no name = target.
function ns.TankCommand(cmd, arg)
	local unit = ns.Roles:FindUnit(arg)
	if not unit then
		ns:Print(arg ~= "" and ("No group member called " .. ns.Escape(arg) .. ".") or "Target a group member or give a name, like /lattice tank Thrall.")
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
