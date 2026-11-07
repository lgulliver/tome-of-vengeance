local ns, T = ...

local function context(now, kind, char, faction)
  return { now = now or 100, kind = kind or "world", zone = "Duskwood",
    char = char or "Me-R", faction = faction or "Horde" }
end

local function enemy()
  return { guid = "G1", name = "Fizz", realm = "Stormrage", raceFile = "Gnome", classFile = "MAGE" }
end

T.test("kill_counts_everywhere", function()
  local db = ns.Store.migrate({})
  ns.Record.kill(db, enemy(), context())
  local rec = db.players.G1
  T.eq(db.total, { kills = 1, deaths = 0 })
  T.eq(rec.kills, 1)
  T.eq(rec.deaths, 0)
  T.eq(rec.ctx.world, { k = 1, d = 0 })
  T.eq(rec.chars["Me-R"], { k = 1, d = 0 })
  T.eq(db.races.Gnome, { kills = 1, deaths = 0, unlockedAt = 100 })
  T.eq(db.classes.MAGE, { kills = 1, deaths = 0, unlockedAt = 100 })
  T.eq(db.factionsSeen, { Horde = true })
  T.eq(db.ledger, { { t = 100, kind = "kill", guid = "G1", zone = "Duskwood", ctxKind = "world" } })
  T.eq(rec.first, { t = 100, zone = "Duskwood" })
  T.eq(rec.last, { t = 100, zone = "Duskwood" })
end)

T.test("first_kill_unlocks_once", function()
  local db = ns.Store.migrate({})
  T.eq(ns.Record.kill(db, { guid = "G1", raceFile = "Gnome" }, context(0)), {
    { kind = "unlock", header = "Tome of Vengeance Unlocked", title = "Gnomes", reason = "First Gnome slain" },
  })
  T.eq(ns.Record.kill(db, { guid = "G2", raceFile = "Gnome" }, context(200)), {})
  T.eq(db.races.Gnome.unlockedAt, 0)
  T.eq(db.races.Gnome.kills, 2)
end)

T.test("class_unlock_uses_localized_display_names", function()
  local db = ns.Store.migrate({})
  local who = enemy()
  who.raceName, who.className = "Localized Gnome", "Localized Mage"
  T.eq(ns.Record.kill(db, who, context()), {
    { kind = "unlock", header = "Tome of Vengeance Unlocked", title = "Localized Gnome",
      reason = "First Gnome slain" },
    { kind = "unlock", header = "Tome of Vengeance Unlocked", title = "Localized Mage",
      reason = "First Mage slain" },
  })
  T.eq(ns.Record.kill(db, who, context(200)), {})
end)

T.test("class_unlock_falls_back_to_plural", function()
  local db = ns.Store.migrate({})
  T.eq(ns.Record.kill(db, { guid = "G1", classFile = "MAGE" }, context()), {
    { kind = "unlock", header = "Tome of Vengeance Unlocked", title = "Mages", reason = "First Mage slain" },
  })
end)

T.test("unknown_race_no_credit", function()
  local db = ns.Store.migrate({})
  T.eq(ns.Record.kill(db, { guid = "G1", name = "Fizz" }, context()), {})
  T.eq(db.players.G1.name, "Fizz")
  T.eq(db.players.G1.kills, 1)
  T.eq(db.total.kills, 1)
  T.eq(db.races, {})
  T.eq(db.classes, {})
end)

T.test("backfill_does_not_retro_credit", function()
  local db = ns.Store.migrate({})
  ns.Record.kill(db, { guid = "G1", name = "Fizz" }, context())
  ns.Record.death(db, { guid = "G1" }, context(101))
  ns.Store.player(db, enemy(), context(102))
  T.eq(db.races, {})
  T.eq(db.classes, {})
  local anns = ns.Record.kill(db, { guid = "G1" }, context(200))
  T.eq(#anns, 2)
  T.eq(db.players.G1.kills, 2)
  T.eq(db.players.G1.deaths, 1)
  T.eq(db.races.Gnome, { kills = 1, deaths = 0, unlockedAt = 200 })
  T.eq(db.classes.MAGE, { kills = 1, deaths = 0, unlockedAt = 200 })
end)

T.test("death_sets_killedMeAt", function()
  local db = ns.Store.migrate({})
  T.eq(ns.Record.death(db, enemy(), context()), {})
  ns.Record.death(db, enemy(), context(150, "arena", "Alt-R", "Alliance"))
  local rec = db.players.G1
  T.eq(rec.killedMeAt, 150)
  T.eq(rec.kills, 0)
  T.eq(rec.deaths, 2)
  T.eq(rec.ctx.world, { k = 0, d = 1 })
  T.eq(rec.ctx.arena, { k = 0, d = 1 })
  T.eq(rec.chars, { ["Me-R"] = { k = 0, d = 1 }, ["Alt-R"] = { k = 0, d = 1 } })
  T.eq(db.total, { kills = 0, deaths = 2 })
  T.eq(db.races.Gnome, { kills = 0, deaths = 2 })
  T.eq(db.classes.MAGE, { kills = 0, deaths = 2 })
  T.eq(db.factionsSeen, { Horde = true, Alliance = true })
  T.eq(db.ledger[2], { t = 150, kind = "death", guid = "G1", zone = "Duskwood", ctxKind = "arena" })
  T.eq(rec.first.t, 100)
  T.eq(rec.last.t, 150)
  T.eq(#ns.Record.kill(db, enemy(), context(160)), 2)
  T.eq(rec.killedMeAt, 150)
end)

T.test("ledger_capped", function()
  local db = ns.Store.migrate({})
  for i = 1, 205 do ns.Record.kill(db, { guid = "G1" }, context(i)) end
  T.eq(ns.Record.LEDGER_MAX, 200)
  T.eq(#db.ledger, 200)
  T.eq(db.ledger[1].t, 6)
  T.eq(db.ledger[200].t, 205)
  ns.Record.death(db, { guid = "G1" }, context(206))
  T.eq(#db.ledger, 200)
  T.eq(db.ledger[1].t, 7)
  T.eq(db.ledger[200].kind, "death")
end)

T.test("battleground_context", function()
  local db = ns.Store.migrate({})
  ns.Record.kill(db, enemy(), context(100, "battleground"))
  ns.Record.kill(db, enemy(), context(200, "arena", "Alt-R", "Alliance"))
  T.eq(db.players.G1.ctx, {
    world = { k = 0, d = 0 }, battleground = { k = 1, d = 0 }, arena = { k = 1, d = 0 },
  })
  T.eq(db.players.G1.chars, { ["Me-R"] = { k = 1, d = 0 }, ["Alt-R"] = { k = 1, d = 0 } })
  T.eq(db.total.kills, 2)
  T.eq(db.factionsSeen, { Horde = true, Alliance = true })
end)

T.test("factionless_player_records_kill", function()
  local db = ns.Store.migrate({})
  local ctx = context()
  ctx.faction = nil
  ns.Record.kill(db, enemy(), ctx)
  T.eq(db.total.kills, 1)
  T.eq(db.factionsSeen, {})
end)
