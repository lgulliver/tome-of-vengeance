local _, ns = ...

ns.UI = ns.UI or {}

local Theme = {
  PARCHMENT_LIGHT = { 0.953, 0.890, 0.749 },
  PARCHMENT_DARK = { 0.886, 0.788, 0.576 },
  INK = { 0.16, 0.10, 0.05 },
  INK_FADED = { 0.34, 0.25, 0.16 },
  BLOOD = { 0.541, 0.110, 0.063 },
  GOLD = { 0.788, 0.635, 0.290 },
  GOLD_TEXT = { 1, 0.906, 0.627 },
  TOAST_BG = { 0.106, 0.071, 0.043 },

  media = {
    flat = "Interface\\Buttons\\WHITE8x8",
    parchment = "Interface\\Stationery\\StationeryTest1",
    parchmentAlt = "Interface\\QuestFrame\\QuestBG",
    leather = "Interface\\AchievementFrame\\UI-Achievement-AchievementBackground",
    goldBorder = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    toastBorder = "Interface\\DialogFrame\\UI-DialogBox-Border",
    statusBar = "Interface\\TargetingFrame\\UI-StatusBar",
    classIcons = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes",
  },
}

-- Headings use the quest-title face (Morpheus), so the book reads like Blizzard's own.
function Theme.font(size, outline, heading)
  local name = "TomeOfVengeance_Font" .. size .. (outline and "SC" or "") .. (heading and "H" or "")
  local f = _G[name]
  if not f then
    f = CreateFont(name)
    local base = heading and QuestTitleFont or GameFontNormal
    local path, _, flags = base:GetFont()
    f:SetFont(path, size, outline and "OUTLINE" or (flags or ""))
  end
  return f
end

-- Class colours are tuned for dark backgrounds; darken bright ones, keeping hue, so they read on parchment.
function Theme.onParchment(c)
  local lum = 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3]
  local scale = lum > 0.2 and 0.2 / lum or 1
  return { c[1] * scale, c[2] * scale, c[3] * scale }
end

local function colorTexture(tex, c, a)
  tex:SetColorTexture(c[1], c[2], c[3], a or c[4] or 1)
end

function Theme.panel(parent, kind)
  local f = CreateFrame("Frame", nil, parent)
  local bg, border = Theme.TOAST_BG, Theme.GOLD
  if kind == "nemesis" then
    bg, border = Theme.TOAST_BG, Theme.BLOOD
  elseif kind == "inset" then
    bg, border = { 0.08, 0.055, 0.035, 1 }, Theme.GOLD
  elseif kind == "raised" then
    bg, border = { 0.14, 0.095, 0.06, 1 }, Theme.GOLD
  end

  -- The border bleeds 2px past the frame; the fill above it leaves only that rim visible.
  local fill = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  fill:SetAllPoints(f)
  colorTexture(fill, bg)
  f.fill = fill

  local borderTex = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  borderTex:SetPoint("TOPLEFT", f, "TOPLEFT", -2, 2)
  borderTex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -2)
  borderTex:SetTexture(Theme.media.flat)
  borderTex:SetVertexColor(border[1], border[2], border[3], 1)
  f.border = borderTex

  return f
end

ns.UI.Theme = Theme
