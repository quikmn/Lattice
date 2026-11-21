-- Lattice options: small self-contained widget kit.
-- Every bound widget takes { label, desc, get, set, ... } and exposes :Refresh().
local _, ns = ...
local U, T = ns.Util, ns.Theme
local W = {}
ns.Widgets = W

local function rgba(c) return c[1], c[2], c[3], c[4] or 1 end

local function Text(parent, size, color, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	U.SetFont(fs, size or T.font)
	fs:SetTextColor(rgba(color or T.text))
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(true)
	return fs
end
W.Text = Text

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
W.Tooltip = Tooltip

-- Escape closes `frame`, through the frame's own key handler. Not UISpecialFrames:
-- Blizzard walks that list when Escape closes its own windows (character sheet,
-- vendor...), and an entry written by an addon taints that walk, so the window's
-- OnHide then fails on secret health values. Keys other than Escape pass through.
-- SetPropagateKeyboardInput is blocked in combat, so a window opened in combat
-- leaves the keyboard alone, and Escape in combat closes it and also reaches the game.
-- Call after the frame's own OnShow script is set (this hooks it).
function W.CloseOnEscape(frame)
	frame:HookScript("OnShow", function(self)
		local ok = not InCombatLockdown()
		if ok then self:SetPropagateKeyboardInput(true) end
		self:EnableKeyboard(ok)
	end)
	frame:SetScript("OnKeyDown", function(self, key)
		local esc = key == "ESCAPE"
		-- frame.eluiKey(frame, key) -> true keeps a key for the window (Ctrl+F); every other key reaches the game
		local taken = not esc and self.eluiKey and self.eluiKey(self, key) and true or false
		if not InCombatLockdown() then self:SetPropagateKeyboardInput(not esc and not taken) end
		if not esc then return end
		if self.eluiEscape and self.eluiEscape(self) then return end -- a search clears first
		self:Hide()
	end)
end

------------------------------------------------------------------------
-- Stack: vertical layout container used by every page
------------------------------------------------------------------------
local Stack = {}
Stack.__index = Stack

function W.Stack(parent, width)
	local s = setmetatable({}, Stack)
	s.parent = parent
	s.width = width
	s.y = 0
	s.widgets = {}
	return s
end

function Stack:Add(frame, height, gap, indent)
	frame:SetParent(self.parent)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", self.parent, "TOPLEFT", indent or 0, -self.y)
	frame:SetWidth(self.width - (indent or 0))
	frame:SetHeight(height)
	-- where it sits, so the settings search can borrow it and put it back
	frame.searchSlot = { stack = self, y = self.y, indent = indent or 0, height = height }
	self.y = self.y + height + (gap or T.rowGap)
	if frame.Refresh then self.widgets[#self.widgets + 1] = frame end
	self.parent:SetHeight(self.y + T.pad)
	if self.onIndex and frame.searchInfo then self.onIndex(self, frame) end
	return frame
end

function Stack:Space(px)
	self.y = self.y + (px or T.pad)
	self.parent:SetHeight(self.y + T.pad)
end

function Stack:RefreshAll()
	for _, w in ipairs(self.widgets) do w:Refresh() end
	if self.onRefreshAll then self.onRefreshAll(self) end -- search results from other pages follow too
end

-- What the settings search knows about a widget: its label, description and opt.keywords
-- ({ "opacity", "alpha" }, English is fine). opt.search = false keeps it out.
local function SearchInfo(opt, extra)
	if not opt.label or opt.search == false then return nil end
	local info = { label = opt.label, desc = opt.desc, keywords = opt.keywords }
	if extra then for k, v in pairs(extra) do info[k] = v end end
	return info
end

------------------------------------------------------------------------
-- Static text
------------------------------------------------------------------------
-- Headings are found by the settings search too (by their text, sub line and `keywords`), so a section that holds
-- buttons and lists rather than switches (spell indicators, sharing, profiles) can still be found.
function W.Header(stack, text, sub, keywords)
	local f = CreateFrame("Frame")
	f.searchInfo = SearchInfo({ label = text, desc = sub, keywords = keywords })
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
		s:SetPoint("RIGHT")
		s:SetText(sub)
		h = 44
	end
	stack:Space(stack.y > 0 and 8 or 0)
	stack.searchHeader = text -- search results show "Page » Heading" for the rows under it
	return stack:Add(f, h, 12)
end

function W.Note(stack, text, color)
	local f = CreateFrame("Frame")
	local fs = Text(f, T.fontSmall + 1, color or T.muted)
	fs:SetPoint("TOPLEFT")
	fs:SetWidth(stack.width)
	fs:SetText(text)
	local h = math.max(14, fs:GetStringHeight() + 2)
	f.text = fs
	return stack:Add(f, h)
end

------------------------------------------------------------------------
-- Button
------------------------------------------------------------------------
function W.Button(parent, label, onClick, width, style)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 120, 26)
	local accent = style == "accent"
	local danger = style == "danger"
	b.bg = U.Solid(b, "BACKGROUND", rgba(accent and T.accent or T.surface))
	b.bg:SetAllPoints()
	if accent then b.bg:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 0.85) end
	b.border = U.Border(b, 1, rgba(danger and T.danger or T.border))
	b.label = Text(b, T.font, accent and { 0.05, 0.07, 0.1, 1 } or (danger and T.danger or T.text))
	b.label:SetPoint("CENTER")
	b.label:SetJustifyH("CENTER")
	b.label:SetText(label)
	b:SetScript("OnEnter", function(self)
		if accent then self.bg:SetVertexColor(rgba(T.accent)) else self.bg:SetVertexColor(rgba(T.surfaceHi)) end
	end)
	b:SetScript("OnLeave", function(self)
		if accent then self.bg:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 0.85) else self.bg:SetVertexColor(rgba(T.surface)) end
	end)
	b:SetScript("OnClick", function(self, ...) if onClick then onClick(self, ...) end end)
	function b:SetText(t) self.label:SetText(t) end
	return b
