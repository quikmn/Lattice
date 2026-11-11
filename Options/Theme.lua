-- Lattice options: shared palette and type scale.
local _, ns = ...

ns.Theme = {
	bg        = { 0.071, 0.078, 0.094, 0.97 }, -- window
	sidebar   = { 0.055, 0.060, 0.074, 1 },
	surface   = { 0.105, 0.114, 0.137, 1 },   -- cards / inputs
	surfaceHi = { 0.137, 0.149, 0.180, 1 },   -- hover
	border    = { 0.180, 0.196, 0.235, 1 },
	text      = { 0.902, 0.910, 0.933, 1 },
	muted     = { 0.553, 0.580, 0.639, 1 },
	accent    = { 0.353, 0.663, 1.000, 1 },   -- #5aa9ff
	accentDim = { 0.353, 0.663, 1.000, 0.18 },
	danger    = { 0.937, 0.365, 0.365, 1 },
	ok        = { 0.384, 0.812, 0.533, 1 },

	fontSmall = 10,
	font      = 12,
	fontTitle = 14,
	fontHuge  = 18,

	pad = 16,
	rowGap = 10,
}
