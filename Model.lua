-- W'orc out - a live 3D orc (or your character) doing the exercise, using the game's own models.
local _, W = ...
local UI, C = W.UI, W.UI.C
local L = W.L

-- Animation IDs from the game's AnimationData. WoW has no exercise animations,
-- so each exercise loops the closest ones. Tune them in game with /wo anim.
W.ANIM = { stand = 0, jumpStart = 37, jump = 38, jumpEnd = 39, cheer = 65, kneel = 72,
           sitDown = 96, sit = 97, sitUp = 98, flex = 79, roar = 71, sleep = 68, crouch = 120 }
local A = W.ANIM

-- Each step: { anim, seconds }. The sequence loops.
W.MOVES = {
  ["Push-ups"]      = { { A.kneel, 0.9 }, { A.stand, 0.5 } },
  ["Squats"]        = { { A.sitDown, 0.6 }, { A.sitUp, 0.6 } },
  ["Sit-ups"]       = { { A.sit, 0.8 }, { A.sitUp, 0.5 } },
  ["Plank"]         = { { A.sleep, 3 } },
  ["Jumping jacks"] = { { A.jumpStart, 0.25 }, { A.jump, 0.3 }, { A.jumpEnd, 0.3 }, { A.cheer, 0.6 } },
  ["Lunges"]        = { { A.kneel, 0.8 }, { A.stand, 0.6 } },
  ["Burpees"]       = { { A.kneel, 0.5 }, { A.jumpStart, 0.25 }, { A.jump, 0.3 }, { A.jumpEnd, 0.3 } },
  ["Wall sit"]      = { { A.sit, 3 } },
}
W.MOVE_DONE = { { 69, 8 } }   -- EmoteDance (the in-game /dance); check with /wo anim 69
W.MOVE_DEFAULT = { { A.cheer, 1.5 } }

