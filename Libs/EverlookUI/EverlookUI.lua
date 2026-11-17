-- EverlookUI: the settings window look shared by quikmn's addons (the Lattice style).
--
-- Single source of truth: D:\Dev\EverlookUI\EverlookUI.lua. Each addon carries a copy in
-- Libs\EverlookUI\ (sync.py writes it; release-addon.py and install-addons.ps1 keep it current).
-- Versioned with LibStub: when several addons carry it, the newest copy is the one every addon uses.
-- Bump MINOR whenever this file changes.
--
--   local UI = LibStub("EverlookUI-1")
--   local app = UI:NewApp({ name = "Whack", addon = ADDON, slash = "/whack", tagline = "...", accent = {r, g, b} })
--   app:Setting({ key = "fontsize", type = "number", label = "Font size", min = 8, max = 48, get = ..., set = ... })
--   app:Command("test", "test", "show fake numbers", function(rest) ... end)
--   app:Section("general", "General", function(stack, app) app:Widget(stack, "fontsize") end)
--   app:Movable({ what = "the text areas", get = ..., set = ... })   -- /whack lock, unlock
--   app:Reset("outgoing", "the outgoing area", function() ... end)   -- /whack reset outgoing (asks first)
--   app:StatusLines(function() return "seen 12 hits" end)            -- /whack status
--   app:RegisterSlash("WHACK")   -- or SlashCmdList.WHACK = function(msg) app:HandleSlash(msg) end
-- Chat commands follow one pattern in every addon: see "Chat commands" below and COMMANDS.md.
--
-- Widgets: Header, Note, Toggle, Slider, Dropdown, Color, Input, CopyBox, Stat, List, Button, ConfirmButton,
-- ButtonRow, TextArea, ScrollPage. Bound widgets take { label, desc, get, set, disabled, after } and have :Refresh().
-- The mouse wheel scrolls the page: sliders and dropdowns never take it. The page scroll bar is 12 px and draggable.
--
-- Search: every window has a search box at the top centre (Ctrl+F; Escape clears it, then closes the window).
-- It finds settings (app:Widget), plain toggles, sliders, dropdowns, colour swatches and button rows on any
-- page, by label, description, page and heading, a dropdown's value and choices, the chat-command name and
-- optional keywords: app:Setting({ ..., keywords = { "opacity", "alpha" } }) or a widget's/button's opt.keywords.
-- opt.search = false keeps a widget out. Results are the real controls, borrowed from their page while listed.
local MAJOR, MINOR = "EverlookUI-1", 4
local UI = LibStub:NewLibrary(MAJOR, MINOR)
if not UI then return end
UI.version = MINOR

------------------------------------------------------------------------
-- Theme
------------------------------------------------------------------------
UI.Theme = {
	bg        = { 0.071, 0.078, 0.094, 0.97 }, -- window
	sidebar   = { 0.055, 0.060, 0.074, 1 },
	surface   = { 0.105, 0.114, 0.137, 1 },   -- cards / inputs
	surfaceHi = { 0.137, 0.149, 0.180, 1 },   -- hover
	border    = { 0.180, 0.196, 0.235, 1 },
	text      = { 0.902, 0.910, 0.933, 1 },
	muted     = { 0.553, 0.580, 0.639, 1 },
	accent    = { 0.353, 0.663, 1.000, 1 },   -- #5aa9ff (Lattice blue)
	accentDim = { 0.353, 0.663, 1.000, 0.18 },
	danger    = { 0.937, 0.365, 0.365, 1 },
	ok        = { 0.384, 0.812, 0.533, 1 },
	onAccent  = { 0.05, 0.07, 0.1, 1 },        -- text and knobs drawn on the accent colour

	fontSmall = 10,
	font      = 12,
	fontTitle = 14,
	fontHuge  = 18,

	pad = 16,
	rowGap = 10,
}

-- A theme with another accent colour ({ r, g, b }); everything else from UI.Theme.
function UI.MakeTheme(accent)
	local T = {}
	for k, v in pairs(UI.Theme) do T[k] = v end
	if type(accent) == "table" and accent[1] then
		T.accent = { accent[1], accent[2], accent[3], 1 }
		T.accentDim = { accent[1], accent[2], accent[3], 0.18 }
	end
	return T
end

