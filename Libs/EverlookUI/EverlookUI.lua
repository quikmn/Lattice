-- EverlookUI: the settings window look shared by quikmn's addons.
--
-- Single source of truth: D:\Dev\EverlookUI\EverlookUI.lua (+ Media\). Each addon carries a copy in
-- Libs\EverlookUI\ (sync.py writes it; release-addon.py and install-addons.ps1 keep it current).
-- Versioned with LibStub: when several addons carry it, the newest copy is the one every addon uses.
-- Bump MINOR whenever this file changes.
--
--   local UI = LibStub("EverlookUI-1")
--   local app = UI:NewApp({ name = "Whack", addon = ADDON, slash = "/whack", tagline = "...", accent = {r, g, b} })
--   app:Setting({ key = "fontsize", type = "number", label = "Font size", min = 8, max = 48, get = ..., set = ... })
--   app:Command("test", "test", "show fake numbers", function(rest) ... end)
--   app:Section("general", "General", function(stack, app) app:Widget(stack, "fontsize") end, { icon = "gear", desc = "..." })
--   app:Movable({ what = "the text areas", get = ..., set = ... })   -- /whack lock, unlock
--   app:Reset("outgoing", "the outgoing area", function() ... end)   -- /whack reset outgoing (asks first)
--   app:StatusLines(function() return "seen 12 hits" end)            -- /whack status
--   app:RegisterSlash("WHACK")   -- or SlashCmdList.WHACK = function(msg) app:HandleSlash(msg) end
-- Chat commands follow one pattern in every addon: see "Chat commands" below and COMMANDS.md.
--
-- The window (EverlookUI 7): a left sidebar (the addon's icon and name, the search box, one row with an icon per
-- page, tool links such as "Report a bug", and "v1.2.3 · /cmd"), a page header (title, one-line description and an
-- optional live preview, app:Preview), the page as cards of rows under small gold headings (label and description
-- left, control right), and a footer bar (an optional profile picker, app:Profiles, and Undo for this session's
-- changes). One-page addons get the same look without the sidebar. The window moves, resizes and remembers both.
--
-- Widgets: Header, Note, Toggle, Slider, Dropdown, Color, Input, CopyBox, Stat, List, Button, ConfirmButton,
-- ButtonRow, TextArea, ScrollPage. Bound widgets take { label, desc, get, set, disabled, after } and have :Refresh().
-- The mouse wheel scrolls the page: sliders and dropdowns never take it. The page scroll bar is 12 px and draggable.
--
-- Search: every window has a search box (Ctrl+F; Escape clears it, then closes the window).
-- It finds settings (app:Widget), plain toggles, sliders, dropdowns, colour swatches and button rows on any
-- page, by label, description, page and heading, a dropdown's value and choices, the chat-command name and
-- optional keywords: app:Setting({ ..., keywords = { "opacity", "alpha" } }) or a widget's/button's opt.keywords.
-- opt.search = false keeps a widget out. Results are the real controls, borrowed from their page while listed.
--
-- AI help (EverlookUI 5): an "AI help" link in the window and "/x ai" copy a description of every setting
-- for an AI assistant; "/x apply" takes its answer back (see "AI help" below and COMMANDS.md).
local LIB_ADDON = ... -- the folder of the addon whose copy this is (its Media\ sits next to this file)
local MAJOR, MINOR = "EverlookUI-1", 8
local UI = LibStub:NewLibrary(MAJOR, MINOR)
if not UI then return end
UI.version = MINOR
UI.media = type(LIB_ADDON) == "string" and ("Interface\\AddOns\\" .. LIB_ADDON .. "\\Libs\\EverlookUI\\Media\\") or nil

------------------------------------------------------------------------
-- Theme: dark slate, one accent colour per addon, gold section headings.
------------------------------------------------------------------------
UI.Theme = {
	bg        = { 0.063, 0.069, 0.082, 0.98 }, -- window
	sidebar   = { 0.047, 0.052, 0.063, 1 },
	card      = { 0.090, 0.098, 0.118, 1 },   -- the rounded cards rows sit in
	surface   = { 0.133, 0.145, 0.173, 1 },   -- inputs, buttons, list rows
	surfaceHi = { 0.169, 0.182, 0.216, 1 },   -- hover
	border    = { 0.192, 0.208, 0.247, 1 },
	divider   = { 0.145, 0.157, 0.188, 1 },   -- between rows in a card
	text      = { 0.910, 0.918, 0.937, 1 },
	muted     = { 0.553, 0.580, 0.639, 1 },
	gold      = { 0.961, 0.776, 0.341, 1 },   -- section headings
	accent    = { 0.353, 0.663, 1.000, 1 },   -- #5aa9ff (Lattice blue)
	accentDim = { 0.353, 0.663, 1.000, 0.16 },
	accentFill = { 0.288, 0.508, 0.752, 1 },   -- the accent for filled areas (switches, buttons, slider fill): softer
	danger    = { 0.937, 0.365, 0.365, 1 },
	ok        = { 0.384, 0.812, 0.533, 1 },
	onAccent  = { 0.05, 0.07, 0.1, 1 },        -- text and knobs drawn on the accent colour

	fontSmall = 10,
	font      = 12,
	fontTitle = 14,
	fontHuge  = 18,

	pad = 16,
	rowGap = 10,
	radius = 6,  -- cards; buttons and inputs use 4, the window 8
}

-- A theme with another accent colour ({ r, g, b }); everything else from UI.Theme.
function UI.MakeTheme(accent)
	local T = {}
	for k, v in pairs(UI.Theme) do T[k] = v end
	if type(accent) == "table" and accent[1] then
		T.accent = { accent[1], accent[2], accent[3], 1 }
		T.accentDim = { accent[1], accent[2], accent[3], 0.16 }
	end
	-- filled areas use the accent 30% of the way to the button colour, so a bright accent (EverlookDB gold) isn't
	-- glaring on switches and buttons; lines, text and icons keep the accent itself (EverlookUI 8)
	local a, sf = T.accent, T.surface
	T.accentFill = { a[1] * 0.7 + sf[1] * 0.3, a[2] * 0.7 + sf[2] * 0.3, a[3] * 0.7 + sf[3] * 0.3, 1 }
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

-- Rounded box from our own disc texture (Media\Round.tga): four quarter-disc corners and three bands. Anchor it
-- like a texture (SetPoint, SetAllPoints, SetSize); colour it with SetVertexColor. corners = { tl, tr, bl, br }
-- (false keeps that corner square; nil rounds all four). Without the media file the corners are square.
local Round = {}
Round.__index = Round
local ROUND_CORNERS = {
	tl = { "TOPLEFT", 0, 0.5, 0, 0.5 }, tr = { "TOPRIGHT", 0.5, 1, 0, 0.5 },
	bl = { "BOTTOMLEFT", 0, 0.5, 0.5, 1 }, br = { "BOTTOMRIGHT", 0.5, 1, 0.5, 1 },
}
function U.Round(parent, radius, layer, sublevel, corners)
	local o = setmetatable({ parts = {}, r = radius or 6, shown = true }, Round)
	layer, sublevel = layer or "BACKGROUND", sublevel or 0
	local box = parent:CreateTexture(nil, layer, nil, sublevel) -- the anchor the parts hang from; never drawn
	box:SetTexture(U.WHITE)
	box:SetAlpha(0)
	o.box = box
	local r = o.r
	local function part(tex)
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(tex or U.WHITE)
		o.parts[#o.parts + 1] = t
		return t
	end
	local mid = part()
	mid:SetPoint("TOPLEFT", box, "TOPLEFT", r, 0)
	mid:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -r, 0)
	local left = part()
	left:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -r)
	left:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, r)
	left:SetWidth(r)
	local right = part()
	right:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, -r)
	right:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, r)
	right:SetWidth(r)
	local disc = UI.media and (UI.media .. "Round") or nil
	for _, key in ipairs({ "tl", "tr", "bl", "br" }) do
		local c = ROUND_CORNERS[key]
		local rounded = disc and (not corners or corners[key])
		local t = part(rounded and disc or U.WHITE)
		t:SetSize(r, r)
		t:SetPoint(c[1], box, c[1], 0, 0)
		if rounded then t:SetTexCoord(c[2], c[3], c[4], c[5]) end
	end
	return o
end
function Round:SetPoint(...) self.box:SetPoint(...) end
function Round:SetAllPoints(...) self.box:SetAllPoints(...) end
function Round:ClearAllPoints() self.box:ClearAllPoints() end
function Round:SetSize(w, h) self.box:SetSize(w, h) end
function Round:SetWidth(w) self.box:SetWidth(w) end
function Round:SetHeight(h) self.box:SetHeight(h) end
function Round:GetWidth() return self.box:GetWidth() end
function Round:GetHeight() return self.box:GetHeight() end
function Round:SetVertexColor(r, g, b, a)
	self.color = { r, g, b, a or 1 }
	for _, t in ipairs(self.parts) do t:SetVertexColor(r, g, b, a or 1) end
end
Round.SetColor = Round.SetVertexColor
function Round:SetAlpha(a) for _, t in ipairs(self.parts) do t:SetAlpha(a) end end
function Round:SetShown(on)
	self.shown = on and true or false
	for _, t in ipairs(self.parts) do t:SetShown(self.shown) end
end
function Round:Show() self:SetShown(true) end
function Round:Hide() self:SetShown(false) end
function Round:IsShown() return self.shown end
UI.Round = Round

-- A rounded box filled with `fill` inside a 1 px `border` of the same shape (a second box 1 px larger behind it),
-- covering `holder`. Returns fill, edge (both Round objects).
function U.RoundBox(holder, radius, fill, border, layer, sublevel)
	sublevel = sublevel or 0
	local edge = U.Round(holder, radius, layer, sublevel)
	edge:SetAllPoints(holder)
	edge:SetVertexColor(rgba(border))
	local inner = U.Round(holder, math.max(1, radius - 1), layer, sublevel + 1)
	inner:SetPoint("TOPLEFT", holder, "TOPLEFT", 1, -1)
	inner:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -1, 1)
	inner:SetVertexColor(rgba(fill))
	return inner, edge
end

-- Line icons (Media\Icons.tga, our own, drawn by tools/make_media.py): 8 x 8 cells, in this order.
-- UI.SetIcon(texture, icon): icon is one of these names, or any texture path or file ID (a game icon).
local ICON_NAMES = {
	"gear", "eye", "text", "palette", "speaker", "bell", "tooltip", "bars",
	"coins", "user", "info", "sliders", "wrench", "database", "chat", "keyboard",
	"paw", "note", "funnel", "puzzle", "sword", "map", "search", "scroll",
	"bug", "shield", "grid", "share", "clock", "star", "home", "undo",
	"page", "book", "bag", "hammer", "flask", "sparkle", "link", "heart",
	"flag", "lock", "mouse", "layers", "target", "list", "check", "close",
	"chevron", "external", "plus", "minus", "refresh", "download", "ai", "dot",
	"frames", "cursor", "music", "globe", "trash",
}
local ICON_INDEX = {}
for i, n in ipairs(ICON_NAMES) do ICON_INDEX[n] = i end
UI.IconNames = ICON_NAMES

function UI.IsIconName(icon) return type(icon) == "string" and ICON_INDEX[icon] ~= nil end

-- Show `icon` on `tex`; false when there is nothing to show (the texture is hidden).
function UI.SetIcon(tex, icon)
	local i = type(icon) == "string" and ICON_INDEX[icon]
	if i then
		if not UI.media then tex:Hide() return false end
		local col, row = (i - 1) % 8, math.floor((i - 1) / 8)
		tex:SetTexture(UI.media .. "Icons")
		tex:SetTexCoord(col / 8, (col + 1) / 8, row / 8, (row + 1) / 8)
		tex:Show()
		return true
	end
	if icon == nil or icon == "" then tex:Hide() return false end
	tex:SetTexture(icon)
	-- game icons carry a dark rim: trim it
	if type(icon) == "number" or tostring(icon):lower():find("interface[/\\]icons[/\\]") then tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	else tex:SetTexCoord(0, 1, 0, 1) end
	tex:Show()
	return true
end

-- An icon for a page by its title, for addons that don't name one: the first word that has an icon wins.
UI.PageIcons = {
	general = "gear", options = "sliders", settings = "sliders", setting = "sliders", config = "sliders", advanced = "sliders",
	display = "eye", appearance = "eye", look = "eye", style = "eye", visibility = "eye", show = "eye",
	layout = "grid", frames = "frames", unit = "frames", window = "frames",
	text = "text", font = "text", fonts = "text", numbers = "text", outgoing = "text", incoming = "text",
	colors = "palette", colours = "palette", color = "palette", colour = "palette", theme = "palette",
	sound = "speaker", sounds = "speaker", audio = "speaker", music = "music",
	alerts = "bell", alert = "bell", notifications = "bell", notification = "bell", warnings = "bell", reminders = "bell",
	tooltip = "tooltip", tooltips = "tooltip",
	bars = "bars", bar = "bars", stats = "bars", statistics = "bars", overview = "bars", progress = "bars", status = "bars",
	auctions = "coins", auction = "coins", selling = "coins", buying = "coins", prices = "coins", price = "coins", gold = "coins", value = "coins",
	profiles = "user", profile = "user", character = "user", account = "user", mine = "user",
	about = "info", help = "info", info = "info", privacy = "shield", records = "database", data = "database", database = "database",
	tools = "wrench", built = "puzzle", modules = "puzzle", plugins = "puzzle", plugin = "puzzle", addons = "puzzle", extended = "layers",
	chat = "chat", messages = "chat", channels = "chat",
	macros = "keyboard", keybinds = "keyboard", bindings = "keyboard", keys = "keyboard", ring = "target", edit = "note",
	templates = "layers", backups = "download", backup = "download", import = "download", export = "share", share = "share",
	pets = "paw", pet = "paw", beast = "paw", beasts = "paw", bestiary = "book", hunter = "paw",
	notes = "note", note = "note", recent = "clock", history = "clock", log = "clock", timers = "clock", cooldowns = "clock",
	filters = "funnel", filter = "funnel", search = "search", scan = "search", scanning = "search",
	combat = "sword", auras = "sparkle", buffs = "sparkle", debuffs = "sparkle", spells = "sparkle",
	minimap = "map", map = "map", maps = "map", zones = "map", location = "map", quests = "scroll", quest = "scroll",
	professions = "hammer", crafting = "hammer", recipes = "hammer", bags = "bag", inventory = "bag", items = "bag", loot = "bag",
	debug = "bug", build = "wrench", developer = "wrench", links = "link", click = "mouse", mouse = "mouse", hover = "cursor",
	casting = "mouse", targets = "target", target = "target", favourites = "star", favorites = "star",
}
function UI.PageIcon(title)
	for word in tostring(title or ""):lower():gmatch("[%a]+") do
		local icon = UI.PageIcons[word]
		if icon then return icon end
	end
	return "page"
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

