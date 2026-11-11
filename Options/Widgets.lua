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
	self.y = self.y + height + (gap or T.rowGap)
	if frame.Refresh then self.widgets[#self.widgets + 1] = frame end
	self.parent:SetHeight(self.y + T.pad)
	return frame
end

function Stack:Space(px)
	self.y = self.y + (px or T.pad)
	self.parent:SetHeight(self.y + T.pad)
end

function Stack:RefreshAll()
	for _, w in ipairs(self.widgets) do w:Refresh() end
end

------------------------------------------------------------------------
-- Static text
------------------------------------------------------------------------
function W.Header(stack, text, sub)
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
		s:SetPoint("RIGHT")
		s:SetText(sub)
		h = 44
	end
	stack:Space(stack.y > 0 and 8 or 0)
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
		f:Refresh()
		if opt.after then opt.after() end
	end)
	Tooltip(f, opt.label, opt.desc)
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
	slider:EnableMouseWheel(true)
	slider:SetScript("OnMouseWheel", function(self, delta)
		self:SetValue(math.min(opt.max, math.max(opt.min, self:GetValue() + delta * (opt.step or 1))))
	end)
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

local function OpenPopup(owner, items, current, onPick)
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
	local width = owner:GetWidth()
	for i, item in ipairs(items) do
		local b = popup.buttons[i]
		if not b then
			b = CreateFrame("Button", nil, popup)
			b:SetHeight(22)
			b.hl = U.Solid(b, "BACKGROUND", rgba(T.accentDim))
			b.hl:SetAllPoints()
			b.hl:Hide()
			b.text = Text(b, T.font, T.text)
			b.text:SetPoint("LEFT", 10, 0)
			b.text:SetPoint("RIGHT", -10, 0)
			b.text:SetWordWrap(false)
			b:SetScript("OnEnter", function(self) self.hl:Show() end)
			b:SetScript("OnLeave", function(self) if not self.selected then self.hl:Hide() end end)
			popup.buttons[i] = b
		end
		b:SetPoint("TOPLEFT", 1, -1 - (i - 1) * 22)
		b:SetPoint("RIGHT", -1, 0)
		b.text:SetText(item.text)
		b.selected = item.value == current
		b.hl:SetShown(b.selected)
		b.text:SetTextColor(rgba(b.selected and T.accent or T.text))
		b:SetScript("OnClick", function() ClosePopup(); onPick(item.value) end)
		b:Show()
	end
	popup:SetSize(width, #items * 22 + 2)
	popup:ClearAllPoints()
	popup:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
	catcher:Show()
	popup:Show()
end

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
		return type(opt.items) == "function" and opt.items() or opt.items
	end

	function f:Refresh()
		local cur = opt.get()
		local shown = cur == nil and (opt.placeholder or "Choose...") or tostring(cur)
		for _, it in ipairs(items()) do
			if it.value == cur then shown = it.text break end
		end
		value:SetText(shown)
	end
	b:SetScript("OnClick", function()
		OpenPopup(b, items(), opt.get(), function(v)
			opt.set(v)
			f:Refresh()
			if opt.after then opt.after() end
		end)
	end)
	Tooltip(b, opt.label, opt.desc)
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
-- Multi-line text area (import/export)
------------------------------------------------------------------------
function W.TextArea(parent, width, height)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(width, height)
	local bg = U.Solid(holder, "BACKGROUND", rgba(T.surface))
	bg:SetAllPoints()
	U.Border(holder, 1, rgba(T.border))
	local scroll = CreateFrame("ScrollFrame", nil, holder)
	scroll:SetPoint("TOPLEFT", 8, -8)
	scroll:SetPoint("BOTTOMRIGHT", -8, 8)
	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetWidth(width - 16)
	U.SetFont(box, T.fontSmall + 1)
	box:SetTextColor(rgba(T.text))
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	scroll:SetScrollChild(box)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local maxScroll = math.max(0, box:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 30)))
	end)
	holder:EnableMouse(true)
	holder:SetScript("OnMouseDown", function() box:SetFocus() end)
	holder.box = box
	return holder
end

------------------------------------------------------------------------
-- Scrollable page body
------------------------------------------------------------------------
function W.ScrollPage(parent)
	local scroll = CreateFrame("ScrollFrame", nil, parent)
	scroll:SetAllPoints()
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)

	local bar = U.Solid(scroll, "OVERLAY", T.muted[1], T.muted[2], T.muted[3], 0.5)
	bar:SetWidth(3)
	bar:Hide()

	local function update()
		local viewH = scroll:GetHeight()
		local contentH = child:GetHeight()
		local maxScroll = math.max(0, contentH - viewH)
		if scroll:GetVerticalScroll() > maxScroll then scroll:SetVerticalScroll(maxScroll) end
		if maxScroll <= 0 then bar:Hide() return end
		local h = math.max(24, viewH * viewH / contentH)
		local y = (viewH - h) * scroll:GetVerticalScroll() / maxScroll
		bar:SetHeight(h)
		bar:ClearAllPoints()
		bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -2, -y)
		bar:Show()
	end

	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local maxScroll = math.max(0, child:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 40)))
		update()
	end)
	scroll:SetScript("OnSizeChanged", function(self, w)
		child:SetWidth(w)
		update()
	end)
	child:SetScript("OnSizeChanged", update)
	scroll.child = child
	scroll.UpdateBar = update
	return scroll
end
