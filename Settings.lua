-- W'orc out - settings window and launcher button.
local _, W = ...
local UI, C = W.UI, W.UI.C

local WIN_W, WIN_H, NAV_W = 680, 540, 168
local f = UI.Window("WorcOutSettings", WIN_W, WIN_H)
W.settings = f

-- Sidebar ---------------------------------------------------------------------------
local nav = UI.Box(f, C.surface, false)
nav:SetPoint("TOPLEFT", 1, -3)
nav:SetPoint("BOTTOMLEFT", 1, 1)
nav:SetWidth(NAV_W)

local logo = UI.Text(nav, 20, C.gold, true)
logo:SetPoint("TOPLEFT", 18, -20)
logo:SetText("W'orc out")
local sub = UI.Text(nav, 12, C.muted)
sub:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -4)
sub:SetText("Workout while you play")

-- Master switch
local masterLabel = UI.Text(nav, 13, C.text)
masterLabel:SetPoint("BOTTOMLEFT", 18, 24)
local master
master = UI.Switch(nav, function() return W.db.enabled end, function(v)
  W.db.enabled = v
  W:Fire("SETTINGS")
end)
master:SetPoint("BOTTOMRIGHT", -18, 22)

-- Content area -------------------------------------------------------------------------
local content = CreateFrame("Frame", nil, f)
content:SetPoint("TOPLEFT", NAV_W + 24, -20)
content:SetPoint("BOTTOMRIGHT", -24, 20)
local CW = WIN_W - NAV_W - 48

local pageTitle = UI.Text(content, 22, C.text, true)
pageTitle:SetPoint("TOPLEFT", 0, 0)
local pageSub = UI.Text(content, 13, C.muted)
pageSub:SetPoint("TOPLEFT", pageTitle, "BOTTOMLEFT", 0, -6)

local pages, navButtons, refreshers = {}, {}, {}
local function onRefresh(fn) refreshers[#refreshers + 1] = fn end

local function NewPage(key, title, subtitle)
  local p = CreateFrame("Frame", nil, content)
  p:SetPoint("TOPLEFT", 0, -56)
  p:SetPoint("BOTTOMRIGHT")
  p.title, p.subtitle = title, subtitle
  p:Hide()
  pages[key] = p
  return p
end

local function Select(key)
  for k, p in pairs(pages) do p:SetShown(k == key) end
  for k, b in pairs(navButtons) do b:SetSelected(k == key) end
  pageTitle:SetText(pages[key].title)
  pageSub:SetText(pages[key].subtitle)
  f.selected = key
end

local function NavButton(key, label, y)
  local b = CreateFrame("Button", nil, nav)
  b:SetSize(NAV_W - 16, 34)
  b:SetPoint("TOPLEFT", 8, y)
  b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints()
  b.mark = b:CreateTexture(nil, "ARTWORK")
  b.mark:SetPoint("TOPLEFT"); b.mark:SetPoint("BOTTOMLEFT"); b.mark:SetWidth(3)
  UI.Color(b.mark, C.accent)
  b.t = UI.Text(b, 14)
  b.t:SetPoint("LEFT", 14, 0)
  b.t:SetText(label)
  function b:SetSelected(sel)
    self.sel = sel
    UI.Color(self.bg, sel and C.surface2 or { 0, 0, 0, 0 })
    self.mark:SetShown(sel)
    local c = sel and C.text or C.muted
    self.t:SetTextColor(c[1], c[2], c[3])
  end
  b:SetScript("OnEnter", function(self) if not self.sel then UI.Color(self.bg, C.hover) end end)
  b:SetScript("OnLeave", function(self) self:SetSelected(self.sel) end)
  b:SetScript("OnClick", function() Select(key) end)
  navButtons[key] = b
end

-- Row helper: a card with a title/description on the left ----------------------------------
local function Row(parent, y, h, title, desc)
  local r = UI.Box(parent, C.surface, C.border)
  r:SetSize(CW, h or 52)
  r:SetPoint("TOPLEFT", 0, y)
  r.title = UI.Text(r, 14, C.text)
  r.title:SetText(title)
  if desc then
    r.title:SetPoint("TOPLEFT", 14, -10)
    r.desc = UI.Text(r, 12, C.muted)
    r.desc:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -4)
    r.desc:SetText(desc)
  else
    r.title:SetPoint("LEFT", 14, 0)
  end
  return r
