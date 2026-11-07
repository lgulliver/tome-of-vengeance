local _, ns = ...

local Book, Theme = ns.UI.Book, ns.UI.Theme
Book.registerSection("ledger", {
  label = "ledger", order = 4,
  buildIndex = function(host, db)
    Book.text(host, "RECENT ENCOUNTERS", 0, 20, Theme.BLOOD)
    host.rows = {}
    if #db.ledger == 0 then Book.text(host, "No encounters recorded. Yet.", -42) end
    for i = #db.ledger, 1, -1 do
      local event = db.ledger[i]
      local rec = db.players[event.guid]
      local row = Book.region(host, "Button")
      row:SetSize(366, 70)
      row:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -38 - (#db.ledger - i) * 74)
      row.event = event
      Book.text(row, date("%Y-%m-%d %H:%M", event.t), 0, 12)
      Book.text(row, (event.kind == "kill" and "Slew " or "Slain by ") .. (rec and rec.name or "Unknown"), -21, 14, Theme.BLOOD)
      Book.text(row, (event.zone or "Unknown zone") .. " · " .. (event.ctxKind or "world"), -45, 12)
      row:SetScript("OnClick", function() Book.open("nemeses", event.guid) end)
      host.rows[#host.rows + 1] = row
    end
    host:SetHeight(math.max(420, 42 + #db.ledger * 74))
  end,
  buildEntry = ns.UI.Nemeses.entry,
})