-- A random victory dance for the current coach (sheets named "_dance_*"), or nil.
function W:RandomDance()
  local list = {}
  for name in pairs(self.SHEETS and self.SHEETS[self:Coach()] or {}) do
    if name:find("^_dance_") then list[#list + 1] = name end
  end
  return list[1] and list[math.random(#list)]
end

-- Model setup ---------------------------------------------------------------------------
-- The orc coach is an NPC model, by creature ID (default: Orgrimmar Grunt).
-- Change it in game with /wo coach <creatureID>.
W.ORC_CREATURE = 3296

local function Dress(m)
  m:ClearModel()
  if W:Coach() == "orc" then
    m:SetCreature(W.db.orcCreature or W.ORC_CREATURE)
  else
    m:SetUnit("player")
  end
  m:SetPortraitZoom(0)
  m:SetCamDistanceScale(1.1)
  m:SetFacing(math.rad(-25))
end

-- Stage: a box with the model and an animation sequencer ---------------------------------
function UI.Stage(parent, w, h)
  local stage = UI.Box(parent, C.surface, C.border)
  stage:SetSize(w, h)

  -- soft floor glow
  local floor = stage:CreateTexture(nil, "ARTWORK")
  floor:SetPoint("BOTTOMLEFT", 1, 1); floor:SetPoint("BOTTOMRIGHT", -1, 1); floor:SetHeight(h * 0.45)
  floor:SetColorTexture(1, 1, 1, 1)
  floor:SetGradient("VERTICAL", CreateColor(C.accent[1], C.accent[2], C.accent[3], 0.18), CreateColor(0, 0, 0, 0))

  local m = CreateFrame("PlayerModel", nil, stage)
  m:SetPoint("TOPLEFT", 2, -2); m:SetPoint("BOTTOMRIGHT", -2, 2)
  stage.model = m

  local seq, step, left, finished = nil, 1, 0, false
  local function play(i)
    step = i
    finished = false
    m:SetAnimation(seq[i][1])
    left = seq[i][2]
  end
  -- Move on only when the current animation has finished (and its minimum time is
  -- over). The timer is a safety net for animations that never report finishing.
  m:SetScript("OnAnimFinished", function() finished = true end)
  m:SetScript("OnUpdate", function(_, dt)
    if not seq then return end
    left = left - dt
    if (finished and left <= 0) or left <= -4 then play(step % #seq + 1) end
  end)

  -- Sprite-sheet animation (4x4 frames, made by worcout-anims/build.sh)
  local flip = stage:CreateTexture(nil, "ARTWORK", nil, 2)
  flip:SetPoint("BOTTOM", 0, 4)
  flip:Hide()
  local COLS, ROWS, FRAMES = 4, 4, 16
  local fps, clock = 12, 0
  stage:SetScript("OnUpdate", function(_, dt)
    if not flip:IsShown() then return end
    clock = clock + dt
    local i = math.floor(clock * fps) % FRAMES
    local r, c = math.floor(i / COLS), i % COLS
    flip:SetTexCoord(c / COLS, (c + 1) / COLS, r / ROWS, (r + 1) / ROWS)
  end)

  function stage:Play(sequence)
    flip:Hide(); m:Show()
    seq = sequence or W.MOVE_DEFAULT
    Dress(m)
    play(1)
  end

  -- Exercise: its sprite sheet if one exists, otherwise the 3D model.
  -- fallback: the 3D model's own animations (W.MOVES[name], or `fallback`)
  function stage:PlayExercise(name, fallback)
    local sheets = W.SHEETS and W.SHEETS[W:Coach()]
    local sheet = sheets and sheets[name]
    if not sheet then return self:Play(fallback or W.MOVES[name]) end
    seq = nil; m:Hide()
    flip:SetTexture(sheet.path)
    -- fit the frame (sheet.w x sheet.h) inside the stage, keeping its shape
    local scale = math.min((w - 8) / sheet.w, (h - 8) / sheet.h)
    flip:SetSize(sheet.w * scale, sheet.h * scale)
    COLS, ROWS = sheet.cols or 4, sheet.rows or 4
    FRAMES = COLS * ROWS
    fps = FRAMES / math.max(0.5, sheet.duration or 1.3)
    clock = 0
    flip:SetTexCoord(0, 1 / COLS, 0, 1 / ROWS)   -- first frame right away
    flip:Show()
  end
  function stage:Hold(anim) seq = nil; Dress(m); m:SetAnimation(anim) end
  return stage
end

-- Animation lab: /wo anim -- browse animation IDs on the model to tune W.MOVES -----------
local lab
local function OpenLab()
  if not lab then
    lab = UI.Window("WorcOutAnimLab", 300, 380, L["Animation lab"])
    lab:SetPoint("CENTER", 380, 0)
    local stage = UI.Stage(lab, 260, 220)
    stage:SetPoint("TOP", 0, -50)
    local id = 0
    local label = UI.Text(lab, 28, C.text)
    label:SetPoint("TOP", stage, "BOTTOM", 0, -14)
    label:SetJustifyH("CENTER")
    local hint = UI.Text(lab, 12, C.muted)
    hint:SetPoint("TOP", label, "BOTTOM", 0, -4)
    hint:SetText(L["Animation ID (some IDs do nothing)"])
    local function show() label:SetText(id); stage:Hold(id) end
    local prev = UI.Button(lab, L["< Prev"], "ghost", 120, 30, function() id = math.max(0, id - 1); show() end)
    prev:SetPoint("BOTTOMLEFT", 20, 20)
    local nxt = UI.Button(lab, L["Next >"], "primary", 120, 30, function() id = id + 1; show() end)
    nxt:SetPoint("BOTTOMRIGHT", -20, 20)
    lab:SetScript("OnShow", show)
    lab.set = function(n) id = n; show() end
  end
  lab:Show()
  return lab
end
W.OpenAnimLab = OpenLab
