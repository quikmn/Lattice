-- Lattice: secure group headers (party, raid groups, combined raid) and layout switching.
--
-- No restricted snippets are used. All unit buttons are pre-created out of
-- combat (startingIndex trick) and decorated from Lua, so roster changes in
-- combat only re-assign units on buttons that already exist.
local _, ns = ...
local H = {}
ns.Headers = H

H.party = nil
H.raidGroups = {}
H.raidCombined = nil
H.activeLayout = nil -- "party" | "raid" | "raid40"

local TEMPLATE = "LatticeUnitButtonTemplate"
local HIDDEN = CreateFrame("Frame")
HIDDEN:Hide()

------------------------------------------------------------------------
-- Creation
------------------------------------------------------------------------
local function NewHeader(name, parent)
	local hdr = CreateFrame("Frame", name, parent, "SecureGroupHeaderTemplate")
	hdr:SetAttribute("template", TEMPLATE)
	hdr:SetAttribute("templateType", "Button")
	return hdr
end

-- Create `count` child buttons now, while out of combat.
local function Precreate(hdr, count)
	hdr:SetAttribute("_ignore", "precreate")
	hdr:SetAttribute("showSolo", true)
	hdr:SetAttribute("showParty", true)
	hdr:SetAttribute("showRaid", true)
	hdr:SetAttribute("unitsPerColumn", nil)
	hdr:SetAttribute("maxColumns", 1)
	hdr:SetAttribute("groupFilter", nil)
	hdr:Show()
	-- Clearing _ignore does NOT trigger an update (the header skips "_ignore" changes),
	-- so the negative startingIndex is set afterwards: that update creates the buttons.
	hdr:SetAttribute("_ignore", nil)
	hdr:SetAttribute("startingIndex", 1 - count)
	hdr:SetAttribute("startingIndex", 1)
	for i = 1, count + 1 do
		local child = hdr:GetAttribute("child" .. i)
		if child then
			ns.Buttons:Setup(child)
		end
	end
end

function H:Create()
	local partyAnchor = ns.Mover:GetAnchor("party", "Party")
	local raidAnchor = ns.Mover:GetAnchor("raid", "Raid")

	self.party = NewHeader("LatticePartyHeader", partyAnchor)
	Precreate(self.party, 5)

	for g = 1, 8 do
		local hdr = NewHeader("LatticeRaidGroup" .. g, raidAnchor)
		Precreate(hdr, 5)
		self.raidGroups[g] = hdr
	end

	self.raidCombined = NewHeader("LatticeRaidCombined", raidAnchor)
	Precreate(self.raidCombined, 40)

	self:ApplyAll()
end

------------------------------------------------------------------------
-- Layout
------------------------------------------------------------------------
local function Children(hdr)
	local i = 0
	return function()
		i = i + 1
		return hdr:GetAttribute("child" .. i)
	end
end
H.Children = Children

function H:LayoutKeyForRoster()
	if not IsInRaid() then return "party" end
	local n = GetNumGroupMembers()
	if ns.db.general.largeRaidLayout and n > ns.db.general.largeRaidThreshold then
		return "raid40"
	end
	return "raid"
end

function H:CurrentLayout()
	return ns.db.layouts[self.activeLayout or "party"]
end

-- Set the attributes that position units inside a header.
local function ConfigureGrowth(hdr, L, unitsPerColumn, maxColumns)
	local sp = L.spacing
	if L.orientation == "HORIZONTAL" then
		hdr:SetAttribute("point", "LEFT")
		hdr:SetAttribute("xOffset", sp)
		hdr:SetAttribute("yOffset", 0)
		hdr:SetAttribute("columnAnchorPoint", "TOP")
	else
		hdr:SetAttribute("point", "TOP")
		hdr:SetAttribute("xOffset", 0)
		hdr:SetAttribute("yOffset", -sp)
		hdr:SetAttribute("columnAnchorPoint", "LEFT")
	end
	hdr:SetAttribute("columnSpacing", L.groupSpacing or sp)
	hdr:SetAttribute("unitsPerColumn", unitsPerColumn)
	hdr:SetAttribute("maxColumns", maxColumns or 1)
end

local SORT = {
	INDEX = { sortMethod = "INDEX" },
	NAME  = { sortMethod = "NAME" },
}