end

-- Page: Triggers --------------------------------------------------------------------------
do
  local p = NewPage("triggers", "Triggers", "Choose what makes you work out, and how often.")
  local y = 0
  for _, def in ipairs(W.TRIGGERS) do
    local key = def.key
    local r = Row(p, y, 48, def.label, def.desc)
    local t = function() return W:Trigger(key) end

    local sw = UI.Switch(r, function() return t().on end, function(v) t().on = v end)
    sw:SetPoint("LEFT", 14, 0)
    r.title:SetPoint("TOPLEFT", 64, -9)

    local mult = UI.Stepper(r, 74, function() return t().mult end, function(v) t().mult = v end,
      0.5, 3, 0.5, function(v) return "x" .. v end)
    mult:SetPoint("RIGHT", -12, 0)

    local every = UI.Stepper(r, 120, function() return t().every end, function(v) t().every = v end,
      1, 500, (key == "kills" or key == "time") and 5 or 1, function(v) return v .. " " .. (v == 1 and def.unit1 or def.unit) end)
    every:SetPoint("RIGHT", mult, "LEFT", -10, 0)

    local unit = UI.Text(r, 12, C.muted)
    unit:SetPoint("RIGHT", every, "LEFT", -8, 0)
    unit:SetJustifyH("RIGHT")
    unit:SetText("every")

    local prog = UI.Progress(r, CW - 2, 2)
    prog:SetPoint("BOTTOMLEFT", 1, 1)

    onRefresh(function()
      sw:Refresh(); every:Refresh(); mult:Refresh()
      prog:SetProgress(t().progress / t().every)
    end)
    W:On("PROGRESS", function(k) if k == key then prog:SetProgress(t().progress / t().every) end end)
    y = y - 54
  end
end

-- Page: Exercises ----------------------------------------------------------------------------
do
  local p = NewPage("exercises", "Exercises", "Picked at random among the active ones.")
  local scroll = CreateFrame("ScrollFrame", nil, p)
  scroll:SetPoint("TOPLEFT"); scroll:SetPoint("BOTTOMRIGHT", 0, 56)
  local list = CreateFrame("Frame", nil, scroll)
  list:SetSize(CW, 10)
  scroll:SetScrollChild(list)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, list:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - d * 40)))
  end)

  local rows = {}
  local function Build()
    for _, r in ipairs(rows) do r:Hide() end
    local y = 0
    for i, ex in ipairs(W.db.exercises) do
      local r = rows[i]
      if not r then
        r = Row(list, 0, 48, "")
        r.icon = UI.Icon(r, 32); r.icon:SetPoint("LEFT", 60, 0)
        r.title:ClearAllPoints(); r.title:SetPoint("LEFT", r.icon, "RIGHT", 12, 0)
        r.sw = UI.Switch(r, function() return r.ex.on end, function(v) r.ex.on = v end)
        r.sw:SetPoint("LEFT", 14, 0)
        r.del = UI.IconButton(r, 26, "x", function()
          table.remove(W.db.exercises, r.index); f:Refresh()
        end, "Remove")
        r.del:SetPoint("RIGHT", -10, 0)
        r.amount = UI.Stepper(r, 110, function() return r.ex.amount end, function(v) r.ex.amount = v end,
          1, 300, 1, function(v) return r.ex.timed and (v .. " s") or (v .. " reps") end)
        r.amount:SetPoint("RIGHT", r.del, "LEFT", -8, 0)
        rows[i] = r
      end
      r.ex, r.index = ex, i
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y)
      r.title:SetText(ex.name)
      r.icon.tex:SetTexture(ex.icon or W.CUSTOM_ICON)
      r.sw:Refresh(); r.amount:Refresh()
      r:Show()
      y = y - 54
    end
    list:SetHeight(-y)
  end
  onRefresh(Build)

  -- Add custom exercise
  local add = UI.Box(p, C.surface, C.border)
  add:SetSize(CW, 44)
  add:SetPoint("BOTTOMLEFT")
  local ibg = UI.Box(add, C.surface2, C.border)
  ibg:SetSize(CW - 230, 28)
  ibg:SetPoint("LEFT", 12, 0)
  local input = CreateFrame("EditBox", nil, ibg)
  input:SetAllPoints()
  input:SetAutoFocus(false)
  input:SetFont(UI.FONT, 14, "")
  input:SetTextColor(unpack(C.text))
  input:SetTextInsets(8, 8, 0, 0)
  local hint = UI.Text(input, 14, C.muted)
  hint:SetPoint("LEFT", 8, 0); hint:SetText("New exercise name")
  input:SetScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)
  input:SetScript("OnEscapePressed", input.ClearFocus)

  local timed = false
  local kind = UI.Segmented(add, { { value = false, label = "Reps" }, { value = true, label = "Timed" } },
    function() return timed end, function(v) timed = v end, 110)
  kind:SetPoint("LEFT", ibg, "RIGHT", 8, 0)

  local function Add()
    local n = strtrim(input:GetText() or "")
    if n == "" then return end
    table.insert(W.db.exercises, { name = n, amount = timed and 30 or 10, timed = timed, on = true, icon = W.CUSTOM_ICON })
    input:SetText(""); input:ClearFocus()
    f:Refresh()
  end
  input:SetScript("OnEnterPressed", Add)
  local addBtn = UI.Button(add, "Add", "primary", 80, 28, Add)
  addBtn:SetPoint("RIGHT", -8, 0)
