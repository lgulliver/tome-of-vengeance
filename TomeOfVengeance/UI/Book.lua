local _, ns = ...

local Theme = ns.UI.Theme
local Book = {}
local sections, frame = {}, nil

local function reset(host)
  host.poolUsed = {}
  for _, pool in pairs(host.pool or {}) do
    for _, child in ipairs(pool) do
      reset(child)
      child:Hide()
    end
  end
end

local function region(parent, kind)
  parent.pool, parent.poolUsed = parent.pool or {}, parent.poolUsed or {}
  local pool = parent.pool[kind] or {}
  parent.pool[kind] = pool
  local index = (parent.poolUsed[kind] or 0) + 1
  parent.poolUsed[kind] = index
  local child = pool[index]
  if not child then
    if kind == "FontString" then child = parent:CreateFontString(nil, "OVERLAY")
    elseif kind == "Texture" then child = parent:CreateTexture(nil, "BACKGROUND")
    else child = CreateFrame(kind, nil, parent) end
    pool[index] = child
  end
  child:ClearAllPoints()
  child:SetAlpha(1)
  child:Show()
  return child
end

local function text(parent, value, y, size, color)
  local label = region(parent, "FontString")
  label:SetFontObject(Theme.font(size or 14, size == 20))
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
  label:SetWidth(parent:GetWidth() - 24)
  label:SetJustifyH("LEFT")
  label:SetTextColor(unpack(color or Theme.INK))
  label:SetText(value)
  return label
end
Book.text = text
Book.region = region

local function page(parent, x)
  local paper = CreateFrame("Frame", nil, parent)
  paper:SetSize(410, 452)
  paper:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -66)
  local bg = paper:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture(Theme.media.parchment)
  bg:SetVertexColor(unpack(Theme.PARCHMENT_LIGHT))
  local scroll = CreateFrame("ScrollFrame", nil, paper)
  scroll:SetPoint("TOPLEFT", paper, "TOPLEFT", 10, -12)
  scroll:SetPoint("BOTTOMRIGHT", paper, "BOTTOMRIGHT", -10, 12)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScroll() - delta * 30, self:GetVerticalScrollRange())))
  end)
  paper.scroll = scroll
  return paper
end

local function content(paper)
  local host = paper.content or CreateFrame("Frame", nil, paper.scroll)
  reset(host)
  host:SetSize(390, 420)
  paper.scroll:SetScrollChild(host)
  paper.scroll:SetVerticalScroll(0)
  paper.content = host
  host:Show()
  return host
end

local function tabs()
  if frame.tabs then for _, tab in ipairs(frame.tabs) do tab:Hide() end end
  frame.tabs = {}
  local ordered = {}
  for id, section in pairs(sections) do ordered[#ordered + 1] = { id = id, section = section } end
  table.sort(ordered, function(a, b) return a.section.order < b.section.order end)
  local x = 32
  for _, entry in ipairs(ordered) do
    local tab = CreateFrame("Button", nil, frame)
    tab:SetSize(62, 25)
    tab:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -38)
    tab.label = text(tab, entry.section.label:upper(), 0, 10, Theme.GOLD_TEXT)
    tab.label:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    tab.label:SetWidth(62)
    tab:SetScript("OnClick", function() Book.open(entry.id) end)
    tab:Show()
    frame.tabs[#frame.tabs + 1] = tab
    x = x + 63
  end
end

function Book.registerSection(id, section)
  sections[id] = section
  if frame then tabs() end
end

function Book.create()
  if frame then return end
  frame = CreateFrame("Frame", "TomeOfVengeanceBook", UIParent)
  frame:SetSize(880, 550)
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  local pos = ns.App.db.settings.bookPos
  frame:SetPoint(pos and pos.point or "CENTER", UIParent, pos and pos.relativePoint or "CENTER", pos and pos.x or 0, pos and pos.y or 0)
  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    ns.App.db.settings.bookPos = { point = point, relativePoint = relativePoint, x = x, y = y }
  end)
  local cover = Theme.panel(frame, "raised")
  cover:SetAllPoints()
  local leather = cover:CreateTexture(nil, "ARTWORK")
  leather:SetAllPoints()
  leather:SetTexture(Theme.media.leather)
  leather:SetVertexColor(0.28, 0.17, 0.10)
  text(frame, "TOME OF VENGEANCE", -12, 20, Theme.GOLD_TEXT)
  frame.activeTitle = text(frame, "", -17, 13, Theme.GOLD_TEXT)
  frame.activeTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 470, -17)
  frame.activeTitle:SetWidth(340)
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() frame:Hide() end)
  frame.leftPaper, frame.rightPaper = page(frame, 24), page(frame, 446)
  local gutter = frame:CreateTexture(nil, "ARTWORK")
  gutter:SetColorTexture(0.23, 0.14, 0.07, 1)
  gutter:SetSize(12, 452)
  gutter:SetPoint("TOPLEFT", frame, "TOPLEFT", 434, -66)
  table.insert(UISpecialFrames, "TomeOfVengeanceBook")
  tabs()
  frame:Hide()
end

function Book.open(section, key)
  Book.create()
  section = sections[section] and section or "races"
  frame.section, frame.key = section, key
  frame.activeTitle:SetText(ns.App.db.activeTitle and ns.Titles.name(ns.App.db.activeTitle) or "")
  frame.leftPage, frame.rightPage = content(frame.leftPaper), content(frame.rightPaper)
  local def = sections[section]
  def.buildIndex(frame.leftPage, ns.App.db)
  def.buildEntry(frame.rightPage, ns.App.db, key)
  for _, tab in ipairs(frame.tabs) do
    tab.label:SetTextColor(unpack(tab.label:GetText() == def.label:upper() and Theme.PARCHMENT_LIGHT or Theme.GOLD))
  end
  frame:Show()
