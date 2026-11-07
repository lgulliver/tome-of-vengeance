local _, ns = ...

local Book, Theme = ns.UI.Book, ns.UI.Theme
Book.registerSection("titles", {
  label = "titles", order = 5,
  buildIndex = function(host, db)
    Book.text(host, "EARNED TITLES", 0, 20, Theme.BLOOD)
    local y = -38
    host.rows = {}
    for _, group in ipairs({ { "total", "Overall" }, { "race", "Races" }, { "class", "Classes" }, { "special", "Deeds" } }) do
      local ids = {}
      for id in pairs(db.titles) do
        if id:match("^([^:]+):") == group[1] then ids[#ids + 1] = id end
      end
      table.sort(ids, function(a, b)
        local an, bn = ns.Titles.name(a), ns.Titles.name(b)
        return an == bn and a < b or an < bn
      end)
      if #ids > 0 then
        Book.text(host, group[2]:upper(), y, 16, Theme.BLOOD)
        y = y - 28
        for _, id in ipairs(ids) do
          local row = Book.region(host, "Button")
          row:SetSize(366, 28)
          row:SetPoint("TOPLEFT", host, "TOPLEFT", 12, y)
          row.key = id
          Book.text(row, (db.activeTitle == id and "• " or "") .. ns.Titles.name(id), 0)
          row:SetScript("OnClick", function() ns.App.db.activeTitle = id; Book.open("titles", id) end)
          host.rows[#host.rows + 1] = row
          y = y - 30
        end
        y = y - 12
      end
    end
    if #host.rows == 0 then Book.text(host, "Your deeds have yet to earn a title.", y) end
    host:SetHeight(math.max(420, -y + 20))
  end,
  buildEntry = function(host, db)
    Book.text(host, "YOUR EPITHET", 0, 20, Theme.BLOOD)
    Book.text(host, db.activeTitle and ns.Titles.name(db.activeTitle) or "Choose an earned title.", -42)
    Book.text(host, "Titles live within the Tome.", -80, 13)
  end,
})
