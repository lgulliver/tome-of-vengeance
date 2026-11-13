local _, ns = ...

local Book, Theme = ns.UI.Book, ns.UI.Theme
local Page = {}
ns.UI.Nemeses = Page

local function identity(rec)
  local race, class = ns.Roster.race(rec.raceFile), ns.Roster.class(rec.classFile)
  if not race and not class then return "Unknown" end
  return (race and Book.display(race, "race") or "") .. (race and class and " " or "")
    .. (class and Book.display(class, "class") or "")
end

function Page.entry(host, db, guid)
  local rec = db.players[guid]
  if not rec then Book.text(host, "Choose a foe to read their story.", -42); return end
  Book.text(host, rec.name or "Unknown", 0, 20, Theme.BLOOD)
  Book.text(host, rec.realm or "Unknown realm", -35)
  Book.text(host, identity(rec), -62)
  local y = -90
  if rec.level then Book.text(host, "Level " .. rec.level, y); y = y - 27 end
  if rec.guild then Book.text(host, rec.guild, y); y = y - 27 end
  Book.text(host, "Slain: " .. rec.kills, y)
  Book.text(host, "Slain by: " .. rec.deaths, y - 22)
  y = y - 60
  for _, field in ipairs({ "first", "last" }) do
    local met = rec[field]
    local stamp = met and met.t and date("%Y-%m-%d %H:%M", met.t) or "Unknown"
    Book.text(host, (field == "first" and "First met: " or "Last met: ") .. stamp, y, 14)
    Book.text(host, met and met.zone or "Unknown zone", y - 21, 14)
    y = y - 49
  end
  for _, kind in ipairs({ "world", "battleground", "arena" }) do
    local counts = rec.ctx[kind]
    Book.text(host, kind:sub(1, 1):upper() .. kind:sub(2) .. ": " .. counts.k .. " / " .. counts.d, y, 14)
    y = y - 24
  end
  for i = #db.ledger, 1, -1 do
    local event = db.ledger[i]
    if event.guid == guid then
      if event.kind == "kill" then Book.text(host, "Avenged", y - 12, 16, Theme.BLOOD); y = y - 36 end
      break
    end
  end
  host:SetHeight(math.max(420, -y + 20))
end

Book.registerSection("nemeses", {
  label = "nemeses", order = 3,
  buildIndex = function(host, db)
    Book.text(host, "Nemeses", 0, 20, Theme.BLOOD)
    host.rows = {}
    local list = ns.Nemesis.list(db)
    if #list == 0 then Book.text(host, "No one has bested you thrice. Yet.", -42) end
    for i, rec in ipairs(list) do
      local guid = rec.guid
      local row = Book.region(host, "Button")
      row:SetSize(366, 54)
      row:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -38 - (i - 1) * 58)
      row.key = guid
      Book.highlight(row)
      Book.text(row, (rec.name or "Unknown") .. "   " .. rec.kills .. " / " .. rec.deaths, 0)
      Book.text(row, identity(rec), -25, 12)
      row:SetScript("OnClick", function() Book.open("nemeses", guid) end)
      host.rows[#host.rows + 1] = row
    end
    host:SetHeight(math.max(420, 42 + #list * 58))
  end,
  buildEntry = Page.entry,
})
