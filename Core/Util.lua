-- Lattice: generic helpers (tables, colors, drawing).
local _, ns = ...
local U = {}
ns.Util = U

------------------------------------------------------------------------
-- Tables
------------------------------------------------------------------------
function U.CopyTable(src)
	if type(src) ~= "table" then return src end
	local t = {}
	for k, v in pairs(src) do
		t[k] = U.CopyTable(v)
	end
	return t
end

-- Fill missing keys in `dst` from `defaults`, recursively. Never overwrites.
-- Arrays (tables with [1]) are treated as values: copied only when missing.
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

-- Remove keys equal to defaults so saved variables and export strings stay small.
function U.StripDefaults(t, defaults)
	if type(t) ~= "table" or type(defaults) ~= "table" then return end
	for k, v in pairs(defaults) do
		local cur = t[k]
		if type(v) == "table" and type(cur) == "table" and v[1] == nil then
			U.StripDefaults(cur, v)
			if next(cur) == nil then t[k] = nil end
		elseif U.DeepEqual(cur, v) then
			t[k] = nil
		end
	end
end

function U.DeepEqual(a, b)
	if a == b then return true end
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	for k, v in pairs(a) do
		if not U.DeepEqual(v, b[k]) then return false end
	end
	for k in pairs(b) do
		if a[k] == nil then return false end
	end
	return true
end

-- Path access: U.Get(tbl, "a.b.c"), U.Set(tbl, "a.b.c", value)
function U.Get(t, path)
	for key in string.gmatch(path, "[^%.]+") do
		if type(t) ~= "table" then return nil end
		t = t[tonumber(key) or key]
	end
	return t
end

function U.Set(t, path, value)
	local keys = {}
	for key in string.gmatch(path, "[^%.]+") do
		keys[#keys + 1] = tonumber(key) or key
	end
	for i = 1, #keys - 1 do
		local k = keys[i]
		if type(t[k]) ~= "table" then t[k] = {} end
		t = t[k]
	end
	t[keys[#keys]] = value
end

function U.TableKeysSorted(t)
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	return keys
end

------------------------------------------------------------------------
-- Colors
------------------------------------------------------------------------
function U.Hex(c)
	return string.format("%02x%02x%02x", (c.r or c[1]) * 255, (c.g or c[2]) * 255, (c.b or c[3]) * 255)
end

function U.ClassColor(classFile)
	local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
	if c then return c.r, c.g, c.b end
	return 0.6, 0.6, 0.6
end

------------------------------------------------------------------------
-- Drawing helpers
------------------------------------------------------------------------
U.WHITE = "Interface\\Buttons\\WHITE8X8"

function U.Font()
	return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

function U.SetFont(fs, size, flags)
	local ok = fs:SetFont(U.Font(), size or 11, flags or "")
	if not ok then
		fs:SetFontObject(GameFontHighlightSmall)
	end
end

-- Solid texture filling a region.
function U.Solid(parent, layer, r, g, b, a, sublevel)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
	t:SetTexture(U.WHITE)
	t:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
	return t
end

-- 1px border made from 4 textures (avoids depending on backdrop templates).
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
		for _, key in ipairs({ "top", "bottom", "left", "right" }) do
			self[key]:SetVertexColor(r2, g2, b2, a2 or 1)
		end
	end

	function border:SetSize(px)
		self.top:SetHeight(px)
		self.bottom:SetHeight(px)
		self.left:SetWidth(px)
		self.right:SetWidth(px)
	end

	function border:SetShown(shown)
		for _, key in ipairs({ "top", "bottom", "left", "right" }) do
			self[key]:SetShown(shown)
		end
	end

	return border
end

-- Point names used by the indicator layout pickers.
U.POINTS = {
	"TOPLEFT", "TOP", "TOPRIGHT",
	"LEFT", "CENTER", "RIGHT",
	"BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT",
}
