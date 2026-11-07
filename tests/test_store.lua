local ns, T = ...

T.test("migrate_fills_defaults", function()
  local db = ns.Store.migrate({})
  T.eq(db.version, 1)
  T.eq(db.settings, {
    alerts = true, sound = true, nemesisThreshold = 3, minimap = true,
    sounds = { unlock = "LEVEL_UP", title = "PVP_THROUGH_QUEUE", nemesis = "RAID_WARNING" },
  })
  T.eq(db.total, { kills = 0, deaths = 0 })
  for _, key in ipairs({ "players", "races", "classes", "titles", "ledger", "factionsSeen" }) do
    T.eq(db[key], {})
  end
  T.eq(db.activeTitle, nil)
end)

T.test("migrate_keeps_existing", function()
  local db = { settings = { nemesisThreshold = 5, alerts = false, sounds = { title = "CUSTOM" } },
    total = { kills = 9, deaths = 1 }, activeTitle = "earned", players = { G1 = { kills = 4 } } }
  T.ok(rawequal(ns.Store.migrate(db), db))
  T.eq(db.settings.nemesisThreshold, 5)
  T.eq(db.settings.alerts, false)
  T.eq(db.settings.sound, true)
  T.eq(db.settings.sounds.title, "CUSTOM")
  T.eq(db.settings.sounds.unlock, "LEVEL_UP")
  T.eq(db.total, { kills = 9, deaths = 1 })
  T.eq(db.players.G1.kills, 4)
  T.eq(db.activeTitle, "earned")
  local settings = db.settings
  T.ok(rawequal(ns.Store.migrate(db), db))
  T.ok(rawequal(db.settings, settings))
end)

T.test("migrate_defaults_are_independent", function()
  local a, b = ns.Store.migrate(nil), ns.Store.migrate({})
  a.settings.sounds.title = "CUSTOM"
  a.ledger[1] = { t = 1 }
  T.eq(b.settings.sounds.title, "PVP_THROUGH_QUEUE")
  T.eq(ns.Store.DEFAULTS.settings.sounds.title, "PVP_THROUGH_QUEUE")
  T.eq(b.ledger, {})
end)

T.test("player_create_and_backfill", function()
  local db = ns.Store.migrate({})
  local r = ns.Store.player(db, { guid = "G1", name = "Fizz" }, { now = 100, zone = "Duskwood" })
  T.eq(r.raceFile, nil)
  T.eq(r.first, { t = 100, zone = "Duskwood" })
  T.eq(r.kills, 0)
  T.eq(r.deaths, 0)
  T.eq(r.ctx, { world = { k = 0, d = 0 }, battleground = { k = 0, d = 0 }, arena = { k = 0, d = 0 } })
  T.eq(r.chars, {})
  local updated = ns.Store.player(db, { guid = "G1", raceFile = "Gnome", classFile = "MAGE",
    realm = "Stormrage", raceID = 7, faction = "Alliance", level = 60, guild = "Guild" },
    { now = 200, zone = "Elwynn Forest" })
  T.ok(rawequal(r, updated))
  T.eq(r.name, "Fizz")
  T.eq(r.raceFile, "Gnome")
  T.eq(r.classFile, "MAGE")
  T.eq(r.realm, "Stormrage")
  T.eq(r.raceID, 7)
  T.eq(r.faction, "Alliance")
  T.eq(r.level, 60)
  T.eq(r.guild, "Guild")
  T.eq(r.last, { t = 200, zone = "Elwynn Forest" })
  T.eq(r.first, { t = 100, zone = "Duskwood" })
  r.kills = 3
  ns.Store.player(db, { guid = "G1", name = "Renamed" }, { now = 300 })
  T.eq(r.name, "Renamed")
  T.eq(r.raceFile, "Gnome")
  T.eq(r.kills, 3)
  T.eq(r.last, { t = 300 })
end)

T.test("same_name_different_guid", function()
  local db = ns.Store.migrate({})
  local a = ns.Store.player(db, { guid = "G1", name = "Bob", realm = "A" }, { now = 1 })
  local b = ns.Store.player(db, { guid = "G2", name = "Bob", realm = "B" }, { now = 1 })
  T.ok(not rawequal(a, b))
  a.ctx.world.k = 1
  a.chars["Me-R"] = { k = 1, d = 0 }
  T.eq(b.ctx.world.k, 0)
  T.eq(b.chars, {})
end)

T.test("char_key", function()
  T.eq(ns.Store.charKey("Me", "Stormrage"), "Me-Stormrage")
end)