local function rgba(c) return c[1], c[2], c[3], c[4] or 1 end
local function hex(c) return string.format("%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end

------------------------------------------------------------------------
-- Util
------------------------------------------------------------------------
local U = {}
UI.Util = U
U.WHITE = "Interface\\Buttons\\WHITE8X8"
U.rgba, U.Hex = rgba, hex

function U.CopyTable(src)
	if type(src) ~= "table" then return src end
	local t = {}
	for k, v in pairs(src) do t[k] = U.CopyTable(v) end
	return t
end

-- Fill missing keys in `dst` from `defaults`, recursively. Never overwrites.
-- Arrays (tables with [1]) are values: copied only when missing.
function U.FillDefaults(dst, defaults)
	for k, v in pairs(defaults) do
		if dst[k] == nil then
			dst[k] = U.CopyTable(v)
		elseif type(v) == "table" and type(dst[k]) == "table" and v[1] == nil then
			U.FillDefaults(dst[k], v)
		end
	end
	return dst
end

function U.Get(t, path)
	for key in string.gmatch(path, "[^%.]+") do
		if type(t) ~= "table" then return nil end
		t = t[tonumber(key) or key]
	end
	return t
end

function U.Set(t, path, value)
	local keys = {}
	for key in string.gmatch(path, "[^%.]+") do keys[#keys + 1] = tonumber(key) or key end
	for i = 1, #keys - 1 do
		local k = keys[i]
		if type(t[k]) ~= "table" then t[k] = {} end
		t = t[k]
	end
	t[keys[#keys]] = value
end

-- Text shown literally in chat or a font string: a lone "|" starts an escape code.
function U.Escape(s) return (tostring(s):gsub("|", "||")) end

function U.Trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

function U.Font() return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end

function U.SetFont(fs, size, flags)
	local ok = fs:SetFont(U.Font(), size or 11, flags or "")
	if not ok then fs:SetFontObject(GameFontHighlightSmall) end
end

function U.Solid(parent, layer, r, g, b, a, sublevel)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
	t:SetTexture(U.WHITE)
	t:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
	return t
end

-- 1 px border from 4 textures (no backdrop templates).
function U.Border(parent, size, r, g, b, a, layer)
	size = size or 1
	local border = {}
	local function edge()
		local t = parent:CreateTexture(nil, layer or "BORDER", nil, 7)
		t:SetTexture(U.WHITE)
		t:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
		return t
	end
	border.top = edge()
	border.top:SetPoint("TOPLEFT")
	border.top:SetPoint("TOPRIGHT")
	border.top:SetHeight(size)
	border.bottom = edge()
	border.bottom:SetPoint("BOTTOMLEFT")
	border.bottom:SetPoint("BOTTOMRIGHT")
	border.bottom:SetHeight(size)
	border.left = edge()
	border.left:SetPoint("TOPLEFT")
	border.left:SetPoint("BOTTOMLEFT")
	border.left:SetWidth(size)
	border.right = edge()
	border.right:SetPoint("TOPRIGHT")
	border.right:SetPoint("BOTTOMRIGHT")
	border.right:SetWidth(size)
	function border:SetColor(r2, g2, b2, a2)
		for _, key in ipairs({ "top", "bottom", "left", "right" }) do self[key]:SetVertexColor(r2, g2, b2, a2 or 1) end
	end
	function border:SetShown(shown)
		for _, key in ipairs({ "top", "bottom", "left", "right" }) do self[key]:SetShown(shown) end
	end
	return border
end

-- The theme a widget should use: the stack's, or the nearest parent window's.
local function ThemeOf(x)
	if type(x) == "table" then
		if rawget(x, "isStack") then return x.T end
		local f = x
		for _ = 1, 25 do
			if type(f) ~= "table" then break end
			local t = rawget(f, "eluiTheme")
			if t then return t end
			f = f.GetParent and f:GetParent()
		end
	end
	return UI.Theme
end
UI.ThemeOf = ThemeOf

------------------------------------------------------------------------
-- Basic pieces
------------------------------------------------------------------------
local function Text(parent, size, color, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	U.SetFont(fs, size or UI.Theme.font)
	fs:SetTextColor(rgba(color or UI.Theme.text))
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(true)
	return fs
end
UI.Text = Text

local function Tooltip(frame, title, body)
	if not body and not title then return end
	frame:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if title then GameTooltip:AddLine(title, 1, 1, 1) end
		if body then GameTooltip:AddLine(body, nil, nil, nil, true) end
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end
UI.Tooltip = Tooltip

-- Escape closes `frame` through its own key handler. Not UISpecialFrames: Blizzard walks that list when
-- Escape closes its own windows, and an entry written by an addon taints the walk (secret-value errors
-- in Blizzard's OnHide). Other keys pass through to the game. SetPropagateKeyboardInput is blocked in
-- combat, so a window opened in combat leaves the keyboard alone and Escape then also reaches the game.
-- Call after the frame's own OnShow script is set (this hooks it).
function UI.CloseOnEscape(frame)
	frame:HookScript("OnShow", function(self)
		local ok = not InCombatLockdown()
		if ok then self:SetPropagateKeyboardInput(true) end
		self:EnableKeyboard(ok)
	end)
	frame:SetScript("OnKeyDown", function(self, key)
		local esc = key == "ESCAPE"
		-- frame.eluiKey(frame, key) -> true takes a key for the window (Ctrl+F); every other key reaches the game
		local taken = not esc and self.eluiKey and self.eluiKey(self, key) and true or false
		if not InCombatLockdown() then self:SetPropagateKeyboardInput(not esc and not taken) end
		if not esc then return end
		-- an open dropdown list closes first, then frame.eluiEscape gets a go (a search clears); then the window closes
		if UI.IsPopupShown and UI.IsPopupShown() then UI.ClosePopup() return end
		if self.eluiEscape and self.eluiEscape(self) then return end
		self:Hide()
	end)
end

------------------------------------------------------------------------
-- Stack: the vertical layout of a page. Rows can change height later (lists, notes) and the
-- rows under them move with :Relayout().
------------------------------------------------------------------------
local Stack = {}
Stack.__index = Stack

function UI.Stack(parent, width, T)
	return setmetatable({ parent = parent, width = width, y = 0, widgets = {}, entries = {}, T = T or ThemeOf(parent), isStack = true }, Stack)
end

function Stack:Place(e)
	e.y = self.y
	if e.borrowed then -- listed in search results right now: keep its room, leave it where it is
		self.y = self.y + e.height + e.gap
		return
	end
	local f = e.frame
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", self.parent, "TOPLEFT", e.indent, -self.y)
	f:SetWidth(self.width - e.indent)
	f:SetHeight(e.height)
	self.y = self.y + e.height + e.gap
end

function Stack:Add(frame, height, gap, indent)
	frame:SetParent(self.parent)
	local e = { frame = frame, height = height, gap = gap or self.T.rowGap, indent = indent or 0 }
	self.entries[#self.entries + 1] = e
	frame.stackEntry = e
	self:Place(e)
	if frame.Refresh then self.widgets[#self.widgets + 1] = frame end
	self.parent:SetHeight(self.y + self.T.pad)
	if self.app and frame.searchInfo then self.app:IndexWidget(self, frame) end
	return frame
end

function Stack:Space(px)
	px = px or self.T.pad
	self.entries[#self.entries + 1] = { space = px }
	self.y = self.y + px
	self.parent:SetHeight(self.y + self.T.pad)
end

function Stack:Relayout()
	self.y = 0
	for _, e in ipairs(self.entries) do
		if e.space then self.y = self.y + e.space else self:Place(e) end
	end
	self.parent:SetHeight(self.y + self.T.pad)
end

-- Give a row a new height and move the rows below it.
function Stack:SetHeightOf(frame, h)
	local e = frame.stackEntry
	if not e or e.height == h then return end
	e.height = h
	self:Relayout()
end

function Stack:RefreshAll()
	for _, w in ipairs(self.widgets) do w:Refresh() end
	-- search results can list controls from other pages that depend on this one
	if self.app and self.app.searching then self.app:RefreshBorrowed(self) end
end

-- What the search knows about a widget (see App:IndexWidget), from the widget's opt.
local function SearchInfo(opt, extra)
	if opt.search == false then return nil end
	local info = { label = opt.label, desc = opt.desc, keywords = opt.keywords, key = opt.searchKey, chatLabel = opt.chatLabel }
	if extra then for k, v in pairs(extra) do info[k] = v end end
	return info
end

------------------------------------------------------------------------
-- Static text
------------------------------------------------------------------------
function UI.Header(stack, text, sub)
	local T = stack.T
	local f = CreateFrame("Frame")
	local title = Text(f, T.fontTitle, T.text)
	title:SetPoint("TOPLEFT")
	title:SetText(text)
	local line = U.Solid(f, "ARTWORK", rgba(T.border))
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT")
	line:SetPoint("BOTTOMRIGHT")
	local h = 26
	if sub then
		local s = Text(f, T.fontSmall + 1, T.muted)
		s:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
		s:SetWidth(stack.width)
		s:SetText(sub)
		h = 34 + math.max(10, s:GetStringHeight())
	end
	stack:Space(stack.y > 0 and 8 or 0)
	stack.searchHeader = text -- search results show "Page » Heading" for the rows under it
	return stack:Add(f, h, 12)
end

-- A paragraph. `text` may be a function (the note then updates on Refresh).
function UI.Note(stack, text, color)
	local T = stack.T
	local f = CreateFrame("Frame")
	local fs = Text(f, T.fontSmall + 1, color or T.muted)
	fs:SetPoint("TOPLEFT")
	fs:SetWidth(stack.width)
	f.text = fs
	local function fill()
		fs:SetText(type(text) == "function" and (text() or "") or text)
		return math.max(14, fs:GetStringHeight() + 2)
	end
	local h = fill()
	if type(text) == "function" then
		function f:Refresh() stack:SetHeightOf(f, fill()) end
	end
	return stack:Add(f, h)
end

-- "Label      value" line; value is a function, read again on Refresh.
function UI.Stat(stack, label, value, labelWidth)
	local T = stack.T
	local f = CreateFrame("Frame")
	local l = Text(f, T.font, T.muted)
	l:SetPoint("LEFT")
	l:SetWidth(labelWidth or 190)
	l:SetWordWrap(false)
	l:SetText(label)
	local v = Text(f, T.font, T.text)
	v:SetPoint("LEFT", labelWidth or 190, 0)
	v:SetPoint("RIGHT")
	v:SetWordWrap(false)
	f.value = v
	function f:Refresh() v:SetText(tostring(value() or "")) end
	stack:Add(f, 16, 6)
	f:Refresh()
	return f
end

------------------------------------------------------------------------
-- Buttons
------------------------------------------------------------------------
-- style: nil, "accent" or "danger".
function UI.Button(parent, label, onClick, width, style)
	local T = ThemeOf(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 120, 26)
	local accent, danger = style == "accent", style == "danger"
	b.bg = U.Solid(b, "BACKGROUND", rgba(accent and T.accent or T.surface))
	b.bg:SetAllPoints()
	if accent then b.bg:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 0.85) end
	b.border = U.Border(b, 1, rgba(danger and T.danger or T.border))
	b.label = Text(b, T.font, accent and T.onAccent or (danger and T.danger or T.text))
	b.label:SetPoint("CENTER")
	b.label:SetJustifyH("CENTER")
	b.label:SetWordWrap(false)
	b.label:SetText(label)
	b:SetScript("OnEnter", function(self)
		if accent then self.bg:SetVertexColor(rgba(T.accent)) else self.bg:SetVertexColor(rgba(T.surfaceHi)) end
	end)
	b:SetScript("OnLeave", function(self)
		if accent then self.bg:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 0.85) else self.bg:SetVertexColor(rgba(T.surface)) end
	end)
	b:SetScript("OnClick", function(self, ...) if onClick then onClick(self, ...) end end)
	function b:SetText(t) self.label:SetText(t) end
	function b:GetText() return self.label:GetText() end
	-- Greyed out and not clickable while `on` is false.
	function b:SetUsable(on)
		self:SetAlpha(on and 1 or 0.4)
		self:EnableMouse(on and true or false)
	end
	return b
end

-- For something that can't be undone: the first click asks, a second click within 4 seconds does it.
-- A narrow button (a list row's) asks "Click again", which fits where "Click again to confirm" would not.
function UI.ConfirmButton(parent, label, onConfirm, width, style)
	local b
	local armed, before = nil, nil -- armed: a token for the 4-second timer; before: the label to put back
	local ask = (width or 120) < 150 and "Click again" or "Click again to confirm"
	local function disarm()
		if armed then armed = nil; b:SetText(before or label) end
	end
	b = UI.Button(parent, label, function(self, ...)
		if not armed then
			before = self:GetText()
			local token = {}
			armed = token
			self:SetText(ask)
			C_Timer.After(4, function() if armed == token then disarm() end end)
			return
		end
		disarm()
		onConfirm(self, ...)
	end, width, style or "danger")
	b:HookScript("OnHide", disarm)
	return b
end

-- A row of buttons: { { label, onClick, width, style, confirm }, ... }. Returns the row (row.buttons[i]).
function UI.ButtonRow(stack, buttons)
	local f = CreateFrame("Frame")
	f:SetParent(stack.parent) -- so the buttons find the window theme
	f.buttons = {}
	local x = 0
	for i, d in ipairs(buttons) do
		local make = d.confirm and UI.ConfirmButton or UI.Button
		local b = make(f, d.label, d.onClick, d.width or 140, d.style)
		b:SetPoint("LEFT", x, 0)
		x = x + (d.width or 140) + 8
		f.buttons[i] = b
		if d.desc then Tooltip(b, d.label, d.desc) end
	end
	if buttons.refresh then
		function f:Refresh() buttons.refresh(f) end
	end
	if buttons.search ~= false then
		local labels, descs, keys = {}, {}, {}
		local function addKeys(k) for _, w in ipairs(type(k) == "table" and k or { k }) do keys[#keys + 1] = w end end
		for _, d in ipairs(buttons) do
			if type(d.label) == "string" then labels[#labels + 1] = d.label end
			if d.desc then descs[#descs + 1] = d.desc end
			addKeys(d.keywords)
		end
		addKeys(buttons.keywords)
		if #labels > 0 then
			f.searchInfo = { label = table.concat(labels, " / "), desc = #descs > 0 and table.concat(descs, " ") or nil, keywords = keys }
		end
	end
	stack:Add(f, 26, 12)
	if f.Refresh then f:Refresh() end
	return f
end

------------------------------------------------------------------------
-- Switch (the toggle's track and knob, also used in list rows)
------------------------------------------------------------------------
local function Switch(parent, T)
	local track = CreateFrame("Frame", nil, parent)
	track:SetSize(34, 18)
	track.bg = U.Solid(track, "BACKGROUND", rgba(T.surface))
	track.bg:SetAllPoints()
	track.border = U.Border(track, 1, rgba(T.border))
	local knob = U.Solid(track, "ARTWORK", rgba(T.muted))
	knob:SetSize(12, 12)
	function track:SetOn(on)
		knob:ClearAllPoints()
		if on then
			knob:SetPoint("RIGHT", track, "RIGHT", -3, 0)
			knob:SetVertexColor(rgba(T.onAccent))
			track.bg:SetVertexColor(rgba(T.accent))
			track.border:SetColor(rgba(T.accent))
		else
			knob:SetPoint("LEFT", track, "LEFT", 3, 0)
			knob:SetVertexColor(rgba(T.muted))
			track.bg:SetVertexColor(rgba(T.surface))
			track.border:SetColor(rgba(T.border))
		end
	end
	return track
end

------------------------------------------------------------------------
-- Toggle
------------------------------------------------------------------------
function UI.Toggle(stack, opt)
	local T = stack.T
	local f = CreateFrame("Button")
	local track = Switch(f, T)
	track:SetPoint("LEFT")
	local label = Text(f, T.font, T.text)
	label:SetPoint("LEFT", track, "RIGHT", 10, 0)
	label:SetPoint("RIGHT")
	label:SetText(opt.label)
	function f:Refresh()
		track:SetOn(opt.get() and true or false)
		local enabled = not opt.disabled or not opt.disabled()
		f:SetAlpha(enabled and 1 or 0.4)
		f:EnableMouse(enabled)
	end
	f:SetScript("OnClick", function()
		opt.set(not opt.get())
		stack:RefreshAll() -- settings that depend on this one grey out or come back at once
		if opt.after then opt.after() end
	end)
	Tooltip(f, opt.label, opt.desc)
	f.searchInfo = opt.label and SearchInfo(opt)
	stack:Add(f, 20)
	f:Refresh()
	return f
end

------------------------------------------------------------------------
-- Slider with an editable value. No mouse wheel: the wheel scrolls the page.
------------------------------------------------------------------------
function UI.Slider(stack, opt)
	local T = stack.T
	local f = CreateFrame("Frame")
	local label = Text(f, T.font, T.text)
	label:SetPoint("TOPLEFT")
	label:SetText(opt.label)

	local slider = CreateFrame("Slider", nil, f)
	slider:SetOrientation("HORIZONTAL")
	slider:SetHeight(16)
	slider:SetPoint("TOPLEFT", 0, -20)
	slider:SetPoint("RIGHT", f, "RIGHT", -70, 0)
	slider:SetMinMaxValues(opt.min, opt.max)
	slider:SetValueStep(opt.step or 1)
	slider:SetObeyStepOnDrag(true)
	local rail = U.Solid(slider, "BACKGROUND", rgba(T.surface))
	rail:SetHeight(4)
	rail:SetPoint("LEFT")
	rail:SetPoint("RIGHT")
	local fill = U.Solid(slider, "ARTWORK", rgba(T.accent))
	fill:SetHeight(4)
	fill:SetPoint("LEFT")
	local thumb = slider:CreateTexture(nil, "OVERLAY")
	thumb:SetTexture(U.WHITE)
	thumb:SetVertexColor(rgba(T.text))
	thumb:SetSize(10, 14)
	slider:SetThumbTexture(thumb)

	local box = CreateFrame("EditBox", nil, f)
	box:SetSize(56, 20)
	box:SetPoint("LEFT", slider, "RIGHT", 12, 0)
	box:SetAutoFocus(false)
	box:SetJustifyH("CENTER")
	U.SetFont(box, T.font)
	box:SetTextColor(rgba(T.text))
	U.Solid(box, "BACKGROUND", rgba(T.surface)):SetAllPoints()
	U.Border(box, 1, rgba(T.border))

	local fmt = opt.fmt or (opt.step and opt.step < 1 and "%.2f" or "%d")
	local updating = false
	local function updateFill(v)
		local w = slider:GetWidth()
		if w and w > 0 then fill:SetWidth(math.max(1, w * (v - opt.min) / (opt.max - opt.min))) end
	end
	function f:Refresh()
		updating = true
		local v = opt.get() or opt.min
		slider:SetValue(v)
		box:SetText(string.format(fmt, v))
		updateFill(v)
		updating = false
		local enabled = not opt.disabled or not opt.disabled()
		f:SetAlpha(enabled and 1 or 0.4)
		slider:EnableMouse(enabled)
		box:EnableMouse(enabled)
	end
	slider:SetScript("OnValueChanged", function(_, v)
		if updating then return end
		local step = opt.step or 1
		v = math.floor(v / step + 0.5) * step
		box:SetText(string.format(fmt, v))
		updateFill(v)
		opt.set(v)
		if opt.after then opt.after() end
	end)
	slider:SetScript("OnSizeChanged", function() updateFill(slider:GetValue()) end)
	box:SetScript("OnEnterPressed", function(self)
		local v = tonumber(self:GetText())
		if v then
			-- snap to the step like dragging does, and set it once (the slider moving must not set it again)
			local step = opt.step or 1
			v = math.min(opt.max, math.max(opt.min, math.floor(v / step + 0.5) * step))
			updating = true
			slider:SetValue(v)
			updating = false
			opt.set(v)
			if opt.after then opt.after() end
		end
		self:ClearFocus()
		f:Refresh()
	end)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Refresh() end)
	Tooltip(f, opt.label, opt.desc)
	f.searchInfo = opt.label and SearchInfo(opt)
	stack:Add(f, 40)
	f:Refresh()
	return f
end

------------------------------------------------------------------------
-- Dropdown (one shared popup list)
------------------------------------------------------------------------
local popup, catcher

local function ClosePopup()
	if popup then popup:Hide() end
	if catcher then catcher:Hide() end
end
UI.ClosePopup = ClosePopup
function UI.IsPopupShown() return popup ~= nil and popup:IsShown() end

-- items = { { value, text, icon?, title? }, ... }. A title row can't be clicked.
-- opts.width overrides the owner's width; opts.atCursor opens it at the mouse.
local function OpenPopup(owner, items, current, onPick, opts)
	opts = opts or {}
	local T = ThemeOf(owner)
	if not popup then
		catcher = CreateFrame("Button", nil, UIParent)
		catcher:SetAllPoints(UIParent)
		catcher:SetFrameStrata("FULLSCREEN_DIALOG")
		catcher:SetScript("OnClick", ClosePopup)
		popup = CreateFrame("Frame", nil, UIParent)
		popup:SetFrameStrata("FULLSCREEN_DIALOG")
		popup:SetFrameLevel(catcher:GetFrameLevel() + 10)
		popup:SetClampedToScreen(true)
		popup.bg = U.Solid(popup, "BACKGROUND", rgba(T.surface))
		popup.bg:SetAllPoints()
		U.Border(popup, 1, rgba(T.border))
		popup.buttons = {}
	end
	for _, b in ipairs(popup.buttons) do b:Hide() end
	local width = opts.width or (owner and owner:GetWidth()) or 200
	for i, item in ipairs(items) do
		local b = popup.buttons[i]
		if not b then
			b = CreateFrame("Button", nil, popup)
			b:SetHeight(22)
			b.hl = U.Solid(b, "BACKGROUND", rgba(T.accentDim))
			b.hl:SetAllPoints()
			b.hl:Hide()
			b.icon = b:CreateTexture(nil, "ARTWORK")
			b.icon:SetSize(16, 16)
			b.icon:SetPoint("LEFT", 8, 0)
			b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			b.text = Text(b, T.font, T.text)
			b.text:SetWordWrap(false)
			b:SetScript("OnEnter", function(self) if not self.isTitle then self.hl:Show() end end)
			b:SetScript("OnLeave", function(self) if not self.selected then self.hl:Hide() end end)
			popup.buttons[i] = b
		end
		b.hl:SetVertexColor(rgba(T.accentDim))
		b:SetPoint("TOPLEFT", 1, -1 - (i - 1) * 22)
		b:SetPoint("RIGHT", -1, 0)
		b.icon:SetShown(item.icon ~= nil)
		if item.icon then b.icon:SetTexture(item.icon) end
		b.text:ClearAllPoints()
		b.text:SetPoint("LEFT", item.icon and 30 or 10, 0)
		b.text:SetPoint("RIGHT", -10, 0)
		b.text:SetText(item.text)
		b.isTitle = item.title and true or false
		b.selected = not b.isTitle and current ~= nil and item.value == current
		b.hl:SetShown(b.selected)
		b.text:SetTextColor(rgba((b.isTitle and T.muted) or (b.selected and T.accent) or T.text))
		b:SetScript("OnClick", function()
			if b.isTitle then return end
			ClosePopup()
			onPick(item.value)
		end)
		b:Show()
	end
	popup:SetSize(width, #items * 22 + 2)
	popup:ClearAllPoints()
	if opts.atCursor or not owner then
		local x, y = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		popup:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 4, y / scale - 4)
	else
		popup:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
	end
	catcher:Show()
	popup:Show()
end
UI.OpenPopup = OpenPopup

function UI.Dropdown(stack, opt)
	local T = stack.T
	local f = CreateFrame("Frame")
	local label = Text(f, T.font, T.text)
	label:SetPoint("TOPLEFT")
	label:SetText(opt.label)
	local b = CreateFrame("Button", nil, f)
	b:SetHeight(24)
	b:SetPoint("TOPLEFT", 0, -18)
	b:SetWidth(opt.width or 240)
	b.eluiTheme = T
	local bg = U.Solid(b, "BACKGROUND", rgba(T.surface))
	bg:SetAllPoints()
	U.Border(b, 1, rgba(T.border))
	local value = Text(b, T.font, T.text)
	value:SetPoint("LEFT", 10, 0)
	value:SetPoint("RIGHT", -24, 0)
	value:SetWordWrap(false)
	local arrow = Text(b, T.font, T.muted)
	arrow:SetPoint("RIGHT", -8, 0)
	arrow:SetText("v")
	b:SetScript("OnEnter", function() bg:SetVertexColor(rgba(T.surfaceHi)) end)
	b:SetScript("OnLeave", function() bg:SetVertexColor(rgba(T.surface)) end)
	local function items() if type(opt.items) == "function" then return opt.items() or {} end return opt.items or {} end
	function f:Refresh()
		local cur = opt.get()
		local shown = cur == nil and (opt.placeholder or "Choose...") or (opt.format and opt.format(cur)) or tostring(cur)
		for _, it in ipairs(items()) do
			if it.value == cur then shown = it.text break end
		end
		value:SetText(shown)
		local enabled = not opt.disabled or not opt.disabled()
		f:SetAlpha(enabled and 1 or 0.4)
		b:EnableMouse(enabled)
	end
	b:SetScript("OnClick", function()
		OpenPopup(b, items(), opt.get(), function(v)
			opt.set(v)
			stack:RefreshAll()
			if opt.after then opt.after() end
		end)
	end)
	Tooltip(b, opt.label, opt.desc)
	f.searchInfo = opt.label and SearchInfo(opt, {
		value = function() return value:GetText() end,
		choices = function()
			local t = {}
			for _, it in ipairs(items()) do if not it.title and it.text then t[#t + 1] = tostring(it.text) end end
			return table.concat(t, " ")
		end,
	})
	stack:Add(f, 44)
	f:Refresh()
	return f
end

------------------------------------------------------------------------
-- Colour swatch
------------------------------------------------------------------------
function UI.Color(stack, opt)
	local T = stack.T
	local f = CreateFrame("Button")
	local sw = CreateFrame("Frame", nil, f)
	sw:SetSize(30, 18)
	sw:SetPoint("LEFT")
	local fill = U.Solid(sw, "ARTWORK", 1, 1, 1, 1)
	fill:SetAllPoints()
	U.Border(sw, 1, rgba(T.border))
	local label = Text(f, T.font, T.text)
	label:SetPoint("LEFT", sw, "RIGHT", 10, 0)
	label:SetText(opt.label)
	function f:Refresh()
		local c = opt.get() or { 1, 1, 1, 1 }
		fill:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
		local enabled = not opt.disabled or not opt.disabled()
		f:SetAlpha(enabled and 1 or 0.4)
		f:EnableMouse(enabled)
	end
	f:SetScript("OnClick", function()
		local c = opt.get() or { 1, 1, 1, 1 }
		local start = { c[1], c[2], c[3], c[4] or 1 }
		local function apply(r, g, b, a)
			opt.set({ r, g, b, opt.hasAlpha and a or (c[4] or 1) })
			f:Refresh()
			if opt.after then opt.after() end
		end
		local function picked()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			local a = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or start[4]
			apply(r, g, b, a)
		end
		local info = {
			r = start[1], g = start[2], b = start[3], opacity = start[4],
			hasOpacity = opt.hasAlpha and true or false,
			swatchFunc = picked, opacityFunc = picked,
			cancelFunc = function() apply(start[1], start[2], start[3], start[4]) end,
		}
		if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
			ColorPickerFrame:SetupColorPickerAndShow(info)
		end
	end)
	Tooltip(f, opt.label, opt.desc)
	f.searchInfo = opt.label and SearchInfo(opt)
	stack:Add(f, 20)
	f:Refresh()
	return f
end

------------------------------------------------------------------------
-- Text input
------------------------------------------------------------------------
function UI.EditBox(parent, width, height)
	local T = ThemeOf(parent)
	local box = CreateFrame("EditBox", nil, parent)
	box:SetSize(width or 200, height or 24)
	box:SetAutoFocus(false)
	box:SetTextInsets(8, 8, 0, 0)
	U.SetFont(box, T.font)
	box:SetTextColor(rgba(T.text))
	U.Solid(box, "BACKGROUND", rgba(T.surface)):SetAllPoints()
	box.border = U.Border(box, 1, rgba(T.border))
	box:SetScript("OnEditFocusGained", function(self) self.border:SetColor(rgba(T.accent)) end)
	box:SetScript("OnEditFocusLost", function(self) self.border:SetColor(rgba(T.border)) end)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	return box
end

-- A labelled text box. opt: label, placeholder, width, get/set (bound: saved on Enter or leaving the box),
-- onChange(text) while typing, onEnter(text), button = { label, onClick(text, box), width, style }, maxLetters.
function UI.Input(stack, opt)
	local T = stack.T
	local f = CreateFrame("Frame")
	f:SetParent(stack.parent)
	local top = 0
	if opt.label then
		local label = Text(f, T.font, T.text)
		label:SetPoint("TOPLEFT")
		label:SetText(opt.label)
		top = -18
	end
	local box = UI.EditBox(f, opt.width or 240, 24)
	box:SetPoint("TOPLEFT", 0, top)
	if opt.maxLetters then box:SetMaxLetters(opt.maxLetters) end
	f.box = box
	local hint = Text(box, T.font, T.muted)
	hint:SetPoint("LEFT", 8, 0)
	hint:SetText(opt.placeholder or "")
	local function updateHint() hint:SetShown(not box:HasFocus() and (box:GetText() or "") == "") end
	box:HookScript("OnEditFocusGained", updateHint)
	box:HookScript("OnEditFocusLost", function(self)
		updateHint()
		if opt.set and (not opt.get or self:GetText() ~= (opt.get() or "")) then
			opt.set(self:GetText())
			if opt.after then opt.after() end
		end
	end)
	box:SetScript("OnTextChanged", function(self, user)
		updateHint()
		if user and opt.onChange then opt.onChange(self:GetText()) end
	end)
	box:SetScript("OnEnterPressed", function(self)
		if opt.onEnter then opt.onEnter(self:GetText(), self) end
		self:ClearFocus()
	end)
	if opt.get then
		-- Escape throws away what was typed (leaving the box would otherwise save it)
		box:SetScript("OnEscapePressed", function(self) self:SetText(opt.get() or ""); self:ClearFocus() end)
	end
	if opt.button then
		local b = UI.Button(f, opt.button.label, function() opt.button.onClick(box:GetText(), box) end, opt.button.width or 110, opt.button.style)
		b:SetPoint("LEFT", box, "RIGHT", 8, 0)
		f.button = b
	end
	if opt.get then
		function f:Refresh()
			if not box:HasFocus() then box:SetText(opt.get() or "") end
			updateHint()
		end
	end
	Tooltip(box, opt.label, opt.desc)
	-- a plain text box is usually data entry (a name, a filter), not a setting: only settings and opt-ins are found
	if opt.label and (opt.searchKey or opt.keywords) then f.searchInfo = SearchInfo(opt) end
	stack:Add(f, opt.label and 44 or 26)
	if f.Refresh then f:Refresh() else updateHint() end
	return f
end

-- Read-only text to copy (a link, a file path): clicking selects it all; typing can't change it.
function UI.CopyBox(stack, label, text)
	local T = stack.T
	local f = CreateFrame("Frame")
	f:SetParent(stack.parent)
	local l = Text(f, T.font, T.text)
	l:SetPoint("TOPLEFT")
	l:SetText(label)
	local box = UI.EditBox(f, stack.width, 24)
	box:SetPoint("TOPLEFT", 0, -18)
	box:SetPoint("RIGHT")
	local function value() if type(text) == "function" then return text() or "" end return text or "" end
	box:SetScript("OnTextChanged", function(self)
		if self:GetText() ~= value() then self:SetText(value()); self:HighlightText() end
	end)
	box:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	f.box = box
	function f:Refresh() box:SetText(value()) end
	Tooltip(box, label, "Click, then Ctrl+C to copy.")
	stack:Add(f, 44)
	f:Refresh()
	return f
end

------------------------------------------------------------------------
-- List: rows of data with an optional switch on the left and buttons on the right.
-- opt.items() -> array; opt.title(item); opt.detail(item); opt.icon(item); opt.color(item) (title colour)
-- opt.toggle = { get(item), set(item, on) }; opt.buttons = { { label = text or fn(item), width, style,
-- onClick(item, button), shown(item), usable(item), confirm } }; opt.tooltip(item) (lines or a hook
-- function(row, item)); opt.onClick(item); opt.empty (text when there are no rows); opt.max (rows shown);
-- opt.rowHeight (default 30; 40 or more shows the detail on a second line).
------------------------------------------------------------------------
function UI.List(stack, opt)
	local T = stack.T
	local f = CreateFrame("Frame")
	f:SetParent(stack.parent)
	f.rows = {}
	local rowH = opt.rowHeight or 30
	local twoLine = rowH >= 40
	local empty = Text(f, T.font, T.muted)
	empty:SetPoint("TOPLEFT", 4, -4)
	empty:SetText(opt.empty or "Nothing here yet.")

	local function newRow(i)
		local r = CreateFrame("Button", nil, f)
		r:SetHeight(rowH)
		r:SetPoint("TOPLEFT", 0, -(i - 1) * (rowH + 2))
		r:SetPoint("RIGHT")
		r.bg = U.Solid(r, "BACKGROUND", rgba(T.surface))
		r.bg:SetAllPoints()
		local x = 8
		if opt.toggle then
			r.switch = Switch(r, T)
			r.switch:SetPoint("LEFT", x, 0)
			r.switch:EnableMouse(true)
			r.switch:SetScript("OnMouseDown", function()
				if r.item == nil then return end
				opt.toggle.set(r.item, not opt.toggle.get(r.item))
				stack:RefreshAll()
			end)
			x = x + 44
		end
		if opt.icon then
			r.icon = r:CreateTexture(nil, "ARTWORK")
			r.icon:SetSize(18, 18)
			r.icon:SetPoint("LEFT", x, 0)
			r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			x = x + 26
		end
		r.buttons = {}
		local right = -6
		for bi = #(opt.buttons or {}), 1, -1 do
			local d = opt.buttons[bi]
			local make = d.confirm and UI.ConfirmButton or UI.Button
			local b = make(r, type(d.label) == "string" and d.label or "", function(btn) if r.item ~= nil then d.onClick(r.item, btn) end end, d.width or 90, d.style)
			b:SetHeight(math.min(22, rowH - 6))
			b:SetPoint("RIGHT", right, 0)
			right = right - (d.width or 90) - 6
			r.buttons[bi] = b
		end
		r.title = Text(r, T.font, T.text)
		r.title:SetWordWrap(false)
		r.detail = Text(r, twoLine and T.fontSmall + 1 or T.font, T.muted)
		r.detail:SetWordWrap(false)
		if twoLine then
			r.title:SetPoint("TOPLEFT", x, -6)
			r.title:SetPoint("RIGHT", right - 4, 0)
			r.detail:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -4)
			r.detail:SetPoint("RIGHT", right - 4, 0)
		else
			r.title:SetPoint("LEFT", x, 0)
			r.detail:SetPoint("LEFT", r.title, "RIGHT", 10, 0)
			r.detail:SetPoint("RIGHT", right - 4, 0)
		end
		r.titleMax = (opt.titleWidth or 220)
		r:SetScript("OnEnter", function(self)
			self.bg:SetVertexColor(rgba(T.surfaceHi))
			if self.item == nil or not opt.tooltip then return end
			local tip = opt.tooltip(self.item, self)
			if type(tip) == "table" then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				for li, line in ipairs(tip) do
					if li == 1 then GameTooltip:AddLine(line, 1, 1, 1) else GameTooltip:AddLine(line, nil, nil, nil, true) end
				end
				GameTooltip:Show()
			end
		end)
		r:SetScript("OnLeave", function(self)
			self.bg:SetVertexColor(rgba(T.surface))
			GameTooltip:Hide()
		end)
		r:SetScript("OnClick", function(self) if self.item ~= nil and opt.onClick then opt.onClick(self.item) end end)
		f.rows[i] = r
		return r
	end

	function f:Refresh()
		local items = opt.items() or {}
		local n = math.min(#items, opt.max or 500)
		for i = 1, n do
			local item = items[i]
			local r = f.rows[i] or newRow(i)
			r.item = item
			r.title:SetText(opt.title(item) or "")
			if not twoLine then
				local w = (r.title.GetUnboundedStringWidth and r.title:GetUnboundedStringWidth()) or r.title:GetStringWidth() or r.titleMax
				r.title:SetWidth(math.min(r.titleMax, (w or 0) + 2))
			end
			if opt.color then
				local c = opt.color(item)
				r.title:SetTextColor(rgba(c or T.text))
			end
			r.detail:SetText(opt.detail and opt.detail(item) or "")
			if r.icon then
				local icon = opt.icon(item)
				r.icon:SetShown(icon ~= nil)
				if icon then r.icon:SetTexture(icon) end
			end
			if r.switch then r.switch:SetOn(opt.toggle.get(item) and true or false) end
			for bi, d in ipairs(opt.buttons or {}) do
				local b = r.buttons[bi]
				if type(d.label) == "function" then b:SetText(d.label(item)) end
				b:SetShown(not d.shown or d.shown(item) and true or false)
				b:SetUsable(not d.usable or d.usable(item) and true or false)
			end
			r:Show()
		end
		for i = n + 1, #f.rows do f.rows[i].item = nil; f.rows[i]:Hide() end
		empty:SetShown(n == 0)
		local h = n == 0 and 24 or n * (rowH + 2)
		if #items > n then
			f.more = f.more or Text(f, T.fontSmall + 1, T.muted)
			f.more:ClearAllPoints()
			f.more:SetPoint("TOPLEFT", 4, -h - 4)
			f.more:SetText(("%d more not shown."):format(#items - n))
			f.more:Show()
			h = h + 20
		elseif f.more then
			f.more:Hide()
		end
		stack:SetHeightOf(f, h)
	end
	stack:Add(f, 24)
	f:Refresh()
	return f
end

------------------------------------------------------------------------
-- Scroll bar (page body and text areas)
------------------------------------------------------------------------
local BAR_W = 12
local PAGE_STEP = 40

-- The page scroll around `frame`, if it sits in one.
local function OuterScroll(frame)
	local p = frame:GetParent()
	while p do
		if rawget(p, "ScrollBy") then return p end -- set by AttachScrollBar below
		p = p:GetParent()
	end
end

-- A scroll bar for `scroll` (a ScrollFrame showing `child`), parented to `holder`; the caller anchors it.
-- Drag the thumb with the left mouse button, or click the track above or below it to jump a page.
-- Offsets are whole pixels, so text never lands between pixels and blurs. The wheel scrolls by `step`.
-- With `onlyWhile` given, the wheel scrolls this area only while onlyWhile() is true (a text area you
-- are typing in) and otherwise scrolls the page around it, as it also does once this area is at its end.
local function AttachScrollBar(scroll, child, holder, step, onlyWhile)
	local T = ThemeOf(holder)
	local track = CreateFrame("Frame", nil, holder)
	track:SetWidth(BAR_W)
	U.Solid(track, "BACKGROUND", T.muted[1], T.muted[2], T.muted[3], 0.12):SetAllPoints()
	local thumb = CreateFrame("Frame", nil, track)
	thumb:SetWidth(BAR_W)
	local thumbTex = U.Solid(thumb, "ARTWORK", T.muted[1], T.muted[2], T.muted[3], 0.55)
	thumbTex:SetAllPoints()
	track:Hide()

	local function maxScroll()
		return math.max(0, math.floor(child:GetHeight() - scroll:GetHeight() + 0.5))
	end
	local function update()
		local viewH, contentH, m = scroll:GetHeight(), child:GetHeight(), maxScroll()
		if scroll:GetVerticalScroll() > m then scroll:SetVerticalScroll(m) end
		if m <= 0 or not scroll:IsShown() then track:Hide() return end
		local trackH = track:GetHeight()
		local h = math.min(trackH, math.max(30, trackH * viewH / contentH))
		thumb:SetHeight(h)
		thumb:ClearAllPoints()
		thumb:SetPoint("TOP", track, "TOP", 0, -(trackH - h) * scroll:GetVerticalScroll() / m)
		track:Show()
	end
	local function setScroll(v)
		ClosePopup() -- an open dropdown list would be left behind
		scroll:SetVerticalScroll(math.min(maxScroll(), math.max(0, math.floor(v + 0.5))))
		update()
	end
	-- Scrolls by `delta` pixels; false when it was already at that end.
	function scroll:ScrollBy(delta)
		local before = self:GetVerticalScroll()
		setScroll(before + delta)
		return self:GetVerticalScroll() ~= before
	end

	local function hover(on) thumbTex:SetVertexColor(T.muted[1], T.muted[2], T.muted[3], on and 0.85 or 0.55) end
	local function stopDrag(self)
		self.dragging = nil
		hover(self:IsMouseOver())
	end
	thumb:EnableMouse(true)
	thumb:SetScript("OnEnter", function() hover(true) end)
	thumb:SetScript("OnLeave", function(self) if not self.dragging then hover(false) end end)
	thumb:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		local _, y = GetCursorPosition()
		self.dragging = { y = y / self:GetEffectiveScale(), start = scroll:GetVerticalScroll() }
		hover(true)
	end)
	thumb:SetScript("OnMouseUp", stopDrag)
	thumb:SetScript("OnHide", stopDrag)
	thumb:SetScript("OnUpdate", function(self)
		local d = self.dragging
		if not d then return end
		if not IsMouseButtonDown("LeftButton") then stopDrag(self) return end
		local _, y = GetCursorPosition()
		y = y / self:GetEffectiveScale()
		local room = track:GetHeight() - self:GetHeight()
		if room > 0 then setScroll(d.start + (d.y - y) * maxScroll() / room) end
	end)
	track:EnableMouse(true)
	track:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		local _, y = GetCursorPosition()
		y = y / self:GetEffectiveScale()
		local page = math.max(step, scroll:GetHeight() - 40)
		setScroll(scroll:GetVerticalScroll() + (y < thumb:GetBottom() and page or -page))
	end)

	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local outer = OuterScroll(self)
		if outer and onlyWhile and not onlyWhile() then outer:ScrollBy(-delta * PAGE_STEP) return end
		if not self:ScrollBy(-delta * step) and outer then outer:ScrollBy(-delta * PAGE_STEP) end
	end)
	return track, update, setScroll
end

-- Multi-line text area. Inside a page the wheel scrolls the page; it scrolls the text only while you type in it.
function UI.TextArea(parent, width, height)
	local T = ThemeOf(parent)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(width, height)
	U.Solid(holder, "BACKGROUND", rgba(T.surface)):SetAllPoints()
	U.Border(holder, 1, rgba(T.border))
	local scroll = CreateFrame("ScrollFrame", nil, holder)
	scroll:SetPoint("TOPLEFT", 8, -6)
	scroll:SetPoint("BOTTOMRIGHT", -(BAR_W + 8), 6)
	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetWidth(width - BAR_W - 16)
	U.SetFont(box, T.fontSmall + 1)
	box:SetTextColor(rgba(T.text))
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	scroll:SetScrollChild(box)
	local track, update, setScroll = AttachScrollBar(scroll, box, holder, 30, function() return box:HasFocus() end)
	track:SetPoint("TOPRIGHT", -3, -3)
	track:SetPoint("BOTTOMRIGHT", -3, 3)
	local want
	box:SetScript("OnCursorChanged", function(_, _, y, _, h)
		y = -y
		local top = scroll:GetVerticalScroll()
		if y < top then want = y
		elseif y + h > top + scroll:GetHeight() then want = y + h - scroll:GetHeight()
		else want = nil return end
		setScroll(want)
		if math.abs(scroll:GetVerticalScroll() - want) < 1 then want = nil end
	end)
	box:HookScript("OnSizeChanged", function()
		update()
		if want then setScroll(want); want = nil end
	end)
	scroll:SetScript("OnSizeChanged", update)
	holder:EnableMouse(true)
	holder:SetScript("OnMouseDown", function() box:SetFocus() end)
	holder.box = box
	holder.track = track
	return holder
end

-- Scrollable page body. The bar takes the right edge of `parent`: build the page about 24 px narrower.
function UI.ScrollPage(parent)
	local scroll = CreateFrame("ScrollFrame", nil, parent)
	scroll:SetPoint("TOPLEFT")
	scroll:SetPoint("BOTTOMRIGHT", -(BAR_W + 6), 0)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)
	local track, update, setScroll = AttachScrollBar(scroll, child, parent, PAGE_STEP)
	track:SetPoint("TOPRIGHT", -3, -2)
	track:SetPoint("BOTTOMRIGHT", -3, 2)
	scroll:SetScript("OnSizeChanged", function(_, w)
		child:SetWidth(w)
		update()
	end)
	-- the bar sits beside the scroll area, so it follows the page's visibility by hand
	scroll:SetScript("OnShow", update)
	scroll:SetScript("OnHide", function() track:Hide() end)
	child:SetScript("OnSizeChanged", update)
	scroll.child = child
	scroll.track = track
	scroll.UpdateBar = update
	scroll.SetScroll = setScroll
	return scroll
end

------------------------------------------------------------------------
-- Link window: a link to copy (addons can't open a browser). Our own frame, not a StaticPopup:
-- touching Blizzard's popups from an addon taints Blizzard's own dialogs.
------------------------------------------------------------------------
function UI.LinkWindow(name, T, intro, url)
	T = T or UI.Theme
	local f = CreateFrame("Frame", name, UIParent)
	f.eluiTheme = T
	f:SetSize(380, 132)
	f:SetPoint("TOP", 0, -160)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:Hide()
	U.Solid(f, "BACKGROUND", rgba(T.bg)):SetAllPoints()
	U.Border(f, 1, rgba(T.border))
	local text = Text(f, T.font, T.text)
	text:SetPoint("TOPLEFT", 16, -14)
	text:SetPoint("TOPRIGHT", -16, -14)
	text:SetJustifyH("CENTER")
	text:SetText(intro or "Press Ctrl+C to copy the link, then paste it in your browser.")
	local box = UI.EditBox(f, 348, 24)
	box:SetPoint("TOP", 0, -54)
	box:SetScript("OnTextChanged", function(self)
		if self:GetText() ~= f.url then self:SetText(f.url); self:HighlightText() end
	end)
	box:SetScript("OnEnterPressed", function() f:Hide() end)
	box:SetScript("OnEscapePressed", function() f:Hide() end)
	f.box = box
	UI.Button(f, CLOSE or "Close", function() f:Hide() end, 100):SetPoint("BOTTOM", 0, 14)
	f.url = url
	function f:SetLink(newIntro, newUrl)
		if newIntro then text:SetText(newIntro) end
		if newUrl then self.url = newUrl end
	end
	f:SetScript("OnShow", function()
		box:SetText(f.url or "")
		box:SetFocus()
		box:HighlightText()
	end)
	f:SetScript("OnHide", function() box:ClearFocus() end)
	UI.CloseOnEscape(f)
	return f
end

------------------------------------------------------------------------
-- Settings search: the matcher. Plain functions (no frames), tested offline.
--   Search.Entry(info) -> an entry; info: label, chatLabel, desc, keywords (table or "a b c"), key (the chat
--     command name), section, header, choices (text or fn), value (fn: the shown value, read at search time)
--   Search.Match(entries, query, keep) -> { { entry, score }, ... } best first; keep(entry) filters
--   Search.Suggest(entries, query, keep) -> a nearby query that finds something, or nil
-- Matching ignores case and accents and works on word starts ("trans" finds "Transparent"); every word typed
-- must match somewhere, in any order. A label match beats a description match; the whole label beats both.
------------------------------------------------------------------------
local Search = {}
UI.Search = Search

-- Accented letters to plain ones, and Cyrillic capitals to small (string.lower only knows A-Z).
local FOLD = {}
do
	local groups = {
		a = "ÀÁÂÃÄÅàáâãäåĀāĂăĄą", ae = "Ææ", c = "ÇçĆćĈĉĊċČč", d = "ÐðĎďĐđ", e = "ÈÉÊËèéêëĒēĔĕĖėĘęĚě",
		g = "ĜĝĞğĠġĢģ", h = "ĤĥĦħ", i = "ÌÍÎÏìíîïĨĩĪīĬĭĮįİı", j = "Ĵĵ", k = "Ķķ", l = "ĹĺĻļĽľĿŀŁł",
		n = "ÑñŃńŅņŇň", o = "ÒÓÔÕÖØòóôõöøŌōŎŏŐő", oe = "Œœ", r = "ŔŕŖŗŘř", s = "ŚśŜŝŞşŠš", ss = "ß",
		t = "ŢţŤťŦŧ", th = "Þþ", u = "ÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲų", w = "Ŵŵ", y = "ÝýÿŶŷŸ", z = "ŹźŻżŽž",
	}
	for to, chars in pairs(groups) do
		for ch in chars:gmatch("[\192-\255][\128-\191]*") do FOLD[ch] = to end
	end
	for b = 0x90, 0x9F do FOLD["\208" .. string.char(b)] = "\208" .. string.char(b + 0x20) end -- А-П
	for b = 0xA0, 0xAF do FOLD["\208" .. string.char(b)] = "\209" .. string.char(b - 0x20) end -- Р-Я
	FOLD["\208\129"], FOLD["\209\145"] = "\208\181", "\208\181" -- Ё ё read as е
end

-- Lower case, no accents, no colour codes or textures, no apostrophes.
function Search.Normalize(s)
	s = tostring(s or "")
	s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", " "):gsub("|A.-|a", " "):gsub("|n", " "):gsub("||", "|")
	-- accents first, then A-Z only: string.lower follows the C locale and can mangle UTF-8 bytes
	s = s:gsub("[\192-\255][\128-\191]*", FOLD)
	s = s:gsub("[A-Z]+", string.lower)
	s = s:gsub("'", ""):gsub("\226\128\153", "")
	return s
end

local WORD = "[%w\128-\255]+"

-- The words of a query, normalized.
function Search.Terms(query)
	local t = {}
	for w in Search.Normalize(query):gmatch(WORD) do t[#t + 1] = w end
	return t
end

-- How much a match in each part counts.
Search.WEIGHT = { label = 10, key = 8, keywords = 7, section = 5, header = 5, value = 4, choices = 3, desc = 3 }
local WEIGHT = Search.WEIGHT

local function makeField(text, weight, whole)
	if type(text) == "table" then text = table.concat(text, " ") end
	if text == nil or text == "" then return nil end
	local norm = Search.Normalize(text)
	local words = {}
	for w in norm:gmatch(WORD) do words[#words + 1] = w end
	if whole then words[#words + 1] = norm end -- a chat name like "outgoing.fontsize" also matches whole
	if #words == 0 then return nil end
	return { text = norm, words = words, weight = weight }
end

function Search.Entry(info)
	local e = { fields = {}, info = info }
	local function add(text, weight, whole)
		local f = makeField(text, weight, whole)
		if f then e.fields[#e.fields + 1] = f end
		return f
	end
	local label = add(info.label, WEIGHT.label)
	if info.chatLabel and info.chatLabel ~= info.label then add(info.chatLabel, WEIGHT.label - 1) end
	add(info.key, WEIGHT.key, true)
	add(info.keywords, WEIGHT.keywords)
	add(info.section, WEIGHT.section)
	add(info.header, WEIGHT.header)
	add(type(info.choices) == "function" and info.choices() or info.choices, WEIGHT.choices)
	add(info.desc, WEIGHT.desc)
	e.labelText = label and table.concat(label.words, " ") or ""
	e.value = type(info.value) == "function" and info.value or nil
	return e
end

-- 3 a whole word, 2 the start of a word, 1 inside a word (4 or more letters typed), 0 not there.
local function termIn(field, term)
	local best = 0
	for _, w in ipairs(field.words) do
		if w == term then return 3 end
		if best == 0 and w:sub(1, #term) == term then best = 2 end
	end
	if best == 0 and #term >= 4 and field.text:find(term, 1, true) then best = 1 end
	return best
end

local function scoreTerms(e, terms)
	local valueField
	if e.value then
		local ok, v = pcall(e.value)
		valueField = ok and makeField(v, WEIGHT.value) or nil
	end
	local total = 0
	for _, term in ipairs(terms) do
		local best = 0
		for _, f in ipairs(e.fields) do
			local q = termIn(f, term)
			if q > 0 and q * f.weight > best then best = q * f.weight end
		end
		if valueField then
			local q = termIn(valueField, term)
			if q > 0 and q * valueField.weight > best then best = q * valueField.weight end
		end
		if best == 0 then return nil end
		total = total + best
	end
	return total
end

function Search.Match(entries, query, keep)
	local terms = Search.Terms(query)
	local out = {}
	if #terms == 0 then return out end
	local whole = table.concat(terms, " ")
	for i, e in ipairs(entries) do
		if not keep or keep(e) then
			local score = scoreTerms(e, terms)
			if score then
				if e.labelText == whole then score = score + 100
				elseif e.labelText:sub(1, #whole) == whole then score = score + 30 end
				out[#out + 1] = { entry = e, score = score, order = i }
			end
		end
	end
	table.sort(out, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		return a.order < b.order
	end)
	return out
end

-- Edit distance with swapped neighbours counting once (optimal string alignment).
local function distance(a, b)
	local la, lb = #a, #b
	if la == 0 then return lb end
	if lb == 0 then return la end
	local prev2, prev, cur = {}, {}, {}
	for j = 0, lb do prev[j] = j end
	for i = 1, la do
		cur = { [0] = i }
		local ca = a:byte(i)
		for j = 1, lb do
			local cb = b:byte(j)
			local cost = ca == cb and 0 or 1
			local v = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
			if i > 1 and j > 1 and ca == b:byte(j - 1) and a:byte(i - 1) == cb then v = math.min(v, prev2[j - 2] + 1) end
			cur[j] = v
		end
		prev2, prev = prev, cur
	end
	return prev[lb]
end
Search.Distance = distance

-- A query one or two typos away that finds something ("trasnparent" -> "transparent"), or nil.
function Search.Suggest(entries, query, keep)
	local terms = Search.Terms(query)
	if #terms == 0 then return nil end
	local vocab, seen = {}, {}
	for _, e in ipairs(entries) do
		if not keep or keep(e) then
			for _, f in ipairs(e.fields) do
				for _, w in ipairs(f.words) do
					if #w >= 3 and not seen[w] and w:find("^[%w\128-\255]+$") then seen[w] = true; vocab[#vocab + 1] = w end
				end
			end
		end
	end
	table.sort(vocab)
	local changed = false
	for i, term in ipairs(terms) do
		local found = false
		for _, w in ipairs(vocab) do
			if w:sub(1, #term) == term or (#term >= 4 and w:find(term, 1, true)) then found = true break end
		end
		if not found then
			local limit = #term <= 2 and 0 or #term <= 5 and 1 or #term <= 8 and 2 or 3
			local best, bestD, bestFull
			for _, w in ipairs(vocab) do
				-- against the whole word, and against its start (a typo in a half-typed word)
				local full = distance(term, w)
				local d = math.min(full, distance(term, w:sub(1, #term)))
				if d <= limit and (not bestD or d < bestD or (d == bestD and full < bestFull)) then best, bestD, bestFull = w, d, full end
			end
			if not best then return nil end
			terms[i] = best
			changed = true
		end
	end
	if not changed then return nil end
	local q = table.concat(terms, " ")
	if #Search.Match(entries, q, keep) > 0 then return q end
	return nil
end

------------------------------------------------------------------------
-- Apps: one settings window per addon, its slash command and its Settings (AddOns) entry.
-- Methods live in UI.App, a table that survives library upgrades, so apps made by an older
-- copy of this file use the newest methods.
------------------------------------------------------------------------
UI.App = UI.App or {}
local App = UI.App
App.__index = App

local SIDEBAR_W = 170

local function addonVersion(addon)
	local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	local v = addon and get and get(addon, "Version")
	return v
end

-- spec: name, addon (folder name), version (else the TOC's), tagline, slash ("/whack"), aliases ({ "/whackit" }: more
-- slash words, kept working and named in help), shortSettings (false: settings only as "/x set <setting> <value>"),
-- chatSearch (false: help doesn't offer "/x search <words>"), windowDesc (what a bare /x opens, for help),
-- accent { r, g, b },
-- frameName (prefix for global frame names; default name without spaces), width, height,
-- position (function returning the table the window position is saved in, as .window),
-- buttons ({ { label, onClick(app, button), text = fn() -> label } } shown under the sidebar or along the bottom),
-- feedbackURL, onShow(app), onHide(app), settingsPanel (false: no entry in Blizzard's Settings).
function UI:NewApp(spec)
	local app = setmetatable({}, App)
	app.spec = spec
	app.name = spec.name
	app.slash = spec.slash or ("/" .. spec.name:lower())
	app.T = UI.MakeTheme(spec.accent)
	app.frameName = spec.frameName or spec.name:gsub("[^%w]", "")
	app.sections, app.order = {}, {}
	app.settings, app.settingOrder = {}, {}
	app.commands, app.commandOrder = {}, {}
	if spec.settingsPanel ~= false then app:RegisterSettingsPanel() end
	return app
end

function App:Version()
	local v = self.spec.version or addonVersion(self.spec.addon) or "?"
	v = tostring(v)
	if v:sub(1, 1) ~= "v" then v = "v" .. v end
	return v
end

function App:ColorCode() return "|cff" .. hex(self.T.accent) end

function App:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(self:ColorCode() .. self.name .. "|r: " .. tostring(msg))
end

------------------------------------------------------------------------
-- Settings: one definition drives the window widget and the slash command.
-- def: key, type ("bool" | "number" | "choice" | "color" | "string"), label, desc, get(), set(v),
-- min, max, step, fmt, choices ({ { value, text } }), width, disabled(), after(v), example (for the help text),
-- hasAlpha, chatLabel (the label in chat replies when it needs more context than in the window),
-- keywords (more words the window's search finds it by, e.g. { "opacity", "alpha" }; English is fine).
------------------------------------------------------------------------
function App:Setting(def)
	assert(def.key and def.type and def.get and def.set, "setting needs key, type, get and set")
	local k = def.key:lower()
	assert(not self.settings[k], "duplicate setting " .. k)
	self.settings[k] = def
	self.settingOrder[#self.settingOrder + 1] = def
	return def
end

function App:GetSetting(key) return key and self.settings[tostring(key):lower()] end

local BOOL_WORDS = {
	on = true, ["true"] = true, yes = true, ["1"] = true, enable = true, enabled = true, show = true,
	off = false, ["false"] = false, no = false, ["0"] = false, disable = false, disabled = false, hide = false,
}

local function numFmt(def)
	return def.fmt or (def.step and def.step < 1 and "%.2f" or "%d")
end

-- The value as shown in chat.
function App:FormatValue(def, v)
	if def.type == "bool" then return v and "on" or "off" end
	if def.type == "number" then return v == nil and "?" or string.format(numFmt(def), v) end
	if def.type == "color" then return type(v) == "table" and ("#" .. hex(v)) or "?" end
	if def.type == "choice" then
		for _, c in ipairs(def.choices) do
			if c.value == v then return tostring(c.value) .. " (" .. c.text .. ")" end
		end
		return tostring(v)
	end
	return U.Escape(v == nil and "" or v)
end

function App:Example(def)
	if def.example then return def.example end
	if def.type == "bool" then return "on" end
	if def.type == "number" then return string.format(numFmt(def), def.get() or def.min or 0) end
	if def.type == "color" then return "ff8040" end
	if def.type == "choice" then return tostring(def.choices[1] and def.choices[1].value or "") end
	return "text"
end

-- What a setting accepts, for help lines.
function App:Accepts(def)
	if def.type == "bool" then return "on or off" end
	if def.type == "number" then
		return string.format(numFmt(def), def.min) .. " to " .. string.format(numFmt(def), def.max)
	end
	if def.type == "color" then return "a colour like ff8040 (hex) or 1 0.5 0.25" end
	if def.type == "choice" then
		local t = {}
		for _, c in ipairs(def.choices) do t[#t + 1] = tostring(c.value) end
		return table.concat(t, ", ")
	end
	return "any text"
end

-- Parse `text` for `def`. Returns ok, value or false, reason.
function App:Parse(def, text)
	text = U.Trim(text)
	if def.type == "bool" then
		local w = text:lower()
		if w == "toggle" then return true, not def.get() end
		local v = BOOL_WORDS[w]
		if v == nil then return false, "needs on or off" end
		return true, v
	elseif def.type == "number" then
		local v = tonumber(text)
		if not v then return false, "needs a number from " .. self:Accepts(def) end
		if v < def.min - 1e-9 or v > def.max + 1e-9 then return false, "must be " .. self:Accepts(def) end
		if def.step then v = math.min(def.max, math.max(def.min, math.floor(v / def.step + 0.5) * def.step)) end
		return true, v
	elseif def.type == "choice" then
		local w = text:lower()
		if w == "" then return false, "needs one of: " .. self:Accepts(def) end
		for _, c in ipairs(def.choices) do
			if tostring(c.value):lower() == w then return true, c.value end
		end
		local found
		for _, c in ipairs(def.choices) do
			if c.text:lower():sub(1, #w) == w then
				if found then return false, "more than one choice starts with that; use one of: " .. self:Accepts(def) end
				found = c
			end
		end
		if found then return true, found.value end
		return false, "needs one of: " .. self:Accepts(def)
	elseif def.type == "color" then
		local h = text:match("^#?(%x%x%x%x%x%x)$")
		if h then
			return true, { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, 1 }
		end
		local r, g, b = text:match("^([%d%.]+)[%s,]+([%d%.]+)[%s,]+([%d%.]+)$")
		r, g, b = tonumber(r), tonumber(g), tonumber(b)
		if r and g and b and r <= 1 and g <= 1 and b <= 1 then return true, { r, g, b, 1 } end
		return false, "needs " .. self:Accepts(def)
	end
	if def.validate then
		local ok, why = def.validate(text)
		if not ok then return false, why end
	end
	return true, text
end

-- Apply a value the same way the window does, then refresh the window.
function App:Apply(def, v)
	def.set(v)
	if def.after then def.after(v) end
	self:Refresh()
end

-- How a setting is set from chat: "/x <setting> <value>", or "/x set <setting> <value>" for an addon whose bare
-- words mean something else (spec.shortSettings = false: "/note <text>" notes your target).
function App:SetPrefix()
	return self.slash .. (self.spec.shortSettings == false and " set " or " ")
end

-- "/x <setting> <value>": set it and reply with the new value; no value shows it and how to set it.
function App:SetFromText(def, text)
	local usage = self:SetPrefix() .. def.key .. " " .. self:Example(def)
	local label = def.chatLabel or def.label
	if U.Trim(text) == "" then
		self:Print(label .. ": " .. self:FormatValue(def, def.get()) .. ". Set it with " .. U.Escape(usage) .. " (" .. self:Accepts(def) .. ").")
		return false
	end
	local ok, v = self:Parse(def, text)
	if not ok then
		self:Print("|cffff6060" .. label .. ": " .. U.Escape(v) .. ".|r Example: " .. U.Escape(usage))
		return false
	end
	self:Apply(def, v)
	self:Print(label .. ": " .. self:FormatValue(def, def.get()))
	return true
end

-- Try "<setting> [value]"; true when the first word named a setting.
function App:TrySetting(msg)
	local word, rest = U.Trim(msg):match("^(%S+)%s*(.*)$")
	local def = self:GetSetting(word)
	if not def then return false end
	self:SetFromText(def, rest or "")
	return true
end

function App:PrintSettings()
	if #self.settingOrder == 0 then self:Print("no settings to change from chat. " .. U.Escape(self.slash) .. " opens the window.") return end
	self:Print("settings (" .. U.Escape(self:SetPrefix()) .. "<setting> <value>):")
	for _, def in ipairs(self.settingOrder) do
		DEFAULT_CHAT_FRAME:AddMessage("  " .. self:ColorCode() .. def.key .. "|r = " .. self:FormatValue(def, def.get())
			.. "  |cff8d94a3" .. (def.chatLabel or def.label) .. " (" .. self:Accepts(def) .. ")|r")
	end
end

------------------------------------------------------------------------
-- Chat commands: one pattern in every addon (the full convention is COMMANDS.md next to this file).
--   /x                         the settings window
--   /x help | ?                every command, in one format
--   /x <setting> <value>       also "set <setting> <value>"; "get [setting]"; a setting alone shows it
--   /x on | off | toggle       the addon (app:OnOff); "/x off <setting>" or "/x <setting> off" for an on/off setting
--   /x reset [section]         asks first: the same command again within 10 s does it (app:Reset)
--   /x status | version        version, state and a health line (app:StatusLines)
--   /x lock | unlock           anything movable (app:Movable)
--   /x search <words>          the window with its search box filled
--   /x feedback                a link for bugs and ideas (spec.feedbackURL)
-- The addon's own commands (app:Command) are tried first, so an addon can give a verb its own meaning. An unknown
-- word gets the nearest command or setting ("did you mean /x tooltip off?").
------------------------------------------------------------------------
local RED, GREY = "|cffff6060", "|cff8d94a3"
UI.RESET_SECONDS = 10

-- name: the first word; usage: shown in help ("recent", "on <macro>"); run(rest, app); aliases: more first words.
-- c.hidden = true keeps it out of help (an old name kept working).
function App:Command(name, usage, desc, run, aliases)
	local c = { name = name, usage = usage or name, desc = desc, run = run, aliases = aliases }
	self.commands[name:lower()] = c
	self.commandOrder[#self.commandOrder + 1] = c
	for _, a in ipairs(aliases or {}) do self.commands[a:lower()] = c end
	return c
end

-- The addon's own on/off switch, for "/x on", "/x off" and "/x toggle":
-- def = { label = "Recording", get = fn() -> bool, set = fn(on) }.
function App:OnOff(def)
	assert(def and def.get and def.set, "OnOff needs get and set")
	self.onOff = def
	return def
end

-- Things the player can move, for "/x unlock", "/x lock" (and "/x move", which flips it):
-- def = { what = "the text areas", get = fn() -> locked, set = fn(locked) }.
function App:Movable(def)
	assert(def and def.get and def.set, "Movable needs get and set")
	self.movable = def
	return def
end

-- More for "/x status": fn(app) returns a line or a list of lines (or prints its own and returns nothing).
function App:StatusLines(fn) self.statusFn = fn end

-- Something "/x reset [section]" puts back: section ("outgoing"; nil for a plain "/x reset"), what it is for the
-- question ("the outgoing area"), run(app). Every reset asks first.
function App:Reset(section, what, run)
	self.resets = self.resets or {}
	self.resetOrder = self.resetOrder or {}
	local r = { section = section and section:lower() or "", what = what or "the settings", run = run }
	assert(not self.resets[r.section], "duplicate reset " .. r.section)
	self.resets[r.section] = r
	self.resetOrder[#self.resetOrder + 1] = r
	return r
end

local function capital(s) return (tostring(s):gsub("^%l", string.upper)) end

-- "/x reset" sections in help: "reset", "reset [outgoing | incoming]" or "reset outgoing | incoming".
local function resetUsage(app)
	local names, plain = {}, false
	for _, r in ipairs(app.resetOrder or {}) do
		if r.section == "" then plain = true else names[#names + 1] = r.section end
	end
	if #names == 0 then return "reset" end
	local list = table.concat(names, " | ")
	return plain and ("reset [" .. list .. "]") or ("reset " .. list)
end

-- The built-in verbs this app offers (for help and suggestions).
function App:Verbs()
	local v = { "help", "get", "set", "status", "version" }
	if self.spec.chatSearch ~= false then v[#v + 1] = "search" end
	if self.onOff then v[#v + 1] = "on"; v[#v + 1] = "off"; v[#v + 1] = "toggle" end
	if self.movable then v[#v + 1] = "lock"; v[#v + 1] = "unlock" end
	if self.resetOrder and #self.resetOrder > 0 then v[#v + 1] = "reset" end
	if self.spec.feedbackURL then v[#v + 1] = "feedback" end
	return v
end

function App:Help()
	self:Print(self:Version() .. (self.spec.tagline and (" - " .. self.spec.tagline) or ""))
	local cc, s = self:ColorCode(), self.slash
	local function line(cmd, desc) DEFAULT_CHAT_FRAME:AddMessage("  " .. cc .. U.Escape(cmd) .. "|r - " .. desc) end
	line(s, self.spec.windowDesc or "open the settings window")
	for _, c in ipairs(self.commandOrder) do
		if not c.hidden then line(s .. " " .. c.usage, c.desc or "") end
	end
	local cmds = self.commands
	if self.onOff and not cmds.on then
		line(s .. " on | off | toggle", "switch " .. (self.onOff.label and self.onOff.label:lower() or self.name) .. " on or off")
	end
	if self.movable and not cmds.unlock then
		line(s .. " unlock | lock", "move " .. (self.movable.what or "it") .. ", then lock again")
	end
	if self.resetOrder and #self.resetOrder > 0 and not cmds.reset then
		local one = #self.resetOrder == 1 and self.resetOrder[1]
		line(s .. " " .. resetUsage(self), "back to defaults" .. (one and (": " .. one.what) or "") .. " (asks first)")
	end
	if #self.settingOrder > 0 then
		local d = self.settingOrder[1]
		local p = self:SetPrefix()
		line(p .. "<setting> <value>", "change a setting, e.g. " .. U.Escape(p .. d.key .. " " .. self:Example(d)))
		line(s .. " get [setting]", "every setting and its value, or one")
	end
	if self.spec.chatSearch ~= false then line(s .. " search <words>", "find a setting in the window") end
	if self.spec.feedbackURL and not cmds.feedback then line(s .. " feedback", "a link for bugs and ideas") end
	line(s .. " status | version | help", "how it is doing, its version, this list")
	if self.spec.aliases and #self.spec.aliases > 0 then
		DEFAULT_CHAT_FRAME:AddMessage("  " .. GREY .. "Also works as " .. U.Escape(table.concat(self.spec.aliases, ", ")) .. ".|r")
	end
end

function App:PrintStatus()
	local state = ""
	if self.onOff then
		state = " " .. (self.onOff.label or "On") .. ": " .. (self.onOff.get() and "|cff62cf88on|r" or "|cffef5d5doff|r") .. "."
	end
	self:Print(self:Version() .. "." .. state)
	if not self.statusFn then return end
	local lines = self.statusFn(self)
	if type(lines) == "string" then lines = { lines } end
	for _, l in ipairs(lines or {}) do DEFAULT_CHAT_FRAME:AddMessage("  " .. tostring(l)) end
end

-- "/x search <words>": the window, its search box filled. Lattice-style apps with their own window override it.
function App:OpenSearch(text)
	self:Open()
	local box = self.window and self.window.searchBox
	if not box then return end
	text = U.Trim(text)
	box:SetText(text)
	if box.UpdateHint then box.UpdateHint() end
	if text == "" then box:SetFocus() else self:Search(text) end
end

function App:HandleReset(rest)
	local key = U.Trim(rest):lower()
	if key == "all" and self.resets and not self.resets.all and self.resets[""] then key = "" end -- "/x reset all" = "/x reset"
	local list = self.resetOrder or {}
	local names = {}
	for _, r in ipairs(list) do if r.section ~= "" then names[#names + 1] = r.section end end
	local r = self.resets and self.resets[key]
	if not r then
		if #list == 0 then
			self:Print(RED .. "nothing to reset from chat.|r The window (" .. U.Escape(self.slash) .. ") has the defaults buttons.")
		elseif key == "" then
			self:Print("reset what? " .. U.Escape(self.slash .. " reset " .. table.concat(names, " | ")))
		else
			local near = UI.Nearest(key, names)
			self:Print(RED .. "nothing called '" .. U.Escape(key) .. "' to reset.|r "
				.. (near and ("Did you mean " .. U.Escape(self.slash .. " reset " .. near) .. "?") or ("Choose: " .. table.concat(names, ", ") .. ".")))
		end
		return "reset"
	end
	local cmd = self.slash .. " reset" .. (key ~= "" and (" " .. key) or "")
	local p = self.pendingReset
	local now = GetTime()
	if p and p.key == key and now - p.at <= UI.RESET_SECONDS then
		self.pendingReset = nil
		r.run(self)
		self:Refresh()
		self:Print(capital(r.what) .. ": back to defaults.")
		return "reset"
	end
	self.pendingReset = { key = key, at = now }
	self:Print("this puts " .. r.what .. " back to defaults. Type " .. U.Escape(cmd) .. " again within " .. UI.RESET_SECONDS .. " s to do it.")
	return "reset-ask"
end

-- The nearest of `words` to `word`: a unique start ("stat" -> "status") or one or two typos away, else nil.
function UI.Nearest(word, words)
	word = tostring(word or ""):lower()
	if word == "" then return nil end
	local starts
	for _, w in ipairs(words) do
		if #word >= 2 and w:sub(1, #word) == word then
			if starts and starts ~= w then starts = false else starts = starts == nil and w or starts end
		end
	end
	if starts then return starts end
	local limit = #word <= 2 and 0 or #word <= 5 and 1 or #word <= 8 and 2 or 3
	local best, bestD
	for _, w in ipairs(words) do
		local d = Search.Distance(word, w)
		if d <= limit and (not bestD or d < bestD) then best, bestD = w, d end
	end
	return best
end

-- What an unknown first word was probably meant to be: a command, a verb or a setting key; else a setting whose
-- label, description or keywords match it ("/dv price" -> tooltip).
function App:Suggest(word)
	local words, seen = {}, {}
	local function add(w) w = w:lower(); if not seen[w] then seen[w] = true; words[#words + 1] = w end end
	for _, c in ipairs(self.commandOrder) do
		if not c.hidden then
			add(c.name)
			for _, a in ipairs(c.aliases or {}) do add(a) end
		end
	end
	for _, v in ipairs(self:Verbs()) do add(v) end
	for _, def in ipairs(self.settingOrder) do add(def.key) end
	local near = UI.Nearest(word, words)
	if near then return near, self.settings[near] ~= nil end
	local entries = {}
	for _, def in ipairs(self.settingOrder) do
		entries[#entries + 1] = Search.Entry({ label = def.label, chatLabel = def.chatLabel, key = def.key, keywords = def.keywords, desc = def.desc, def = def })
	end
	local found = Search.Match(entries, word)
	if found[1] then return found[1].entry.info.def.key, true end
	return nil
end

function App:Unknown(word, rest)
	local near, isSetting = self:Suggest(word)
	local try = near and (self.slash .. " " .. near .. ((rest and rest ~= "" and (isSetting or self.commands[near])) and (" " .. rest) or ""))
	self:Print(RED .. "unknown command '" .. U.Escape(word) .. "'.|r "
		.. (try and ("Did you mean " .. U.Escape(try) .. "? ") or "") .. U.Escape(self.slash) .. " help lists the commands.")
end

-- "/x on|off|toggle [setting]".
local function onOffVerb(app, rest, w)
	if rest ~= "" then
		local key = rest:match("^(%S+)")
		local def = app:GetSetting(key)
		if def and def.type == "bool" then app:SetFromText(def, w) return "setting" end
		if def then
			app:Print(RED .. (def.chatLabel or def.label) .. " isn't on/off.|r Set it with " .. U.Escape(app:SetPrefix() .. def.key .. " " .. app:Example(def)) .. ".")
			return "setting"
		end
		app:Unknown(key)
		return "unknown"
	end
	local o = app.onOff
	if not o then
		app:Print(RED .. app.name .. " has no on/off switch of its own.|r Switch a part of it: " .. U.Escape(app.slash .. " <setting> off") .. " (" .. U.Escape(app.slash) .. " get lists them).")
		return "unknown"
	end
	local on
	if w == "toggle" then on = not o.get() else on = w == "on" end
	o.set(on)
	app:Refresh()
	app:Print((o.label or app.name) .. ": " .. (o.get() and "on" or "off"))
	return "onoff"
end

local function lockVerb(app, rest, w)
	local m = app.movable
	if not m then return nil end
	local locked
	if w == "move" then locked = not m.get() else locked = w == "lock" end
	m.set(locked)
	app:Refresh()
	return locked and "lock" or "unlock"
end

-- word -> function(app, rest, word) returning what was done, or nil to go on (a setting, else unknown).
UI.Verbs = {
	get = function(app, rest)
		if rest == "" then app:PrintSettings() return "settings" end
		local def = app:GetSetting(rest:match("^(%S+)"))
		if def then app:SetFromText(def, "") return "setting" end
		app:Unknown(rest:match("^(%S+)"))
		return "unknown"
	end,
	set = function(app, rest)
		local key, value = rest:match("^(%S+)%s*(.*)$")
		local def = app:GetSetting(key)
		if def then app:SetFromText(def, value or "") return "setting" end
		if not key then
			app:Print("set what? " .. U.Escape(app:SetPrefix() .. "<setting> <value>") .. "; " .. U.Escape(app.slash) .. " get lists the settings.")
			return "settings"
		end
		app:Unknown(key, value)
		return "unknown"
	end,
	settings = function(app, rest)
		if rest ~= "" and app:TrySetting(rest) then return "setting" end
		app:PrintSettings()
		return "settings"
	end,
	options = function(app) app:Open() return "open" end,
	on = onOffVerb, off = onOffVerb, toggle = onOffVerb,
	lock = lockVerb, unlock = lockVerb, move = lockVerb,
	reset = function(app, rest) return app:HandleReset(rest) end,
	status = function(app) app:PrintStatus() return "status" end,
	version = function(app) app:Print(app:Version()) return "version" end,
	search = function(app, rest) app:OpenSearch(rest) return "search" end,
	find = function(app, rest) app:OpenSearch(rest) return "search" end,
	feedback = function(app)
		if not app.spec.feedbackURL then return nil end
		app:ShowFeedback()
		return "feedback"
	end,
}
UI.Verbs.config = UI.Verbs.options
UI.Verbs.bug = UI.Verbs.feedback
UI.Verbs.ver = UI.Verbs.version

-- The whole slash command: bare opens the window; help; the addon's commands; the shared verbs; "<setting> <value>".
function App:HandleSlash(msg)
	msg = U.Trim(msg)
	if msg == "" then self:Toggle() return "toggle" end
	local word, rest = msg:match("^(%S+)%s*(.*)$")
	local w = word:lower()
	if w == "help" or w == "?" or w == "commands" then self:Help() return "help" end
	local c = self.commands[w]
	if c then c.run(rest or "", self) return "command" end
	local verb = UI.Verbs[w]
	if verb then
		local done = verb(self, rest or "", w)
		if done then return done end
	end
	if self:TrySetting(msg) then return "setting" end
	self:Unknown(word, rest)
	return "unknown"
end

-- Registers the slash command: SLASH_<id>1 = the main command, then spec.aliases ("/everlookdb"), and
-- SlashCmdList[id]. before(msg) returning true stops it (not ready yet, say).
function App:RegisterSlash(id, before)
	id = id or self.frameName:upper()
	local words = { self.slash }
	for _, a in ipairs(self.spec.aliases or {}) do words[#words + 1] = a end
	for i, w in ipairs(words) do _G["SLASH_" .. id .. i] = w end
	local app = self
	SlashCmdList[id] = function(msg)
		if before and before(msg) then return end
		app:HandleSlash(msg)
	end
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
-- build(stack, app, section) fills the section's page; called once, when it is first shown.
function App:Section(id, title, build)
	assert(not self.sections[id], "duplicate section " .. id)
	self.sections[id] = { id = id, title = title, build = build }
	self.order[#self.order + 1] = id
end

-- The widget for a setting (by key), with `extra` options mixed in.
function App:Widget(stack, key, extra)
	local def = self:GetSetting(key)
	assert(def, "no setting " .. tostring(key))
	local app = self
	local opt = {
		label = def.label, desc = def.desc, get = def.get, disabled = def.disabled,
		min = def.min, max = def.max, step = def.step, fmt = def.fmt, items = def.choices,
		width = def.width, hasAlpha = def.hasAlpha, placeholder = def.placeholder,
		keywords = def.keywords, searchKey = def.key, chatLabel = def.chatLabel,
		set = function(v) def.set(v) end,
		after = function() if def.after then def.after(def.get()) end; app:RefreshButtons() end,
	}
	if extra then for k, v in pairs(extra) do opt[k] = v end end
	local t = def.type
	if t == "bool" then return UI.Toggle(stack, opt) end
	if t == "number" then return UI.Slider(stack, opt) end
	if t == "choice" then return UI.Dropdown(stack, opt) end
	if t == "color" then return UI.Color(stack, opt) end
	return UI.Input(stack, opt)
end

------------------------------------------------------------------------
-- Settings search in the window. The box sits at the top centre; typing lists the matching controls from
-- every page. The listed controls are the real ones, borrowed from their page (its layout keeps their room)
-- and given back when the search changes or ends, so whatever you change there is the setting itself.
------------------------------------------------------------------------
local MAX_RESULTS = 50
local PATH_SEP = " \194\187 " -- " » "

-- Stack:Add calls this for a widget with searchInfo on one of the app's pages.
function App:IndexWidget(stack, frame)
	local s = self.sections[stack.section]
	local list = self.searchBySection and self.searchBySection[stack.section]
	if not s or not list then return end
	local info = {}
	for k, v in pairs(frame.searchInfo) do info[k] = v end
	local header = stack.searchHeader
	if header and Search.Normalize(header) == Search.Normalize(s.title) then header = nil end -- "Options » Options"
	info.section, info.header = s.title, header
	local e = Search.Entry(info)
	e.frame, e.stack, e.sectionId = frame, stack, s.id
	e.path = s.title .. (header and (PATH_SEP .. header) or "")
	list[#list + 1] = e
end

-- Every indexed control, in page order.
function App:SearchEntries()
	local all = {}
	for _, id in ipairs(self.order) do
		for _, e in ipairs(self.searchBySection and self.searchBySection[id] or {}) do all[#all + 1] = e end
	end
	return all
end

-- Build a page's widgets, hidden (ShowSection shows it; the search reads it).
function App:BuildSection(id)
	local f, s = self.window, self.sections[id]
	if not f or not s or s.scroll then return s end
	s.scroll = UI.ScrollPage(f.content)
	s.scroll:Hide()
	local width = f.contentWidth - 24 -- the scroll bar takes the right edge
	s.scroll.child:SetWidth(width)
	s.stack = UI.Stack(s.scroll.child, width, self.T)
	s.stack.app, s.stack.section = self, id
	self.searchBySection[id] = {}
	s.build(s.stack, self, s)
	s.scroll.UpdateBar()
	s.searchFailed = nil
	return s
end

local function DropSection(app, s)
	if s.scroll then s.scroll:Hide(); s.scroll:SetParent(nil) end
	s.scroll, s.stack = nil, nil
	if app.searchBySection then app.searchBySection[s.id] = nil end
end

-- Build the pages not built yet so the search knows their settings (all of them, or with `one` just the next).
-- A page that fails is reported once and left to be built when it is opened. True when one was built.
function App:EnsureSearchIndex(one)
	if not self.window then return false end
	for _, id in ipairs(self.order) do
		local s = self.sections[id]
		if not s.scroll and not s.searchFailed then
			local ok, err = pcall(self.BuildSection, self, id)
			if not ok then
				DropSection(self, s)
				s.searchFailed = true
				local handler = geterrorhandler and geterrorhandler()
				if handler then handler(err) end
			end
			if one then return true end
		end
	end
	return false
end

-- After the window opens: build the other pages one per frame, so the first search is instant.
function App:WarmSearch()
	if self.warming then return end
	self.warming = true
	local app = self
	local function step()
		if not app:IsShown() or not app:EnsureSearchIndex(true) then app.warming = nil return end
		C_Timer.After(0, step)
	end
	C_Timer.After(0, step)
end

local function Listed(e) return e.frame:IsShown() end -- a control its addon hid (doesn't apply now) isn't listed

-- Put a control into the results at `y`.
function App:Borrow(e, parent, y, width)
	local fr, se = e.frame, e.frame.stackEntry
	if not self.borrowed[e] then
		self.borrowed[e] = true
		se.borrowed = true
		fr:SetParent(parent)
	end
	fr:ClearAllPoints()
	fr:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
	fr:SetWidth(width)
	fr:SetHeight(se.height)
	if fr.Refresh then fr:Refresh() end
end

-- Give controls back to their pages (all of them, or those not in `keep`).
function App:ReturnBorrowed(keep)
	if not self.borrowed then return end
	local stacks = {}
	for e in pairs(self.borrowed) do
		if not (keep and keep[e]) then
			self.borrowed[e] = nil
			e.frame.stackEntry.borrowed = nil
			e.frame:SetParent(e.stack.parent)
			stacks[e.stack] = true
		end
	end
	for st in pairs(stacks) do st:Relayout() end
end

function App:RefreshBorrowed(skipStack)
	if self.refreshingResults or not self.borrowed then return end
	self.refreshingResults = true
	for e in pairs(self.borrowed) do
		if e.stack ~= skipStack and e.frame.Refresh then e.frame:Refresh() end
	end
	self.refreshingResults = nil
end

-- Search for `text` and list what matches; an empty text ends the search. Returns the matches.
function App:Search(text)
	local f = self.window
	if not f then return {} end
	local q = U.Trim(text)
	if q == "" then self:StopSearch() return {} end
	self:EnsureSearchIndex()
	if not self.searching then
		self.searching = true
		ClosePopup()
		for _, s in pairs(self.sections) do if s.scroll then s.scroll:Hide() end end
	end
	local entries = self:SearchEntries()
	self.searchQuery = q
	local results = Search.Match(entries, q, Listed)
	self:ShowResults(results, q, entries)
	return results
end

function App:ShowResults(results, q, entries)
	local f, T = self.window, self.T
	local R = f.results
	local child = R.child
	local width = f.contentWidth - 24
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
		R.empty:SetText(("No setting matches '%s'."):format(U.Escape(q)))
		R.empty:Show()
		y = y + 22
		local sug = Search.Suggest(entries, q, Listed)
		R.suggest.query = sug
		if sug then
			R.suggest.label:SetText("Did you mean |cff" .. hex(T.accent) .. U.Escape(sug) .. "|r?")
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
			self:Borrow(e, child, y, width)
			y = y + e.frame.stackEntry.height + 18
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
function App:StopSearch()
	local f = self.window
	if f and f.searchBox and f.searchBox:GetText() ~= "" then f.searchBox:SetText("") end
	if not self.searching then return end
	self.searching = nil
	self:ReturnBorrowed()
	ClosePopup()
	f.results:Hide()
	local s = self.current and self.sections[self.current]
	if s and s.scroll then
		s.stack:RefreshAll()
		s.scroll:Show()
	end
end

-- From a result's path: open its page, scroll to it and light it up for a moment.
function App:JumpTo(e)
	local id = e.sectionId
	self:StopSearch()
	self:ShowSection(id)
	local s = self.sections[id]
	if self.current ~= id or not s or e.stack ~= s.stack then return end -- kept on the page (unsaved changes) or rebuilt
	local se = e.frame.stackEntry
	if s.scroll.SetScroll and se and se.y then s.scroll.SetScroll(se.y - 12) end
	self:Flash(e.frame)
end

function App:Flash(frame)
	local T = self.T
	local tex = rawget(frame, "eluiFlash")
	if not tex then
		tex = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
		tex:SetTexture(U.WHITE)
		tex:SetPoint("TOPLEFT", -6, 4)
		tex:SetPoint("BOTTOMRIGHT", 6, -4)
		frame.eluiFlash = tex
	end
	tex:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 1)
	tex:SetAlpha(0.28)
	tex:Show()
	local driver = self.flashDriver
	if not driver then
		driver = CreateFrame("Frame")
		self.flashDriver = driver
	end
	if driver.tex and driver.tex ~= tex then driver.tex:Hide() end
	driver.tex = tex
	local start = GetTime()
	driver:SetScript("OnUpdate", function(d)
		local t = GetTime() - start
		if t >= 1.8 then tex:Hide(); d.tex = nil; d:SetScript("OnUpdate", nil) return end
		tex:SetAlpha(t < 0.6 and 0.28 or 0.28 * (1 - (t - 0.6) / 1.2))
	end)
end

-- The box, the results page and the keys (Ctrl+F, Escape). Called by CreateWindow.
function App:CreateSearch(f, width)
	local app, T = self, self.T
	self.borrowed = self.borrowed or {}
	self.searchBySection = self.searchBySection or {}

	local box = UI.EditBox(f, width, 26)
	box:SetTextInsets(26, 26, 0, 0)
	box:SetMaxLetters(60)
	local icon = box:CreateTexture(nil, "OVERLAY")
	icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
	icon:SetSize(14, 14)
	icon:SetPoint("LEFT", 8, -1)
	icon:SetVertexColor(rgba(T.muted))
	local hint = Text(box, T.font, T.muted)
	hint:SetPoint("LEFT", 26, 0)
	hint:SetText("Search settings")
	local keyHint = Text(box, T.fontSmall, T.muted)
	keyHint:SetPoint("RIGHT", -9, 0)
	keyHint:SetText("Ctrl+F")
	local clear = CreateFrame("Button", nil, box)
	clear:SetSize(22, 22)
	clear:SetPoint("RIGHT", -2, 0)
	local cx = Text(clear, T.font, T.muted)
	cx:SetPoint("CENTER")
	cx:SetText("x")
	clear:SetScript("OnEnter", function() cx:SetTextColor(rgba(T.text)) end)
	clear:SetScript("OnLeave", function() cx:SetTextColor(rgba(T.muted)) end)
	clear:SetScript("OnClick", function() app:StopSearch(); box:SetFocus() end)
	Tooltip(clear, "Clear the search")

	local function update()
		local empty = (box:GetText() or "") == ""
		hint:SetShown(empty)
		keyHint:SetShown(empty and not box:HasFocus())
		clear:SetShown(not empty)
	end
	box.UpdateHint = update
	box:HookScript("OnEditFocusGained", update)
	box:HookScript("OnEditFocusLost", update)
	-- searches once per frame at most, however fast you type or paste
	local pending
	box:SetScript("OnTextChanged", function(self, user)
		update()
		if not user or pending then return end
		pending = true
		C_Timer.After(0, function()
			pending = nil
			if f:IsShown() then app:Search(box:GetText()) end
		end)
	end)
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	-- Escape clears the search; Escape in an empty box closes the window
	box:SetScript("OnEscapePressed", function(self)
		local had = (self:GetText() or "") ~= "" or app.searching
		self:ClearFocus()
		if had then app:StopSearch() else app:Close() end
	end)
	update()
	f.searchBox = box

	-- the results page, in the content area in place of the page you were on
	local R = UI.ScrollPage(f.content)
	R:Hide()
	R.child:SetWidth(f.contentWidth - 24)
	R.paths = {}
	function R.NewPath(i)
		local b = CreateFrame("Button", nil, R.child)
		b:SetHeight(14)
		b.text = Text(b, T.fontSmall + 1, T.muted)
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
		b:SetScript("OnClick", function(self) if self.entry then app:JumpTo(self.entry) end end)
		R.paths[i] = b
		return b
	end
	R.empty = Text(R.child, T.font, T.text)
	R.empty:SetPoint("TOPLEFT", 0, -4)
	R.empty:SetPoint("RIGHT")
	R.empty:Hide()
	R.suggest = CreateFrame("Button", nil, R.child)
	R.suggest:SetHeight(18)
	R.suggest:SetPoint("TOPLEFT", 0, -26)
	R.suggest.label = Text(R.suggest, T.font, T.muted)
	R.suggest.label:SetPoint("LEFT")
	R.suggest.label:SetWordWrap(false)
	R.suggest:SetScript("OnClick", function(self)
		if not self.query then return end
		box:SetText(self.query)
		box.UpdateHint()
		app:Search(self.query)
	end)
	R.suggest:Hide()
	R.more = Text(R.child, T.fontSmall + 1, T.muted)
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
		if app.searching or (box:GetText() or "") ~= "" then app:StopSearch() return true end
	end
	return box
end

local function SavePosition(app, f)
	local holder = app.spec.position and app.spec.position()
	if type(holder) ~= "table" then return end
	local point, _, rel, x, y = f:GetPoint()
	if point then holder.window = { point, rel or point, math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5) } end
end

local function RestorePosition(app, f)
	local holder = app.spec.position and app.spec.position()
	local p = type(holder) == "table" and holder.window
	f:ClearAllPoints()
	if type(p) == "table" and type(p[1]) == "string" then
		f:SetPoint(p[1], UIParent, p[2] or p[1], tonumber(p[3]) or 0, tonumber(p[4]) or 0)
	else
		f:SetPoint("CENTER")
	end
end

function App:CreateWindow()
	local app, T, spec = self, self.T, self.spec
	local sidebar = #self.order > 1
	local W = spec.width or (sidebar and 780 or 600)
	local H = spec.height or 560
	local f = CreateFrame("Frame", self.frameName .. "OptionsWindow", UIParent)
	f.eluiTheme = T
	f.app = self
	f:SetSize(W, H)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) self:StartMoving() end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition(app, self)
	end)
	f:Hide()
	RestorePosition(self, f)
	U.Solid(f, "BACKGROUND", rgba(T.bg)):SetAllPoints()
	U.Border(f, 1, rgba(T.border))

	f.footer = {}
	local function footerButton(parent, d, width)
		local b = UI.Button(parent, d.label, function(btn) d.onClick(app, btn); app:RefreshButtons() end, width, d.style)
		b.def = d
		f.footer[#f.footer + 1] = b
		if d.desc then Tooltip(b, d.label, d.desc) end
		return b
	end
	local buttons = {}
	for _, d in ipairs(spec.buttons or {}) do buttons[#buttons + 1] = d end
	if spec.feedbackURL then
		buttons[#buttons + 1] = { label = "Feedback / report a bug", onClick = function() app:ShowFeedback() end }
	end

	local contentLeft, contentTop, contentBottom, titleRight
	if sidebar then
		local side = CreateFrame("Frame", nil, f)
		side:SetPoint("TOPLEFT", 1, -1)
		side:SetPoint("BOTTOMLEFT", 1, 1)
		side:SetWidth(SIDEBAR_W)
		U.Solid(side, "BACKGROUND", rgba(T.sidebar)):SetAllPoints()
		local sideLine = U.Solid(side, "BORDER", rgba(T.border))
		sideLine:SetWidth(1)
		sideLine:SetPoint("TOPRIGHT")
		sideLine:SetPoint("BOTTOMRIGHT")

		local logo = Text(side, T.fontHuge, T.text)
		logo:SetPoint("TOPLEFT", 18, -18)
		logo:SetWidth(SIDEBAR_W - 30)
		logo:SetText(self.name)
		-- a long single word ("MouseoverMacros") can't wrap and was cut off: shrink until the widest word fits
		local font, size, flags = logo:GetFont()
		if font and size then
			local widest = 0
			for word in tostring(self.name):gmatch("%S+") do
				logo:SetText(word)
				widest = math.max(widest, logo.GetUnboundedStringWidth and logo:GetUnboundedStringWidth() or logo:GetStringWidth() or 0)
			end
			local room = SIDEBAR_W - 30
			if widest > room then
				logo:SetFont(font, math.max(11, math.floor(size * room / widest)), flags)
			end
			logo:SetText(self.name)
		end
		local ver = Text(side, T.fontSmall, T.muted)
		ver:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -3)
		ver:SetText(self:Version())
		-- the nav starts under the name (which may wrap), the version and the tagline
		local navTop = 18 + math.max(20, math.ceil(logo:GetStringHeight() or 20)) + 3 + math.max(10, math.ceil(ver:GetStringHeight() or 10))
		if spec.tagline then
			local tag = Text(side, T.fontSmall, T.muted)
			tag:SetPoint("TOPLEFT", ver, "BOTTOMLEFT", 0, -8)
			tag:SetWidth(SIDEBAR_W - 30)
			tag:SetText(spec.tagline)
			navTop = navTop + 8 + math.ceil(tag:GetStringHeight() or 12)
		end
		navTop = navTop + 14
		f.tagline = spec.tagline

		f.navButtons = {}
		for i, id in ipairs(self.order) do
			local s = self.sections[id]
			local b = CreateFrame("Button", nil, side)
			b:SetHeight(30)
			b:SetPoint("TOPLEFT", 8, -navTop - (i - 1) * 32)
			b:SetPoint("RIGHT", -8, 0)
			b.bg = U.Solid(b, "BACKGROUND", rgba(T.accentDim))
			b.bg:SetAllPoints()
			b.bg:Hide()
			b.bar = U.Solid(b, "ARTWORK", rgba(T.accent))
			b.bar:SetWidth(2)
			b.bar:SetPoint("TOPLEFT")
			b.bar:SetPoint("BOTTOMLEFT")
			b.bar:Hide()
			b.text = Text(b, T.font, T.muted)
			b.text:SetPoint("LEFT", 12, 0)
			b.text:SetText(s.title)
			b:SetScript("OnEnter", function(self) if app.current ~= id then self.text:SetTextColor(rgba(T.text)) end end)
			b:SetScript("OnLeave", function(self) if app.current ~= id then self.text:SetTextColor(rgba(T.muted)) end end)
			b:SetScript("OnClick", function() app:ShowSection(id) end)
			f.navButtons[id] = b
		end
		-- footer buttons stack up from the bottom of the sidebar
		for i, d in ipairs(buttons) do
			local b = footerButton(side, d, SIDEBAR_W - 16)
			b:SetPoint("BOTTOMLEFT", 8, 12 + (#buttons - i) * 32)
		end
		contentLeft, contentTop, contentBottom = SIDEBAR_W + 1 + T.pad + 8, -52, T.pad -- the search box sits above
	else
		local title = Text(f, T.fontHuge, T.text)
		title:SetPoint("TOPLEFT", T.pad, -14)
		title:SetWordWrap(false)
		title:SetText(self.name)
		local ver = Text(f, T.fontSmall, T.muted)
		ver:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 1)
		ver:SetText(self:Version())
		local function width(fs) return fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth() or 0 end
		titleRight = T.pad + (width(title) or 0) + 8 + (width(ver) or 0)
		local top = 44
		if spec.tagline then
			local tag = Text(f, T.fontSmall + 1, T.muted)
			tag:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
			tag:SetWidth(W - 2 * T.pad - 30)
			tag:SetText(spec.tagline)
			top = 14 + 22 + 6 + math.ceil(tag:GetStringHeight()) + 10
		end
		f.tagline = spec.tagline
		local line = U.Solid(f, "ARTWORK", rgba(T.border))
		line:SetHeight(1)
		line:SetPoint("TOPLEFT", 1, -top)
		line:SetPoint("TOPRIGHT", -1, -top)
		local bottom = T.pad
		if #buttons > 0 then
			local x = T.pad
			for _, d in ipairs(buttons) do
				local w = d.width or 150
				local b = footerButton(f, d, w)
				-- never narrower than the label ("Feedback / report a bug" needs about 160 px)
				local tw = b.label.GetUnboundedStringWidth and b.label:GetUnboundedStringWidth() or b.label:GetStringWidth() or 0
				if tw + 24 > w then w = math.ceil(tw + 24); b:SetWidth(w) end
				b:SetPoint("BOTTOMLEFT", x, 14)
				x = x + w + 8
			end
			bottom = 52
		end
		contentLeft, contentTop, contentBottom = T.pad, -top - 14, bottom
	end

	local close = CreateFrame("Button", nil, f)
	close:SetSize(24, 24)
	close:SetPoint("TOPRIGHT", -8, -8)
	local x = Text(close, T.fontTitle, T.muted)
	x:SetPoint("CENTER")
	x:SetText("x")
	close:SetScript("OnEnter", function() x:SetTextColor(rgba(T.text)) end)
	close:SetScript("OnLeave", function() x:SetTextColor(rgba(T.muted)) end)
	close:SetScript("OnClick", function() f:Hide() end)
	f.close = close

	local content = CreateFrame("Frame", nil, f)
	content:SetPoint("TOPLEFT", contentLeft, contentTop)
	content:SetPoint("BOTTOMRIGHT", -T.pad, contentBottom)
	f.content = content
	f.contentWidth = W - contentLeft - T.pad

	-- the search box, top centre: over the page column, or in the title row of a one-page window
	if sidebar then
		local boxW = math.min(300, W - SIDEBAR_W - 120)
		local box = self:CreateSearch(f, boxW)
		box:SetPoint("TOP", f, "TOPLEFT", SIDEBAR_W + 1 + (W - SIDEBAR_W - 1) / 2, -12)
	else
		local boxW, right = 240, W - 44 -- clear of the close button
		local left = math.floor((W - boxW) / 2)
		if left < titleRight + 16 then left = math.ceil(titleRight + 16) end
		if left + boxW > right then boxW = math.max(140, right - left) end
		local box = self:CreateSearch(f, boxW)
		box:SetPoint("TOPLEFT", f, "TOPLEFT", left, -10)
	end

	f:SetScript("OnShow", function()
		app:RefreshButtons()
		if spec.onShow then spec.onShow(app) end
		app:WarmSearch()
	end)
	f:SetScript("OnHide", function()
		ClosePopup()
		f.searchBox:ClearFocus()
		app:StopSearch()
		if spec.onHide then spec.onHide(app) end
	end)
	UI.CloseOnEscape(f)
	self.window = f
	return f
end

function App:RefreshButtons()
	local f = self.window
	if not f then return end
	for _, b in ipairs(f.footer) do
		if b.def.text then b:SetText(b.def.text(self)) end
	end
end

function App:ShowSection(id)
	local f = self.window
	if not f then return end
	local s = self.sections[id]
	if not s then return end
	ClosePopup()
	if self.searching then self:StopSearch() end -- a page picked in the sidebar ends the search
	for sid, other in pairs(self.sections) do
		if other.scroll then other.scroll:SetShown(sid == id) end
		local b = f.navButtons and f.navButtons[sid]
		if b then
			local active = sid == id
			b.bg:SetShown(active)
			b.bar:SetShown(active)
			b.text:SetTextColor(rgba(active and self.T.text or self.T.muted))
		end
	end
	self.current = id
	if not s.scroll then
		self:BuildSection(id)
	else
		s.stack:RefreshAll()
	end
	s.scroll:Show()
end

-- Build a section again from scratch (its rows depend on data).
function App:RebuildSection(id)
	local s = self.sections[id]
	if not s or not s.scroll then return end
	if self.searching then self:ReturnBorrowed() end
	DropSection(self, s)
	if self.searching then
		self:Search(self.searchQuery or "") -- builds it again for the results
	elseif self.current == id and self:IsShown() then
		self:ShowSection(id)
	end
end

-- Re-read every value shown in the open window.
function App:Refresh()
	if not self.window then return end
	self:RefreshButtons()
	if self.searching then self:RefreshBorrowed() return end
	local s = self.current and self.sections[self.current]
	if s and s.stack then s.stack:RefreshAll() end
end

function App:Open(id)
	if not self.window then self:CreateWindow() end
	self.window:Show()
	self:ShowSection(id or self.current or self.order[1])
end

function App:Close()
	if self.window then self.window:Hide() end
end

function App:IsShown() return self.window ~= nil and self.window:IsShown() end

function App:Toggle()
	if self:IsShown() then self:Close() else self:Open() end
end

function App:ShowFeedback()
	if not self.feedback then
		self.feedback = UI.LinkWindow(self.frameName .. "FeedbackWindow", self.T,
			"Report a bug or suggest an idea.\nPress Ctrl+C to copy the link, then paste it in your browser.", self.spec.feedbackURL)
	end
	self.feedback:Show()
	return self.feedback
end

------------------------------------------------------------------------
-- Blizzard's Settings > AddOns: a small page with a button that opens the window.
-- Only the official registration calls; Blizzard's panel is never hidden or changed by us.
------------------------------------------------------------------------
function App:RegisterSettingsPanel()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
	local app, T = self, self.T
	local p = CreateFrame("Frame")
	p.eluiTheme = T
	p.name = self.name
	local title = Text(p, T.fontHuge + 2, T.text)
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(self.name)
	local ver = Text(p, T.fontSmall + 1, T.muted)
	ver:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 2)
	p:SetScript("OnShow", function() ver:SetText(app:Version()) end)
	local tag = Text(p, T.font, T.muted)
	tag:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	tag:SetWidth(520)
	tag:SetText((self.spec.tagline or "") .. "\n\nAll settings are in " .. self.name .. "'s own window (also " .. self.slash .. ").")
	local b = UI.Button(p, "Open " .. self.name .. " settings", function() app:Open() end, 240, "accent")
	b:SetPoint("TOPLEFT", tag, "BOTTOMLEFT", 0, -16)
	p.openButton = b
	p.OnCommit = function() end
	p.OnDefault = function() end
	p.OnRefresh = function() end
	local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, p, self.name)
	if ok and category then
		pcall(Settings.RegisterAddOnCategory, category)
		self.settingsCategory = category
	end
	self.settingsPanel = p
end
