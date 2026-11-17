-- W'orc out - the workout window: exercise, timer, group break and guild share.
local _, W = ...
local UI, C = W.UI, W.UI.C

local WIDTH = 380
local f = UI.Window("WorcOutPopup", WIDTH, 640)
f:SetPoint("CENTER", 0, 80)
f.close:SetScript("OnClick", function() W:Skip() end)
f:SetScript("OnHide", function() if W.current then W:Skip() end end)

-- Header -------------------------------------------------------------------------
local kicker = UI.Kicker(f, 11, C.gold)
kicker:SetPoint("TOP", 0, -26)
kicker:SetText("WORKOUT TIME")

local reason = UI.Text(f, 14, C.muted)
reason:SetPoint("TOP", kicker, "BOTTOM", 0, -6)
reason:SetJustifyH("CENTER")

-- Exercise ---------------------------------------------------------------------------
local stage = UI.Stage(f, WIDTH - 40, 220)
stage:SetPoint("TOP", 0, -76)

local icon = UI.Icon(stage, 36)
icon:SetPoint("TOPLEFT", 8, -8)
icon:SetFrameLevel(stage.model:GetFrameLevel() + 2)

local name = UI.Text(f, 22, C.text, true)
name:SetPoint("TOP", stage, "BOTTOM", 0, -14)
name:SetJustifyH("CENTER")

local amount = UI.Text(f, 60, C.gold, true)
amount:SetPoint("TOP", name, "BOTTOM", 0, -8)
amount:SetJustifyH("CENTER")

local unit = UI.Text(f, 13, C.muted)
unit:SetPoint("TOP", amount, "BOTTOM", 0, -2)
unit:SetJustifyH("CENTER")

local bar = UI.Progress(f, WIDTH - 80, 6)
bar:SetPoint("TOP", unit, "BOTTOM", 0, -14)

-- Actions ----------------------------------------------------------------------------
local done = UI.Button(f, "Done", "primary", WIDTH - 40, 40)
done:SetPoint("BOTTOM", 0, 64)

local snooze = UI.Button(f, "Snooze 5 min", "ghost", (WIDTH - 48) / 2, 32, function() W:Snooze(5) end)
snooze:SetPoint("BOTTOMLEFT", 20, 22)
local skip = UI.Button(f, "Skip", "ghost", (WIDTH - 48) / 2, 32, function() W:Skip() end)
skip:SetPoint("BOTTOMRIGHT", -20, 22)

-- Banner (group break / guild share) ----------------------------------------------------
local banner = UI.Box(f, C.accentLo, C.accent)
banner:SetSize(WIDTH - 40, 64)
banner:SetPoint("BOTTOM", done, "TOP", 0, 14)
banner:Hide()
banner.text = UI.Text(banner, 13, C.text)
banner.text:SetPoint("TOPLEFT", 12, -10)
banner.text:SetPoint("RIGHT", -12, 0)
banner.yes = UI.Button(banner, "Tell group", "primary", 110, 24)
banner.yes:SetPoint("BOTTOMLEFT", 12, 8)
banner.no = UI.Button(banner, "No thanks", "ghost", 90, 24)
banner.no:SetPoint("LEFT", banner.yes, "RIGHT", 8, 0)

local function ShowBanner(text, yesLabel, onYes)
  banner.text:SetText(text)
  banner.yes:SetLabel(yesLabel)
  banner.yes:SetScript("OnClick", function() onYes(); banner:Hide() end)
  banner.no:SetScript("OnClick", function() banner:Hide() end)
  banner:Show()
end

-- Timer for timed exercises ---------------------------------------------------------------
local timerLeft, ticker
local function StopTimer() if ticker then ticker:Cancel(); ticker = nil end end
local function fmtTime(s) return string.format("%d:%02d", math.floor(s / 60), s % 60) end

local function StartTimer(task)
  StopTimer()
  timerLeft = task.amount
  done:SetLabel("Running...")
  done:Disable()
  ticker = C_Timer.NewTicker(1, function()
    timerLeft = timerLeft - 1
    amount:SetText(fmtTime(math.max(0, timerLeft)))
    bar:SetProgress(1 - timerLeft / task.amount)
    if timerLeft <= 0 then
      StopTimer()
      if W.db.sound then PlaySound(SOUNDKIT and SOUNDKIT.UI_QUEST_ROLLING_FORWARD_01 or 888) end
      done:Enable()
      done:SetLabel("Done")
      done:SetScript("OnClick", function() W:Complete() end)
    end
  end)
end

-- States --------------------------------------------------------------------------------------
local function ShowTask(task)
  StopTimer()
  f.doneScreen = false
  kicker:SetText("WORKOUT TIME")
  reason:SetText(task.reason)
  icon.tex:SetTexture(task.icon)
  icon:Show()
  stage:PlayExercise(task.name)
  name:SetText(task.name)
  bar:SetProgress(0)
  bar:SetShown(task.timed)
  snooze:Show(); skip:Show()
  done:Enable()
  if task.timed then
    amount:SetText(fmtTime(task.amount))
    unit:SetText("hold it")
    done:SetLabel("Start timer")
    done:SetScript("OnClick", function() StartTimer(task) end)
  else
    amount:SetText(task.amount)
    unit:SetText("reps")
    done:SetLabel("Done")
    done:SetScript("OnClick", function() W:Complete() end)
  end

  banner:Hide()
  if W:GroupChannel() then
    if W.db.askGroup == "always" then
      W:SendGroupBreak(task)
    elseif W.db.askGroup == "ask" then
      ShowBanner(string.format("You're in a group. Tell them you're taking a %d min break?", W.db.breakMinutes),
        "Tell group", function() W:SendGroupBreak(task) end)
    end
  end
  f:Show()
end

local function ShowDone(task)
  StopTimer()
  f:Show()
  f.doneScreen = true
  kicker:SetText("NICE WORK")
  stage:Play(W.MOVE_DONE)
  reason:SetText(string.format("%d exercises done  |  %d day streak", W.db.stats.total, W.db.stats.streak))
  name:SetText(task.name)
  amount:SetText("+" .. task.amount)
  unit:SetText(task.timed and "seconds" or "reps")
  bar:SetShown(true)
  bar:SetProgress(1)
  snooze:Hide(); skip:Hide()
  done:Enable()
  done:SetLabel("Close")
  done:SetScript("OnClick", function() f:Hide() end)

  banner:Hide()
  if IsInGuild() then
    if W.db.askGuild == "always" then
      W:SendGuildDone(task)
    elseif W.db.askGuild == "ask" then
      ShowBanner("Share it with your guild? Peer pressure works.", "Share", function() W:SendGuildDone(task) end)
      return
    end
  end
  C_Timer.After(6, function() if not W.current and not banner:IsShown() then f:Hide() end end)
end

W:On("TASK", ShowTask)
W:On("TASK_DONE", ShowDone)
W:On("TASK_CLOSED", function()
  StopTimer()
  if not f:IsShown() or W.current then return end
  -- keep the window open on the "Nice work" screen, otherwise hide it
  if not f.doneScreen then f:Hide() end
end)
