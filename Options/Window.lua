-- Lattice options: main window with sidebar navigation.
local _, ns = ...
local U, T, W = ns.Util, ns.Theme, ns.Widgets
local Options = {}
ns.Options = Options

local function rgba(c) return c[1], c[2], c[3], c[4] or 1 end

local pages, pageOrder = {}, {}
local window, currentPage

-- Settings search: the matcher is EverlookUI's (Libs\EverlookUI), the same as in quikmn's other addons.
local EUI = LibStub and LibStub("EverlookUI-1", true)
local Search = EUI and EUI.Search
local search = { on = false, borrowed = {} } -- on: results shown; borrowed[entry]: controls listed now
local MAX_RESULTS = 50
local PATH_SEP = " \194\187 " -- " » "

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

	-- Footer actions in the sidebar (plain buttons: a page's one gold button is its own)
	local ai = W.Button(side, "AI help", function() ns.app:ShowAiHelp() end, SIDEBAR_W - 16)
	ai:SetPoint("BOTTOMLEFT", 8, 108)
	W.Tooltip(ai, "Get help from AI to set up Lattice",
		"Copies a description of every setting. Paste it into Claude or another AI and say what you want, then paste its answer into /lattice apply. You see every change before it is made.")
	f.aiButton = ai

	local feedback = W.Button(side, "Feedback / report a bug", function() ns.ShowFeedback() end, SIDEBAR_W - 16)
	feedback:SetPoint("BOTTOMLEFT", 8, 76)

	local preview = W.Button(side, "Preview frames", function() ns.TestMode:Toggle() end, SIDEBAR_W - 16)
	preview:SetPoint("BOTTOMLEFT", 8, 44)
	f.previewButton = preview

	local unlock = W.Button(side, "Unlock frames", function() ns.Mover:Toggle() end, SIDEBAR_W - 16)
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
	content:SetPoint("TOPLEFT", SIDEBAR_W + 1 + T.pad + 8, -52) -- the search box sits above
	content:SetPoint("BOTTOMRIGHT", -T.pad, T.pad)
	f.content = content

	if Search then Options:CreateSearch(f) end

	f:SetScript("OnHide", function()
		W.ClosePopup()
		if f.searchBox then f.searchBox:ClearFocus(); Options:StopSearch() end
		if ns.TestMode:IsActive() and not ns.TestMode.manual then ns.TestMode:Stop() end
	end)
	-- the buttons follow the state, whatever changed it (slash command, combat, the other button)
	local function syncButtons()
		f.previewButton:SetText(ns.TestMode:IsActive() and "Stop preview" or "Preview frames")
		f.unlockButton:SetText(ns.Mover:IsUnlocked() and "Lock frames" or "Unlock frames")
	end
	ns:Listen("PreviewChanged", syncButtons)
	ns:Listen("MoverChanged", syncButtons)
	f:SetScript("OnShow", function()
		syncButtons()
		if currentPage and pages[currentPage].stack then pages[currentPage].stack:RefreshAll() end
		if Search then Options:WarmSearch() end
	end)
	W.CloseOnEscape(f) -- not UISpecialFrames, see there
	return f
end

local function IndexWidget(p, stack, frame)
	local header = stack.searchHeader
	if header and Search.Normalize(header) == Search.Normalize(p.title) then header = nil end -- "General » General"
	local info = {}
	for k, v in pairs(frame.searchInfo) do info[k] = v end
	info.section, info.header = p.title, header
	local e = Search.Entry(info)
	e.frame, e.stack, e.page = frame, stack, p
	e.path = p.title .. (header and (PATH_SEP .. header) or "")
	p.entries[#p.entries + 1] = e
end

-- A page's widgets, built hidden (ShowPage shows it; the search reads it).
local function BuildPage(p)
	if p.scroll then return end
	p.scroll = W.ScrollPage(window.content)
	p.scroll:Hide()
	local width = window.content:GetWidth() - 24 -- the scroll bar takes the right edge
	p.scroll.child:SetWidth(width)
	p.stack = W.Stack(p.scroll.child, width)
	p.entries = {}
	if Search then
		p.stack.onIndex = function(stack, frame) IndexWidget(p, stack, frame) end
		p.stack.onRefreshAll = function(stack) if search.on then Options:RefreshBorrowed(stack) end end
	end
	p.builder(p.stack, p)
	p.scroll:UpdateBar()
	p.searchFailed = nil
end

local function DropPage(p)
	if p.scroll then p.scroll:Hide(); p.scroll:SetParent(nil) end
	p.scroll, p.stack, p.entries = nil, nil, nil
end

function Options:ShowPage(id)
	if not window then return end
	local p = pages[id]
	if not p then return end
	if search.on then self:StopSearch() end -- a page picked in the sidebar ends the search
	for pid, other in pairs(pages) do
		if other.scroll then other.scroll:SetShown(pid == id) end
		local b = window.navButtons[pid]
		local active = pid == id
		b.bg:SetShown(active)
		b.bar:SetShown(active)
		b.text:SetTextColor(rgba(active and T.text or T.muted))
	end
	if not p.scroll then
		BuildPage(p)
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
	if search.on then self:ReturnBorrowed() end
	DropPage(p)
	if search.on then
		self:Search(search.query or "") -- builds it again for the results
	elseif currentPage == id then
		self:ShowPage(id)
	end
end

function Options:RebuildAll()
	for id in pairs(pages) do self:RebuildPage(id) end
end

-- Binding helper: Options.Bind("appearance.nameSize", "appearance", { label = ..., ... })
-- Values are always read from the *current* profile (ns.db can change on profile switch).
-- The path is the setting's key for chat and AI help (opt.key), unless opt.key names another.
function Options.Bind(path, scope, opt)
	opt = opt or {}
	opt.key = opt.key or path
	opt.get = function() return U.Get(ns.db, path) end
	opt.set = function(v)
		U.Set(ns.db, path, v)
		ns:ApplySettings(scope)
	end
	return opt
end

function Options:RefreshCurrent()
	if search.on then self:RefreshBorrowed() return end
	local p = currentPage and pages[currentPage]
	if p and p.stack then p.stack:RefreshAll() end
end

------------------------------------------------------------------------
-- Settings search: a box at the top centre (Ctrl+F). Typing lists the matching controls from every page;
-- they are the real ones, borrowed from their page while listed, so changing one there changes the setting.
-- The path over each ("Appearance » Health bar") opens its page and lights it up. Escape clears, then closes.
------------------------------------------------------------------------
-- Build the pages not built yet (all, or with `one` just the next). True when one was built.
function Options:EnsureSearchIndex(one)
	if not window then return false end
	for _, id in ipairs(pageOrder) do
		local p = pages[id]
		if not p.scroll and not p.searchFailed then
			local ok, err = pcall(BuildPage, p)
			if not ok then
				DropPage(p)
				p.searchFailed = true -- reported once; it is built again when opened
				local handler = geterrorhandler and geterrorhandler()
				if handler then handler(err) end
			end
			if one then return true end
		end
	end
	return false
end

-- After the window opens: build the other pages one per frame, so the first search is instant.
function Options:WarmSearch()
	if search.warming then return end
	search.warming = true
	local function step()
		if not self:IsShown() or not self:EnsureSearchIndex(true) then search.warming = nil return end
		C_Timer.After(0, step)
	end
	C_Timer.After(0, step)
end

local function Listed(e) return e.frame:IsShown() end

function Options:SearchEntries()
	local all = {}
	for _, id in ipairs(pageOrder) do
		for _, e in ipairs(pages[id].entries or {}) do all[#all + 1] = e end
	end
	return all
end

local function Borrow(e, parent, y, width)
	local fr = e.frame
	if not search.borrowed[e] then
		search.borrowed[e] = true
		fr:SetParent(parent)
	end
	fr:ClearAllPoints()
	fr:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
	fr:SetWidth(width)
	fr:SetHeight(fr.searchSlot.height)
	if fr.Refresh then fr:Refresh() end
end

-- Put controls back where they were on their page (all, or those not in `keep`).
function Options:ReturnBorrowed(keep)
	for e in pairs(search.borrowed) do
		if not (keep and keep[e]) then
			search.borrowed[e] = nil
			local fr, slot = e.frame, e.frame.searchSlot
			local st = slot.stack
			fr:SetParent(st.parent)
			fr:ClearAllPoints()
			fr:SetPoint("TOPLEFT", st.parent, "TOPLEFT", slot.indent, -slot.y)
			fr:SetWidth(st.width - slot.indent)
			fr:SetHeight(slot.height)
		end
	end
end

function Options:RefreshBorrowed(skipStack)
	if search.refreshing then return end
	search.refreshing = true
	for e in pairs(search.borrowed) do
		if e.stack ~= skipStack and e.frame.Refresh then e.frame:Refresh() end
	end
	search.refreshing = nil
end

-- Search for `text`; an empty text ends the search. Returns the matches.
function Options:Search(text)
	if not window or not Search then return {} end
	local q = U.Trim and U.Trim(text) or tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if q == "" then self:StopSearch() return {} end
	self:EnsureSearchIndex()
	if not search.on then
		search.on = true
		W.ClosePopup()
		for _, p in pairs(pages) do if p.scroll then p.scroll:Hide() end end
	end
	search.query = q
	local entries = self:SearchEntries()
	local results = Search.Match(entries, q, Listed)
	self:ShowResults(results, q, entries)
	return results
end

local function Esc(s) return (tostring(s):gsub("|", "||")) end

function Options:ShowResults(results, q, entries)
	local R = window.results
	local child = R.child
	local width = window.content:GetWidth() - 24
	R.child:SetWidth(width)
	local n = math.min(#results, MAX_RESULTS)
	local want = {}
	for i = 1, n do want[results[i].entry] = true end
	self:ReturnBorrowed(want)
	for _, row in ipairs(R.paths) do row.entry = nil; row:Hide() end
	R.empty:Hide()
	R.suggest:Hide()
	R.more:Hide()
	local y = 4
	if n == 0 then
		R.empty:SetText(("No setting matches '%s'."):format(Esc(q)))
		R.empty:Show()
		y = y + 22
		local sug = Search.Suggest(entries, q, Listed)
		R.suggest.query = sug
		if sug then
			local a = T.accent
			R.suggest.label:SetText(("Did you mean |cff%02x%02x%02x%s|r?"):format(a[1] * 255, a[2] * 255, a[3] * 255, Esc(sug)))
			R.suggest:SetWidth(math.min(width, (R.suggest.label:GetStringWidth() or 200) + 4))
			R.suggest:Show()
			y = y + 22
		end
	else
		for i = 1, n do
			local e = results[i].entry
			local row = R.paths[i] or R.NewPath(i)
			row.entry = e
			row.text:SetText(e.path)
			local tw = row.text.GetUnboundedStringWidth and row.text:GetUnboundedStringWidth() or row.text:GetStringWidth() or 200
			row:SetWidth(math.min(width, (tw or 200) + 4))
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
			row:Show()
			y = y + 17
			Borrow(e, child, y, width)
			y = y + e.frame.searchSlot.height + 18
		end
		if #results > n then
			R.more:SetText(("%d more. Add a word to narrow it down."):format(#results - n))
			R.more:ClearAllPoints()
			R.more:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
			R.more:Show()
			y = y + 20
		end
	end
	child:SetHeight(y + T.pad)
	R:Show()
	R.SetScroll(0)
	R.UpdateBar()
end

-- End the search: the controls go back and the page you were on shows again.
function Options:StopSearch()
	if window and window.searchBox and window.searchBox:GetText() ~= "" then window.searchBox:SetText("") end
	if not search.on then return end
	search.on = false
	self:ReturnBorrowed()
	W.ClosePopup()
	window.results:Hide()
	local p = currentPage and pages[currentPage]
	if p and p.scroll then
		p.stack:RefreshAll()
		p.scroll:Show()
	end
end

-- From a result's path: open its page, scroll to the control and light it up for a moment.
function Options:JumpTo(e)
	local p = e.page
	self:StopSearch()
	self:ShowPage(p.id)
	if currentPage ~= p.id or e.stack ~= p.stack then return end
	if p.scroll.SetScroll then p.scroll.SetScroll(e.frame.searchSlot.y - 12) end
	local fr = e.frame
	local tex = rawget(fr, "searchFlash")
	if not tex then
		tex = fr:CreateTexture(nil, "BACKGROUND", nil, -8)
		tex:SetTexture("Interface\\Buttons\\WHITE8X8")
		tex:SetPoint("TOPLEFT", -6, 4)
		tex:SetPoint("BOTTOMRIGHT", 6, -4)
		fr.searchFlash = tex
	end
	tex:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 1)
	tex:SetAlpha(0.28)
	tex:Show()
	local driver = search.flash or CreateFrame("Frame")
	search.flash = driver
	if driver.tex and driver.tex ~= tex then driver.tex:Hide() end
	driver.tex = tex
	local start = GetTime()
	driver:SetScript("OnUpdate", function(d)
		local t = GetTime() - start
		if t >= 1.8 then tex:Hide(); d.tex = nil; d:SetScript("OnUpdate", nil) return end
		tex:SetAlpha(t < 0.6 and 0.28 or 0.28 * (1 - (t - 0.6) / 1.2))
	end)
end

function Options:CreateSearch(f)
	local box = W.EditBox(f, 300, 26)
	box:SetPoint("TOP", f, "TOPLEFT", SIDEBAR_W + 1 + (WIDTH - SIDEBAR_W - 1) / 2, -12)
	box:SetTextInsets(26, 26, 0, 0)
	box:SetMaxLetters(60)
	local icon = box:CreateTexture(nil, "OVERLAY")
	icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
	icon:SetSize(14, 14)
	icon:SetPoint("LEFT", 8, -1)
	icon:SetVertexColor(rgba(T.muted))
	local hint = W.Text(box, T.font, T.muted)
	hint:SetPoint("LEFT", 26, 0)
	hint:SetText("Search settings")
	local keyHint = W.Text(box, T.fontSmall, T.muted)
	keyHint:SetPoint("RIGHT", -9, 0)
	keyHint:SetText("Ctrl+F")
	local clear = CreateFrame("Button", nil, box)
	clear:SetSize(22, 22)
	clear:SetPoint("RIGHT", -2, 0)
	local cx = W.Text(clear, T.font, T.muted)
	cx:SetPoint("CENTER")
	cx:SetText("x")
	clear:SetScript("OnEnter", function() cx:SetTextColor(rgba(T.text)) end)
	clear:SetScript("OnLeave", function() cx:SetTextColor(rgba(T.muted)) end)
	clear:SetScript("OnClick", function() Options:StopSearch(); box:SetFocus() end)
	W.Tooltip(clear, "Clear the search")
	local function update()
		local empty = (box:GetText() or "") == ""
		hint:SetShown(empty)
		keyHint:SetShown(empty and not box:HasFocus())
		clear:SetShown(not empty)
	end
	box.UpdateHint = update
	box:HookScript("OnEditFocusGained", update)
	box:HookScript("OnEditFocusLost", update)
	local pending -- searches once per frame at most, however fast you type or paste
	box:SetScript("OnTextChanged", function(_, user)
		update()
		if not user or pending then return end
		pending = true
		C_Timer.After(0, function()
			pending = nil
			if f:IsShown() then Options:Search(box:GetText()) end
		end)
	end)
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	box:SetScript("OnEscapePressed", function(self)
		local had = (self:GetText() or "") ~= "" or search.on
		self:ClearFocus()
		if had then Options:StopSearch() else f:Hide() end
	end)
	update()
	f.searchBox = box

	local R = W.ScrollPage(f.content)
	R:Hide()
	R.paths = {}
	function R.NewPath(i)
		local b = CreateFrame("Button", nil, R.child)
		b:SetHeight(14)
		b.text = W.Text(b, T.fontSmall + 1, T.muted)
		b.text:SetPoint("LEFT")
		b.text:SetWordWrap(false)
		b:SetScript("OnEnter", function(self)
			self.text:SetTextColor(rgba(T.accent))
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine("Go to this setting", 1, 1, 1)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function(self)
			self.text:SetTextColor(rgba(T.muted))
			GameTooltip:Hide()
		end)
		b:SetScript("OnClick", function(self) if self.entry then Options:JumpTo(self.entry) end end)
		R.paths[i] = b
		return b
	end
	R.empty = W.Text(R.child, T.font, T.text)
	R.empty:SetPoint("TOPLEFT", 0, -4)
	R.empty:SetPoint("RIGHT")
	R.empty:Hide()
	R.suggest = CreateFrame("Button", nil, R.child)
	R.suggest:SetHeight(18)
	R.suggest:SetPoint("TOPLEFT", 0, -26)
	R.suggest.label = W.Text(R.suggest, T.font, T.muted)
	R.suggest.label:SetPoint("LEFT")
	R.suggest.label:SetWordWrap(false)
	R.suggest:SetScript("OnClick", function(self)
		if not self.query then return end
		box:SetText(self.query)
		box.UpdateHint()
		Options:Search(self.query)
	end)
	R.suggest:Hide()
	R.more = W.Text(R.child, T.fontSmall + 1, T.muted)
	R.more:Hide()
	f.results = R

	f.eluiKey = function(_, key)
		if key == "F" and IsControlKeyDown() then
			box:SetFocus()
			box:HighlightText()
			return true
		end
	end
	f.eluiEscape = function()
		if search.on or (box:GetText() or "") ~= "" then Options:StopSearch() return true end
	end
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

-- Every page built (hidden), the window made if it wasn't: what AI help and chat read the settings from.
-- Returns the search entries of every page (the controls with their page and heading).
function Options:AllEntries()
	if not Search then return {} end
	if not window then window = CreateWindow() end
	self:EnsureSearchIndex()
	return self:SearchEntries()
end

-- /lattice search <words>: the window with its search box filled (empty: the box gets the focus).
function Options:OpenSearch(text)
	self:Open()
	local box = window and window.searchBox
	if not box then return end
	text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	box:SetText(text)
	if box.UpdateHint then box.UpdateHint() end
	if text == "" then box:SetFocus() else self:Search(text) end
end
