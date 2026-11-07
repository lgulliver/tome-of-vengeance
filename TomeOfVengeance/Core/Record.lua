local _, ns = ...

local Record = { LEDGER_MAX = 200 }

local function credit(entries, file, entry, displayName, field, now, anns)
  if not file or not entry then return end
  local counts = entries[file]
  if not counts then
    counts = { kills = 0, deaths = 0 }
    entries[file] = counts
  end
  counts[field] = counts[field] + 1
  if field == "kills" and counts.unlockedAt == nil then
    counts.unlockedAt = now
    anns[#anns + 1] = {
      kind = "unlock",
      header = "Tome of Vengeance Unlocked",
      title = displayName or entry.plural,
      reason = "First " .. entry.singular .. " slain",
    }
  end
end

local function record(db, who, ctx, kind, field, counter)
  local rec = ns.Store.player(db, who, ctx)
  local anns = {}
  rec[field] = rec[field] + 1
  rec.ctx[ctx.kind][counter] = rec.ctx[ctx.kind][counter] + 1
  local char = rec.chars[ctx.char]
  if not char then
    char = { k = 0, d = 0 }
    rec.chars[ctx.char] = char
  end
  char[counter] = char[counter] + 1
  db.total[field] = db.total[field] + 1
  -- Neutral Pandaren on the Wandering Isle have no faction yet.
  if ctx.faction then db.factionsSeen[ctx.faction] = true end
  credit(db.races, rec.raceFile, ns.Roster.race(rec.raceFile), who.raceName, field, ctx.now, anns)
  credit(db.classes, rec.classFile, ns.Roster.class(rec.classFile), who.className, field, ctx.now, anns)
  if kind == "death" then rec.killedMeAt = ctx.now end
  db.ledger[#db.ledger + 1] = {
    t = ctx.now, kind = kind, guid = who.guid, zone = ctx.zone, ctxKind = ctx.kind,
  }
  while #db.ledger > Record.LEDGER_MAX do table.remove(db.ledger, 1) end
  return anns
end

function Record.kill(db, who, ctx)
  return record(db, who, ctx, "kill", "kills", "k")
end

function Record.death(db, who, ctx)
  return record(db, who, ctx, "death", "deaths", "d")
end

ns.Record = Record