-- The window look: a rounded slate box with a 1 px rim and a thin accent line along the top.
local function WindowChrome(f, T)
	f.bgFill, f.bgEdge = U.RoundBox(f, 8, T.bg, T.border)
	local line = U.Solid(f, "ARTWORK", rgba(T.accent))
	line:SetHeight(2)
	line:SetPoint("TOPLEFT", 8, -1)
	line:SetPoint("TOPRIGHT", -8, -1)
	f.accentLine = line
end
UI.WindowChrome = WindowChrome

-- The close button in a window's top right corner (an X icon, lit on hover).
local function CloseButton(f, T)
	local close = CreateFrame("Button", nil, f)
	close:SetSize(24, 24)
	close:SetPoint("TOPRIGHT", -10, -10)
	local hl = U.Round(close, 4, "BACKGROUND")
	hl:SetAllPoints(close)
	hl:SetVertexColor(rgba(T.surfaceHi))
	hl:Hide()
	local icon = close:CreateTexture(nil, "ARTWORK")
	icon:SetSize(10, 10)
	icon:SetPoint("CENTER")
	local x
	if UI.SetIcon(icon, "close") then
		icon:SetVertexColor(rgba(T.muted))
	else
		x = Text(close, T.fontTitle, T.muted)
		x:SetPoint("CENTER")
		x:SetText("x")
	end
	close:SetScript("OnEnter", function()
		hl:Show()
		if x then x:SetTextColor(rgba(T.text)) else icon:SetVertexColor(rgba(T.text)) end
	end)
	close:SetScript("OnLeave", function()
		hl:Hide()
		if x then x:SetTextColor(rgba(T.muted)) else icon:SetVertexColor(rgba(T.muted)) end
	end)
	close:SetScript("OnClick", function() f:Hide() end)
	return close
end
UI.CloseButton = CloseButton