local GROUP_BY = {
	ROLE  = { groupBy = "ASSIGNEDROLE", order = "TANK,HEALER,DAMAGER,NONE" },
	CLASS = { groupBy = "CLASS", order = "WARRIOR,PALADIN,DRUID,PRIEST,SHAMAN,MONK,EVOKER,DEATHKNIGHT,DEMONHUNTER,ROGUE,HUNTER,MAGE,WARLOCK" },
	GROUP = { groupBy = "GROUP", order = "1,2,3,4,5,6,7,8" },
}

local function ConfigureSorting(hdr, L)
	hdr:SetAttribute("sortMethod", (SORT[L.sortMethod] or SORT.INDEX).sortMethod)
	local gb = GROUP_BY[L.groupBy]
	if gb then
		hdr:SetAttribute("groupBy", gb.groupBy)
		hdr:SetAttribute("groupingOrder", gb.order)
	else
		hdr:SetAttribute("groupBy", nil)
		hdr:SetAttribute("groupingOrder", nil)
	end
end

local function ResizeChildren(hdr, L)
	for child in Children(hdr) do
		child.latticeLayout = L
		child:SetSize(L.width, L.height)
		ns.Buttons:ApplyLayout(child)
	end
end

-- Force the header to recompute (attribute change triggers an update when visible).
local rev = 0
local function Refresh(hdr)
	rev = rev + 1
	hdr:SetAttribute("latticeRev", rev)
end

local function SetHeaderVisible(hdr, condition)
	UnregisterStateDriver(hdr, "visibility")
	if condition == "hide" then
		hdr:SetParent(HIDDEN)
		return
	end
	if condition == "show" then
		hdr:SetParent(hdr.latticeAnchor)
		hdr:Show()
		return
	end
	hdr:SetParent(hdr.latticeAnchor)
	RegisterStateDriver(hdr, "visibility", condition)
end

function H:ApplyParty()
	local hdr = self.party
	hdr.latticeAnchor = hdr.latticeAnchor or hdr:GetParent()
	local L = ns.db.layouts.party
	hdr:SetAttribute("_ignore", "config")
	hdr:SetAttribute("showRaid", false)
	hdr:SetAttribute("showParty", true)
	hdr:SetAttribute("showPlayer", L.showPlayer)
	hdr:SetAttribute("showSolo", L.showSolo)
	hdr:SetAttribute("groupFilter", nil)
	ConfigureGrowth(hdr, L, nil, 1)
	ConfigureSorting(hdr, L)
	ResizeChildren(hdr, L)
	hdr:ClearAllPoints()
	hdr:SetPoint("TOPLEFT", hdr.latticeAnchor, "TOPLEFT", 0, 0)
	hdr:SetAttribute("_ignore", nil)
	SetHeaderVisible(hdr, ns.db.general.enabled and "[group:raid] hide; show" or "hide")
	Refresh(hdr)
	ns.Mover:FitAnchor("party", hdr:GetWidth(), hdr:GetHeight())
end

-- Which raid groups currently have members (only meaningful out of combat).
local function PopulatedGroups()
	local present = {}
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			local _, _, subgroup = GetRaidRosterInfo(i)
			if ns.Secret.IsSecret(subgroup) then
				-- Can't read groups here: show all eight rather than guess.
				for g = 1, 8 do present[g] = true end
				break
			end
			if subgroup then present[subgroup] = true end
		end
	end
	return present
end

