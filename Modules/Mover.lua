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

	-- The overlay takes the drag: it sits above the unit frames (DIALOG strata), so a box with frames in it
	-- (party) can be grabbed anywhere, not just where no frame covers it.
	overlay:EnableMouse(true)
	overlay:RegisterForDrag("LeftButton")
	overlay:SetScript("OnDragStart", function()
		if unlocked and not InCombatLockdown() then
			a:StartMoving()
			a.moving = true
		end
	end)
	overlay:SetScript("OnDragStop", function() Mover:StopDrag(a) end)
	anchors[key] = a
	self:RestorePosition(a)
	return a
end

-- End a drag and keep where the box was dropped. Also run when the frames lock while a box is still held
-- (combat starting): the box carries the secure headers, so it must not keep moving into combat.
function Mover:StopDrag(a)
	if not a.moving then return end
	a.moving = nil
	a:StopMovingOrSizing()
	self:SavePosition(a)
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

-- on = true unlocks, false locks. quiet: no chat line (combat locking prints its own).
function Mover:SetUnlocked(on, quiet)
	on = on and true or false
	if on and InCombatLockdown() then
		ns:Print("Can't move frames in combat.")
		return
	end
	if on == unlocked then
		if not quiet then ns:Print(on and "Frames are already unlocked." or "Frames are already locked.") end
		return
	end
	unlocked = on
	for _, a in pairs(anchors) do
		if not on then self:StopDrag(a) end
		a.overlay:SetShown(on)
	end
	-- Show preview frames while unlocked so there's something to see when solo.
	if on and not ns.TestMode:IsActive() then
		ns.TestMode:Start()
		self.startedPreview = true
	elseif not on and self.startedPreview then
		ns.TestMode:Stop()
		self.startedPreview = false
	end
	if not quiet then
		ns:Print(on and "Frames unlocked: drag the boxes. Type /lattice lock when done."
			or "Frames locked.")
	end
	ns:Fire("MoverChanged", on)
end

function Mover:Toggle()
	self:SetUnlocked(not unlocked)
end

ns:RegisterEvent("PLAYER_REGEN_DISABLED", function()
	if unlocked then
		Mover:SetUnlocked(false, true)
		ns:Print("Frames locked: combat started.")
	end
end)