-- Escape closes `frame` through its own key handler. Not UISpecialFrames: Blizzard walks that list when
-- Escape closes its own windows, and an entry written by an addon taints the walk (secret-value errors
-- in Blizzard's OnHide). Other keys pass through to the game. SetPropagateKeyboardInput is blocked in
-- combat, and an addon can't keep Escape from the game in combat: a window then takes no keys at all, so
-- Escape opens only the Game Menu instead of closing the window too. When combat starts with one of these
-- windows open it lets go of the keyboard (EnableKeyboard is allowed in combat; PLAYER_REGEN_DISABLED comes
-- just before the lockdown) and takes it back when combat ends.
-- Call after the frame's own OnShow script is set (this hooks it).
local escFrames = setmetatable({}, { __mode = "k" })
local combatWatch
local function WatchCombat()
	if combatWatch then return end
	combatWatch = CreateFrame("Frame")
	combatWatch:RegisterEvent("PLAYER_REGEN_DISABLED")
	combatWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
	combatWatch:SetScript("OnEvent", function(_, event)
		local entering = event == "PLAYER_REGEN_DISABLED"
		for f in pairs(escFrames) do
			if f:IsShown() then
				if entering then
					f:EnableKeyboard(false)
				else
					f:SetPropagateKeyboardInput(true)
					f:EnableKeyboard(true)
				end
			end
		end
	end)
end
UI.WatchCombatKeys = WatchCombat

function UI.CloseOnEscape(frame)
	escFrames[frame] = true
	WatchCombat()
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
-- A card stack (the app's pages: UI.Stack(parent, width, T, { cards = true })) puts what comes between two headings
-- in one rounded card: setting rows (label left, control right) with a thin line between them, and anything else
-- (notes, lists, button rows, an addon's own frames) with some room around it. stack.width is then the width
-- inside a card, the width every piece should use; stack.outer is the card's.
------------------------------------------------------------------------
local Stack = {}
Stack.__index = Stack
local CARD_PAD = 12 -- inside a card, left and right
local CARD_GAP = 14 -- after a card
UI.CARD_PAD = CARD_PAD

function UI.Stack(parent, width, T, opts)
	local cards = type(opts) == "table" and opts.cards and true or false
	local st = setmetatable({ parent = parent, width = width, outer = width, y = 0, widgets = {}, entries = {},
		T = T or ThemeOf(parent), isStack = true, cards = cards, flow = { cards = {}, divs = {} } }, Stack)
	if cards then
		st.width = width - 2 * CARD_PAD
		st.cardPool, st.divPool = {}, {}
	end
	return st
end

-- Put entry `e` at x, the current y (a control listed in search results right now keeps its room but stays put).
function Stack:PlaceAt(e, x)
	e.y, e.x = self.y, x
	if e.borrowed then return end
	local f = e.frame
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", self.parent, "TOPLEFT", x, -self.y)
	f:SetWidth(e.kind == "heading" and (self.outer - x) or (self.width - e.indent))
	f:SetHeight(e.height)
end

-- Lay out one more entry.
function Stack:Flow(e)
	local F = self.flow
	if e.space then self.y = self.y + e.space return end
	if not self.cards then
		self:PlaceAt(e, e.indent)
		self.y = self.y + e.height + e.gap
		return
	end
	if e.kind == "heading" then
		self:CloseCard()
		self:PlaceAt(e, 2)
		self.y = self.y + e.height + 6
		return
	end
	if e.height <= 0 then -- folded away (or a helper frame with no room): no card for it
		self:PlaceAt(e, CARD_PAD + e.indent)
		return
	end
	if not F.card then
		F.card = { top = self.y }
		F.cards[#F.cards + 1] = F.card
		F.prev, F.lastGap = nil, 0
		self.y = self.y + 4
	end
	if e.row then
		if F.prev == "row" then F.divs[#F.divs + 1] = self.y end
		self:PlaceAt(e, CARD_PAD + e.indent)
		self.y = self.y + e.height
		F.prev, F.lastGap = "row", 0
	else
		if F.prev == "row" then self.y = self.y + 8 elseif F.prev == nil then self.y = self.y + 6 end
		self:PlaceAt(e, CARD_PAD + e.indent)
		self.y = self.y + e.height + e.gap
		F.prev, F.lastGap = "block", e.gap
	end
	F.card.bottom = self.y - F.lastGap + (F.prev == "block" and 10 or 4)
end
Stack.Place = Stack.Flow -- the EverlookUI 6 name

function Stack:CloseCard()
	local F = self.flow
	if not F.card then return end
	self.y = F.card.bottom + CARD_GAP
	F.card, F.prev = nil, nil
end

-- Where the content ends (the open card's bottom, else y).
function Stack:Bottom()
	local c = self.flow.card
	return c and c.bottom or self.y
end

-- The card backgrounds and the lines between rows, from the last layout.
function Stack:DrawCards()
	if not self.cards then return end
	local F, T = self.flow, self.T
	for i, c in ipairs(F.cards) do
		local r = self.cardPool[i]
		if not r then
			r = U.Round(self.parent, T.radius, "BACKGROUND", -6)
			r:SetVertexColor(rgba(T.card))
			self.cardPool[i] = r
		end
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", self.parent, "TOPLEFT", 0, -c.top)
		r:SetSize(self.outer, math.max(2 * T.radius, (c.bottom or c.top) - c.top))
		r:Show()
	end
	for i = #F.cards + 1, #self.cardPool do self.cardPool[i]:Hide() end
	for i, y in ipairs(F.divs) do
		local t = self.divPool[i]
		if not t then
			t = U.Solid(self.parent, "BACKGROUND", T.divider[1], T.divider[2], T.divider[3], 1, -5)
			self.divPool[i] = t
		end
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", self.parent, "TOPLEFT", CARD_PAD, -y)
		t:SetSize(self.outer - 2 * CARD_PAD, 1)
		t:Show()
	end
	for i = #F.divs + 1, #self.divPool do self.divPool[i]:Hide() end
end

function Stack:Finish()
	self:DrawCards()
	self.parent:SetHeight(self:Bottom() + self.T.pad)
end

-- frame.eluiRow: a setting row (label left, control right); frame.eluiKind: "heading" or "pagehead".
function Stack:Add(frame, height, gap, indent)
	frame:SetParent(self.parent)
	local e = { frame = frame, height = height, gap = gap or self.T.rowGap, indent = indent or 0,
		row = rawget(frame, "eluiRow") and true or nil, kind = rawget(frame, "eluiKind") }
	self.entries[#self.entries + 1] = e
	frame.stackEntry = e
	self:Flow(e)
	self:Finish()
	if frame.Refresh then self.widgets[#self.widgets + 1] = frame end
	if self.app and frame.searchInfo then self.app:IndexWidget(self, frame) end
	return frame
end

function Stack:Space(px)
	px = px or self.T.pad
	local e = { space = px }
	self.entries[#self.entries + 1] = e
	self:Flow(e)
	self:Finish()
end

function Stack:Relayout()
	self.y = 0
	self.flow = { cards = {}, divs = {} }
	for _, e in ipairs(self.entries) do self:Flow(e) end
	self:Finish()
end

-- Give a row a new height and move the rows below it.
function Stack:SetHeightOf(frame, h)
	local e = frame.stackEntry
	if not e or e.height == h then return end
	e.height = h
	self:Relayout()
end

-- A new width (the window was resized): rows that wrap text measure again.
function Stack:SetWidth(width)
	if width == self.outer then return end
	self.outer = width
	self.width = self.cards and (width - 2 * CARD_PAD) or width
	for _, e in ipairs(self.entries) do
		local f = e.frame
		if f and e.height > 0 and rawget(f, "eluiMeasure") then
			e.height = f.eluiMeasure(f, (e.kind == "heading" and self.outer or self.width) - e.indent)
		end
	end
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

-- A control changed a value: the app remembers it for Undo (EverlookUI 7). id names the control.
local function Changed(stack, opt, before, id)
	local app = stack and stack.app
	if app and app.RecordChange then
		app:RecordChange({ id = id or opt, label = opt.label, get = opt.get, set = opt.set, after = opt.after, before = before })
	end
end
UI.Changed = Changed

------------------------------------------------------------------------
-- Setting rows: the label (and a muted line of description) on the left, the control on the right.
------------------------------------------------------------------------
local ROW_PAD = 9
local ROW_MIN = 36

-- The description shown under a label: all of a short one, else its first sentence (the tooltip has the rest).
local function ShortDesc(desc)
	if type(desc) ~= "string" or desc == "" then return nil, false end
	if #desc <= 120 then return desc, false end
	local first = desc:match("^(.-[%.!?])%s")
	if first and #first <= 160 then return first, true end
	return desc:sub(1, 117) .. "...", true
end
UI.ShortDesc = ShortDesc

-- Makes `f` a row: f.label (and f.desc) on the left of a control `controlW` wide anchored at RIGHT. Returns true when
-- the description was shortened (then the row keeps a tooltip with all of it).
local function RowLabel(f, T, opt, controlW)
	local label = Text(f, T.font, T.text)
	label:SetText(opt.label or "")
	local text, cut = ShortDesc(opt.desc)
	local desc
	if text then
		desc = Text(f, T.fontSmall + 1, T.muted)
		desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
		desc:SetText(text)
	end
	f.label, f.desc = label, desc
	f.eluiRow = true
	f.eluiControlW = controlW
	f.eluiMeasure = function(self, width)
		local w = math.max(80, width - (self.eluiControlW or 0) - 16)
		label:SetWidth(w)
		local th = math.ceil(label:GetStringHeight() or 12)
		if desc then
			desc:SetWidth(w)
			th = th + 3 + math.ceil(desc:GetStringHeight() or 10)
		end
		local h = math.max(ROW_MIN, th + 2 * ROW_PAD)
		label:ClearAllPoints()
		label:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -math.floor((h - th) / 2))
		return h
	end
	return cut
end

------------------------------------------------------------------------
-- Static text
------------------------------------------------------------------------
-- On a card page: a small gold heading that starts a new card. The page's first heading, when it is named like the
-- page ("Options" on the Options page), is the page title at the top of the window instead (its `sub` becomes the
-- page's description). Elsewhere: a title with a line under it.
function UI.Header(stack, text, sub)
	local T = stack.T
	local f = CreateFrame("Frame")
	local app = stack.app
	local sec = app and stack.section and app.sections[stack.section]
	stack.searchHeader = text -- search results show "Page » Heading" for the rows under it
	local own = stack.cards and sec and #stack.entries == 0 and app.window
		and (U.Trim(text):lower() == U.Trim(sec.title):lower() or (not app.window.navButtons and U.Trim(text):lower() == U.Trim(app.name):lower()))
	if own and not app.window.navButtons then
		-- a one-page window already shows the addon's name at the top: the heading goes, its line stays as a note
		f.eluiKind = "pagehead"
		f.title = Text(f, T.fontHuge, T.text)
		f.title:SetText(text)
		f.title:Hide()
		stack:Add(f, 0, 0)
		if sub then UI.Note(stack, sub) end
		return f
	end
	if own then
		f.eluiKind = "pagehead"
		f.title = Text(f, T.fontHuge, T.text)
		f.title:SetText(text)
		f.title:Hide()
		if sub and not sec.desc then sec.desc = sub end
		if app.current == sec.id and app.UpdatePageHeader then app:UpdatePageHeader() end
		return stack:Add(f, 0, 0)
	end
	if stack.cards then
		f.eluiKind = "heading"
		local title = Text(f, T.fontSmall + 1, T.gold)
		title:SetPoint("TOPLEFT")
		title:SetWordWrap(false)
		title:SetText(text)
		f.title = title
		local s
		if sub then
			s = Text(f, T.fontSmall + 1, T.muted)
			s:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
			s:SetText(sub)
			f.sub = s
		end
		f.eluiMeasure = function(_, width)
			title:SetWidth(width - 4)
			if not s then return 16 end
			s:SetWidth(width - 4)
			return 16 + 4 + math.max(10, math.ceil(s:GetStringHeight() or 10))
		end
		return stack:Add(f, f.eluiMeasure(f, stack.outer - 2), 6)
	end
	local title = Text(f, T.fontTitle, T.text)
	title:SetPoint("TOPLEFT")
	title:SetText(text)
	f.title = title
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
	f.eluiMeasure = function(_, width) fs:SetWidth(width) return math.max(14, fs:GetStringHeight() + 2) end
	if type(text) == "function" then
		function f:Refresh() stack:SetHeightOf(f, fill()) end
	end
	return stack:Add(f, h)
end

-- "Label      value" line; value is a function, read again on Refresh. On a card page it is a row with the
-- value on the right.
function UI.Stat(stack, label, value, labelWidth)
	local T = stack.T
	local f = CreateFrame("Frame")
	local l = Text(f, T.font, T.muted)
	l:SetPoint("LEFT")
	l:SetWidth(labelWidth or 190)
	l:SetWordWrap(false)
	l:SetText(label)
	f.label = l
	local v = Text(f, T.font, T.text)
	v:SetPoint("LEFT", labelWidth or 190, 0)
	v:SetPoint("RIGHT")
	v:SetWordWrap(false)
	f.value = v
	function f:Refresh() v:SetText(tostring(value() or "")) end
	if stack.cards then
		f.eluiRow = true
		v:SetJustifyH("RIGHT")
		stack:Add(f, 30, 0)
	else
		stack:Add(f, 16, 6)
	end
	f:Refresh()
	return f
end

------------------------------------------------------------------------
-- Buttons
------------------------------------------------------------------------
-- style: nil, "accent" (the screen's one primary button) or "danger".
function UI.Button(parent, label, onClick, width, style)
	local T = ThemeOf(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 120, 26)
	local accent, danger = style == "accent", style == "danger"
	local fill = T.accentFill or T.accent
	b.bg, b.border = U.RoundBox(b, 4, accent and fill or T.surface, (accent and fill) or (danger and T.danger) or T.border)
	b.label = Text(b, T.font, accent and T.onAccent or (danger and T.danger or T.text))
	b.label:SetPoint("CENTER")
	b.label:SetJustifyH("CENTER")
	b.label:SetWordWrap(false)
	b.label:SetText(label)
	b:SetScript("OnEnter", function(self)
		if accent then self.bg:SetVertexColor(rgba(T.accent)); self.border:SetColor(rgba(T.accent)) else self.bg:SetVertexColor(rgba(T.surfaceHi)) end
	end)
	b:SetScript("OnLeave", function(self)
		if accent then self.bg:SetVertexColor(rgba(fill)); self.border:SetColor(rgba(fill)) else self.bg:SetVertexColor(rgba(T.surface)) end
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
-- Switch (the toggle's pill and knob, also used in list rows)
------------------------------------------------------------------------
local function Switch(parent, T)
	local track = CreateFrame("Frame", nil, parent)
	track:SetSize(36, 20)
	track.bg = U.Round(track, 10, "BACKGROUND")
	track.bg:SetAllPoints(track)
	track.border = { SetColor = function() end, SetShown = function() end } -- (EverlookUI 6 had a square border)
	local knob = track:CreateTexture(nil, "ARTWORK")
	knob:SetTexture(UI.media and (UI.media .. "Round") or U.WHITE)
	knob:SetSize(14, 14)
	track.knob = knob
	function track:SetOn(on)
		self.on = on and true or false
		knob:ClearAllPoints()
		if on then
			knob:SetPoint("RIGHT", track, "RIGHT", -3, 0)
			-- a dark knob on the softened accent: a white one was lost on gold (EverlookUI 8)
			knob:SetVertexColor(rgba(T.onAccent))
			track.bg:SetVertexColor(rgba(T.accentFill or T.accent))
		else
			knob:SetPoint("LEFT", track, "LEFT", 3, 0)
			knob:SetVertexColor(rgba(T.muted))
			track.bg:SetVertexColor(rgba(T.surfaceHi))
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
	track:SetPoint("RIGHT", f, "RIGHT", 0, 0)
	f.switch = track
	local cut = RowLabel(f, T, opt, 36)
	function f:Refresh()
		track:SetOn(opt.get() and true or false)
		local enabled = not opt.disabled or not opt.disabled()
		f:SetAlpha(enabled and 1 or 0.4)
		f:EnableMouse(enabled)
	end
	f:SetScript("OnClick", function()
		local before = opt.get()
		opt.set(not before)
		Changed(stack, opt, before)
		stack:RefreshAll() -- settings that depend on this one grey out or come back at once
		if opt.after then opt.after() end
	end)
	if cut then Tooltip(f, opt.label, opt.desc) end
	f.searchInfo = opt.label and SearchInfo(opt)
	stack:Add(f, f.eluiMeasure(f, stack.width), 0)
	f:Refresh()
	return f
end

------------------------------------------------------------------------
-- Slider with an editable value. No mouse wheel: the wheel scrolls the page.
------------------------------------------------------------------------
local SLIDER_W, VALUE_W = 150, 50
function UI.Slider(stack, opt)
	local T = stack.T
	local f = CreateFrame("Frame")
	local cut = RowLabel(f, T, opt, SLIDER_W + 12 + VALUE_W)

	local box = CreateFrame("EditBox", nil, f)
	box:SetSize(VALUE_W, 22)
	box:SetPoint("RIGHT", f, "RIGHT", 0, 0)
	box:SetAutoFocus(false)
	box:SetJustifyH("CENTER")
	U.SetFont(box, T.font)
	box:SetTextColor(rgba(T.text))
	box.bg, box.border = U.RoundBox(box, 4, T.surface, T.border)

	local slider = CreateFrame("Slider", nil, f)
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(SLIDER_W, 16)
	slider:SetPoint("RIGHT", box, "LEFT", -12, 0)
	slider:SetMinMaxValues(opt.min, opt.max)
	slider:SetValueStep(opt.step or 1)
	slider:SetObeyStepOnDrag(true)
	local rail = U.Round(slider, 2, "BACKGROUND")
	rail:SetHeight(4)
	rail:SetPoint("LEFT")
	rail:SetPoint("RIGHT")
	rail:SetVertexColor(rgba(T.surfaceHi))
	local fill = U.Round(slider, 2, "ARTWORK")
	fill:SetHeight(4)
	fill:SetPoint("LEFT")
	fill:SetVertexColor(rgba(T.accentFill or T.accent))
	local thumb = slider:CreateTexture(nil, "OVERLAY")
	thumb:SetTexture(UI.media and (UI.media .. "Round") or U.WHITE)
	thumb:SetVertexColor(rgba(T.text))
	thumb:SetSize(14, 14)
	slider:SetThumbTexture(thumb)

	local fmt = opt.fmt or (opt.step and opt.step < 1 and "%.2f" or "%d")
	local updating = false
	local function updateFill(v)
		local w = slider:GetWidth()
		if w and w > 0 then fill:SetWidth(math.max(4, w * (v - opt.min) / (opt.max - opt.min))) end
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
		local before = opt.get()
		opt.set(v)
		Changed(stack, opt, before)
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
			local before = opt.get()
			opt.set(v)
			Changed(stack, opt, before)
			if opt.after then opt.after() end
		end
		self:ClearFocus()
		f:Refresh()
	end)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Refresh() end)
	box:SetScript("OnEditFocusGained", function(self) self.border:SetColor(rgba(T.accent)) end)
	box:SetScript("OnEditFocusLost", function(self) self.border:SetColor(rgba(T.border)) end)
	Tooltip(f, opt.label, cut and opt.desc or nil)
	f.searchInfo = opt.label and SearchInfo(opt)
	stack:Add(f, f.eluiMeasure(f, stack.width), 0)
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
		popup.bg, popup.edge = U.RoundBox(popup, 6, T.surface, T.border)
		popup.buttons = {}
	end
	popup.bg:SetVertexColor(rgba(T.surface))
	for _, b in ipairs(popup.buttons) do b:Hide() end
	local width = opts.width or (owner and owner:GetWidth()) or 200
	for i, item in ipairs(items) do
		local b = popup.buttons[i]
		if not b then
			b = CreateFrame("Button", nil, popup)
			b:SetHeight(22)
			b.hl = U.Round(b, 4, "BACKGROUND")
			b.hl:SetAllPoints(b)
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
		b:SetPoint("TOPLEFT", 3, -3 - (i - 1) * 22)
		b:SetPoint("RIGHT", -3, 0)
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
	popup:SetSize(width, #items * 22 + 6)
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

-- The dropdown's button: the value and a chevron on a rounded box. Returns button, valueText.
local function DropButton(parent, T, width)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, 26)
	b.eluiTheme = T
	b.bg, b.edge = U.RoundBox(b, 4, T.surface, T.border)
	local value = Text(b, T.font, T.text)
	value:SetPoint("LEFT", 10, 0)
	value:SetPoint("RIGHT", -26, 0)
	value:SetWordWrap(false)
	local arrow = b:CreateTexture(nil, "ARTWORK")
	arrow:SetSize(10, 10)
	arrow:SetPoint("RIGHT", -10, 0)
	if UI.SetIcon(arrow, "chevron") then
		arrow:SetVertexColor(rgba(T.muted))
	else
		local a = Text(b, T.font, T.muted)
		a:SetPoint("RIGHT", -8, 0)
		a:SetText("v")
	end
	b:SetScript("OnEnter", function() b.bg:SetVertexColor(rgba(T.surfaceHi)) end)
	b:SetScript("OnLeave", function() b.bg:SetVertexColor(rgba(T.surface)) end)
	return b, value
end
UI.DropButton = DropButton

function UI.Dropdown(stack, opt)
	local T = stack.T
	local f = CreateFrame("Frame")
	local width, b, value, cut
	if opt.label then
		width = math.min(opt.width or 200, math.max(140, math.floor(stack.width * 0.5)))
		b, value = DropButton(f, T, width)
		b:SetPoint("RIGHT", f, "RIGHT", 0, 0)
		cut = RowLabel(f, T, opt, width)
	else
		b, value = DropButton(f, T, opt.width or 240)
		b:SetPoint("TOPLEFT", 0, 0)
	end
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
			local before = opt.get()
			opt.set(v)
			Changed(stack, opt, before)
			stack:RefreshAll()
			if opt.after then opt.after() end
		end, { width = math.max(b:GetWidth() or 0, 180) })
	end)
	Tooltip(b, opt.label, (cut or not opt.label) and opt.desc or nil)
	f.searchInfo = opt.label and SearchInfo(opt, {
		value = function() return value:GetText() end,
		choices = function()
			local t = {}
			for _, it in ipairs(items()) do if not it.title and it.text then t[#t + 1] = tostring(it.text) end end
			return table.concat(t, " ")
		end,
	})
	if opt.label then stack:Add(f, f.eluiMeasure(f, stack.width), 0) else stack:Add(f, 26) end
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
	sw:SetSize(36, 20)
	sw:SetPoint("RIGHT", f, "RIGHT", 0, 0)
	local fill = U.RoundBox(sw, 4, { 1, 1, 1, 1 }, T.border)
	local cut = RowLabel(f, T, opt, 36)
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
			local before = opt.get()
			opt.set({ r, g, b, opt.hasAlpha and a or (c[4] or 1) })
			Changed(stack, opt, before)
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
	if cut then Tooltip(f, opt.label, opt.desc) end
	f.searchInfo = opt.label and SearchInfo(opt)
	stack:Add(f, f.eluiMeasure(f, stack.width), 0)
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
	box.bg, box.border = U.RoundBox(box, 4, T.surface, T.border)
	box:SetScript("OnEditFocusGained", function(self) self.border:SetColor(rgba(T.accent)) end)
	box:SetScript("OnEditFocusLost", function(self) self.border:SetColor(rgba(T.border)) end)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	return box
end

-- A text box. opt: label, placeholder, width, get/set (bound: saved on Enter or leaving the box),
-- onChange(text) while typing, onEnter(text), button = { label, onClick(text, box), width, style }, maxLetters.
-- With a label it is a setting row (the box on the right); without one, a box (and its button) on the left.
function UI.Input(stack, opt)
	local T = stack.T
	local f = CreateFrame("Frame")
	f:SetParent(stack.parent)
	local bw = opt.button and (opt.button.width or 110) or 0
	local box, cut
	if opt.label then
		local w = math.min(opt.width or 220, math.max(120, math.floor(stack.width * 0.55) - (bw > 0 and bw + 8 or 0)))
		box = UI.EditBox(f, w, 26)
		box:SetPoint("RIGHT", f, "RIGHT", bw > 0 and -(bw + 8) or 0, 0)
		cut = RowLabel(f, T, opt, w + (bw > 0 and bw + 8 or 0))
	else
		box = UI.EditBox(f, opt.width or 240, 26)
		box:SetPoint("TOPLEFT", 0, 0)
	end
	if opt.maxLetters then box:SetMaxLetters(opt.maxLetters) end
	f.box = box
	local hint = Text(box, T.font, T.muted)
	hint:SetPoint("LEFT", 8, 0)
	hint:SetPoint("RIGHT", -8, 0)
	hint:SetWordWrap(false)
	hint:SetText(opt.placeholder or "")
	local function updateHint() hint:SetShown(not box:HasFocus() and (box:GetText() or "") == "") end
	box:HookScript("OnEditFocusGained", updateHint)
	box:HookScript("OnEditFocusLost", function(self)
		updateHint()
		if opt.set and (not opt.get or self:GetText() ~= (opt.get() or "")) then
			local before = opt.get and opt.get()
			opt.set(self:GetText())
			if opt.get then Changed(stack, opt, before) end
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
		local b = UI.Button(f, opt.button.label, function() opt.button.onClick(box:GetText(), box) end, bw, opt.button.style)
		if opt.label then b:SetPoint("RIGHT", f, "RIGHT", 0, 0) else b:SetPoint("LEFT", box, "RIGHT", 8, 0) end
		f.button = b
	end
	if opt.get then
		function f:Refresh()
			if not box:HasFocus() then box:SetText(opt.get() or "") end
			updateHint()
		end
	end
	Tooltip(box, opt.label, (cut or not opt.label) and opt.desc or nil)
	-- a plain text box is usually data entry (a name, a filter), not a setting: only settings and opt-ins are found
	if opt.label and (opt.searchKey or opt.keywords) then f.searchInfo = SearchInfo(opt) end
	if opt.label then stack:Add(f, f.eluiMeasure(f, stack.width), 0) else stack:Add(f, 26) end
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
	local box = UI.EditBox(f, stack.width, 26)
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
	stack:Add(f, 46)
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
		r.bg = U.Round(r, 4, "BACKGROUND")
		r.bg:SetAllPoints(r)
		r.bg:SetVertexColor(rgba(T.surface))
		local x = 8
		if opt.toggle then
			r.switch = Switch(r, T)
			r.switch:SetPoint("LEFT", x, 0)
			r.switch:EnableMouse(true)
			r.switch:SetScript("OnMouseDown", function()
				if r.item == nil then return end
				local item = r.item
				local before = opt.toggle.get(item)
				opt.toggle.set(item, not before)
				Changed(stack, {
					label = opt.title and opt.title(item) or nil,
					get = function() return opt.toggle.get(item) end,
					set = function(v) opt.toggle.set(item, v) end,
				}, before, item)
				stack:RefreshAll()
			end)
			x = x + 46
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
	-- a slim rounded rail and thumb in the middle of a 12 px wide grab area
	local rail = U.Round(track, 3, "BACKGROUND")
	rail:SetPoint("TOP", track, "TOP", 0, 0)
	rail:SetPoint("BOTTOM", track, "BOTTOM", 0, 0)
	rail:SetWidth(6)
	rail:SetVertexColor(T.muted[1], T.muted[2], T.muted[3], 0.08)
	local thumb = CreateFrame("Frame", nil, track)
	thumb:SetWidth(BAR_W)
	local thumbTex = U.Round(thumb, 3, "ARTWORK")
	thumbTex:SetPoint("TOP", thumb, "TOP", 0, 0)
	thumbTex:SetPoint("BOTTOM", thumb, "BOTTOM", 0, 0)
	thumbTex:SetWidth(6)
	thumbTex:SetVertexColor(T.muted[1], T.muted[2], T.muted[3], 0.55)
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
	WindowChrome(f, T)
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

local SIDEBAR_W = 196 -- the sidebar of a window with more than one page
local HEADER_H = 72   -- the page title and description (taller for a long description or a preview)
local FOOTER_H = 48   -- the footer bar: profile picker on the left, Undo on the right
local MIN_H = 420
UI.SIDEBAR_W, UI.FOOTER_H = SIDEBAR_W, FOOTER_H

-- The window width. EverlookUI 6 windows were 780 (sidebar) or 600 px wide by default and addons sized their pages
-- (spec.width) for the room that left; the new sidebar and cards take more, so the window grows by that much and a
-- page keeps exactly the width it had (stack.width): 780 -> 826, 600 -> 624.
local function WindowWidth(spec, sidebar)
	if sidebar then return (spec.width or 780) + 46 end
	return (spec.width or 600) + 24
end

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
	if def.type == "color" then
		return def.hasAlpha and "a colour like ff8040 (hex) or 1 0.5 0.25 (0-1), opacity as a 4th number: 1 0.5 0.25 0.6"
			or "a colour like ff8040 (hex) or 1 0.5 0.25"
	end
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
		-- a colour with opacity keeps its opacity unless a 4th number gives a new one
		local cur = def.hasAlpha and def.get and def.get()
		local keepA = type(cur) == "table" and tonumber(cur[4]) or 1
		local h = text:match("^#?(%x%x%x%x%x%x)$")
		if h then
			return true, { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, keepA }
		end
		local r, g, b, a = text:match("^([%d%.]+)[%s,]+([%d%.]+)[%s,]+([%d%.]+)[%s,]*([%d%.]*)$")
		r, g, b = tonumber(r), tonumber(g), tonumber(b)
		a = (a ~= nil and a ~= "") and tonumber(a) or nil
		if r and g and b and r <= 1 and g <= 1 and b <= 1 and (not a or a <= 1) then
			return true, { r, g, b, def.hasAlpha and a or (a and 1) or keepA }
		end
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

-- The setting a chat word names. An addon with keys beyond its registry overrides this ("bar2.edge" in Everlook
-- Bar): it returns def, prepare, where prepare() readies the def (picks bar 2) and may return a function that
-- undoes that; or nil, why.
function App:ResolveSetting(word)
	return self:GetSetting(word)
end

-- Set or show `def` from chat text, after its prepare step.
local function setResolved(app, def, prepare, text)
	if prepare then prepare() end
	return app:SetFromText(def, text or "")
end

-- Try "<setting> [value]"; true when the first word named a setting.
function App:TrySetting(msg)
	local word, rest = U.Trim(msg):match("^(%S+)%s*(.*)$")
	local def, prepare = self:ResolveSetting(word)
	if not def then return false end
	setResolved(self, def, prepare, rest)
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
	if #self.settingOrder > 0 then v[#v + 1] = "ai"; v[#v + 1] = "apply" end
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
		line(p .. "<setting> <value>", "change a setting, e.g. " .. U.Escape(p .. d.key .. " " .. self:Example(d))
			.. "; several on one line: " .. U.Escape(s .. " set <setting> <value> ; <setting> <value>"))
		line(s .. " get [setting]", "every setting and its value, or one")
		if not cmds.ai then line(s .. " ai", "copy a description of every setting for an AI assistant (Claude or another)") end
		if not cmds.apply then line(s .. " apply", "paste the AI's answer: shows each change, then applies the settings") end
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
		local def, prepare = app:ResolveSetting(key)
		if def and def.type == "bool" then setResolved(app, def, prepare, w) return "setting" end
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

-- "a 1 ; b 2" -> { "a 1", "b 2" }: the changes of one "/x set" line (a ";" with a space on both sides splits).
function UI.SplitSets(rest)
	local parts = {}
	for part in (tostring(rest or "") .. " ; "):gmatch("(.-)%s+;%s+") do
		part = U.Trim(part)
		if part ~= "" then parts[#parts + 1] = part end
	end
	if #parts == 0 and U.Trim(rest) ~= "" then parts[1] = U.Trim(rest) end
	return parts
end

-- word -> function(app, rest, word) returning what was done, or nil to go on (a setting, else unknown).
UI.Verbs = {
	get = function(app, rest)
		if rest == "" then app:PrintSettings() return "settings" end
		local def, prepare = app:ResolveSetting(rest:match("^(%S+)"))
		if def then setResolved(app, def, prepare, "") return "setting" end
		app:Unknown(rest:match("^(%S+)"))
		return "unknown"
	end,
	set = function(app, rest)
		-- several at once on one line: "/x set size 20 ; flag off"
		local parts = UI.SplitSets(rest)
		if #parts > 1 then
			for _, part in ipairs(parts) do UI.Verbs.set(app, part) end
			return "setting"
		end
		local key, value = rest:match("^(%S+)%s*(.*)$")
		local def, prepare = app:ResolveSetting(key)
		if def then setResolved(app, def, prepare, value) return "setting" end
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
	ai = function(app)
		if #app.settingOrder == 0 then return nil end
		app:ShowAiHelp()
		return "ai"
	end,
	apply = function(app, rest)
		if #app.settingOrder == 0 then return nil end
		app:ShowApply(rest ~= "" and rest or nil)
		return "apply"
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
-- opts (EverlookUI 7): icon (a name from UI.IconNames such as "gear", or any texture path or file ID; default from the
-- title, UI.PageIcon) and desc (the line under the page title; default: the sub-line of the page's first heading
-- when that heading repeats the page title).
function App:Section(id, title, build, opts)
	assert(not self.sections[id], "duplicate section " .. id)
	self.sections[id] = { id = id, title = title, build = build }
	self.order[#self.order + 1] = id
	if opts then self:SectionInfo(id, opts) end
end

-- Change a page's icon, description or title later: app:SectionInfo("general", { icon = "gear", desc = "..." }).
function App:SectionInfo(id, opts)
	local s = self.sections[id]
	if not s or type(opts) ~= "table" then return end
	if opts.icon ~= nil then s.icon = opts.icon end
	if opts.desc ~= nil then s.desc = opts.desc end
	if opts.title ~= nil then s.title = opts.title end
	local b = self.window and self.window.navButtons and self.window.navButtons[id]
	if b then
		b.text:SetText(s.title)
		UI.SetIcon(b.icon, s.icon or UI.PageIcon(s.title))
		self:PaintNav()
	end
	if self.current == id then self:UpdatePageHeader() end
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
-- Settings search in the window. The box sits at the top of the sidebar (or of a one-page window); typing lists the matching controls from
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
	s.stack = UI.Stack(s.scroll.child, width, self.T, { cards = true })
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

-- Put a control into the results at x, y.
function App:Borrow(e, parent, y, width, x)
	local fr, se = e.frame, e.frame.stackEntry
	if not self.borrowed[e] then
		self.borrowed[e] = true
		se.borrowed = true
		fr:SetParent(parent)
	end
	fr:ClearAllPoints()
	fr:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, -y)
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
	if f.pageTitle then
		for _, d in pairs(self.previews or {}) do if d.frame then d.frame:Hide() end end
		f.pageTitle:SetText("Search results")
		f.pageDesc:SetText(#results == 0 and "Nothing found." or (#results == 1 and "1 setting matches." or (#results .. " settings match.")))
		f.pageDesc:Show()
	end
	return results
end

function App:ShowResults(results, q, entries)
	local f, T = self.window, self.T
	local R = f.results
	local child = R.child
	local width = f.contentWidth - 24
	local inner = width - 2 * CARD_PAD
	local n = math.min(#results, MAX_RESULTS)
	local want = {}
	for i = 1, n do want[results[i].entry] = true end
	self:ReturnBorrowed(want)
	for _, row in ipairs(R.paths) do row.entry = nil; row:Hide() end
	for _, c in ipairs(R.cards) do c:Hide() end
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
		-- each result: its path (click to go there), then the control in a card of its own
		for i = 1, n do
			local e = results[i].entry
			local row = R.paths[i] or R.NewPath(i)
			row.entry = e
			row.text:SetText(e.path)
			local tw = row.text.GetUnboundedStringWidth and row.text:GetUnboundedStringWidth() or row.text:GetStringWidth() or 200
			row:SetWidth(math.min(width, (tw or 200) + 4))
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", child, "TOPLEFT", 2, -y)
			row:Show()
			y = y + 18
			local se = e.frame.stackEntry
			local isRow = se.row
			local top = y + (isRow and 2 or 10)
			self:Borrow(e, child, top, inner - (se.indent or 0), CARD_PAD + (se.indent or 0))
			local bottom = top + se.height + (isRow and 2 or 10)
			local card = R.cards[i]
			if not card then
				card = U.Round(child, T.radius, "BACKGROUND", -6)
				card:SetVertexColor(rgba(T.card))
				R.cards[i] = card
			end
			card:ClearAllPoints()
			card:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
			card:SetSize(width, bottom - y)
			card:Show()
			y = bottom + CARD_GAP
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
	self:UpdatePageHeader()
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
function App:CreateSearch(f, width, parent)
	local app, T = self, self.T
	self.borrowed = self.borrowed or {}
	self.searchBySection = self.searchBySection or {}

	local box = UI.EditBox(parent or f, width, 26)
	box:SetTextInsets(26, 26, 0, 0)
	box:SetMaxLetters(60)
	local icon = box:CreateTexture(nil, "OVERLAY")
	if UI.SetIcon(icon, "search") then
		icon:SetSize(12, 12)
		icon:SetPoint("LEFT", 9, 0)
	else
		icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
		icon:SetSize(14, 14)
		icon:SetPoint("LEFT", 8, -1)
	end
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
	R.paths, R.cards = {}, {}
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

-- The window's place and size: holder.window = { point, relativePoint, x, y, width, height }.
local function SavePosition(app, f)
	local holder = app.spec.position and app.spec.position()
	if type(holder) ~= "table" then return end
	local point, _, rel, x, y = f:GetPoint()
	if point then
		local w, h = f:GetWidth(), f:GetHeight()
		holder.window = { point, rel or point, math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5),
			w and math.floor(w + 0.5) or nil, h and math.floor(h + 0.5) or nil }
	end
end

local function RestorePosition(app, f)
	local holder = app.spec.position and app.spec.position()
	local p = type(holder) == "table" and holder.window
	f:ClearAllPoints()
	if type(p) == "table" and type(p[1]) == "string" then
		f:SetPoint(p[1], UIParent, p[2] or p[1], tonumber(p[3]) or 0, tonumber(p[4]) or 0)
		local w, h = tonumber(p[5]), tonumber(p[6])
		if w and h then f:SetSize(math.max(app.minW or w, w), math.max(MIN_H, h)) end
	else
		f:SetPoint("CENTER")
	end
end

local function StringWidth(fs)
	return (fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth()) or fs:GetStringWidth() or 0
end

-- The icon for a tool link without one, from its label.
local function ToolIcon(d)
	if d.icon then return d.icon end
	local l = tostring(d.label or ""):lower()
	if l:find("lock") or l:find("move") then return "lock" end
	if l:find("test") or l:find("preview") then return "sparkle" end
	if l:find("bug") or l:find("feedback") then return "bug" end
	if l:find("macro") or l:find("key") then return "keyboard" end
	if l:find("reset") then return "refresh" end
	return "wrench"
end

-- A tool link (sidebar bottom, or the footer of a one-page window): an icon and plain text, lit on hover.
-- Behaves like a UI.Button for the addon: SetText, GetText, SetUsable, .label, .def.
local function ToolLink(parent, T, d, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(24)
	b.eluiTheme = T
	b.def = d
	b.bg = U.Round(b, 4, "BACKGROUND")
	b.bg:SetAllPoints(b)
	b.bg:SetVertexColor(rgba(T.surfaceHi))
	b.bg:Hide()
	local color = d.style == "accent" and T.accent or T.muted
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(14, 14)
	b.icon:SetPoint("LEFT", 8, 0)
	local hasIcon = UI.SetIcon(b.icon, ToolIcon(d))
	b.icon:SetVertexColor(rgba(color))
	b.label = Text(b, T.font, color)
	b.label:SetPoint("LEFT", hasIcon and 30 or 12, 0)
	b.label:SetPoint("RIGHT", -6, 0)
	b.label:SetWordWrap(false)
	b.label:SetText(d.label)
	b:SetScript("OnEnter", function(self)
		self.bg:Show()
		self.label:SetTextColor(rgba(T.text))
		self.icon:SetVertexColor(rgba(T.text))
	end)
	b:SetScript("OnLeave", function(self)
		self.bg:Hide()
		self.label:SetTextColor(rgba(color))
		self.icon:SetVertexColor(rgba(color))
	end)
	b:SetScript("OnClick", function(self, ...) if onClick then onClick(self, ...) end end)
	function b:SetText(t) self.label:SetText(t) end
	function b:GetText() return self.label:GetText() end
	function b:SetUsable(on)
		self:SetAlpha(on and 1 or 0.4)
		self:EnableMouse(on and true or false)
	end
	-- as wide as its label (one-page footer)
	function b:FitWidth()
		self:SetWidth(math.ceil(StringWidth(self.label)) + (hasIcon and 30 or 12) + 12)
		return self:GetWidth()
	end
	if d.desc then Tooltip(b, d.label, d.desc) end
	return b
end
UI.ToolLink = ToolLink

-- The addon's icon: spec.icon (an icon name, texture path or file ID), else the TOC's IconTexture, else its first
-- letter on a rounded accent square.
function App:MakeAppIcon(parent, size)
	local T = self.T
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(size, size)
	local icon = self.spec.icon
	if icon == nil and self.spec.addon then
		local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
		icon = get and get(self.spec.addon, "IconTexture")
	end
	local tex = holder:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints(holder)
	holder.texture = tex
	if icon and UI.SetIcon(tex, icon) then
		if UI.IsIconName(icon) then tex:SetVertexColor(rgba(T.accent)) end
		return holder
	end
	local bg = U.Round(holder, math.floor(size / 4), "BACKGROUND")
	bg:SetAllPoints(holder)
	bg:SetVertexColor(rgba(T.accent))
	local letter = Text(holder, math.floor(size * 0.55), T.onAccent)
	letter:SetPoint("CENTER", 0, 0)
	letter:SetJustifyH("CENTER")
	letter:SetText((tostring(self.name):match("%w") or "?"):upper())
	holder.letter = letter
	return holder
end

-- "v1.2.3 · /whack": the sidebar footer, and the title row of a one-page window.
function App:VersionLine() return self:Version() .. "  \194\183  " .. self.slash end

-- The tool links: the addon's spec.buttons, AI help (when it has settings) and Report a bug (spec.feedbackURL).
-- window.footer lists the addon's buttons and Report a bug (as in EverlookUI 6); window.aiButton is AI help.
function App:MakeTools(parent)
	local app, f, T = self, self.window, self.T
	local tools = {}
	f.footer = {}
	for _, d in ipairs(self.spec.buttons or {}) do
		local b = ToolLink(parent, T, d, function(btn) d.onClick(app, btn); app:RefreshButtons() end)
		f.footer[#f.footer + 1] = b
		tools[#tools + 1] = b
	end
	if #self.settingOrder > 0 then
		local d = { label = "AI help", icon = "ai" }
		local b = ToolLink(parent, T, d, function() app:ShowAiHelp() end)
		Tooltip(b, "Get help from AI to configure this addon",
			"Copies a description of every setting. Paste it into Claude or another AI with what you want; then paste its answer into "
			.. self.slash .. " apply.")
		f.aiButton = b
		tools[#tools + 1] = b
	end
	if self.spec.feedbackURL then
		local d = { label = "Report a bug", icon = "bug", desc = "Report a bug or suggest an idea: a link to copy.", feedback = true }
		local b = ToolLink(parent, T, d, function() app:ShowFeedback() end)
		f.footer[#f.footer + 1] = b
		tools[#tools + 1] = b
	end
	return tools
end

function App:CreateWindow()
	local app, T, spec = self, self.T, self.spec
	local sidebar = #self.order > 1
	local W = WindowWidth(spec, sidebar)
	local H = (spec.height or 560) + 40 -- room for the footer bar
	self.minW = W
	local f = CreateFrame("Frame", self.frameName .. "OptionsWindow", UIParent)
	f.eluiTheme = T
	f.app = self
	f:SetSize(W, H)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetResizable(true)
	if f.SetResizeBounds then f:SetResizeBounds(W, MIN_H) elseif f.SetMinResize then f:SetMinResize(W, MIN_H) end
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) self:StartMoving() end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition(app, self)
	end)
	f:Hide()
	self.window = f
	RestorePosition(self, f)
	W = math.floor((f:GetWidth() or W) + 0.5) -- a size the player gave it last time
	WindowChrome(f, T)

	-- the page area (its top is set below, under the header); the search results live in it too
	local CL, top = sidebar and (SIDEBAR_W + 1 + 20) or 16, HEADER_H
	local content = CreateFrame("Frame", nil, f)
	f.content = content
	f.contentWidth = W - CL - 16
	local tools = {}
	if sidebar then
		local side = CreateFrame("Frame", nil, f)
		side:SetPoint("TOPLEFT", 1, -1)
		side:SetPoint("BOTTOMLEFT", 1, 1)
		side:SetWidth(SIDEBAR_W)
		local sbg = U.Round(side, 7, "BACKGROUND", 2, { tl = true, bl = true })
		sbg:SetAllPoints(side)
		sbg:SetVertexColor(rgba(T.sidebar))
		local sideLine = U.Solid(side, "BORDER", rgba(T.border))
		sideLine:SetWidth(1)
		sideLine:SetPoint("TOPRIGHT")
		sideLine:SetPoint("BOTTOMRIGHT")
		f.sidebar = side

		-- the addon: icon, name (shrinks until its longest word fits, may take two lines), subtitle
		local icon = self:MakeAppIcon(side, 30)
		icon:SetPoint("TOPLEFT", 14, -18)
		f.appIcon = icon
		local room = SIDEBAR_W - 54 - 10
		local logo = Text(side, T.fontTitle + 1, T.text)
		logo:SetPoint("TOPLEFT", 54, -17)
		logo:SetWidth(room)
		local font, size, flags = logo:GetFont()
		if font and size then
			local widest = 0
			for word in tostring(self.name):gmatch("%S+") do
				logo:SetText(word)
				widest = math.max(widest, StringWidth(logo))
			end
			if widest > room then logo:SetFont(font, math.max(11, math.floor(size * room / widest)), flags) end
		end
		logo:SetText(self.name)
		f.logo = logo
		local sub = Text(side, T.fontSmall, T.muted)
		sub:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -3)
		sub:SetWidth(room)
		sub:SetWordWrap(false)
		sub:SetText(spec.subtitle or "Settings")
		f.subtitle = sub
		f.tagline = spec.tagline
		if spec.tagline then
			local hover = CreateFrame("Frame", nil, side)
			hover:SetPoint("TOPLEFT", 8, -10)
			hover:SetPoint("RIGHT", -8, 0)
			hover:SetHeight(48)
			Tooltip(hover, self.name, spec.tagline)
		end
		local headBottom = math.max(18 + 30, 17 + math.ceil(logo:GetStringHeight() or 16) + 3 + 12)

		-- the search box under it
		local box = self:CreateSearch(f, SIDEBAR_W - 24, side)
		box:SetPoint("TOPLEFT", f, "TOPLEFT", 13, -(headBottom + 14))
		local navTop = headBottom + 14 + 26 + 14

		-- the pages
		f.navButtons = {}
		for i, id in ipairs(self.order) do
			local s = self.sections[id]
			local b = CreateFrame("Button", nil, side)
			b:SetHeight(30)
			b:SetPoint("TOPLEFT", 8, -navTop - (i - 1) * 32)
			b:SetPoint("RIGHT", -8, 0)
			b.hover = U.Round(b, 5, "BACKGROUND")
			b.hover:SetAllPoints(b)
			b.hover:SetVertexColor(T.surfaceHi[1], T.surfaceHi[2], T.surfaceHi[3], 0.6)
			b.hover:Hide()
			b.bg = U.Round(b, 5, "BACKGROUND", 1)
			b.bg:SetAllPoints(b)
			b.bg:SetVertexColor(rgba(T.accentDim))
			b.bg:Hide()
			b.bar = U.Solid(b, "ARTWORK", rgba(T.accent))
			b.bar:SetSize(3, 16)
			b.bar:SetPoint("LEFT", 0, 0)
			b.bar:Hide()
			b.icon = b:CreateTexture(nil, "ARTWORK")
			b.icon:SetSize(16, 16)
			b.icon:SetPoint("LEFT", 10, 0)
			local hasIcon = UI.SetIcon(b.icon, s.icon or UI.PageIcon(s.title))
			b.icon:SetVertexColor(rgba(T.muted))
			b.text = Text(b, T.font, T.muted)
			b.text:SetPoint("LEFT", hasIcon and 34 or 12, 0)
			b.text:SetPoint("RIGHT", -6, 0)
			b.text:SetWordWrap(false)
			b.text:SetText(s.title)
			b:SetScript("OnEnter", function(self)
				if app.current ~= id then self.hover:Show(); self.text:SetTextColor(rgba(T.text)) end
			end)
			b:SetScript("OnLeave", function(self)
				self.hover:Hide()
				if app.current ~= id then self.text:SetTextColor(rgba(T.muted)) end
			end)
			b:SetScript("OnClick", function() app:ShowSection(id) end)
			f.navButtons[id] = b
		end

		-- tools at the bottom, over the version line; a line above them
		local ver = Text(side, T.fontSmall, T.muted)
		ver:SetPoint("BOTTOMLEFT", 16, 12)
		ver:SetPoint("RIGHT", -10, 0)
		ver:SetWordWrap(false)
		ver:SetText(self:VersionLine())
		f.versionText = ver
		tools = self:MakeTools(side)
		for i, b in ipairs(tools) do
			b:SetPoint("BOTTOMLEFT", 8, 30 + (#tools - i) * 26)
			b:SetPoint("RIGHT", side, "RIGHT", -8, 0)
		end
		local line = U.Solid(side, "ARTWORK", rgba(T.divider))
		line:SetHeight(1)
		line:SetPoint("BOTTOMLEFT", 14, 30 + #tools * 26 + 6)
		line:SetPoint("RIGHT", side, "RIGHT", -14, 0)

		-- the page header
		f.pageTitle = Text(f, T.fontHuge, T.text)
		f.pageTitle:SetPoint("TOPLEFT", CL, -20)
		f.pageTitle:SetWordWrap(false)
		f.pageDesc = Text(f, T.fontSmall + 1, T.muted)
		f.pageDesc:SetPoint("TOPLEFT", f.pageTitle, "BOTTOMLEFT", 0, -6)
		top = HEADER_H
	else
		-- one page: icon, name and "v1.0 · /cmd" in a title row, the search box on its right, the tagline under it
		local icon = self:MakeAppIcon(f, 28)
		icon:SetPoint("TOPLEFT", 16, -16)
		f.appIcon = icon
		local boxW = 200
		local title = Text(f, T.fontTitle + 2, T.text)
		title:SetPoint("TOPLEFT", 54, -16)
		title:SetWordWrap(false)
		title:SetText(self.name)
		f.logo = title
		local meta = Text(f, T.fontSmall, T.muted)
		meta:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
		meta:SetWordWrap(false)
		meta:SetText(self:VersionLine())
		f.versionText = meta
		local nameRoom = W - 54 - 44 - boxW - 16
		title:SetWidth(math.min(nameRoom, math.ceil(StringWidth(title)) + 2))
		local box = self:CreateSearch(f, boxW)
		box:SetPoint("TOPRIGHT", f, "TOPRIGHT", -44, -15)
		top = 58
		f.tagline = spec.tagline
		if spec.tagline then
			local tag = Text(f, T.fontSmall + 1, T.muted)
			tag:SetPoint("TOPLEFT", 16, -top)
			tag:SetWidth(W - 32)
			tag:SetText(spec.tagline)
			f.taglineText = tag
			top = top + math.ceil(tag:GetStringHeight() or 12) + 10
		end
		local line = U.Solid(f, "ARTWORK", rgba(T.divider))
		line:SetHeight(1)
		line:SetPoint("TOPLEFT", 1, -top)
		line:SetPoint("TOPRIGHT", -1, -top)
		top = top + 14
	end
	f.contentLeft, f.headerTop = CL, top

	f.close = CloseButton(f, T)

	content:SetPoint("TOPLEFT", CL, -top)
	content:SetPoint("BOTTOMRIGHT", -16, FOOTER_H + 8)

	-- the footer bar: profile picker (or the addon's own control) and, in a one-page window, the tools on the
	-- left; Undo on the right
	local bar = CreateFrame("Frame", nil, f)
	bar:SetPoint("BOTTOMLEFT", sidebar and (SIDEBAR_W + 1) or 1, 1)
	bar:SetPoint("BOTTOMRIGHT", -1, 1)
	bar:SetHeight(FOOTER_H)
	local barLine = U.Solid(bar, "ARTWORK", rgba(T.divider))
	barLine:SetHeight(1)
	barLine:SetPoint("TOPLEFT", sidebar and 0 or 0, 0)
	barLine:SetPoint("TOPRIGHT", 0, 0)
	f.footerBar = bar
	local undo = UI.Button(bar, "Undo", function() app:Undo() end, 84)
	undo:SetPoint("RIGHT", bar, "RIGHT", -26, 0)
	undo:HookScript("OnEnter", function(self)
		local h = app.history
		local c = h and h[#h]
		if not c then return end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Undo", 1, 1, 1)
		GameTooltip:AddLine("Puts back " .. (c.label and ('"' .. tostring(c.label) .. '"') or "the last change")
			.. (#h > 1 and (" (" .. #h .. " changes to undo).") or "."), nil, nil, nil, true)
		GameTooltip:AddLine("Ctrl+Z", T.muted[1], T.muted[2], T.muted[3])
		GameTooltip:Show()
	end)
	undo:HookScript("OnLeave", function() GameTooltip:Hide() end)
	undo:SetUsable(false)
	f.undoButton = undo
	local x = sidebar and 20 or 15
	if not sidebar then
		tools = self:MakeTools(bar)
		for _, b in ipairs(tools) do
			b:SetPoint("LEFT", bar, "LEFT", x, 0)
			x = x + b:FitWidth() + 4
		end
		if #tools > 0 then x = x + 8 end
	end
	f.slotLeft = x
	self:BuildFooterSlot()

	-- resize grip, bottom right corner
	local grip = CreateFrame("Button", nil, f)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -3, 3)
	for i = 0, 2 do
		for j = 0, i do
			local d = U.Solid(grip, "ARTWORK", T.muted[1], T.muted[2], T.muted[3], 0.5)
			d:SetSize(2, 2)
			d:SetPoint("BOTTOMRIGHT", -(2 + j * 4), 2 + (i - j) * 4)
		end
	end
	grip:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then f:StartSizing("BOTTOMRIGHT") end end)
	grip:SetScript("OnMouseUp", function()
		f:StopMovingOrSizing()
		SavePosition(app, f)
	end)
	f.resizeGrip = grip
	f:SetScript("OnSizeChanged", function(_, w) app:OnWindowSized(w) end)

	-- Ctrl+Z is Undo (Ctrl+F, set by CreateSearch, focuses the search box)
	local searchKey = f.eluiKey
	f.eluiKey = function(self, key)
		if key == "Z" and IsControlKeyDown() then app:Undo() return true end
		return searchKey and searchKey(self, key)
	end

	f:SetScript("OnShow", function()
		app.history = nil
		app:RefreshUndo()
		app:RefreshButtons()
		if spec.onShow then spec.onShow(app) end
		app:WarmSearch()
	end)
	f:SetScript("OnHide", function()
		ClosePopup()
		f.searchBox:ClearFocus()
		app:StopSearch()
		app.history = nil -- Undo covers one visit of the window
		if spec.onHide then spec.onHide(app) end
	end)
	UI.CloseOnEscape(f)
	return f
end

-- The window was resized: pages, results and the page header take the new width.
function App:OnWindowSized(w)
	local f = self.window
	if not f or not w or not f.contentLeft then return end
	local cw = math.floor(w - f.contentLeft - 16 + 0.5)
	if cw == f.contentWidth then return end
	f.contentWidth = cw
	for _, s in pairs(self.sections) do
		if s.stack then s.stack:SetWidth(cw - 24) end
	end
	if f.results then f.results.child:SetWidth(cw - 24) end
	if self.searching and self.searchQuery then self:Search(self.searchQuery) end
	self:UpdatePageHeader()
end

------------------------------------------------------------------------
-- Footer bar: profiles (or any control the addon puts there) on the left
------------------------------------------------------------------------
-- app:Profiles(def): a profile picker in the footer bar. def = { label = "Profile", items = { { value, text } } or
-- fn() -> items, get = fn() -> value, set = fn(value), after = fn() }. Switching profiles changes every setting at
-- once, so it clears Undo and redraws the pages.
function App:Profiles(def)
	assert(type(def) == "table" and def.get and def.set and def.items, "Profiles needs items, get and set")
	self.profiles = def
	if self.window then self:BuildFooterSlot() end
	return def
end

-- app:FooterSlot(function(bar, app) return frame end): the addon's own control on the left of the footer bar.
function App:FooterSlot(fn)
	self.footerSlotFn = fn
	if self.window then self:BuildFooterSlot() end
end

function App:BuildFooterSlot()
	local f, T, app = self.window, self.T, self
	if not f or not f.footerBar then return end
	if f.footerSlot then f.footerSlot:Hide() end
	f.footerSlot = nil
	local bar = f.footerBar
	local slot
	if self.profiles then
		local def = self.profiles
		slot = CreateFrame("Frame", nil, bar)
		slot:SetSize(260, 26)
		local label = Text(slot, T.font, T.muted)
		label:SetPoint("LEFT")
		label:SetWordWrap(false)
		label:SetText(def.label or "Profile")
		local lw = math.ceil(StringWidth(label)) + 10
		local b, value = DropButton(slot, T, 170)
		b:SetPoint("LEFT", lw, 0)
		slot:SetWidth(lw + 170)
		local function items() if type(def.items) == "function" then return def.items() or {} end return def.items end
		function slot:Refresh()
			local cur = def.get()
			local shown = tostring(cur or "")
			for _, it in ipairs(items()) do if it.value == cur then shown = it.text break end end
			value:SetText(shown)
		end
		b:SetScript("OnClick", function()
			OpenPopup(b, items(), def.get(), function(v)
				def.set(v)
				if def.after then def.after(v) end
				app.history = nil
				app:RefreshUndo()
				for _, s in pairs(app.sections) do if s.stack then s.stack:RefreshAll() end end
				app:Refresh()
			end, { width = 200 })
		end)
		Tooltip(b, def.label or "Profile", def.desc)
		slot.button = b
	elseif self.footerSlotFn then
		local ok, frame = pcall(self.footerSlotFn, bar, self)
		if ok and frame then slot = frame
		elseif not ok then local h = geterrorhandler and geterrorhandler(); if h then h(frame) end end
	end
	if not slot then return end
	slot:SetParent(bar)
	slot:ClearAllPoints()
	slot:SetPoint("LEFT", bar, "LEFT", f.slotLeft or 20, 0)
	slot:Show()
	if slot.Refresh then slot:Refresh() end
	f.footerSlot = slot
end

------------------------------------------------------------------------
-- Live preview (EverlookUI 7): a small frame at the top right of a page that shows what the settings do.
-- app:Preview(sectionId or "*", { width = 240, height = 60, build = fn(frame, app), refresh = fn(frame, app) })
-- "*" is every page without its own. The frame (a card) is built when its page first shows; refresh runs when it
-- shows, after every change made in the window (and Undo) and on app:Refresh().
------------------------------------------------------------------------
function App:Preview(id, def)
	assert(type(def) == "table" and (def.build or def.refresh), "Preview needs build or refresh")
	self.previews = self.previews or {}
	self.previews[id or "*"] = def
	if self.window and self:IsShown() then self:UpdatePageHeader() end
	return def
end

function App:PreviewFor(id)
	local p = self.previews
	return p and id and (p[id] or p["*"]) or nil
end

local function report(err) local h = geterrorhandler and geterrorhandler(); if h then h(err) end end

function App:RefreshPreview()
	local def = self.window and self:PreviewFor(self.current)
	if not (def and def.frame and def.refresh and def.frame:IsShown()) then return end
	local ok, err = pcall(def.refresh, def.frame, self)
	if not ok then report(err) end
end

-- The page title, description and preview for the page shown; the page area starts under them.
function App:UpdatePageHeader()
	local f, T = self.window, self.T
	if not f or not f.pageTitle then return end
	local s = self.current and self.sections[self.current]
	for _, d in pairs(self.previews or {}) do if d.frame then d.frame:Hide() end end
	local def = s and self:PreviewFor(s.id)
	local pw, ph = 0, 0
	if def then
		if not def.frame then
			local holder = CreateFrame("Frame", nil, f)
			holder.eluiTheme = T
			holder:SetSize(def.width or 240, def.height or 56)
			holder.bg, holder.edge = U.RoundBox(holder, T.radius, T.card, T.border)
			def.frame = holder
			if def.build then
				local ok, err = pcall(def.build, holder, self)
				if not ok then report(err) end
			end
		end
		pw, ph = def.frame:GetWidth() or 0, def.frame:GetHeight() or 0
		def.frame:ClearAllPoints()
		def.frame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -44, -14)
		def.frame:Show()
		self:RefreshPreview()
	end
	local textW = f.contentWidth - (def and (pw + 44 - 16 + 12) or 32)
	f.pageTitle:SetWidth(math.max(120, textW))
	f.pageDesc:SetWidth(math.max(120, textW))
	f.pageTitle:SetText(s and s.title or "")
	f.pageDesc:SetText(s and s.desc or "")
	f.pageDesc:SetShown(s ~= nil and s.desc ~= nil and s.desc ~= "")
	local textH = 20 + 22 + ((s and s.desc and s.desc ~= "") and (6 + math.ceil(f.pageDesc:GetStringHeight() or 12)) or 0) + 14
	local top = math.max(HEADER_H, textH, ph > 0 and (14 + ph + 14) or 0)
	if top ~= f.headerTop then
		f.headerTop = top
		f.content:ClearAllPoints()
		f.content:SetPoint("TOPLEFT", f, "TOPLEFT", f.contentLeft, -top)
		f.content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, FOOTER_H + 8)
	end
end

------------------------------------------------------------------------
-- Undo (EverlookUI 7): each change made with a control in the window is remembered until the window closes; the
-- footer's Undo (or Ctrl+Z) puts the last one back through the same get/set. Changes to one control in a row (a
-- slider drag) count as one; changing it back to where it started drops it. Chat commands aren't recorded.
------------------------------------------------------------------------
local function SameValue(a, b)
	if type(a) == "table" and type(b) == "table" then
		for k, v in pairs(a) do if b[k] ~= v then return false end end
		for k, v in pairs(b) do if a[k] ~= v then return false end end
		return true
	end
	return a == b
end
UI.SameValue = SameValue

-- c = { id, label, get, set, after, before }
function App:RecordChange(c)
	if self.undoing then return end
	self.history = self.history or {}
	local h = self.history
	local last = h[#h]
	local now
	if c.get then now = c.get() end
	if last and last.id == c.id then
		if c.get and SameValue(now, last.before) then table.remove(h) end -- back where it started
	elseif not (c.get and SameValue(now, c.before)) then
		c.before = U.CopyTable(c.before)
		h[#h + 1] = c
		if #h > 200 then table.remove(h, 1) end
	end
	self:RefreshUndo()
	self:RefreshPreview()
end

function App:CanUndo() return self.history ~= nil and #self.history > 0 end

-- Puts the last change back; returns it, or nil when there was nothing to undo.
function App:Undo()
	local h = self.history
	local c = h and table.remove(h)
	if not c then return nil end
	self.undoing = true
	local ok, err = pcall(c.set, U.CopyTable(c.before))
	if ok and c.after then ok, err = pcall(c.after) end
	self.undoing = nil
	if not ok then report(err) end
	if self.searching then self:RefreshBorrowed() end
	local s = self.current and self.sections[self.current]
	if s and s.stack then s.stack:RefreshAll() end
	self:RefreshButtons()
	self:RefreshUndo()
	self:RefreshPreview()
	return c
end

function App:RefreshUndo()
	local b = self.window and self.window.undoButton
	if b then b:SetUsable(self:CanUndo()) end
end

function App:RefreshButtons()
	local f = self.window
	if not f then return end
	for _, b in ipairs(f.footer) do
		if b.def.text then b:SetText(b.def.text(self)) end
	end
	if f.footerSlot and f.footerSlot.Refresh then f.footerSlot:Refresh() end
end

-- The sidebar rows: the page shown lit (accent tint, bar, white text, accent icon), the others muted.
function App:PaintNav()
	local f = self.window
	if not f or not f.navButtons then return end
	for sid, b in pairs(f.navButtons) do
		local active = sid == self.current
		b.bg:SetShown(active)
		b.bar:SetShown(active)
		b.text:SetTextColor(rgba(active and self.T.text or self.T.muted))
		b.icon:SetVertexColor(rgba(active and self.T.accent or self.T.muted))
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
	end
	self.current = id
	self:PaintNav()
	if not s.scroll then
		self:BuildSection(id)
	else
		s.stack:RefreshAll()
	end
	self:UpdatePageHeader()
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
	self:RefreshPreview()
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
-- AI help (EverlookUI 5). "/x ai" and the "AI help" button by the search box show a description of every
-- setting, selected for Ctrl+C: the player pastes it into Claude or another AI with what they want. "/x apply"
-- takes the AI's answer: a preview line per change ("Size (size): 18 -> 20"), then Apply. Addons can't write the
-- clipboard and chat runs only the first line of a paste, hence the two windows. From the apply box only setting
-- changes, get, on/off/toggle and lock/unlock run; reset and the addon's own commands are refused (chat only).
--   spec.aiAbout   a paragraph: what the addon does and how it works (else the tagline)
--   spec.siteURL   the addon's page; the text links it, and spec.feedbackURL
--   def.default    a setting's default, a value or a function (shown to the AI when given)
--   app:AiExtra(function(app) return "text" end)   more context after the settings (bars, placed plugins...)
--   app:ResolveSetting(word)                        keys beyond the registry (see "Chat commands")
-- The text is built from the live registry (app:AiText()), so it is always complete and current; settings are
-- grouped by page and heading as in the window (from the search index), the rest under "More settings".
------------------------------------------------------------------------
function App:AiExtra(fn) self.aiExtraFn = fn end

-- Text for the AI: no colour codes or textures. A "|r" counts as a code only after a "|c": usage lines
-- like "left|center|right" keep their letters.
local function plain(s)
	s = tostring(s or "")
	if s:find("|c%x%x%x%x%x%x%x%x") then s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
	s = s:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|n", " "):gsub("||", "|")
	return s
end
UI.Plain = plain

-- 0.6 -> "0.6", 1 -> "1"
local function short(v)
	if type(v) ~= "number" then return tostring(v) end
	local s = string.format("%.3f", v):gsub("0+$", ""):gsub("%.$", "")
	if s == "-0" then s = "0" end
	return s
end

-- A sentence ends with a full stop.
local function sentence(s)
	s = U.Trim(plain(s))
	if s ~= "" and not s:find("[%.!%?:]$") then s = s .. "." end
	return s
end

-- The word that picks a choice from chat: its value, or its label for an empty value ("" = None).
local function choiceWord(c)
	local v = tostring(c.value)
	if v == "" then return plain(c.text):lower() end
	return v
end

-- A value as the AI reads it (and the apply preview shows it).
function App:AiValue(def, v)
	local t = def.type
	if t == "bool" then return v and "on" or "off" end
	if v == nil then return "(not set)" end
	if t == "number" then return tonumber(v) and string.format(numFmt(def), v) or tostring(v) end
	if t == "choice" then
		for _, c in ipairs(def.choices or {}) do
			if c.value == v then
				local w, text = choiceWord(c), plain(c.text)
				return w:lower() == text:lower() and w or (w .. " (" .. text .. ")")
			end
		end
		return tostring(v)
	end
	if t == "color" then
		if type(v) ~= "table" then return tostring(v) end
		local n, parts = def.hasAlpha and 4 or 3, {}
		for i = 1, n do parts[i] = short(tonumber(v[i]) or 1) end
		return table.concat(parts, " ") .. " (#" .. hex({ tonumber(v[1]) or 0, tonumber(v[2]) or 0, tonumber(v[3]) or 0 }) .. ")"
	end
	return '"' .. plain(v) .. '"'
end

-- What a setting takes, for the AI.
function App:AiType(def)
	local t = def.type
	if t == "bool" then return "On/off" end
	if t == "number" then
		return "Number " .. short(def.min) .. " to " .. short(def.max) .. (def.step and (", step " .. short(def.step)) or "")
	end
	if t == "choice" then
		local list = {}
		for _, c in ipairs(def.choices or {}) do
			local w, text = choiceWord(c), plain(c.text)
			list[#list + 1] = w:lower() == text:lower() and w or (w .. " = " .. text)
		end
		return "Choice: " .. table.concat(list, "; ")
	end
	if t == "color" then
		return def.hasAlpha and "Colour: hex rrggbb, or r g b a as 0-1 numbers (a = opacity)" or "Colour: hex rrggbb, or r g b as 0-1 numbers"
	end
	return "Text"
end

-- One setting: "- key: Label. Type. Now: value. Default: value. Help: ... Also found as: ..."
function App:AiSettingLine(def, label)
	local parts = { "- " .. def.key .. ": " .. sentence(label or def.label), self:AiType(def) .. "." }
	local ok, v = pcall(def.get)
	parts[#parts + 1] = "Now: " .. (ok and self:AiValue(def, v) or "(unknown)") .. "."
	local d = def.default
	if type(d) == "function" then
		local okD, dv = pcall(d)
		d = okD and dv or nil
	end
	if d ~= nil then parts[#parts + 1] = "Default: " .. self:AiValue(def, d) .. "." end
	if def.disabled then
		local okOff, off = pcall(def.disabled)
		if okOff and off then parts[#parts + 1] = "Greyed out in the window right now (depends on another setting)." end
	end
	if def.desc then parts[#parts + 1] = "Help: " .. sentence(def.desc) end
	local kw = def.keywords
	if type(kw) == "table" then kw = table.concat(kw, ", ") end
	if type(kw) == "string" and kw ~= "" then parts[#parts + 1] = "Also found as: " .. kw .. "." end
	return table.concat(parts, " ")
end

-- The settings grouped by page and heading as in the window: { { title = "Bars » Layout", defs = { ... } }, ... }.
-- Builds the window's pages (hidden) the way the search does; settings on no page come last.
function App:AiGroups()
	if not self.window and #self.order > 0 then
		local ok, err = pcall(self.CreateWindow, self)
		if not ok then
			local handler = geterrorhandler and geterrorhandler()
			if handler then handler(err) end
		end
	end
	if self.window and self.window.content then self:EnsureSearchIndex() end
	local groups, byPath, placed = {}, {}, {}
	for _, e in ipairs(self:SearchEntries()) do
		local def = e.info.key and self:GetSetting(e.info.key)
		if def and not placed[def] then
			placed[def] = true
			local g = byPath[e.path]
			if not g then
				g = { title = e.path, defs = {} }
				byPath[e.path] = g
				groups[#groups + 1] = g
			end
			g.defs[#g.defs + 1] = def
		end
	end
	local rest = {}
	for _, def in ipairs(self.settingOrder) do if not placed[def] then rest[#rest + 1] = def end end
	if #rest > 0 then groups[#groups + 1] = { title = #groups > 0 and "More settings" or "Settings", defs = rest, loose = true } end
	return groups
end

-- The whole text for the AI.
function App:AiText()
	local spec, s, p = self.spec, self.slash, self:SetPrefix()
	local out = {}
	local function add(line) out[#out + 1] = line or "" end
	add(self.name .. " " .. self:Version() .. ", a World of Warcraft addon: its settings, for an AI assistant.")
	add()
	local about = spec.aiAbout and sentence(spec.aiAbout)
	if not about then
		about = sentence(spec.tagline or (self.name .. " is a World of Warcraft addon"))
		about = about .. (#self.order > 0
			and (" Its settings window opens with " .. s .. ", and every setting below can also be changed with a chat command.")
			or " Every setting below can be changed with a chat command.")
	end
	add(about)
	if spec.siteURL then add("Addon page: " .. spec.siteURL) end
	if spec.feedbackURL then add("Bugs and ideas: " .. spec.feedbackURL) end
	add()
	add("HOW TO ANSWER")
	add("The player says at the end what they want. Then:")
	add("- Answer with chat commands only, one per line, using exactly these setting keys and allowed values. A setting command is: " .. p .. "<key> <value>")
	add("- Explain briefly what each line does, on its own line starting with # just above the command.")
	add("- Don't invent settings, keys or values. If something can't be done with these settings, say so.")
	add("- Give all the lines together in one block: the player pastes that block into the apply window (" .. s .. " apply), "
		.. "which skips blank lines and lines starting with #, shows every change and then applies them.")
	add("- To fit it in one chat line instead, join the changes after set with \" ; \": " .. s .. " set <key> <value> ; <key> <value>")
	add("- The apply window only changes settings (and on/off, lock/unlock). The other commands at the end have to be typed in chat, one at a time: say so if your answer needs one.")
	add("- Values: on or off; a number inside the range; one of the listed choice words; a colour as hex like ff8040 or as 0-1 numbers like 1 0.5 0.25; text as it is.")
	add()
	add("SETTINGS (key: label. Type. Current value. Default, when known.)")
	for _, g in ipairs(self:AiGroups()) do
		add()
		add(plain(g.title) .. ":")
		for _, def in ipairs(g.defs) do add(self:AiSettingLine(def, g.loose and (def.chatLabel or def.label) or def.label)) end
	end
	if self.onOff or self.movable then
		add()
		add("SWITCHES (the apply window runs these too)")
		if self.onOff then
			local ok, on = pcall(self.onOff.get)
			add("- " .. s .. " on / off / toggle: " .. sentence(self.onOff.label or self.name) .. " Now: " .. (ok and (on and "on" or "off") or "?") .. ".")
		end
		if self.movable then
			local ok, locked = pcall(self.movable.get)
			add("- " .. s .. " unlock / lock: move " .. sentence(self.movable.what or "it") .. " Now: " .. (ok and (locked and "locked" or "unlocked") or "?") .. ".")
		end
	end
	add()
	add("OTHER COMMANDS (chat only, one at a time; the apply window doesn't run these)")
	for _, c in ipairs(self.commandOrder) do
		if not c.hidden then add("- " .. s .. " " .. plain(c.usage) .. ": " .. sentence(c.desc or "")) end
	end
	local shared = { s .. " (the settings window)", s .. " help", s .. " get [key]", s .. " status", s .. " version" }
	if self.spec.chatSearch ~= false then shared[#shared + 1] = s .. " search <words>" end
	if self.resetOrder and #self.resetOrder > 0 then shared[#shared + 1] = s .. " " .. resetUsage(self) .. " (back to defaults; asks first)" end
	shared[#shared + 1] = s .. " ai (this text)"
	shared[#shared + 1] = s .. " apply (the apply window)"
	add("- Shared by every EverlookDB addon: " .. table.concat(shared, ", ") .. ".")
	if self.aiExtraFn then
		local ok, extra = pcall(self.aiExtraFn, self)
		if not ok then
			local handler = geterrorhandler and geterrorhandler()
			if handler then handler(extra) end
		elseif type(extra) == "string" and extra ~= "" then
			add()
			add("MORE ABOUT " .. self.name:upper())
			add(plain(extra))
		end
	end
	add()
	add("WHAT THE PLAYER WANTS")
	add("(written below)")
	-- a lone "|" starts an escape code in an edit box: write "or"-bars as slashes
	return (table.concat(out, "\n"):gsub("%s*|%s*", " / "))
end

-- Same value? (colours by component, numbers within a hair)
local function sameValue(def, a, b)
	if def.type == "color" then
		if type(a) ~= "table" or type(b) ~= "table" then return false end
		for i = 1, 4 do
			if math.abs((tonumber(a[i]) or 1) - (tonumber(b[i]) or 1)) > 0.002 then return false end
		end
		return true
	end
	if def.type == "number" then return tonumber(a) ~= nil and tonumber(b) ~= nil and math.abs(a - b) < 1e-9 end
	if def.type == "bool" then return (a and true or false) == (b and true or false) end
	return a == b
end

-- Read the AI's answer without changing anything. One row per change, read or problem:
-- { n (line number), line, kind = "set" | "get" | "onoff" | "lock", label, key, def, prepare, old, value, same }
-- or { n, line, err, hint }. Lines may start with the slash command (or an alias) or not; blank lines, lines
-- starting with # and code fences are skipped; "set a 1 ; b 2" gives two rows.
function App:PlanApply(text)
	local app, rows, n = self, {}, 0
	local slashes = { [self.slash:lower()] = true }
	for _, a in ipairs(self.spec.aliases or {}) do slashes[a:lower()] = true end
	local function bad(line, err, hint) rows[#rows + 1] = { n = n, line = line, err = err, hint = hint } end

	local function setRow(line, body)
		local key, value = body:match("^(%S+)%s*(.*)$")
		local def, prepare = app:ResolveSetting(key)
		if not def then
			if type(prepare) == "string" then return bad(line, prepare) end
			local near, isSetting = app:Suggest(key)
			return bad(line, "no setting called '" .. key .. "'",
				near and isSetting and ("Did you mean " .. app:SetPrefix() .. near .. (value ~= "" and (" " .. value) or "") .. "?") or nil)
		end
		local undo = prepare and prepare()
		local okGet, old = pcall(def.get)
		local row = { n = n, line = line, key = key, def = def, prepare = prepare, label = def.chatLabel or def.label, old = okGet and old or nil }
		if U.Trim(value) == "" then
			row.kind = "get"
		else
			local ok, v = app:Parse(def, value)
			if ok then
				row.kind, row.value = "set", v
				row.same = okGet and sameValue(def, old, v)
			else
				row.err = row.label .. ": " .. v
				row.hint = "Example: " .. app:SetPrefix() .. key .. " " .. app:Example(def)
			end
		end
		if type(undo) == "function" then undo() end
		rows[#rows + 1] = row
	end

	local function planLine(line)
		local body = U.Trim((line:gsub("^[-*]%s+", ""):gsub("^%d+[%.%)]%s+", "")))
		body = U.Trim((body:gsub("^`(.*)`$", "%1")))
		if body:sub(1, 1) == "/" then
			local cmd, after = body:match("^(%S+)%s*(.*)$")
			if not slashes[cmd:lower()] then return bad(line, cmd .. " is another addon's command: paste it into " .. cmd .. " apply") end
			body = after
			if body == "" then return bad(line, "that opens the window; nothing to apply") end
		end
		local word, rest = body:match("^(%S+)%s*(.*)$")
		local w = word:lower()
		if app.commands[w] then
			return bad(line, "'" .. word .. "' is a command, not a setting change: type it in chat if you want it")
		end
		if w == "set" then
			local parts = UI.SplitSets(rest)
			if #parts == 0 then return bad(line, "set what? " .. app:SetPrefix() .. "<setting> <value>") end
			for _, part in ipairs(parts) do setRow(line, part) end
			return
		end
		if w == "get" then
			if rest == "" then return bad(line, "get which setting?") end
			return setRow(line, rest:match("^(%S+)"))
		end
		if w == "on" or w == "off" or w == "toggle" then
			if rest ~= "" then
				local key = rest:match("^(%S+)")
				local def = app:ResolveSetting(key)
				if def and def.type ~= "bool" then
					return bad(line, (def.chatLabel or def.label) .. " isn't on/off", "Example: " .. app:SetPrefix() .. key .. " " .. app:Example(def))
				end
				return setRow(line, key .. " " .. w)
			end
			local o = app.onOff
			if not o then return bad(line, app.name .. " has no on/off switch of its own; switch a setting instead") end
			local ok, cur = pcall(o.get)
			cur = ok and cur and true or false
			local v
			if w == "toggle" then v = not cur else v = w == "on" end
			rows[#rows + 1] = { n = n, line = line, kind = "onoff", label = o.label or app.name, old = cur, value = v, same = cur == v }
			return
		end
		if w == "lock" or w == "unlock" or w == "move" then
			local m = app.movable
			if not m then return bad(line, app.name .. " has nothing to lock or unlock") end
			local ok, cur = pcall(m.get)
			cur = ok and cur and true or false
			local v
			if w == "move" then v = not cur else v = w == "lock" end
			rows[#rows + 1] = { n = n, line = line, kind = "lock", label = "Locked (" .. (m.what or "moving") .. ")", old = cur, value = v, same = cur == v }
			return
		end
		if w == "reset" then return bad(line, "reset isn't run from here; type it in chat if you mean it (it asks first)") end
		if not app:ResolveSetting(word) and (UI.Verbs[w] or w == "help" or w == "?" or w == "commands") then
			return bad(line, "'" .. word .. "' isn't a setting change: type it in chat if you want it")
		end
		return setRow(line, body)
	end

	local src = tostring(text or ""):gsub("\r\n?", "\n")
	for raw in (src .. "\n"):gmatch("([^\n]*)\n") do
		n = n + 1
		local line = U.Trim(raw)
		if line ~= "" and line:sub(1, 1) ~= "#" and line:sub(1, 3) ~= "```" then planLine(line) end
	end
	return rows
end

-- A preview line for a row and its colour.
function App:PreviewLine(r)
	local T = self.T
	if r.err then
		return "Line " .. r.n .. ": " .. r.line .. "  -  " .. r.err .. "." .. (r.hint and (" " .. r.hint) or ""), T.danger
	end
	local function show(v)
		if r.kind == "onoff" then return v and "on" or "off" end
		if r.kind == "lock" then return v and "locked" or "unlocked" end
		return self:AiValue(r.def, v)
	end
	local name = plain(r.label) .. (r.key and (" (" .. r.key .. ")") or "")
	if r.kind == "get" then return name .. ": " .. show(r.old) .. " (only shown)", T.muted end
	if r.same then return name .. ": already " .. show(r.value), T.muted end
	return name .. ": " .. show(r.old) .. " -> " .. show(r.value), T.text
end

-- Apply the rows of PlanApply: setting changes, on/off and lock. Returns changed, skipped (problem lines).
function App:RunPlan(rows)
	local changed, skipped = 0, 0
	for _, r in ipairs(rows) do
		if r.err then
			skipped = skipped + 1
		elseif r.kind ~= "get" and not r.same then
			local ok, err = pcall(function()
				if r.kind == "set" then
					local undo = r.prepare and r.prepare()
					local okSet, e = pcall(function()
						r.def.set(r.value)
						if r.def.after then r.def.after(r.value) end
					end)
					if type(undo) == "function" then undo() end
					if not okSet then error(e, 0) end
				elseif r.kind == "onoff" then
					self.onOff.set(r.value)
				elseif r.kind == "lock" then
					self.movable.set(r.value)
				end
			end)
			if ok then
				changed = changed + 1
			else
				skipped = skipped + 1
				r.err = tostring(err)
				local handler = geterrorhandler and geterrorhandler()
				if handler then handler(err) end
			end
		end
	end
	self:Refresh()
	return changed, skipped
end

-- Plan and apply `text`; prints and returns "Changed 5 settings, 1 line skipped."
function App:ApplyText(text)
	local rows = self:PlanApply(text)
	local changed, skipped = self:RunPlan(rows)
	local msg = ("Changed %d setting%s"):format(changed, changed == 1 and "" or "s")
	if skipped > 0 then msg = msg .. (", %d line%s skipped"):format(skipped, skipped == 1 and "" or "s") end
	msg = msg .. "."
	self:Print(msg)
	return changed, skipped, rows, msg
end

-- A small movable window in the settings window's look. onShow(f) runs when it opens.
local function Dialog(app, suffix, W, H, title, intro, onShow)
	local T = app.T
	local f = CreateFrame("Frame", app.frameName .. suffix, UIParent)
	f.eluiTheme, f.app = T, app
	f:SetSize(W, H)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) self:StartMoving() end)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	f:Hide()
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	WindowChrome(f, T)
	local t = Text(f, T.fontHuge, T.text)
	t:SetPoint("TOPLEFT", T.pad, -14)
	t:SetPoint("RIGHT", f, "RIGHT", -44, 0)
	t:SetWordWrap(false)
	t:SetText(title)
	local sub = Text(f, T.fontSmall + 1, T.muted)
	sub:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
	sub:SetWidth(W - 2 * T.pad)
	sub:SetText(intro)
	f.title, f.intro = t, sub
	f.top = 14 + 22 + 8 + math.ceil(sub:GetStringHeight() or 12) + 14
	f.close = CloseButton(f, T)
	f:SetScript("OnShow", function(self)
		-- over the settings window it was opened from (same strata): above its deepest controls
		local w = app.window
		if w and w:IsShown() and w.GetFrameLevel then self:SetFrameLevel(math.min(9000, (w:GetFrameLevel() or 0) + 100)) end
		self:Raise()
		if onShow then onShow(self) end
	end)
	UI.CloseOnEscape(f)
	return f
end

-- "/x ai": the text for the AI, selected for Ctrl+C.
function App:ShowAiHelp()
	local f = self.aiWindow
	if not f then
		local app, T = self, self.T
		local W, H = 640, 540
		f = Dialog(self, "AiHelpWindow", W, H, "Get help from AI to configure " .. self.name,
			"1. Press Ctrl+C to copy the text below (it is already selected).\n"
			.. "2. Paste it into Claude or another AI assistant and say what you want, e.g. \"bigger text, and put it at the bottom\".\n"
			.. "3. Paste the AI's answer into the apply window (" .. self.slash .. " apply, or the button below).")
		local area = UI.TextArea(f, W - 2 * T.pad, H - f.top - 62)
		area:SetPoint("TOPLEFT", T.pad, -f.top)
		local box = area.box
		box:SetMaxLetters(0)
		f.area, f.box = area, box
		-- read-only: typing puts the text back (and selects it again)
		box:SetScript("OnTextChanged", function(self, user)
			if user and self:GetText() ~= f.text then self:SetText(f.text or ""); self:HighlightText() end
		end)
		box:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
		box:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Hide() end)
		box:SetScript("OnKeyUp", function(_, key)
			if key == "C" and IsControlKeyDown() then
				f.copied = true
				f.status:SetText("Copied. Paste it into your AI, then its answer into " .. app.slash .. " apply.")
				f.status:SetTextColor(rgba(T.ok))
			end
		end)
		f.status = Text(f, T.font, T.accent)
		f.status:SetPoint("BOTTOMLEFT", T.pad, 21)
		f.status:SetPoint("RIGHT", f, "RIGHT", -(T.pad + 90 + 8 + 180 + 12), 0)
		f.status:SetWordWrap(false)
		local closeB = UI.Button(f, CLOSE or "Close", function() f:Hide() end, 90)
		closeB:SetPoint("BOTTOMRIGHT", -T.pad, 14)
		local applyB = UI.Button(f, "Open the apply window", function() app:ShowApply() end, 180)
		applyB:SetPoint("RIGHT", closeB, "LEFT", -8, 0)
		f.applyButton = applyB
		f:HookScript("OnHide", function() box:ClearFocus() end)
		self.aiWindow = f
	end
	f:Show()
	f.text = self:AiText()
	f.copied = nil
	f.box:SetText(f.text)
	f.box:SetCursorPosition(0)
	f.box:SetFocus()
	f.box:HighlightText()
	f.status:SetText("Press Ctrl+C to copy.")
	f.status:SetTextColor(rgba(self.T.accent))
	return f
end

-- "/x apply [text]": paste the AI's answer, see each change, Apply. A chat line's " ; " become separate lines.
function App:ShowApply(text)
	local f = self.applyWindow
	if not f then
		local app, T = self, self.T
		local W, H = 640, 580
		f = Dialog(self, "AiApplyWindow", W, H, "Apply the AI's commands",
			"Paste the AI's commands below (Ctrl+V), one per line, with or without " .. self.slash .. ". Blank lines and lines starting "
			.. "with # are skipped. Only setting changes, on/off and lock/unlock run from here, and you see each change before Apply.")
		local inputH = 160
		local input = UI.TextArea(f, W - 2 * T.pad, inputH)
		input:SetPoint("TOPLEFT", T.pad, -f.top)
		local box = input.box
		box:SetMaxLetters(0)
		f.input, f.box = input, box
		local hint = Text(input, T.font, T.muted)
		hint:SetPoint("TOPLEFT", 8, -7)
		hint:SetText("Paste the AI's commands here")
		f.hint = hint
		local function updateHint() hint:SetShown((box:GetText() or "") == "" and not box:HasFocus()) end
		box:HookScript("OnEditFocusGained", updateHint)
		box:HookScript("OnEditFocusLost", updateHint)
		box:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Hide() end)

		local label = Text(f, T.font, T.text)
		label:SetPoint("TOPLEFT", input, "BOTTOMLEFT", 0, -12)
		label:SetText("Preview")
		local holder = CreateFrame("Frame", nil, f)
		holder:SetPoint("TOPLEFT", input, "BOTTOMLEFT", 0, -34)
		holder:SetSize(W - 2 * T.pad, H - f.top - inputH - 34 - 62)
		U.Solid(holder, "BACKGROUND", rgba(T.surface)):SetAllPoints()
		U.Border(holder, 1, rgba(T.border))
		local scroll = CreateFrame("ScrollFrame", nil, holder)
		scroll:SetPoint("TOPLEFT", 8, -6)
		scroll:SetPoint("BOTTOMRIGHT", -(BAR_W + 8), 6)
		local innerW = W - 2 * T.pad - BAR_W - 16
		local child = CreateFrame("Frame", nil, scroll)
		child:SetSize(innerW, 1)
		scroll:SetScrollChild(child)
		local fs = Text(child, T.fontSmall + 1, T.text)
		fs:SetPoint("TOPLEFT")
		fs:SetWidth(innerW)
		fs:SetSpacing(3)
		f.preview = fs
		local track, update = AttachScrollBar(scroll, child, holder, 30)
		track:SetPoint("TOPRIGHT", -3, -3)
		track:SetPoint("BOTTOMRIGHT", -3, 3)

		f.summary = Text(f, T.font, T.muted)
		f.summary:SetPoint("BOTTOMLEFT", T.pad, 21)
		f.summary:SetPoint("RIGHT", f, "RIGHT", -(T.pad + 120 + 8 + 90 + 12), 0)
		f.summary:SetWordWrap(false)
		local applyB = UI.Button(f, "Apply", function() f.Apply() end, 120, "accent")
		applyB:SetPoint("BOTTOMRIGHT", -T.pad, 14)
		local clearB = UI.Button(f, "Clear", function() box:SetText(""); f.Preview(); box:SetFocus() end, 90)
		clearB:SetPoint("RIGHT", applyB, "LEFT", -8, 0)
		f.applyButton, f.clearButton = applyB, clearB

		-- result: the line to show instead of the count (after Apply)
		function f.Preview(result)
			updateHint()
			local rows = app:PlanApply(box:GetText() or "")
			local lines, changes, problems = {}, 0, 0
			for _, r in ipairs(rows) do
				local l, c = app:PreviewLine(r)
				lines[#lines + 1] = "|cff" .. hex(c) .. U.Escape(l) .. "|r"
				if r.err then problems = problems + 1 elseif r.kind ~= "get" and not r.same then changes = changes + 1 end
			end
			if #lines == 0 then lines[1] = "|cff" .. hex(T.muted) .. "Nothing to apply yet. Each change shows here before you apply it.|r" end
			fs:SetText(table.concat(lines, "\n"))
			child:SetHeight(math.max(1, math.ceil((fs:GetStringHeight() or 0) + 4)))
			update()
			applyB:SetUsable(changes > 0)
			f.rows, f.changes, f.problems = rows, changes, problems
			if result then
				f.summary:SetText(result)
				f.summary:SetTextColor(rgba(T.ok))
			else
				local msg = changes == 0 and "No changes yet." or ("%d change%s ready."):format(changes, changes == 1 and "" or "s")
				if problems > 0 then msg = msg .. (" %d line%s will be skipped."):format(problems, problems == 1 and "" or "s") end
				f.summary:SetText(msg)
				f.summary:SetTextColor(rgba(problems > 0 and T.danger or T.muted))
			end
		end
		function f.Apply()
			local _, _, _, msg = app:ApplyText(box:GetText() or "")
			f.Preview(msg)
		end
		-- the preview follows the text, once per frame at most
		local pending
		box:SetScript("OnTextChanged", function()
			updateHint()
			if pending then return end
			pending = true
			C_Timer.After(0, function()
				pending = nil
				if f:IsShown() then f.Preview() end
			end)
		end)
		f:HookScript("OnHide", function() box:ClearFocus() end)
		self.applyWindow = f
	end
	f:Show()
	if text then f.box:SetText(table.concat(UI.SplitSets(text), "\n")) end
	f.Preview()
	f.box:SetFocus()
	return f
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
