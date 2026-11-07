local ns, T = ...

local function database(threshold)
  return ns.Store.migrate({ settings = { nemesisThreshold = threshold or 3 } })
end

T.test("threshold_boundary", function()
  T.eq(ns.Nemesis.is({ deaths = 2, kills = 0 }, 3), false)
  T.eq(ns.Nemesis.is({ deaths = 3, kills = 0 }, 3), true)
end)

T.test("evened_score_not_nemesis", function()
  T.eq(ns.Nemesis.is({ deaths = 3, kills = 3 }, 3), false)
  T.eq(ns.Nemesis.is({ deaths = 3, kills = 4 }, 3), false)
end)

T.test("custom_threshold", function()
  local db, state = database(5), {}
  db.players.G1 = { name = "Fizz", deaths = 4, kills = 0 }
  T.eq(ns.Nemesis.list(db), {})
  T.eq(ns.Nemesis.sighted(db, state, "G1", 0), nil)
  T.eq(state, {})
  db.players.G1.deaths = 5
  T.eq(#ns.Nemesis.list(db), 1)
  T.ok(ns.Nemesis.sighted(db, state, "G1", 0))
end)

T.test("sighted_throttled", function()
  local db, state = database(), {}
  db.players.G1 = { name = "Fizz", deaths = 3, kills = 0 }
  local expected = { kind = "nemesis", header = "Nemesis Sighted", title = "Fizz",
    reason = "Has slain you 3 times" }
  T.eq(ns.Nemesis.THROTTLE, 300)
  T.eq(ns.Nemesis.sighted(db, state, "G1", 0), expected)
  T.eq(state.G1, 0)
  T.eq(ns.Nemesis.sighted(db, state, "G1", 299), nil)
  T.eq(state.G1, 0)
  T.eq(ns.Nemesis.sighted(db, state, "G1", 300), expected)
  T.eq(state.G1, 300)
end)

T.test("sighted_throttle_per_guid_and_session", function()
  local db, state = database(), {}
  db.players.G1 = { name = "Fizz", deaths = 3, kills = 0 }
  db.players.G2 = { name = "Bob", deaths = 4, kills = 1 }
  T.ok(ns.Nemesis.sighted(db, state, "G1", 10))
  T.ok(ns.Nemesis.sighted(db, state, "G2", 11))
  T.ok(ns.Nemesis.sighted(db, {}, "G1", 12))
end)

T.test("alerts_off", function()
  local db, state = database(), {}
  db.players.G1 = { name = "Fizz", deaths = 3, kills = 0 }
  db.settings.alerts = false
  T.eq(ns.Nemesis.sighted(db, state, "G1", 0), nil)
  T.eq(state, {})
  T.eq(#ns.Nemesis.list(db), 1)
  db.settings.alerts = true
  T.ok(ns.Nemesis.sighted(db, state, "G1", 1))
end)

T.test("sighted_unknown_or_evened_score", function()
  local db, state = database(), {}
  db.players.G1 = { name = "Fizz", deaths = 3, kills = 3 }
  T.eq(ns.Nemesis.sighted(db, state, "unknown", 0), nil)
  T.eq(ns.Nemesis.sighted(db, state, "G1", 0), nil)
  T.eq(state, {})
end)

T.test("list_sorted", function()
  local db = database()
  db.players.G1 = { name = "Zed", deaths = 3, kills = 1 }
  db.players.G2 = { name = "Amy", deaths = 3, kills = 0 }
  db.players.G3 = { name = "Bob", deaths = 5, kills = 2 }
  db.players.G4 = { name = "Even", deaths = 5, kills = 5 }
  db.players.G5 = { name = "Below", deaths = 2, kills = 0 }
  local list = ns.Nemesis.list(db)
  T.eq(#list, 3)
  T.eq({ list[1].guid, list[2].guid, list[3].guid }, { "G3", "G2", "G1" })
  T.ok(rawequal(list[1], db.players.G3))
  T.eq(ns.Nemesis.list(database()), {})
end)