end

function Book.toggle()
  if Book.isShown() then frame:Hide() else Book.open(frame and frame.section or "races", frame and frame.key) end
end

function Book.isShown()
  return frame ~= nil and frame:IsShown()
end

local function display(entry, kind)
  if kind == "race" and C_CreatureInfo and C_CreatureInfo.GetRaceInfo then
    local info = C_CreatureInfo.GetRaceInfo(entry.raceID)
    if info and info.raceName then return info.raceName end
  elseif kind == "class" then
    if C_CreatureInfo and C_CreatureInfo.GetClassInfo then
      local info = C_CreatureInfo.GetClassInfo(entry.classID)
      if info and info.className then return info.className end
    end
    if LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[entry.classFile] then
      return LOCALIZED_CLASS_NAMES_MALE[entry.classFile]
    end
  end
  return entry.singular
end

Book.display = display

function Book.collection(kind, heading)
  local section = kind == "race" and "races" or "classes"
  local field = kind == "race" and "raceFile" or "classFile"
  return {
    label = section, order = kind == "race" and 1 or 2,
    buildIndex = function(host, db)
      text(host, heading:upper(), 0, 20, Theme.BLOOD)
      local entries = kind == "race" and ns.Roster.races(ns.Compat.expansion(), ns.Compat.isRetail(), db.factionsSeen)
        or ns.Roster.classes(ns.Compat.expansion())
      host.rows = {}
      for i, entry in ipairs(entries) do
        local key = entry[field]
        local counts = db[section][key]
        local unlocked = counts and counts.unlockedAt ~= nil
        local row = region(host, "Button")
        row:SetSize(366, 27)
        row:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -36 - (i - 1) * 29)
        row.key = key
        local color = kind == "class" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[key]
        color = color and { color.r, color.g, color.b } or Theme.INK
        row.label = text(row, unlocked and display(entry, kind) or "???", -4, 14, color)
        row.label:SetWidth(280)
        row.count = text(row, unlocked and tostring(counts.kills) or "???", -4, 14)
        row.count:SetPoint("TOPLEFT", row, "TOPLEFT", 300, -4)
        row.count:SetWidth(54)
        row.count:SetJustifyH("RIGHT")
        if not unlocked then
          -- Font flags have no italic; fading carries the locked look.
          row:SetAlpha(0.45)
        end
        local rule = region(row, "Texture")
        rule:SetColorTexture(0.48, 0.34, 0.18, 0.2)
        rule:SetSize(366, 1)
        rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT")
        row:SetScript("OnClick", function() Book.open(section, key) end)
        row:Show()
        host.rows[#host.rows + 1] = row
      end
      host:SetHeight(math.max(420, 40 + #entries * 29))
    end,
    buildEntry = function(host, db, key)
      local entry = kind == "race" and ns.Roster.race(key) or ns.Roster.class(key)
      local counts = db[section][key]
      if not entry or not counts or counts.unlockedAt == nil then
        text(host, "???", 0, 20, Theme.BLOOD)
        host.prompt = text(host, "Slay one to fill this page.", -42)
        return
      end
      text(host, display(entry, kind):upper(), 0, 20, Theme.BLOOD)
      host.stats = text(host, "Slain: " .. counts.kills .. " · Slain by: " .. counts.deaths, -38)
      local count, tier, name = ns.Titles.progress(db, kind, key)
      local bar = region(host, "StatusBar")
      bar:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -65)
      bar:SetSize(366, 7)
      bar:SetStatusBarTexture(Theme.media.flat)
      bar:SetStatusBarColor(unpack(Theme.BLOOD))
      bar:SetMinMaxValues(0, tier or math.max(1, count))
      bar:SetValue(count)
      local bg = region(bar, "Texture")
      bg:SetAllPoints()
      bg:SetColorTexture(unpack(Theme.PARCHMENT_DARK))
      text(host, tier and ("Next title at " .. tier .. ": " .. name) or "Every title earned", -85, 13)
      text(host, "TITLES EARNED", -132, 16, Theme.BLOOD)
      local y, earned = -159, false
      for _, n in ipairs(ns.Data.Titles.TIERS) do
        local id = kind .. ":" .. key .. ":" .. n
        if db.titles[id] ~= nil then
          text(host, ns.Titles.name(id) .. " (" .. n .. ")", y, 13)
          y, earned = y - 24, true
        end
      end
      if not earned then text(host, "None yet", y, 13); y = y - 24 end
      text(host, "MOST SLAIN", y - 16, 16, Theme.BLOOD)
      y = y - 45
      local players = {}
      for guid, rec in pairs(db.players) do
        if rec[field] == key and rec.kills > 0 then players[#players + 1] = { guid = guid, rec = rec } end
      end
      table.sort(players, function(a, b)
        if a.rec.kills ~= b.rec.kills then return a.rec.kills > b.rec.kills end
        local an, bn = a.rec.name or "Unknown", b.rec.name or "Unknown"
        if an ~= bn then return an < bn end
        return a.guid < b.guid
      end)
      for i = 1, math.min(5, #players) do
        local rec = players[i].rec
        text(host, (rec.name or "Unknown") .. (rec.realm and ("-" .. rec.realm) or "") .. " — " .. rec.kills, y, 13)
        y = y - 24
      end
      host:SetHeight(math.max(420, -y + 16))
    end,
  }
end

ns.UI.Book = Book
