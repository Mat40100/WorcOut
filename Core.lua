-- W'orc out - core: settings, triggers, exercise queue, stats.
local ADDON, W = ...
_G.WorcOut = W

W.NAME = "W'orc out"
W.TAG = "[W'orc out]"

-- Defaults ---------------------------------------------------------------
-- Every trigger: on/off, "every N" threshold, rep multiplier.
W.TRIGGERS = {
  { key = "levelup", label = "Level up",        desc = "Every time you gain levels",        unit = "levels", unit1 = "level",  every = 1,  mult = 1.5 },
  { key = "kills",   label = "Mobs killed",     desc = "Tagged by you or your group",  unit = "kills", unit1 = "kill",   every = 25, mult = 1 },
  { key = "boss",    label = "Boss killed",     desc = "Dungeon and raid bosses",           unit = "bosses", unit1 = "boss",  every = 1,  mult = 2 },
  { key = "distance",label = "Distance run",    desc = "On foot, taxis excluded",           unit = "km",      every = 2,  mult = 1 },
  { key = "capital", label = "Enter a capital", desc = "Max once every 10 minutes",         unit = "visits", unit1 = "visit",  every = 1,  mult = 1 },
  { key = "quests",  label = "Quests done",     desc = "Quests turned in",                  unit = "quests", unit1 = "quest",  every = 5,  mult = 1 },
  { key = "death",   label = "You died",        desc = "Pay the price of failure",          unit = "deaths", unit1 = "death",  every = 1,  mult = 1 },
  { key = "time",    label = "Time played",     desc = "Session time, in minutes",          unit = "min",     every = 45, mult = 1 },
}