end

-- Page: Social ---------------------------------------------------------------------------------
do
  local p = NewPage("social", "Social", "Let your group and guild know you're getting swole.")
  local opts = { { value = "ask", label = "Ask" }, { value = "always", label = "Always" }, { value = "never", label = "Never" } }

  local r1 = Row(p, 0, 64, "Group break message", "When a workout starts in a group")
  local s1 = UI.Segmented(r1, opts, function() return W.db.askGroup end, function(v) W.db.askGroup = v; f:Refresh() end, 210)
  s1:SetPoint("RIGHT", -14, 0)

  local r2 = Row(p, -72, 64, "Break duration announced", "Minutes you tell your group")
  local s2 = UI.Stepper(r2, 110, function() return W.db.breakMinutes end, function(v) W.db.breakMinutes = v; f:Refresh() end,
    1, 15, 1, function(v) return v .. " min" end)
  s2:SetPoint("RIGHT", -14, 0)

  local r3 = Row(p, -144, 64, "Guild share", "After you complete an exercise")
  local s3 = UI.Segmented(r3, opts, function() return W.db.askGuild end, function(v) W.db.askGuild = v; f:Refresh() end, 210)
  s3:SetPoint("RIGHT", -14, 0)

  local pv = UI.Box(p, C.surface2, C.border)
  pv:SetSize(CW, 104)
  pv:SetPoint("TOPLEFT", 0, -228)
  local pvt = UI.Kicker(pv, 10, C.gold)
  pvt:SetPoint("TOPLEFT", 14, -12); pvt:SetText("PREVIEW")
  local g = UI.Text(pv, 13, { 0.67, 0.67, 1 })
  g:SetPoint("TOPLEFT", 14, -34); g:SetPoint("RIGHT", -14, 0)
  local gu = UI.Text(pv, 13, { 0.25, 1, 0.25 })
  gu:SetPoint("TOPLEFT", g, "BOTTOMLEFT", 0, -10); gu:SetPoint("RIGHT", -14, 0)
  onRefresh(function()
    s1:Refresh(); s2:Refresh(); s3:Refresh()
    local me = UnitName("player") or "You"
    g:SetText(string.format("[Party] [%s]: [W'orc out] Quick %d min break for my workout: 15 squats! Back soon. (addon: W'orc out)", me, W.db.breakMinutes))
    gu:SetText(string.format("[Guild] [%s]: [W'orc out] Just did 15 squats (Level 24!). %d exercises done so far! (addon: W'orc out)", me, W.db.stats.total))
  end)
