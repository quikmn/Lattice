-- Lattice options: main window with sidebar navigation.
local _, ns = ...
local U, T, W = ns.Util, ns.Theme, ns.Widgets
local Options = {}
ns.Options = Options

local function rgba(c) return c[1], c[2], c[3], c[4] or 1 end

local pages, pageOrder = {}, {}
local window, currentPage

-- builder(stack, page) creates widgets into `stack`; called once, lazily.
function Options:RegisterPage(id, title, icon, builder)
	pages[id] = { id = id, title = title, icon = icon, builder = builder }
	pageOrder[#pageOrder + 1] = id
end

local SIDEBAR_W, WIDTH, HEIGHT = 170, 780, 560

local function CreateWindow()
	local f = CreateFrame("Frame", "LatticeOptionsWindow", UIParent)
	f:SetSize(WIDTH, HEIGHT)
	f:SetPoint("CENTER")
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()
	tinsert(UISpecialFrames, "LatticeOptionsWindow") -- close with Escape

	local bg = U.Solid(f, "BACKGROUND", rgba(T.bg))
	bg:SetAllPoints()
	U.Border(f, 1, rgba(T.border))

	-- Sidebar
	local side = CreateFrame("Frame", nil, f)
	side:SetPoint("TOPLEFT", 1, -1)
	side:SetPoint("BOTTOMLEFT", 1, 1)
	side:SetWidth(SIDEBAR_W)
	local sideBg = U.Solid(side, "BACKGROUND", rgba(T.sidebar))
	sideBg:SetAllPoints()
	local sideLine = U.Solid(side, "BORDER", rgba(T.border))
	sideLine:SetWidth(1)
	sideLine:SetPoint("TOPRIGHT")
	sideLine:SetPoint("BOTTOMRIGHT")

	local logo = W.Text(side, T.fontHuge, T.text)
	logo:SetPoint("TOPLEFT", 18, -18)
	logo:SetText("Lattice")
	local ver = W.Text(side, T.fontSmall, T.muted)
	ver:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -3)
	ver:SetText("v" .. ns.version)

	f.navButtons = {}
	for i, id in ipairs(pageOrder) do
		local p = pages[id]
		local b = CreateFrame("Button", nil, side)
		b:SetHeight(30)
		b:SetPoint("TOPLEFT", 8, -64 - (i - 1) * 32)
		b:SetPoint("RIGHT", -8, 0)
		b.bg = U.Solid(b, "BACKGROUND", rgba(T.accentDim))
		b.bg:SetAllPoints()
		b.bg:Hide()
		b.bar = U.Solid(b, "ARTWORK", rgba(T.accent))
		b.bar:SetWidth(2)
		b.bar:SetPoint("TOPLEFT")
		b.bar:SetPoint("BOTTOMLEFT")
		b.bar:Hide()
		b.text = W.Text(b, T.font, T.muted)
		b.text:SetPoint("LEFT", 12, 0)
		b.text:SetText(p.title)
		b:SetScript("OnEnter", function(self) if currentPage ~= id then self.text:SetTextColor(rgba(T.text)) end end)
		b:SetScript("OnLeave", function(self) if currentPage ~= id then self.text:SetTextColor(rgba(T.muted)) end end)
		b:SetScript("OnClick", function() Options:ShowPage(id) end)
		f.navButtons[id] = b
	end

	-- Footer actions in the sidebar
	local preview = W.Button(side, "Preview frames", function(self)
		ns.TestMode:Toggle()
		self:SetText(ns.TestMode:IsActive() and "Stop preview" or "Preview frames")
	end, SIDEBAR_W - 16)
	preview:SetPoint("BOTTOMLEFT", 8, 44)
	f.previewButton = preview

	local unlock = W.Button(side, "Unlock frames", function(self)
		ns.Mover:Toggle()
		self:SetText(ns.Mover:IsUnlocked() and "Lock frames" or "Unlock frames")
	end, SIDEBAR_W - 16)
	unlock:SetPoint("BOTTOMLEFT", 8, 12)
	f.unlockButton = unlock

	-- Close button
	local close = CreateFrame("Button", nil, f)
	close:SetSize(24, 24)
	close:SetPoint("TOPRIGHT", -8, -8)
	local x = W.Text(close, T.fontTitle, T.muted)
	x:SetPoint("CENTER")
	x:SetText("x")
	close:SetScript("OnEnter", function() x:SetTextColor(rgba(T.text)) end)
	close:SetScript("OnLeave", function() x:SetTextColor(rgba(T.muted)) end)
	close:SetScript("OnClick", function() f:Hide() end)

	-- Content area
	local content = CreateFrame("Frame", nil, f)
	content:SetPoint("TOPLEFT", SIDEBAR_W + 1 + T.pad + 8, -T.pad - 8)
	content:SetPoint("BOTTOMRIGHT", -T.pad, T.pad)
	f.content = content

	f:SetScript("OnHide", function()
		W.ClosePopup()
		if ns.TestMode:IsActive() and not ns.TestMode.manual then ns.TestMode:Stop() end
	end)
	f:SetScript("OnShow", function()
		f.previewButton:SetText(ns.TestMode:IsActive() and "Stop preview" or "Preview frames")
		f.unlockButton:SetText(ns.Mover:IsUnlocked() and "Lock frames" or "Unlock frames")
		if currentPage and pages[currentPage].stack then pages[currentPage].stack:RefreshAll() end
	end)
	return f
end

function Options:ShowPage(id)
	if not window then return end
	local p = pages[id]
	if not p then return end
	for pid, other in pairs(pages) do
		if other.scroll then other.scroll:SetShown(pid == id) end
		local b = window.navButtons[pid]
		local active = pid == id
		b.bg:SetShown(active)
		b.bar:SetShown(active)
		b.text:SetTextColor(rgba(active and T.text or T.muted))
	end
	if not p.scroll then
		p.scroll = W.ScrollPage(window.content)
		local width = window.content:GetWidth() - 12
		p.scroll.child:SetWidth(width)
		p.stack = W.Stack(p.scroll.child, width)
		p.builder(p.stack, p)
		p.scroll:UpdateBar()
	else
		p.stack:RefreshAll()
	end
	p.scroll:Show()
	currentPage = id
end

-- Rebuild a page from scratch (used when its structure depends on data, e.g. lists).
function Options:RebuildPage(id)
	local p = pages[id]
	if not p or not p.scroll then return end
	p.scroll:Hide()
	p.scroll:SetParent(nil)
	p.scroll = nil
	p.stack = nil
	if currentPage == id then self:ShowPage(id) end
end

function Options:RebuildAll()
	for id in pairs(pages) do self:RebuildPage(id) end
end

-- Binding helper: Options.Bind("appearance.nameSize", "appearance", { label = ..., ... })
-- Values are always read from the *current* profile (ns.db can change on profile switch).
function Options.Bind(path, scope, opt)
	opt = opt or {}
	opt.get = function() return U.Get(ns.db, path) end
	opt.set = function(v)
		U.Set(ns.db, path, v)
		ns:ApplySettings(scope)
	end
	return opt
end

function Options:RefreshCurrent()
	local p = currentPage and pages[currentPage]
	if p and p.stack then p.stack:RefreshAll() end
end

function Options:Toggle()
	if not window then window = CreateWindow() end
	if window:IsShown() then
		window:Hide()
	else
		window:Show()
		self:ShowPage(currentPage or pageOrder[1])
	end
end

function Options:Open(pageId)
	if not window then window = CreateWindow() end
	window:Show()
	self:ShowPage(pageId or currentPage or pageOrder[1])
end

function Options:IsShown()
	return window and window:IsShown()
end
