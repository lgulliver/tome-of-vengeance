local ns, T = ...

local function ctx(now)
  return { now = now or 100, kind = "world", zone = "Duskwood", char = "Me-R", faction = "Horde" }
end

local function kill(db, race, class, now)
  return ns.Record.kill(db, { guid = "G1", name = "Fizz", raceFile = race, classFile = class }, ctx(now))
end

local function title(anns, name)
  for _, ann in ipairs(anns) do
    if ann.kind == "title" and ann.title == name then return ann end
  end
end

T.test("gnome_10_override", function()
  local db = ns.Store.migrate({})
  for _ = 1, 9 do kill(db, "Gnome") end
  T.eq(title(kill(db, "Gnome", nil, 200), "Gnome Punter"), {
    kind = "title", header = "Tome of Vengeance Unlocked", title = "Gnome Punter", reason = "10 Gnomes slain",
  })
  T.eq(db.titles["race:Gnome:10"], 200)
  T.eq(ns.Titles.name("race:Gnome:10"), "Gnome Punter")
end)

T.test("template_used_without_override", function()
  local db = ns.Store.migrate({})
  for _ = 1, 9 do kill(db, "Human") end
  T.eq(title(kill(db, "Human"), "Human Hunter").reason, "10 Humans slain")
  T.eq(ns.Titles.name("race:Human:10"), "Human Hunter")
end)

T.test("tier_not_repeated", function()
  local db = ns.Store.migrate({})
  for _ = 1, 10 do kill(db, "Gnome") end
  T.eq(kill(db, "Gnome", nil, 201), {})
  T.eq(db.titles["race:Gnome:10"], 100)
end)

T.test("overall_first_blood", function()
  local db = ns.Store.migrate({})
  T.eq(kill(db, "Gnome"), {
    { kind = "unlock", header = "Tome of Vengeance Unlocked", title = "Gnomes", reason = "First Gnome slain" },
    { kind = "title", header = "Tome of Vengeance Unlocked", title = "Blooded", reason = "First foe slain" },
  })
  T.eq(db.titles["total:1"], 100)
  T.eq(ns.Titles.name("total:1"), "Blooded")
end)

T.test("revenge_within_5min", function()
  for _, elapsed in ipairs({ 0, 299, 300 }) do
    local db = ns.Store.migrate({})
    ns.Record.death(db, { guid = "G1", name = "Fizz" }, ctx(0))
    T.eq(title(kill(db, nil, nil, elapsed), "Vengeance Is Mine").reason, "Avenged yourself on Fizz")
    T.eq(db.titles["special:revenge"], elapsed)
    T.eq(title(kill(db, nil, nil, elapsed), "Vengeance Is Mine"), nil)
  end
end)

T.test("revenge_too_late", function()
  local db = ns.Store.migrate({})
  ns.Record.death(db, { guid = "G1", name = "Fizz" }, ctx(0))
  T.eq(title(kill(db, nil, nil, 301), "Vengeance Is Mine"), nil)
  T.eq(db.titles["special:revenge"], nil)
end)

T.test("nemesis_slayer", function()
  local db = ns.Store.migrate({})
  for _ = 1, 3 do ns.Record.death(db, { guid = "G1", name = "Fizz" }, ctx(0)) end
  db.players.G1.kills = 2
  -- Becoming even on this kill must still earn the pre-kill nemesis title.
  T.eq(title(kill(db, nil, nil, 402), "Nemesis Slayer").reason, "Slew your nemesis Fizz")
  T.eq(db.titles["special:nemesis"], 402)
  T.eq(title(kill(db, nil, nil, 403), "Nemesis Slayer"), nil)
end)

T.test("nemesis_custom_threshold", function()
  local db = ns.Store.migrate({ settings = { nemesisThreshold = 5 } })
  for _ = 1, 4 do ns.Record.death(db, { guid = "G1", name = "Fizz" }, ctx(0)) end
  T.eq(title(kill(db, nil, nil, 400), "Nemesis Slayer"), nil)
  ns.Record.death(db, { guid = "G1", name = "Fizz" }, ctx(0))
  T.ok(title(kill(db, nil, nil, 400), "Nemesis Slayer"))
end)

T.test("progress_next_tier", function()
  local db = ns.Store.migrate({})
  for _ = 1, 211 do kill(db, "Gnome") end
  local count, tier, name = ns.Titles.progress(db, "race", "Gnome")
  T.eq({ count, tier, name }, { 211, 250, "Bane of the Tinkerers" })
end)

T.test("progress_empty_and_complete", function()
  local db = ns.Store.migrate({})
  local count, tier, name = ns.Titles.progress(db, "class", "MAGE")
  T.eq({ count, tier, name }, { 0, 10, "Mage Hunter" })
  count, tier, name = ns.Titles.progress(db, "total")
  T.eq({ count, tier, name }, { 0, 1, "Blooded" })
  db.races.Gnome = { kills = 1000, deaths = 0 }
  count, tier, name = ns.Titles.progress(db, "race", "Gnome")
  T.eq(count, 1000)
  T.eq(tier, nil)
  T.eq(name, nil)
end)

T.test("all_templates_and_overall_tiers", function()
  local db = ns.Store.migrate({})
  local rec = { raceFile = "Human", classFile = "MAGE", name = "Fizz" }
  db.races.Human = { kills = 1000 }
  db.classes.MAGE = { kills = 1000 }
  db.total.kills = 1000
  local anns = ns.Titles.evaluate(db, rec, ctx(0), false)
  T.eq(#anns, 19)
  T.eq(ns.Titles.evaluate(db, rec, ctx(1), false), {})
  local names = { "Human Hunter", "Human Slayer", "Scourge of the Humans", "Bane of the Humans",
    "Human Reaper", "Doom of the Humans" }
  for i, n in ipairs({ 10, 50, 100, 250, 500, 1000 }) do
    T.eq(ns.Titles.name("race:Human:" .. n), names[i])
    T.eq(db.titles["class:MAGE:" .. n], 0)
  end
  for i, name in ipairs({ "Blooded", "Skirmisher", "Raider", "Warmonger", "Butcher", "Warlord",
    "Avatar of Vengeance" }) do
    T.eq(anns[12 + i].title, name)
  end
  T.eq(title(anns, "Mage Hunter").reason, "1000 Mages slain")
end)

T.test("unknown_identity_only_earns_overall", function()
  local db = ns.Store.migrate({})
  local anns = kill(db)
  T.eq(#anns, 1)
  T.eq(anns[1].title, "Blooded")
  T.eq(db.titles, { ["total:1"] = 100 })
end)
