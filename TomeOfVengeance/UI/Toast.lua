local _, ns = ...

local Theme = ns.UI.Theme
local Toast = {}

local W, H = 360, 90
local FADE_IN, HOLD, FADE_OUT = 0.25, 3.5, 0.25

local frame, header, title, reason
local queue = {}
local showing = nil
local state, elapsed = "idle", 0

local function build()
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetFrameLevel(100)
  f:SetSize(W, H)
  f:SetPoint("TOP", UIParent, "TOP", 0, -120)
  f:EnableMouse(false)
  f:Hide()

  local panel = Theme.panel(f, "toast")
  panel:SetAllPoints(f)
  f.panel = panel

  -- Text goes on the panel: a child frame draws over its parent's regions, hiding them.
  header = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  header:SetPoint("TOP", f, "TOP", 0, -14)
  header:SetWidth(W - 24)
  header:SetJustifyH("CENTER")
  header:SetTextColor(Theme.PARCHMENT_DARK[1], Theme.PARCHMENT_DARK[2], Theme.PARCHMENT_DARK[3], 1)

  title = panel:CreateFontString(nil, "OVERLAY")
  title:SetFontObject(Theme.font(18, true))
  title:SetPoint("TOP", header, "BOTTOM", 0, -4)
  title:SetWidth(W - 24)
  title:SetJustifyH("CENTER")
  title:SetTextColor(Theme.GOLD_TEXT[1], Theme.GOLD_TEXT[2], Theme.GOLD_TEXT[3], 1)

  reason = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  reason:SetPoint("TOP", title, "BOTTOM", 0, -4)
  reason:SetWidth(W - 24)
  reason:SetJustifyH("CENTER")
  reason:SetTextColor(Theme.PARCHMENT_LIGHT[1], Theme.PARCHMENT_LIGHT[2], Theme.PARCHMENT_LIGHT[3], 1)

  f:SetScript("OnUpdate", function(self, dt)
    local remaining = dt
    while remaining > 0 do
      if state == "in" then
        local need = FADE_IN - elapsed
        if remaining < need then
          elapsed = elapsed + remaining
          f:SetAlpha(elapsed / FADE_IN)
          break
        end
        f:SetAlpha(1)
        remaining = remaining - need
        state, elapsed = "hold", 0
      elseif state == "hold" then
        local need = HOLD - elapsed
        if remaining < need then
          elapsed = elapsed + remaining
          break
        end
        remaining = remaining - need
        state, elapsed = "out", 0
      elseif state == "out" then
        local need = FADE_OUT - elapsed
        if remaining < need then
          elapsed = elapsed + remaining
          f:SetAlpha(1 - elapsed / FADE_OUT)
          break
        end
        f:SetAlpha(0)
        f:Hide()
        remaining = remaining - need
        state, showing = "idle", nil
        Toast._next()
        if state == "idle" then break end
      else
        break
      end
    end
  end)

  frame = f
  return f
end

local function play(ann)
  local settings = ns.App and ns.App.db and ns.App.db.settings or {}
  if settings.sound then
    ns.Compat.playSound(ns.Data.Sounds.forKind(ann.kind, settings))
  end
end

local function showCurrent(ann)
  local f = frame or build()
  showing = ann
  state, elapsed = "in", 0
  f:SetAlpha(0)
  f:Show()
  header:SetText(ann.header or "")
  title:SetText(ann.title or "")
  reason:SetText(ann.reason or "")
  local border = ann.kind == "nemesis" and Theme.BLOOD or Theme.GOLD
  f.panel.border:SetVertexColor(border[1], border[2], border[3], 1)
  play(ann)
end

function Toast._next()
  if showing or #queue == 0 then return end
  showCurrent(table.remove(queue, 1))
end

function Toast.show(ann)
  queue[#queue + 1] = ann
  Toast._next()
end

function Toast.queueLength()
  return #queue + (showing and 1 or 0)
end

function Toast.borderColor()
  if not frame then return nil end
  return { frame.panel.border:GetVertexColor() }
end

ns.UI.Toast = Toast