end

-- A button for something that can't be undone: the first click asks, a second click within 4 seconds does it.
function W.ConfirmButton(parent, label, onConfirm, width, style)
	local b
	local armed = false
	b = W.Button(parent, label, function(self, ...)
		if not armed then
			armed = true
			self:SetText("Click again to confirm")
			C_Timer.After(4, function()
				if armed then armed = false; b:SetText(label) end
			end)
			return
		end
		armed = false
		self:SetText(label)
		onConfirm(self, ...)
	end, width, style or "danger")
	b:HookScript("OnHide", function() if armed then armed = false; b:SetText(label) end end)
	return b
end

------------------------------------------------------------------------
-- Toggle (switch)
------------------------------------------------------------------------
function W.Toggle(stack, opt)
	local f = CreateFrame("Button")
	local track = CreateFrame("Frame", nil, f)
	track:SetSize(34, 18)
	track:SetPoint("LEFT")
	track.bg = U.Solid(track, "BACKGROUND", rgba(T.surface))
	track.bg:SetAllPoints()
	track.border = U.Border(track, 1, rgba(T.border))
	local knob = U.Solid(track, "ARTWORK", rgba(T.muted))
	knob:SetSize(12, 12)

	local label = Text(f, T.font, T.text)
	label:SetPoint("LEFT", track, "RIGHT", 10, 0)
	label:SetPoint("RIGHT")
	label:SetText(opt.label)

	function f:Refresh()
		local on = opt.get() and true or false
		knob:ClearAllPoints()
		if on then
			knob:SetPoint("RIGHT", track, "RIGHT", -3, 0)
			knob:SetVertexColor(0.05, 0.07, 0.1, 1)
			track.bg:SetVertexColor(rgba(T.accent))
			track.border:SetColor(rgba(T.accent))
		else
			knob:SetPoint("LEFT", track, "LEFT", 3, 0)
			knob:SetVertexColor(rgba(T.muted))
			track.bg:SetVertexColor(rgba(T.surface))
			track.border:SetColor(rgba(T.border))
		end
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
	f.searchInfo = SearchInfo(opt)
	f.setting = { type = "bool", opt = opt } -- AI help reads the controls that have a key (Options/AIHelp.lua)
	stack:Add(f, 20)
	f:Refresh()
	return f
