local _, ns = ...

local Nemesis = {}
ns.Nemesis = Nemesis

Nemesis.THROTTLE = 300

function Nemesis.is(rec, threshold)
  return rec.deaths >= threshold and rec.kills < rec.deaths
end

function Nemesis.list(db)
  local list = {}
  for guid, rec in pairs(db.players) do
    if Nemesis.is(rec, db.settings.nemesisThreshold) then
      rec.guid = guid
      list[#list + 1] = rec
    end
  end
  table.sort(list, function(a, b)
    if a.deaths ~= b.deaths then return a.deaths > b.deaths end
    return (a.name or "") < (b.name or "")
  end)
  return list
end

function Nemesis.sighted(db, state, guid, now)
  if not db.settings.alerts then return nil end
  local rec = db.players[guid]
  if not rec or not Nemesis.is(rec, db.settings.nemesisThreshold) then return nil end
  local last = state[guid]
  if last ~= nil and now - last < Nemesis.THROTTLE then return nil end
  state[guid] = now
  return {
    kind = "nemesis",
    header = "Nemesis Sighted",
    title = rec.name,
    reason = "Has slain you " .. rec.deaths .. " times",
  }
end
