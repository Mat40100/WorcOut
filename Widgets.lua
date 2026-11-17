-- W'orc out - widget kit. Style: dark forged iron, ember and gold.
local _, W = ...
local UI = {}
W.UI = UI

UI.C = {
  bg       = { 0.060, 0.052, 0.048, 0.98 },
  surface  = { 0.095, 0.085, 0.080, 1 },
  surface2 = { 0.135, 0.120, 0.110, 1 },
  hover    = { 0.190, 0.160, 0.140, 1 },
  border   = { 0.240, 0.200, 0.165, 1 },
  borderHi = { 0.620, 0.470, 0.220, 1 },
  text     = { 0.970, 0.940, 0.890, 1 },
  muted    = { 0.640, 0.590, 0.530, 1 },
  accent   = { 0.980, 0.560, 0.160, 1 },   -- ember
  accentHi = { 1.000, 0.700, 0.300, 1 },
  accentLo = { 0.980, 0.560, 0.160, 0.10 },
  gold     = { 1.000, 0.830, 0.380, 1 },
  blood    = { 0.700, 0.100, 0.080, 1 },
  danger   = { 0.900, 0.330, 0.280, 1 },
  ink      = { 0.050, 0.025, 0.000, 1 },   -- text on ember
}
local C = UI.C

UI.FONT = "Fonts\\ARIALN.TTF"
UI.FONT_TITLE = "Fonts\\FRIZQT__.TTF"

local function color(tex, c) tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
UI.Color = color

local function rgba(c, a) return CreateColor(c[1], c[2], c[3], a or c[4] or 1) end
-- gradient from `top` to `bottom` (or left to right when horizontal)
function UI.Gradient(tex, top, bottom, horizontal)
  tex:SetColorTexture(1, 1, 1, 1)
  if horizontal then tex:SetGradient("HORIZONTAL", rgba(top), rgba(bottom))
  else tex:SetGradient("VERTICAL", rgba(bottom), rgba(top)) end
end
local grad = UI.Gradient

