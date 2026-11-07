-- Headless smoke of the real addon UI.
local function check(value, message) assert(value, message) end
local function near(a, b) return math.abs(a - b) < 0.01 end

for _, retail in ipairs({ true, false }) do
  local env = dofile("tests/wow_stub.lua")
  if not retail then
    env.WOW_PROJECT_ID = 2
    env.issecretvalue = nil
    env.Settings = nil
    env.GetClientDisplayExpansionLevel = function() return 0 end
  end

  local recorded, sounds = {}, {}
  local ns = {}

  local toc = assert(io.open("TomeOfVengeance/TomeOfVengeance.toc"))
  for line in toc:lines() do
    line = line:gsub("\r", ""):match("^%s*(.-)%s*$")
    if line ~= "" and line:sub(1, 1) ~= "#" then
      setfenv(assert(loadfile("TomeOfVengeance/" .. line:gsub("\\", "/"))), env)("TomeOfVengeance", ns)
    end
  end
  toc:close()

  -- Wrap the real Toast so tests can inspect announcements and sound calls.
  local origShow = ns.UI.Toast.show
  ns.UI.Toast.show = function(ann)
    recorded[#recorded + 1] = ann
    return origShow(ann)
  end
  local origPlaySound = ns.Compat.playSound
  ns.Compat.playSound = function(key)
    sounds[#sounds + 1] = key
    return origPlaySound(key)
  end

  check(ns.App, "Task 7 glue missing")
  env.fire("ADDON_LOADED", "OtherAddon")
  check(not env.TomeOfVengeanceDB, "unrelated addon ignored")
  env.fire("ADDON_LOADED", "TomeOfVengeance")
  local db = env.TomeOfVengeanceDB
  check(db.version == 1 and ns.App.db == db, "database initialised")
  env.fire("PLAYER_LOGIN")
  check(db.factionsSeen.Horde, "login faction")
  check(ns.Compat.isRetail() == retail, "flavour")
  check(ns.Compat.context().char == "Hero-Home", "character key")

  local Book = ns.UI.Book
  check(Book, "real Book module loaded")
  Book.toggle()
  local book = env.TomeOfVengeanceBook
  check(Book.isShown() and book.section == "races", "book defaults to races")
  check(env.UISpecialFrames[1] == book:GetName(), "Escape frame registered")
  if not retail then
    check(#book.leftPage.rows == 4, "Classic Horde sees four races")
    for _, row in ipairs(book.leftPage.rows) do
      check(row.label:GetText() == "???" and row.count:GetText() == "???", "locked rows hide name and count")
    end
  end
  Book.toggle()

  local enemy = 0x540
  local function cleu(sub, source, sourceName, flags, dest, destName, destFlags)
    env.cleu = { 100, sub, false, source, sourceName, flags, 0, dest, destName, destFlags, 0 }
    env.fire("COMBAT_LOG_EVENT_UNFILTERED")
  end

  cleu("PARTY_KILL", "ME", "Hero", 0x511, "E1", "Fizz-Away", enemy)
  check(db.total.kills == 1 and db.races.Gnome.unlockedAt, "kill unlocks race")
  check(ns.UI.Toast.queueLength() == 3, "toast queue holds two unlocks and a title")
  check(recorded[1].kind == "unlock" and recorded[2].kind == "unlock", "race/class unlock announcements")
  check(recorded[3].kind == "title" and recorded[3].title == "Blooded", "first kill earns Blooded")
  check(db.players.E1.realm == "Away", "identity realm")

  Book.open("races", "Gnome")
  check(book.rightPage.stats:GetText():find("Slain: 1", 1, true), "race entry shows kill")
  local gnome
  for _, row in ipairs(book.leftPage.rows) do if row.key == "Gnome" then gnome = row end end
  check(gnome and gnome.count:GetText() == "1" and gnome.label:GetText() == "Gnome", "race unlock refreshed")
  gnome:Click()
  check(book.key == "Gnome", "index click selects entry")
  if retail then
    book.leftPaper.scroll:GetScript("OnMouseWheel")(book.leftPaper.scroll, -100)
    check(book.leftPaper.scroll:GetVerticalScroll() > 0, "long roster scrolls")
  end
  Book.open("classes", "MAGE")
  check(book.rightPage.stats:GetText():find("Slain: 1", 1, true), "class entry shows kill")
  local mage
  for _, row in ipairs(book.leftPage.rows) do if row.key == "MAGE" then mage = row end end
  check(near(select(1, mage.label:GetTextColor()), env.RAID_CLASS_COLORS.MAGE.r), "class colour")
  check(#book.tabs == 6, "six top section links")
  for _, id in ipairs({ "nemeses", "ledger", "titles", "settings" }) do
    Book.open(id)
    check(book.section == id, "section opens: " .. id)
  end
  Book.open("races", "Human")
  check(book.rightPage.prompt:GetText() == "Slay one to fill this page.", "locked entry prompt")
  db.activeTitle = "total:1"
  Book.open("races", "Gnome")
  check(book.activeTitle:GetText() == "Blooded", "header active title")
  book:SetPoint("CENTER", env.UIParent, "CENTER", 25, -35)
  book:GetScript("OnDragStop")(book)
  check(db.settings.bookPos.x == 25 and db.settings.bookPos.y == -35, "drag position saved")
  Book.toggle()
  local function contains(host, value)
    for _, child in ipairs(host._children) do
      if child._shown ~= false or child._kind == "FontString" then
        if child._text and child._text:find(value, 1, true) then return true end
      end
    end
    return false
  end
  db.races.Gnome.kills = 211
  db.titles["race:Gnome:10"] = 1000
  Book.open("races", "Gnome")
  check(contains(book.rightPage, "Next title at 250: Bane of the Tinkerers"), "next tier rendered")
  check(contains(book.rightPage, "Gnome Punter (10)"), "earned title rendered")
  check(contains(book.rightPage, "Fizz-Away"), "most slain rendered")
  db.races.Gnome.kills = 1000
  Book.open("races", "Gnome")
  check(contains(book.rightPage, "Every title earned"), "final tier rendered")
  db.races.Gnome.kills = 1
  local frameCount = #env.frames
  for _ = 1, 5 do Book.open("races", "Gnome") end
  check(#env.frames == frameCount, "repeated navigation reuses frames")
  Book.toggle()

  env.advance(4.5)
  check(ns.UI.Toast.queueLength() == 2, "two toasts remain after 4s")

  cleu("SPELL_DAMAGE", "E1", "Fizz-Away", enemy, "ME", "Hero", 0x511)
  env.fire("PLAYER_DEAD")
  check(db.total.deaths == 1, "damage attributed")

  local lookup = env.GetPlayerInfoByGUID
  env.GetPlayerInfoByGUID = function() return nil end
  cleu("SWING_DAMAGE", "E2", "Unknown-Elsewhere", enemy, "ME", "Hero", 0x511)
  env.fire("PLAYER_DEAD")
  check(db.players.E2.name == "Unknown" and db.players.E2.realm == "Elsewhere", "uncached death preserves realm")
  env.GetPlayerInfoByGUID = lookup

  env.secret = "E1"
  cleu("PARTY_KILL", "ME", "Hero", 0x511, "E1", "Fizz-Away", enemy)
  check(db.total.kills == (retail and 1 or 2), "secret events skipped when supported")
  env.secret = nil

  local kills, deaths = db.total.kills, db.total.deaths
  for _, start in ipairs({ "requested", "challenged" }) do
    if start == "requested" then env.fire("DUEL_REQUESTED", "Fizz") else env.StartDuel("target") end
    cleu("PARTY_KILL", "ME", "Hero", 0x511, "E1", "Fizz-Away", enemy)
    cleu("SPELL_DAMAGE", "E1", "Fizz-Away", enemy, "ME", "Hero", 0x511)
    env.fire("DUEL_FINISHED")
    env.fire("PLAYER_DEAD")
    env.Ambiguate = nil
  end
  check(db.total.kills == kills and db.total.deaths == deaths, "cross-realm duel excluded")

  while db.players.E1.deaths < 3 do
    cleu("SPELL_DAMAGE", "E1", "Fizz-Away", enemy, "ME", "Hero", 0x511)
    env.fire("PLAYER_DEAD")
  end
  local soundCount = #sounds
  db.settings.sound = false
  cleu("SWING_DAMAGE", "ME", "Hero", 0x511, "E1", "Fizz-Away", enemy)
  check(recorded[#recorded].kind == "nemesis", "hostile combat-log destination sighted")
  check(#sounds == soundCount, "sound disabled does not call PlaySound")
  db.settings.sound = true

  -- Earlier titles queue ahead of the banner; drain to the last toast.
  for _ = 1, 20 do
    if ns.UI.Toast.queueLength() <= 1 then break end
    env.advance(4.5)
  end
  local border = ns.UI.Toast.borderColor()
  check(border and near(border[1], ns.UI.Theme.BLOOD[1]) and near(border[2], ns.UI.Theme.BLOOD[2])
    and near(border[3], ns.UI.Theme.BLOOD[3]), "nemesis border is blood coloured")

  env.fire("NAME_PLATE_UNIT_ADDED", "target")
  check(recorded[#recorded].kind == "nemesis" and db.players.E1.level == 60, "sighting enriches and alerts")
  local length = #recorded
  env.fire("PLAYER_TARGET_CHANGED")
  env.fire("UPDATE_MOUSEOVER_UNIT")
  check(#recorded == length, "sightings throttled")

  env.SlashCmdList.TOMEOFVENGEANCE("")
  check(Book.isShown(), "slash toggles")
  env.TomeOfVengeance_OnCompartmentClick()
  check(not Book.isShown(), "compartment toggles")
  env.SlashCmdList.TOMEOFVENGEANCE("settings")
  check(Book.isShown() and book.section == "settings", "settings opens")
  Book.open("nemeses", "E1")
  check(#book.leftPage.rows == 1 and book.leftPage.rows[1].key == "E1", "nemesis list uses threshold")
  check(contains(book.rightPage, "Enemy Guild"), "player detail includes guild")
  Book.open("ledger")
  check(book.leftPage.rows[1].event == db.ledger[#db.ledger], "ledger newest first")
  book.leftPage.rows[1]:Click()
  check(book.section == "nemeses" and book.key == db.ledger[#db.ledger].guid, "ledger opens any player")
  Book.open("titles")
  check(#book.leftPage.rows >= 2, "earned titles listed")
  book.leftPage.rows[1]:Click()
  check(db.activeTitle == book.leftPage.rows[1].key and book.activeTitle:GetText() == ns.Titles.name(db.activeTitle), "title click updates header")
  check(ns.UI.Minimap.button:IsShown(), "minimap created")
  local minimap = ns.UI.Minimap.button
  minimap:GetScript("OnEnter")(minimap)
  check(env.GameTooltip._text == "Tome of Vengeance" and env.GameTooltip._line:find("Slain: ", 1, true), "minimap tooltip totals")
  minimap:GetScript("OnLeave")(minimap)
  minimap:GetScript("OnDragStart")(minimap)
  env.advance(0.1)
  check(near(db.settings.minimapAngle, 0), "minimap drag saves angle")
  minimap:GetScript("OnDragStop")(minimap)
  check(not minimap:GetScript("OnUpdate"), "minimap drag stops")
  ns.UI.Minimap.button:Click()
  check(not Book.isShown(), "minimap toggles book")
  Book.open("settings")
  book.leftPage.controls.minimap:Click()
  check(not db.settings.minimap and not ns.UI.Minimap.button:IsShown(), "minimap setting hides button")
  book.leftPage.controls.alerts:Click()
  check(not db.settings.alerts, "alerts checkbox saved")
  book.leftPage.controls.sound:Click()
  check(not db.settings.sound, "sound checkbox saved")
  book.leftPage.controls.threshold:SetValue(4)
  check(db.settings.nemesisThreshold == 4, "threshold slider saved")
  Book.open("nemeses")
  check(#book.leftPage.rows == 0 and contains(book.leftPage, "No one has bested you thrice. Yet."), "threshold removes nemesis")
  Book.open("settings")
  local oldSound = db.settings.sounds.unlock
  book.rightPage.sounds.unlock.select:Click()
  check(db.settings.sounds.unlock ~= oldSound, "sound cycles shortlist")
  book.rightPage.sounds.unlock.play:Click()
  check(sounds[#sounds] == db.settings.sounds.unlock, "preview uses selected sound even muted")
  local warmed = #env.frames
  for _ = 1, 5 do Book.open("settings") end
  check(#env.frames == warmed, "settings reuses pooled controls")
  db.ledger[#db.ledger + 1] = { t = 1001, kind = "kill", guid = "E2", zone = "Duskwood", ctxKind = "world" }
  Book.open("ledger")
  book.leftPage.rows[1]:Click()
  check(book.key == "E2" and contains(book.rightPage, "Avenged"), "non-nemesis player shows revenge marker")
  db.ledger[#db.ledger + 1] = { t = 1002, kind = "death", guid = "E2", zone = "Duskwood", ctxKind = "world" }
  Book.open("nemeses", "E2")
  local avenged = false
  for _, label in ipairs(book.rightPage.pool.FontString) do
    if label:IsShown() and label:GetText() == "Avenged" then avenged = true end
  end
  check(not avenged, "later death removes avenged marker")
  Book.open("settings")
  book.rightPage.erase:Click()
  check(env.popup == "TOMEOFVENGEANCE_RESET" and ns.App.db == db, "erase uses shared confirmation")
  if retail then
    check(env.settingsCategory and env.settingsRegistered, "Retail Settings launcher registered")
    env.settingsCategory.panel.launch:Click()
    check(book.section == "settings", "Settings launcher opens page")
  end
  env.SlashCmdList.TOMEOFVENGEANCE("reset")
  check(ns.App.db == db and db.total.kills == kills, "reset requires confirmation")
  env.StaticPopupDialogs.TOMEOFVENGEANCE_RESET.OnAccept()
  check(ns.App.db.total.kills == 0 and ns.App.db == env.TomeOfVengeanceDB, "confirmed reset")
  check(ns.UI.Minimap.button:IsShown(), "reset restores minimap default")
  check(book.leftPage.controls.minimap:GetChecked(), "reset refreshes visible controls")
  book.leftPage.controls.sound:Click()
  check(not ns.App.db.settings.sound and db.settings.sound == false, "controls use replacement database after reset")
  env.SlashCmdList.TOMEOFVENGEANCE("debug")
  check(env.messages[#env.messages]:find("CLEU registered: yes", 1, true), "debug registration")

  local identity = ns.Compat.who("E1", "Fizz-Away")
  check(identity.raceID == 7 and identity.faction == "Alliance" and identity.className == "Mage", "identity metadata")

  env.IsInInstance = function() return true, "pvp" end
  check(ns.Compat.context().kind == "battleground", "battleground context")
  env.IsInInstance = function() return true, "arena" end
  check(ns.Compat.context().kind == "arena", "arena context")

  ns.Compat.playSound("MISSING")
  check(env.sounds[1][1] == 8959 and env.sounds[1][2] == "Master", "sound fallback")

  env.GetPlayerInfoByGUID = nil
  identity = ns.Compat.who("E3", "Uncached-Away")
  check(identity.name == "Uncached" and identity.realm == "Away" and identity.raceFile == nil, "missing lookup API")

  env.GetPlayerInfoByGUID = function() error("uncached API error") end
  check(pcall(env.fire, "COMBAT_LOG_EVENT_UNFILTERED"), "handler errors contained")

  env.GetClientDisplayExpansionLevel = nil
  env.GetBuildInfo = function() return "1.60", "", "", 16001 end
  check(ns.Compat.expansion() == 0, "Forever expansion fallback")

  env.GetBuildInfo = function() return "5.5", "", "", 50504 end
  check(ns.Compat.expansion() == 4, "Classic expansion fallback")

  env.PlaySound = function() error("sound unavailable") end
  check(pcall(ns.Compat.playSound, "MISSING"), "sound errors contained")

  print("PASS smoke " .. (retail and "Retail" or "Classic"))
end
print("2 smoke profiles passed, 0 failed")