end

------------------------------------------------------------------------
-- Slider with editable value
------------------------------------------------------------------------
function W.Slider(stack, opt)
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
	local boxBg = U.Solid(box, "BACKGROUND", rgba(T.surface))
	boxBg:SetAllPoints()
	U.Border(box, 1, rgba(T.border))

	local fmt = opt.fmt or (opt.step and opt.step < 1 and "%.2f" or "%d")
	local updating = false

	local function updateFill(v)
		local w = slider:GetWidth()
		if w and w > 0 then
			fill:SetWidth(math.max(1, w * (v - opt.min) / (opt.max - opt.min)))
		end
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
	end)
	slider:SetScript("OnSizeChanged", function() updateFill(slider:GetValue()) end)
	-- No mouse wheel on sliders: the wheel scrolls the page, so scrolling past a slider never changes it.
	box:SetScript("OnEnterPressed", function(self)
		local v = tonumber(self:GetText())
		if v then
			v = math.min(opt.max, math.max(opt.min, v))
			slider:SetValue(v)
			opt.set(v)
		end
		self:ClearFocus()
		f:Refresh()
	end)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Refresh() end)
	Tooltip(f, opt.label, opt.desc)
	f.searchInfo = SearchInfo(opt)
	f.setting = { type = "number", opt = opt }
	stack:Add(f, 40)
	f:Refresh()
	return f
end

------------------------------------------------------------------------
-- Dropdown (shared popup list)
------------------------------------------------------------------------
local popup, catcher

local function ClosePopup()
	if popup then popup:Hide() end
	if catcher then catcher:Hide() end
end
W.ClosePopup = ClosePopup

-- items = { { value, text, icon?, title? }, ... }. A title row can't be clicked.
-- opts.width overrides the owner's width; opts.atCursor opens it at the mouse.
local function OpenPopup(owner, items, current, onPick, opts)
	opts = opts or {}
	if not popup then
		catcher = CreateFrame("Button", nil, UIParent)
		catcher:SetAllPoints(UIParent)
		catcher:SetFrameStrata("FULLSCREEN_DIALOG")
		catcher:SetScript("OnClick", ClosePopup)
		popup = CreateFrame("Frame", nil, UIParent)
		popup:SetFrameStrata("FULLSCREEN_DIALOG")
		popup:SetFrameLevel(catcher:GetFrameLevel() + 10)
		popup:SetClampedToScreen(true)
		local bg = U.Solid(popup, "BACKGROUND", rgba(T.surface))
		bg:SetAllPoints()
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
			b.text:SetPoint("RIGHT", -10, 0)
			b.text:SetWordWrap(false)
			b:SetScript("OnEnter", function(self) if not self.isTitle then self.hl:Show() end end)
			b:SetScript("OnLeave", function(self) if not self.selected then self.hl:Hide() end end)
			popup.buttons[i] = b
		end
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
W.OpenPopup = OpenPopup