function H:ApplyRaid()
	local key = self:LayoutKeyForRoster()
	if key == "party" then key = "raid" end
	local L = ns.db.layouts[key]
	local enabled = ns.db.general.enabled
	local grouped = L.mode == "groups"

	-- Per-group headers
	local present = PopulatedGroups()
	local slot = 0
	for g, hdr in ipairs(self.raidGroups) do
		hdr.latticeAnchor = hdr.latticeAnchor or hdr:GetParent()
		hdr:SetAttribute("_ignore", "config")
		hdr:SetAttribute("showRaid", true)
		hdr:SetAttribute("showParty", false)
		hdr:SetAttribute("showSolo", false)
		hdr:SetAttribute("groupFilter", tostring(g))
		ConfigureGrowth(hdr, L, nil, 1)
		hdr:SetAttribute("groupBy", nil)
		hdr:SetAttribute("sortMethod", (SORT[L.sortMethod] or SORT.INDEX).sortMethod)
		ResizeChildren(hdr, L)

		local visible = grouped and enabled and (present[g] or not L.collapseEmptyGroups or not IsInRaid())
		hdr:ClearAllPoints()
		if visible then
			local perLine = math.max(1, L.groupsPerLine or 8)
			local col = slot % perLine
			local line = math.floor(slot / perLine)
			local groupW = (L.orientation == "HORIZONTAL") and (5 * L.width + 4 * L.spacing) or L.width
			local groupH = (L.orientation == "HORIZONTAL") and L.height or (5 * L.height + 4 * L.spacing)
			local x, y
			if L.orientation == "HORIZONTAL" then
				-- groups stacked as rows, wrapping into new columns
				x = line * (groupW + L.groupSpacing)
				y = -col * (groupH + L.groupSpacing)
			else
				-- groups side by side as columns, wrapping into new rows
				x = col * (groupW + L.groupSpacing)
				y = -line * (groupH + L.groupSpacing)
			end
			hdr:SetPoint("TOPLEFT", hdr.latticeAnchor, "TOPLEFT", x, y)
			slot = slot + 1
		else
			hdr:SetPoint("TOPLEFT", hdr.latticeAnchor, "TOPLEFT", 0, 0)
		end
		hdr:SetAttribute("_ignore", nil)
		SetHeaderVisible(hdr, visible and "[group:raid] show; hide" or "hide")
		Refresh(hdr)
	end

	-- Combined header
	local hdr = self.raidCombined
	hdr.latticeAnchor = hdr.latticeAnchor or hdr:GetParent()
	hdr:SetAttribute("_ignore", "config")
	hdr:SetAttribute("showRaid", true)
	hdr:SetAttribute("showParty", false)
	hdr:SetAttribute("showSolo", false)
	hdr:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
	ConfigureGrowth(hdr, L, L.unitsPerColumn, 8)
	ConfigureSorting(hdr, L)
	ResizeChildren(hdr, L)
	hdr:ClearAllPoints()
	hdr:SetPoint("TOPLEFT", hdr.latticeAnchor, "TOPLEFT", 0, 0)
	hdr:SetAttribute("_ignore", nil)
	SetHeaderVisible(hdr, (not grouped and enabled) and "[group:raid] show; hide" or "hide")
	Refresh(hdr)

	-- Anchor box roughly covering the raid frames
	local cols = grouped and math.min(8, L.groupsPerLine or 8) or math.ceil(40 / math.max(1, L.unitsPerColumn or 5))
	local rows = grouped and 5 or (L.unitsPerColumn or 5)
	if L.orientation == "HORIZONTAL" then cols, rows = rows, cols end
	ns.Mover:FitAnchor("raid", cols * (L.width + L.spacing), rows * (L.height + L.spacing))
	self.activeLayout = IsInRaid() and key or "party"
end

function H:ApplyAll()
	ns:RunOutOfCombat("headers-apply", function()
		self:ApplyParty()
		self:ApplyRaid()
		ns.Mover:RestoreAll()
		ns.Buttons:UpdateAllButtons()
	end)
end

-- Roster changes: re-pick the layout (party/raid/large raid) out of combat.
function H:OnRosterChanged()
	ns:RunOutOfCombat("headers-roster", function()
		local key = self:LayoutKeyForRoster()
		local raidKey = key == "party" and "raid" or key
		if key ~= self.activeLayout or ns.db.layouts[raidKey].collapseEmptyGroups then
			self:ApplyRaid()
			if key == "party" then self.activeLayout = "party" end
		end
	end)
end

-- Fade real headers out while the preview is up (alpha isn't protected).
function H:SetPreviewHidden(hidden)
	local a = hidden and 0 or 1
	if self.party then self.party:SetAlpha(a) end
	for _, hdr in ipairs(self.raidGroups) do hdr:SetAlpha(a) end
	if self.raidCombined then self.raidCombined:SetAlpha(a) end
end

------------------------------------------------------------------------
-- Blizzard frames
------------------------------------------------------------------------
local hiddenBlizzard = false

local function Kill(frame)
	if not frame then return end
	pcall(function()
		frame:UnregisterAllEvents()
		frame:SetParent(HIDDEN)
		frame:Hide()
	end)
end

function H:HideBlizzard()
	if hiddenBlizzard or not ns.db.general.hideBlizzard then return end
	ns:RunOutOfCombat("hide-blizzard", function()
		hiddenBlizzard = true
		Kill(_G.CompactPartyFrame)
		for i = 1, 4 do
			Kill(_G["PartyMemberFrame" .. i])
		end
		if _G.PartyFrame then Kill(_G.PartyFrame) end
		if _G.CompactRaidFrameContainer then Kill(_G.CompactRaidFrameContainer) end
		if _G.CompactRaidFrameManager then Kill(_G.CompactRaidFrameManager) end
	end)
end