-- Box with 1px border ----------------------------------------------------------
function UI.Box(parent, bg, border, name)
  local f = CreateFrame("Frame", name, parent)
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints()
  color(f.bg, bg or C.surface)
  if border ~= false then
    f.edges = {}
    local function edge(p1, p2, horiz)
      local t = f:CreateTexture(nil, "BORDER")
      color(t, border or C.border)
      t:SetPoint(p1); t:SetPoint(p2)
      if horiz then t:SetHeight(1) else t:SetWidth(1) end
      f.edges[#f.edges + 1] = t
    end
    edge("TOPLEFT", "TOPRIGHT", true)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    edge("TOPLEFT", "BOTTOMLEFT", false)
    edge("TOPRIGHT", "BOTTOMRIGHT", false)
  end
  function f:SetBorder(c) for _, e in ipairs(self.edges or {}) do color(e, c) end end
  function f:SetFill(c) color(self.bg, c) end
  function f:SetFillGradient(top, bottom) grad(self.bg, top, bottom) end
  return f
end

-- Gold corner brackets ------------------------------------------------------------
function UI.Corners(f, size, c, thick)
  size, c, thick = size or 12, c or C.gold, thick or 2
  for _, p in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
    local h = f:CreateTexture(nil, "OVERLAY"); color(h, c)
    h:SetSize(size, thick); h:SetPoint(p)
    local v = f:CreateTexture(nil, "OVERLAY"); color(v, c)
    v:SetSize(thick, size); v:SetPoint(p)
  end
end

-- Thin line fading out at both ends --------------------------------------------------
function UI.Rule(parent, w, c, layer)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(w, 1)
  c = c or C.gold
  local l = f:CreateTexture(nil, layer or "ARTWORK")
  l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMRIGHT", f, "BOTTOM")
  grad(l, { c[1], c[2], c[3], 0 }, c, true)
  local r = f:CreateTexture(nil, layer or "ARTWORK")
  r:SetPoint("TOPLEFT", f, "TOP"); r:SetPoint("BOTTOMRIGHT")
  grad(r, c, { c[1], c[2], c[3], 0 }, true)
  return f
end

-- Text --------------------------------------------------------------------------
function UI.Text(parent, size, c, title, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  fs:SetFont(title and UI.FONT_TITLE or UI.FONT, size or 13, "")
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 0.8)
  c = c or C.text
  fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
  fs:SetJustifyH("LEFT")
  return fs
end

-- Spaced small-caps label, e.g. "W O R K O U T   T I M E"
function UI.Kicker(parent, size, c)
  local fs = UI.Text(parent, size or 11, c or C.gold, true)
  local set = fs.SetText
  fs.SetText = function(self, t) set(self, ((t or ""):upper():gsub("(.)", "%1 "):sub(1, -2))) end
  return fs
end

-- Button --------------------------------------------------------------------------
-- style: "primary" (ember), "ghost", "danger"
function UI.Button(parent, label, style, w, h, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w or 120, h or 32)
  style = style or "ghost"
  local box = UI.Box(b, C.surface2, style == "primary" and C.gold or (style == "danger" and C.danger or C.border))
  box:SetAllPoints()
  b.box = box
  local function paint(hover)
    if style == "primary" then
      box:SetFillGradient(hover and C.accentHi or C.accent, hover and C.accent or { 0.78, 0.36, 0.08, 1 })
    else
      box:SetFillGradient(hover and C.hover or C.surface2, hover and C.surface2 or C.surface)
    end
  end
  paint(false)
  if style == "primary" then
    local shine = box:CreateTexture(nil, "ARTWORK")
    shine:SetPoint("TOPLEFT", 1, -1); shine:SetPoint("TOPRIGHT", -1, -1); shine:SetHeight(1)
    color(shine, { 1, 0.9, 0.6, 0.6 })
  end
  b.label = UI.Text(box, style == "primary" and 15 or 14,
    style == "primary" and C.ink or (style == "danger" and C.danger or C.text), style == "primary")
  if style == "primary" then b.label:SetShadowColor(1, 0.85, 0.6, 0.35); b.label:SetShadowOffset(0, -1) end
  b.label:SetPoint("CENTER")
  b.label:SetJustifyH("CENTER")
  b.label:SetText(label)
  b:SetScript("OnEnter", function() paint(true) end)
  b:SetScript("OnLeave", function() paint(false) end)
  b:SetScript("OnMouseDown", function() b.label:SetPoint("CENTER", 0, -1) end)
  b:SetScript("OnMouseUp", function() b.label:SetPoint("CENTER", 0, 0) end)
  b:SetScript("OnDisable", function() b.label:SetAlpha(0.6) end)
  b:SetScript("OnEnable", function() b.label:SetAlpha(1) end)
  if onClick then b:SetScript("OnClick", onClick) end
  function b:SetLabel(t) self.label:SetText(t) end
  return b
end

-- Icon button (square, glyph) ------------------------------------------------
function UI.IconButton(parent, size, glyph, onClick, tip)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  local box = UI.Box(b, { 0, 0, 0, 0 }, false)
  box:SetAllPoints()
  b.text = UI.Text(box, size * 0.6, C.muted)
  b.text:SetPoint("CENTER")
  b.text:SetText(glyph)
  b:SetScript("OnEnter", function()
    box:SetFill(C.hover); b.text:SetTextColor(unpack(C.gold))
    if tip then GameTooltip:SetOwner(b, "ANCHOR_TOP"); GameTooltip:SetText(tip); GameTooltip:Show() end
  end)
  b:SetScript("OnLeave", function()
    box:SetFill({ 0, 0, 0, 0 }); b.text:SetTextColor(unpack(C.muted)); GameTooltip:Hide()
  end)
  b:SetScript("OnClick", onClick)
  return b
end

-- Switch ----------------------------------------------------------------------------
function UI.Switch(parent, get, set)
  local s = CreateFrame("Button", nil, parent)
  s:SetSize(40, 20)
  local box = UI.Box(s, C.surface2, C.border)
  box:SetAllPoints()
  local knob = box:CreateTexture(nil, "ARTWORK")
  knob:SetSize(14, 14)
  function s:Refresh()
    local on = get()
    if on then box:SetFillGradient(C.accent, { 0.70, 0.32, 0.06, 1 }); box:SetBorder(C.gold)
    else box:SetFill(C.surface2); box:SetBorder(C.border) end
    if on then grad(knob, { 1, 0.97, 0.88, 1 }, { 0.92, 0.82, 0.62, 1 }) else color(knob, C.muted) end
    knob:ClearAllPoints()
    knob:SetPoint(on and "RIGHT" or "LEFT", on and -3 or 3, 0)
  end
  s:SetScript("OnClick", function(self) set(not get()); self:Refresh() end)
  return s
end

-- Stepper: [-] value [+] ---------------------------------------------------------------
function UI.Stepper(parent, w, get, set, min, max, step, fmt)
  local f = UI.Box(parent, C.surface, C.border)
  f:SetSize(w or 96, 26)
  local val = UI.Text(f, 14, C.text)
  val:SetPoint("CENTER")
  val:SetJustifyH("CENTER")
  local function refresh() val:SetText(fmt and fmt(get()) or tostring(get())) end
  local function bump(d)
    local v = math.min(max, math.max(min, get() + d))
    set(math.floor(v / step + 0.5) * step); refresh()
  end
  local minus = UI.IconButton(f, 24, "-", function() bump(-step) end)
  minus:SetPoint("LEFT", 1, 0)
  local plus = UI.IconButton(f, 24, "+", function() bump(step) end)
  plus:SetPoint("RIGHT", -1, 0)
  f.Refresh = refresh
  return f
end

-- Segmented control ----------------------------------------------------------------------
function UI.Segmented(parent, options, get, set, w)
  local f = UI.Box(parent, C.surface, C.border)
  local segW = (w or 240) / #options
  f:SetSize(segW * #options, 28)
  local btns = {}
  for i, o in ipairs(options) do
    local b = CreateFrame("Button", nil, f)
    b:SetSize(segW - 4, 22)
    b:SetPoint("LEFT", (i - 1) * segW + 2, 0)
    b.bg = b:CreateTexture(nil, "ARTWORK")
    b.bg:SetAllPoints()
    b.t = UI.Text(b, 13)
    b.t:SetPoint("CENTER"); b.t:SetJustifyH("CENTER"); b.t:SetText(o.label)
    b:SetScript("OnClick", function() set(o.value); f:Refresh() end)
    btns[i] = b
  end
  function f:Refresh()
    for i, o in ipairs(options) do
      local sel = get() == o.value
      if sel then grad(btns[i].bg, C.accent, { 0.75, 0.34, 0.07, 1 }) else color(btns[i].bg, { 0, 0, 0, 0 }) end
      local c = sel and C.ink or C.muted
      btns[i].t:SetTextColor(c[1], c[2], c[3])
    end
  end
  return f
end

-- Progress bar -------------------------------------------------------------------------------
function UI.Progress(parent, w, h, c)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(w, h or 4)
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(); color(bg, { 0, 0, 0, 0.5 })
  local fill = f:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT"); fill:SetPoint("BOTTOMLEFT")
  grad(fill, { 0.70, 0.20, 0.05, 1 }, c or C.accent, true)
  local tip = f:CreateTexture(nil, "OVERLAY")
  tip:SetSize(2, h or 4); tip:SetPoint("RIGHT", fill, "RIGHT"); color(tip, C.gold)
  function f:SetProgress(p)
    p = math.max(0, math.min(1, p or 0))
    fill:SetWidth(math.max(0.01, self:GetWidth() * p))
    fill:SetShown(p > 0); tip:SetShown(p > 0 and p < 1)
  end
  f:SetProgress(0)
  return f
end

-- Icon with gold frame ---------------------------------------------------------------------
function UI.Icon(parent, size, path)
  local f = UI.Box(parent, { 0, 0, 0, 1 }, C.borderHi)
  f:SetSize(size, size)
  f.tex = f:CreateTexture(nil, "ARTWORK")
  f.tex:SetPoint("TOPLEFT", 2, -2); f.tex:SetPoint("BOTTOMRIGHT", -2, 2)
  f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  if path then f.tex:SetTexture(path) end
  return f
end

-- Draggable window shell -------------------------------------------------------------------------
function UI.Window(name, w, h, title)
  local f = UI.Box(UIParent, C.bg, C.border, name)
  f:SetSize(w, h)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  tinsert(UISpecialFrames, name)
  f:SetFillGradient(C.bg, { 0.035, 0.030, 0.028, 0.98 })

  -- warm glow behind the header
  local glow = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  glow:SetPoint("TOPLEFT", 1, -1); glow:SetPoint("TOPRIGHT", -1, -1); glow:SetHeight(math.min(160, h * 0.4))
  grad(glow, { C.blood[1], C.blood[2], C.blood[3], 0.35 }, { C.blood[1], C.blood[2], C.blood[3], 0 })

  -- gold rule on top + corner brackets
  local rule = UI.Rule(f, w - 2, C.gold)
  rule:SetPoint("TOP", 0, -1)
  UI.Corners(f, 14, C.gold, 2)

  if title then
    f.title = UI.Text(f, 15, C.gold, true)
    f.title:SetPoint("TOPLEFT", 20, -18)
    f.title:SetText(title)
  end
  f.close = UI.IconButton(f, 26, "x", function() f:Hide() end, "Close")
  f.close:SetPoint("TOPRIGHT", -10, -10)
  f:Hide()
  return f
end