function W.Dropdown(stack, opt)
	local f = CreateFrame("Frame")
	local label = Text(f, T.font, T.text)
	label:SetPoint("TOPLEFT")
	label:SetText(opt.label)
	local b = CreateFrame("Button", nil, f)
	b:SetHeight(24)
	b:SetPoint("TOPLEFT", 0, -18)
	b:SetWidth(opt.width or 240)
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

	local function items()
		if type(opt.items) == "function" then return opt.items() or {} end return opt.items or {}
	end

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
	f.searchInfo = SearchInfo(opt, {
		value = function() return value:GetText() end,
		choices = function()
			local t = {}
			for _, it in ipairs(items()) do if not it.title and it.text then t[#t + 1] = tostring(it.text) end end
			return table.concat(t, " ")
		end,
	})
	f.setting = { type = "choice", opt = opt }
	stack:Add(f, 44)
	f:Refresh()
	return f
end

------------------------------------------------------------------------
-- Color swatch
------------------------------------------------------------------------
function W.Color(stack, opt)
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
		end
		local info = {
			r = start[1], g = start[2], b = start[3],
			opacity = start[4],
			hasOpacity = opt.hasAlpha and true or false,
			swatchFunc = function()
				local r, g, b = ColorPickerFrame:GetColorRGB()
				local a = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or start[4]
				apply(r, g, b, a)
			end,
			opacityFunc = function()
				local r, g, b = ColorPickerFrame:GetColorRGB()
				local a = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or start[4]
				apply(r, g, b, a)
			end,
			cancelFunc = function() apply(start[1], start[2], start[3], start[4]) end,
		}
		if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
			ColorPickerFrame:SetupColorPickerAndShow(info)
		end
	end)
	Tooltip(f, opt.label, opt.desc)
	f.searchInfo = SearchInfo(opt)
	f.setting = { type = "color", opt = opt }
	stack:Add(f, 20)
	f:Refresh()
	return f
end

------------------------------------------------------------------------
-- Single-line text input
------------------------------------------------------------------------
function W.EditBox(parent, width, height)
	local box = CreateFrame("EditBox", nil, parent)
	box:SetSize(width or 200, height or 24)
	box:SetAutoFocus(false)
	box:SetTextInsets(8, 8, 0, 0)
	U.SetFont(box, T.font)
	box:SetTextColor(rgba(T.text))
	local bg = U.Solid(box, "BACKGROUND", rgba(T.surface))
	bg:SetAllPoints()
	box.border = U.Border(box, 1, rgba(T.border))
	box:SetScript("OnEditFocusGained", function(self) self.border:SetColor(rgba(T.accent)) end)
	box:SetScript("OnEditFocusLost", function(self) self.border:SetColor(rgba(T.border)) end)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	return box
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

-- A scroll bar for `scroll` (a ScrollFrame showing `child`), parented to `holder`; the caller anchors it
-- (track = the returned frame). Drag the thumb with the left mouse button, or click the track above or
-- below it to jump a page. Offsets are whole pixels, so text never lands between pixels and blurs.
-- The wheel scrolls by `step`. With `onlyWhile` given, the wheel scrolls this area only while
-- onlyWhile() is true (a text area you are typing in) and otherwise scrolls the page around it,
-- as it also does once this area is at its end.
local function AttachScrollBar(scroll, child, holder, step, onlyWhile)
	local track = CreateFrame("Frame", nil, holder)
	track:SetWidth(BAR_W)
	local trackBg = U.Solid(track, "BACKGROUND", T.muted[1], T.muted[2], T.muted[3], 0.12)
	trackBg:SetAllPoints()
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

	local function hover(on)
		thumbTex:SetVertexColor(T.muted[1], T.muted[2], T.muted[3], on and 0.85 or 0.55)
	end
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

------------------------------------------------------------------------
-- Multi-line text area (import/export)
------------------------------------------------------------------------
-- Inside a settings page the wheel scrolls the page; it scrolls the text only while you type in it.
function W.TextArea(parent, width, height)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(width, height)
	local bg = U.Solid(holder, "BACKGROUND", rgba(T.surface))
	bg:SetAllPoints()
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
	-- keep the line you are typing on in view (the box grows a moment after the cursor moves)
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

------------------------------------------------------------------------
-- Scrollable page body
------------------------------------------------------------------------
-- The bar takes the right edge of `parent`: build the page about 24 px narrower than it.
function W.ScrollPage(parent)
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
	-- the bar sits outside the scroll area (beside it), so it follows the page's visibility by hand
	scroll:SetScript("OnShow", update)
	scroll:SetScript("OnHide", function() track:Hide() end)
	child:SetScript("OnSizeChanged", update)
	scroll.child = child
	scroll.track = track
	scroll.UpdateBar = update
	scroll.SetScroll = setScroll
	return scroll
end
