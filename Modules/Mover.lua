-- Lattice: anchor frames that position the group headers; drag to move when unlocked.
local _, ns = ...
local U, T = ns.Util, ns.Theme
local Mover = {}
ns.Mover = Mover

local anchors = {}
local unlocked = false

-- key: "party" or "raid". Position stored in ns.db.positions[key].
function Mover:GetAnchor(key, label)
	if anchors[key] then return anchors[key] end
	local a = CreateFrame("Frame", "LatticeAnchor_" .. key, UIParent)
	a:SetSize(120, 40)
	a:SetMovable(true)
	a:SetClampedToScreen(true)
	a:RegisterForDrag("LeftButton")
	a.key = key

	local overlay = CreateFrame("Frame", nil, a)
	overlay:SetAllPoints()
	overlay:SetFrameStrata("DIALOG")
	local bg = U.Solid(overlay, "BACKGROUND", T.accent[1], T.accent[2], T.accent[3], 0.25)
	bg:SetAllPoints()
	U.Border(overlay, 1, T.accent[1], T.accent[2], T.accent[3], 0.9)
	local text = overlay:CreateFontString(nil, "OVERLAY")
	U.SetFont(text, 12, "OUTLINE")
	text:SetPoint("CENTER")
	text:SetText("Lattice: " .. (label or key) .. "\n|cffaaaaaadrag to move|r")
	overlay:Hide()
	a.overlay = overlay

	a:SetScript("OnDragStart", function(self)
		if unlocked and not InCombatLockdown() then self:StartMoving() end
	end)
	a:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		Mover:SavePosition(self)
	end)
	anchors[key] = a
	self:RestorePosition(a)
	return a
end

function Mover:SavePosition(a)
	local point, _, relPoint, x, y = a:GetPoint(1)
	ns.db.positions[a.key] = { point = point, relPoint = relPoint, x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
end

function Mover:RestorePosition(a)
	local pos = ns.db.positions[a.key] or ns.Defaults.positions[a.key]
	ns:RunOutOfCombat("anchor-pos-" .. a.key, function()
		a:ClearAllPoints()
		a:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
	end)
end

function Mover:RestoreAll()
	for _, a in pairs(anchors) do self:RestorePosition(a) end
end

-- Size the anchor to the header so the drag box covers the frames.
function Mover:FitAnchor(key, w, h)
	local a = anchors[key]
	if a then
		ns:RunOutOfCombat("anchor-size-" .. key, function()
			a:SetSize(math.max(60, w or 60), math.max(24, h or 24))
		end)
	end
end

function Mover:IsUnlocked() return unlocked end

function Mover:Toggle()
	if InCombatLockdown() then
		ns:Print("Can't move frames in combat.")
		return
	end
	unlocked = not unlocked
	for _, a in pairs(anchors) do
		a:EnableMouse(unlocked)
		a.overlay:SetShown(unlocked)
	end
	-- Show preview frames while unlocked so there's something to see when solo.
	if unlocked and not ns.TestMode:IsActive() then
		ns.TestMode:Start()
		self.startedPreview = true
	elseif not unlocked and self.startedPreview then
		ns.TestMode:Stop()
		self.startedPreview = false
	end
end

ns:RegisterEvent("PLAYER_REGEN_DISABLED", function()
	if unlocked then Mover:Toggle() end
end)