W.DEFAULT_EXERCISES = {
  { name = "Push-ups",      amount = 10, timed = false, icon = "Interface\\Icons\\Ability_Warrior_Charge" },
  { name = "Squats",        amount = 15, timed = false, icon = "Interface\\Icons\\Spell_Nature_Strength" },
  { name = "Sit-ups",       amount = 15, timed = false, icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance" },
  { name = "Plank",         amount = 30, timed = true,  icon = "Interface\\Icons\\Spell_Holy_DevotionAura" },
  { name = "Jumping jacks", amount = 20, timed = false, icon = "Interface\\Icons\\Ability_Rogue_Sprint" },
  { name = "Lunges",        amount = 12, timed = false, icon = "Interface\\Icons\\Ability_Hunter_Pet_Raptor" },
  { name = "Burpees",       amount = 6,  timed = false, icon = "Interface\\Icons\\Ability_Warrior_Rampage" },
  { name = "Wall sit",      amount = 30, timed = true,  icon = "Interface\\Icons\\Ability_Warrior_ShieldWall" },
}
W.CUSTOM_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local DEFAULTS = {
  enabled = true,
  difficulty = 1,          -- global multiplier: 0.5 / 1 / 1.5 / 2
  deferInCombat = true,
  sound = true,
  askGroup = "ask",        -- ask | always | never
  askGuild = "ask",
  breakMinutes = 2,
  countMounted = false,
  coach = "auto",          -- auto (by faction) | orc | nightelf
  launcher = { shown = true },
  stats = { total = 0, byName = {}, days = {}, streak = 0, lastDay = nil },
}

local CAPITALS = { [1453] = true, [1455] = true, [1457] = true, [1454] = true, [1456] = true, [1458] = true }

-- Utils -----------------------------------------------------------------
local function copy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do r[k] = copy(v) end
  return r
end

local function merge(dst, src)
  for k, v in pairs(src) do
    if dst[k] == nil then dst[k] = copy(v)
    elseif type(v) == "table" and type(dst[k]) == "table" and not v[1] then merge(dst[k], v) end
  end
end

function W:Print(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff7ccb4aW'orc out|r " .. msg) end

local listeners = {}
function W:On(name, fn) listeners[name] = listeners[name] or {}; table.insert(listeners[name], fn) end
function W:Fire(name, ...) for _, fn in ipairs(listeners[name] or {}) do fn(...) end end

-- Database --------------------------------------------------------------
function W:InitDB()
  WorcOutDB = WorcOutDB or {}
  local db = WorcOutDB
  merge(db, DEFAULTS)
  db.triggers = db.triggers or {}
  for _, t in ipairs(self.TRIGGERS) do
    db.triggers[t.key] = db.triggers[t.key] or { on = true, every = t.every, mult = t.mult, progress = 0 }
  end
  db.exercises = db.exercises or copy(self.DEFAULT_EXERCISES)
  for _, e in ipairs(db.exercises) do if e.on == nil then e.on = true end end
  self.db = db
end

-- Coach shown in the workout window: Horde -> orc, Alliance -> night elf, unless chosen.
function W:Coach()
  if self.db.coach == "orc" or self.db.coach == "nightelf" then return self.db.coach end
  return UnitFactionGroup("player") == "Alliance" and "nightelf" or "orc"
end

function W:Trigger(key) return self.db.triggers[key] end
function W:TriggerDef(key) for _, t in ipairs(self.TRIGGERS) do if t.key == key then return t end end end

-- Exercise selection -------------------------------------------------------
function W:PickExercise()
  local pool = {}
  for _, e in ipairs(self.db.exercises) do if e.on then pool[#pool + 1] = e end end
  if #pool == 0 then return nil end
  -- avoid repeating the last one when possible
  local e
  repeat e = pool[math.random(#pool)] until #pool == 1 or e.name ~= self.lastExercise
  self.lastExercise = e.name
  return e
end

function W:BuildTask(key, reason)
  local ex = self:PickExercise()
  if not ex then return nil end
  local trig = self:Trigger(key)
  local amount = ex.amount * (trig and trig.mult or 1) * self.db.difficulty
  amount = math.max(1, math.floor(amount + 0.5))
  if ex.timed then amount = math.max(5, math.floor(amount / 5 + 0.5) * 5) end
  return { name = ex.name, icon = ex.icon or self.CUSTOM_ICON, amount = amount, timed = ex.timed,
           trigger = key, reason = reason }
end

function W:FormatTask(task)
  return task.timed and (task.amount .. "s of " .. task.name:lower()) or (task.amount .. " " .. task.name:lower())
end

-- Queue -------------------------------------------------------------------
W.queue = {}

function W:Request(key, reason)
  if not self.db.enabled then return end
  local task = self:BuildTask(key, reason)
  if not task then return end
  table.insert(self.queue, task)
  self:Pump()
end

function W:Pump()
  if self.current or #self.queue == 0 then return end
  if self.db.deferInCombat and InCombatLockdown() then return end
  self.current = table.remove(self.queue, 1)
  if self.db.sound then PlaySound(SOUNDKIT and SOUNDKIT.READY_CHECK or 8960) end
  self:Fire("TASK", self.current)
end

function W:Snooze(minutes)
  local task = self.current
  self.current = nil
  self:Fire("TASK_CLOSED")
  C_Timer.After(minutes * 60, function() table.insert(self.queue, 1, task); self:Pump() end)
  self:Pump()
end

function W:Skip()
  self.current = nil
  self:Fire("TASK_CLOSED")
  self:Pump()
end

function W:Complete()
  local task = self.current
  self.current = nil
  local s = self.db.stats
  local today = date("%Y-%m-%d")
  if s.lastDay ~= today then
    local yesterday = date("%Y-%m-%d", time() - 86400)
    s.streak = (s.lastDay == yesterday) and (s.streak + 1) or 1
    s.lastDay = today
  end
  s.total = s.total + 1
  s.byName[task.name] = (s.byName[task.name] or 0) + task.amount
  s.days[today] = (s.days[today] or 0) + 1
  self:Fire("TASK_DONE", task)
  self:Fire("TASK_CLOSED")
end

-- Chat --------------------------------------------------------------------
function W:GroupChannel()
  if IsInRaid and IsInRaid() then return "RAID" end
  if IsInGroup and IsInGroup() then return "PARTY" end
end

function W:SendGroupBreak(task)
  local ch = self:GroupChannel()
  if not ch then return end
  SendChatMessage(string.format("%s Quick %d min break for my workout: %s! Back soon. (addon: W'orc out)",
    self.TAG, self.db.breakMinutes, self:FormatTask(task)), ch)
end

function W:SendGuildDone(task)
  if not IsInGuild() then return end
  SendChatMessage(string.format("%s Just did %s (%s). %d exercises done so far! (addon: W'orc out)",
    self.TAG, self:FormatTask(task), task.reason, self.db.stats.total), "GUILD")
end

-- Progress tracking ----------------------------------------------------------
function W:Add(key, n, reasonFn)
  local trig = self:Trigger(key)
  if not trig or not trig.on then return end
  trig.progress = trig.progress + (n or 1)
  if trig.progress >= trig.every then
    trig.progress = trig.progress - trig.every
    if trig.progress > trig.every then trig.progress = 0 end
    self:Request(key, reasonFn and reasonFn() or self:TriggerDef(key).label)
  end
  self:Fire("PROGRESS", key)
end

local lastCapital = 0
local lastX, lastY, lastMap
local function DistanceTick()
  local y, x, _, map = UnitPosition("player")
  if not x then lastX = nil; return end
  local onFoot = not UnitOnTaxi("player") and (W.db.countMounted or not IsMounted())
  if lastX and map == lastMap and onFoot and not UnitIsDeadOrGhost("player") then
    local d = math.sqrt((x - lastX) ^ 2 + (y - lastY) ^ 2)
    if d > 0.5 and d < 30 then             -- ignore jitter and teleports
      W.yards = (W.yards or 0) + d
      local km = 1093.6                      -- yards per km
      if W.yards >= km then
        W.yards = W.yards - km
        W:Add("distance", 1, function() return "You ran " .. W:Trigger("distance").every .. " km" end)
      end
    end
  end
  lastX, lastY, lastMap = x, y, map
end

-- Events --------------------------------------------------------------------
local f = CreateFrame("Frame")
local events = {}

function events.ADDON_LOADED(name)
  if name ~= ADDON then return end
  W:InitDB()
  W:Fire("READY")
end

function events.PLAYER_LOGIN()
  C_Timer.NewTicker(1, DistanceTick)
  C_Timer.NewTicker(60, function()
    W:Add("time", 1, function() return W:Trigger("time").every .. " minutes of play" end)
  end)
end

function events.PLAYER_LEVEL_UP(level)
  W:Add("levelup", 1, function() return "Level " .. level .. "!" end)
end

-- Kills: the combat log is restricted for addons on this client, so we watch units we
-- can see (target, nameplates, mouseover...) die while tapped by us or our group.
local counted = {}
local function CheckKill(unit)
  if not unit or not UnitExists(unit) or not UnitIsDead(unit) then return end
  if UnitIsPlayer(unit) or not UnitCanAttack("player", unit) or UnitIsTapDenied(unit) then return end
  local guid = UnitGUID(unit)
  if not guid or counted[guid] then return end
  counted[guid] = GetTime()
  W:Add("kills", 1, function() return W:Trigger("kills").every .. " mobs killed" end)
end

function events.UNIT_HEALTH(unit) CheckKill(unit) end
function events.PLAYER_TARGET_CHANGED() CheckKill("target") end

-- forget old GUIDs so the table stays small
C_Timer.NewTicker(300, function()
  local now = GetTime()
  for g, t in pairs(counted) do if now - t > 600 then counted[g] = nil end end
end)

function events.ENCOUNTER_END(_, name, _, _, success)
  if success == 1 then W:Add("boss", 1, function() return (name or "Boss") .. " defeated" end) end
end

function events.QUEST_TURNED_IN()
  W:Add("quests", 1, function() return W:Trigger("quests").every .. " quests done" end)
end

function events.PLAYER_DEAD()
  W:Add("death", 1, function() return "You died" end)
end

function events.ZONE_CHANGED_NEW_AREA()
  local map = C_Map.GetBestMapForUnit("player")
  if map and CAPITALS[map] and GetTime() - lastCapital > 600 then
    lastCapital = GetTime()
    W:Add("capital", 1, function() return "Welcome to " .. GetZoneText() end)
  end
end

function events.PLAYER_REGEN_ENABLED() W:Pump() end

for ev in pairs(events) do f:RegisterEvent(ev) end
f:SetScript("OnEvent", function(_, ev, ...) events[ev](...) end)

-- Slash -----------------------------------------------------------------------
SLASH_WORCOUT1 = "/worcout"
SLASH_WORCOUT2 = "/wo"
SlashCmdList.WORCOUT = function(msg)
  msg = (msg or ""):lower()
  if msg == "test" then
    W:Request("levelup", "Test workout")
  elseif msg:match("^coach") then
    local id = tonumber(msg:match("%d+"))
    W.db.orcCreature = id
    W:Print("coach creature: " .. (id or ("default (" .. W.ORC_CREATURE .. ")")))
    W.OpenAnimLab()
  elseif msg:match("^anim") then
    local lab = W.OpenAnimLab()
    local n = tonumber(msg:match("%d+"))
    if n then lab.set(n) end
  elseif msg == "toggle" then
    W.db.enabled = not W.db.enabled
    W:Print(W.db.enabled and "enabled" or "paused")
    W:Fire("SETTINGS")
  else
    W:Fire("OPEN_SETTINGS")
  end
end