end

-- Page: General -------------------------------------------------------------------------------
do
  local p = NewPage("general", "General", "Difficulty and behaviour.")
  local r1 = Row(p, 0, 64, "Difficulty", "Multiplies every exercise amount")
  local s1 = UI.Segmented(r1, {
    { value = 0.5, label = "Chill" }, { value = 1, label = "Normal" },
    { value = 1.5, label = "Hard" }, { value = 2, label = "Orc" } },
    function() return W.db.difficulty end, function(v) W.db.difficulty = v end, 260)
  s1:SetPoint("RIGHT", -14, 0)

  local function toggleRow(y, title, desc, key)
    local r = Row(p, y, 64, title, desc)
    local sw = UI.Switch(r, function() return W.db[key] end, function(v) W.db[key] = v end)
    sw:SetPoint("RIGHT", -14, 0)
    onRefresh(function() sw:Refresh() end)
  end
  toggleRow(-72, "Wait for combat to end", "Workouts never pop up mid-fight", "deferInCombat")
  toggleRow(-144, "Sound", "Play a sound when a workout starts", "sound")
  toggleRow(-216, "Count distance while mounted", "Off: only running on foot counts", "countMounted")
  local r5 = Row(p, -288, 64, "Coach", "Auto: orc for Horde, night elf for Alliance")
  local s5 = UI.Segmented(r5, { { value = "auto", label = "Auto" }, { value = "orc", label = "Orc" },
    { value = "nightelf", label = "Night elf" } },
    function() return W.db.coach end, function(v) W.db.coach = v end, 240)
  s5:SetPoint("RIGHT", -14, 0)
  onRefresh(function() s5:Refresh() end)
  onRefresh(function() s1:Refresh() end)

  local test = UI.Button(p, "Try a workout now", "primary", 200, 36, function()
    f:Hide(); W:Request("levelup", "Test workout")
  end)
  test:SetPoint("TOPLEFT", 0, -372)
end

