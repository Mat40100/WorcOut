-- W'orc out - small see-through window showing how close each active trigger is to firing.
local _, W = ...
local UI, C, L = W.UI, W.UI.C, W.L

local WIDTH, ROW_H = 220, 30
local KM = 1093.6   -- yards per km (same as Core)

local f = CreateFrame("Frame", "WorcOutTracker", UIParent)
f:SetSize(WIDTH, 40)
f:SetPoint("RIGHT", UIParent, "RIGHT", -40, 120)
f:SetFrameStrata("LOW")
f:SetClampedToScreen(true)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:Hide()

local bg = f:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
UI.Gradient(bg, { 0, 0, 0, 0.55 }, { 0, 0, 0, 0.25 })
local line = f:CreateTexture(nil, "BORDER")
line:SetPoint("TOPLEFT"); line:SetPoint("TOPRIGHT"); line:SetHeight(1)
UI.Gradient(line, { C.gold[1], C.gold[2], C.gold[3], 0.9 }, { C.gold[1], C.gold[2], C.gold[3], 0 }, true)

local title = UI.Kicker(f, 9, C.gold)
title:SetPoint("TOPLEFT", 10, -8)
title:SetText(L["Next workouts"])

f:SetScript("OnMouseDown", function(self) self.dragged = false end)
f:SetScript("OnDragStart", function(self)
  self.dragged = true
  if not W.db.tracker.locked then self:StartMoving() end
end)
f:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local p, _, rp, x, y = self:GetPoint()
  W.db.tracker.pos = { p, rp, x, y }
end)
f:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine("W'orc out")
  if not W.db.tracker.locked then GameTooltip:AddLine(L["Drag: move"], 1, 1, 1) end
  GameTooltip:AddLine(L["Click: settings"], 1, 1, 1)
  GameTooltip:Show()
end)
f:SetScript("OnLeave", function() GameTooltip:Hide() end)
f:SetScript("OnMouseUp", function(self, btn)
  if btn == "LeftButton" and not self.dragged then W:Fire("OPEN_SETTINGS") end
end)

-- Rows ----------------------------------------------------------------------------------------
local rows = {}
local function GetRow(i)
  local r = rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, f)
  r:SetSize(WIDTH - 20, ROW_H - 4)
  r.name = UI.Text(r, 12, C.text)
  r.name:SetPoint("TOPLEFT")
  r.value = UI.Text(r, 12, C.muted)
  r.value:SetPoint("TOPRIGHT")
  r.value:SetJustifyH("RIGHT")
  r.bar = UI.Progress(r, WIDTH - 20, 3)
  r.bar:SetPoint("BOTTOMLEFT", 0, 4)
  rows[i] = r
  return r
end

-- Progress towards the next workout, as (done, goal, text). Distance counts the current km too.
local function Progress(def, t)
  if def.key == "distance" then
    local km = t.progress + (W.yards or 0) / KM
    return km, t.every, ("%.1f / %d km"):format(km, t.every)
  end
  local unit = t.every == 1 and def.unit1 or def.unit
  return t.progress, t.every, ("%d / %d %s"):format(t.progress, t.every, unit or "")
end

local function Update()
  if not f:IsShown() then return end
  local list = {}
  for _, def in ipairs(W.TRIGGERS) do
    local t = W:Trigger(def.key)
    -- "every 1" triggers (level up, boss, death...) are always 0/1: nothing to track
    if t.on and (t.every > 1 or def.key == "distance") then
      local done, goal, text = Progress(def, t)
      list[#list + 1] = { label = def.label, ratio = done / goal, text = text }
    end
  end
  table.sort(list, function(a, b) return a.ratio > b.ratio end)
  for i, r in ipairs(rows) do r:Hide() end
  for i, it in ipairs(list) do
    local r = GetRow(i)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 10, -24 - (i - 1) * ROW_H)
    r.name:SetText(it.label)
    r.value:SetText(it.text)
    r.bar:SetProgress(it.ratio)
    r.value:SetTextColor(unpack(it.ratio >= 0.8 and C.gold or C.muted))
    r:Show()
  end
  f:SetHeight(30 + math.max(1, #list) * ROW_H)
  f:SetAlpha(W.db.enabled and 1 or 0.5)
end
W.UpdateTracker = Update

function W:ApplyTracker()
  local tr = self.db.tracker
  if tr.pos then f:ClearAllPoints(); f:SetPoint(tr.pos[1], UIParent, tr.pos[2], tr.pos[3], tr.pos[4]) end
  f:SetShown(tr.shown)
  Update()
end

f:SetScript("OnShow", Update)
W:On("PROGRESS", Update)
W:On("SETTINGS", function() W:ApplyTracker() end)
W:On("READY", function()
  W:ApplyTracker()
  C_Timer.NewTicker(2, Update)   -- distance moves between whole km
end)

-- Victory dance over the tracker for a few seconds after each finished exercise ---------------
-- (drawn on the tracker itself: above it, it could hide behind the minimap)
local DANCE_TIME, FADE = 10, 0.6
local dance = CreateFrame("Frame", nil, f)
dance:SetPoint("CENTER", f, "CENTER", 0, -6)
dance:SetFrameLevel(f:GetFrameLevel() + 10)
dance:Hide()
local function DimRows(a) for _, r in ipairs(rows) do r:SetAlpha(a) end end
dance:SetScript("OnHide", function() DimRows(1) end)
local tex = dance:CreateTexture(nil, "ARTWORK")
tex:SetAllPoints()
local sheet, fps, frames, cols, rows, clock

dance:SetScript("OnUpdate", function(self, dt)
  clock = clock + dt
  local i = math.floor(clock * fps) % frames
  local r, c = math.floor(i / cols), i % cols
  tex:SetTexCoord(c / cols, (c + 1) / cols, r / rows, (r + 1) / rows)
  local a = math.min(1, (DANCE_TIME - clock) / FADE, clock / 0.3)
  self:SetAlpha(a)
  DimRows(1 - a * 0.85)
  if clock >= DANCE_TIME then self:Hide() end
end)

W:On("TASK_DONE", function()
  if not f:IsShown() then return end
  local sheets = W.SHEETS and W.SHEETS[W:Coach()]
  sheet = sheets and sheets[W.lastDance or W:RandomDance() or ""]
  if not sheet then return end
  cols, rows = sheet.cols or 4, sheet.rows or 4
  frames = cols * rows
  fps = frames / math.max(0.5, sheet.duration or 1.3)
  clock = 0
  tex:SetTexture(sheet.path)
  tex:SetTexCoord(0, 1 / cols, 0, 1 / rows)
  local box = math.max(f:GetHeight() - 24, 90)          -- fit inside the tracker
  local scale = box / math.max(sheet.w, sheet.h)
  dance:SetSize(sheet.w * scale, sheet.h * scale)
  dance:SetAlpha(0)
  dance:Show()
end)