-- Page: Stats -------------------------------------------------------------------------------------
do
  local p = NewPage("stats", "Stats", "Every rep counts.")
  local cards = {}
  local labels = { "Exercises done", "Today", "Day streak" }
  local cw = (CW - 24) / 3
  for i, l in ipairs(labels) do
    local c = UI.Box(p, C.surface, C.border)
    c:SetSize(cw, 86)
    c:SetPoint("TOPLEFT", (i - 1) * (cw + 12), 0)
    c.v = UI.Text(c, 34, i == 3 and C.accent or C.gold, true)
    c.v:SetPoint("TOPLEFT", 14, -14)
    c.l = UI.Text(c, 12, C.muted)
    c.l:SetPoint("BOTTOMLEFT", 14, 12)
    c.l:SetText(l)
    cards[i] = c
  end

  local listTitle = UI.Kicker(p, 10, C.gold)
  listTitle:SetPoint("TOPLEFT", 0, -110)
  listTitle:SetText("TOTAL BY EXERCISE")
  local lines = {}

  onRefresh(function()
    local s = W.db.stats
    cards[1].v:SetText(s.total)
    cards[2].v:SetText(s.days[date("%Y-%m-%d")] or 0)
    cards[3].v:SetText(s.streak)
    local sorted = {}
    for n, v in pairs(s.byName) do sorted[#sorted + 1] = { n, v } end
    table.sort(sorted, function(a, b) return a[2] > b[2] end)
    local max = sorted[1] and sorted[1][2] or 1
    for _, l in ipairs(lines) do l:Hide() end
    for i = 1, math.min(#sorted, 8) do
      local l = lines[i]
      if not l then
        l = CreateFrame("Frame", nil, p)
        l:SetSize(CW, 30)
        l.n = UI.Text(l, 13); l.n:SetPoint("TOPLEFT")
        l.v = UI.Text(l, 13, C.muted); l.v:SetPoint("TOPRIGHT"); l.v:SetJustifyH("RIGHT")
        l.bar = UI.Progress(l, CW, 4); l.bar:SetPoint("BOTTOMLEFT", 0, 4)
        lines[i] = l
      end
      l:SetPoint("TOPLEFT", 0, -132 - (i - 1) * 34)
      l.n:SetText(sorted[i][1])
      local timed
      for _, e in ipairs(W.db.exercises) do if e.name == sorted[i][1] then timed = e.timed end end
      l.v:SetText(sorted[i][2] .. (timed and " s" or " reps"))
      l.bar:SetProgress(sorted[i][2] / max)
      l:Show()
    end
    if #sorted == 0 then
      lines[0] = lines[0] or UI.Text(p, 13, C.muted)
      lines[0]:SetPoint("TOPLEFT", 0, -136)
      lines[0]:SetText("Nothing yet. Go kill some boars.")
      lines[0]:Show()
    elseif lines[0] then lines[0]:Hide() end
  end)
end

NavButton("triggers", "Triggers", -84)
NavButton("exercises", "Exercises", -122)
NavButton("social", "Social", -160)
NavButton("general", "General", -198)
NavButton("stats", "Stats", -236)

function f:Refresh()
  master:Refresh()
  masterLabel:SetText(W.db.enabled and "Active" or "Paused")
  for _, fn in ipairs(refreshers) do fn() end
end

f:SetScript("OnShow", function(self)
  self:Refresh()
  Select(self.selected or "triggers")
end)

W:On("OPEN_SETTINGS", function() f:SetShown(not f:IsShown()) end)
W:On("SETTINGS", function() if f:IsShown() then f:Refresh() end end)
W:On("TASK_DONE", function() if f:IsShown() then f:Refresh() end end)

-- Launcher button -----------------------------------------------------------------------------------
local launcher = UI.Box(UIParent, C.bg, C.border, "WorcOutLauncher")
launcher:SetSize(40, 40)
launcher:SetPoint("CENTER", -300, -200)
launcher:SetMovable(true)
launcher:SetClampedToScreen(true)
launcher:Hide()
local lbtn = CreateFrame("Button", nil, launcher)
lbtn:SetAllPoints()
lbtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
lbtn:RegisterForDrag("LeftButton")
local lic = lbtn:CreateTexture(nil, "ARTWORK")
lic:SetPoint("TOPLEFT", 4, -4); lic:SetPoint("BOTTOMRIGHT", -4, 4)
lic:SetTexture("Interface\\Icons\\Spell_Nature_Strength")
lic:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local function UpdateLauncher()
  lic:SetDesaturated(not W.db.enabled)
  launcher:SetBorder(W.db.enabled and C.accent or C.border)
end

lbtn:SetScript("OnDragStart", function() launcher:StartMoving() end)
lbtn:SetScript("OnDragStop", function()
  launcher:StopMovingOrSizing()
  local pt, _, rp, x, y = launcher:GetPoint()
  W.db.launcher.pos = { pt, rp, x, y }
end)
lbtn:SetScript("OnClick", function(_, btn)
  if btn == "RightButton" then
    W.db.enabled = not W.db.enabled
    W:Fire("SETTINGS")
  else
    W:Fire("OPEN_SETTINGS")
  end
end)
lbtn:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine("W'orc out")
  GameTooltip:AddLine(W.db.enabled and "|cff7ccb4aActive|r" or "|cff999999Paused|r")
  GameTooltip:AddLine("Left-click: settings", 1, 1, 1)
  GameTooltip:AddLine("Right-click: pause / resume", 1, 1, 1)
  GameTooltip:AddLine("Drag: move", 1, 1, 1)
  GameTooltip:Show()
end)
lbtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

W:On("SETTINGS", UpdateLauncher)
W:On("READY", function()
  local pos = W.db.launcher.pos
  if pos then launcher:ClearAllPoints(); launcher:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) end
  launcher:SetShown(W.db.launcher.shown)
  UpdateLauncher()
end)
