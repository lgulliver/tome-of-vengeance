local _, ns = ...

local Titles = {}
local data = ns.Data.Titles
local names = {}

local function entryName(entry, key, index, tier)
  local overrides = data.OVERRIDES[key]
  if overrides and overrides[tier] then return overrides[tier] end
  local noun = (index == 1 or index == 2 or index == 5) and entry.singular or entry.plural
  return string.format(data.TEMPLATES[index], noun)
end

for _, group in ipairs({ { "race", ns.Data.Races }, { "class", ns.Data.Classes } }) do
  for _, entry in ipairs(group[2]) do
    local key = entry.raceFile or entry.classFile
    for i, tier in ipairs(data.TIERS) do
      names[group[1] .. ":" .. key .. ":" .. tier] = entryName(entry, key, i, tier)
    end
  end
end
for _, tier in ipairs(data.OVERALL) do names[tier.id] = tier.name end
for key, name in pairs(data.SPECIAL) do names["special:" .. key] = name end

function Titles.name(id)
  return names[id] or id
end

local function earn(db, anns, id, reason, now)
  if db.titles[id] ~= nil then return end
  db.titles[id] = now
  anns[#anns + 1] = {
    kind = "title", header = "Tome of Vengeance Unlocked", title = Titles.name(id), reason = reason,
  }
end

local function evaluateEntry(db, anns, kind, key, entry, counts, now)
  if not entry or not counts then return end
  for _, tier in ipairs(data.TIERS) do
    if counts.kills >= tier then
      earn(db, anns, kind .. ":" .. key .. ":" .. tier, counts.kills .. " " .. entry.plural .. " slain", now)
    end
  end
end

function Titles.evaluate(db, rec, ctx, wasNemesis)
  local anns = {}
  evaluateEntry(db, anns, "race", rec.raceFile, ns.Roster.race(rec.raceFile), db.races[rec.raceFile], ctx.now)
  evaluateEntry(db, anns, "class", rec.classFile, ns.Roster.class(rec.classFile), db.classes[rec.classFile], ctx.now)
  for _, tier in ipairs(data.OVERALL) do
    if db.total.kills >= tier.n then
      earn(db, anns, tier.id, tier.n == 1 and "First foe slain" or db.total.kills .. " foes slain", ctx.now)
    end
  end
  local name = rec.name or "Unknown"
  if wasNemesis then earn(db, anns, "special:nemesis", "Slew your nemesis " .. name, ctx.now) end
  if rec.killedMeAt and ctx.now - rec.killedMeAt <= 300 then
    earn(db, anns, "special:revenge", "Avenged yourself on " .. name, ctx.now)
  end
  return anns
end

function Titles.progress(db, kind, key)
  local counts, tiers
  if kind == "total" then
    counts, tiers = db.total, data.OVERALL
  elseif kind == "race" then
    counts, tiers = db.races[key], data.TIERS
  elseif kind == "class" then
    counts, tiers = db.classes[key], data.TIERS
  else
    return 0, nil, nil
  end
  local count = counts and counts.kills or 0
  for _, tier in ipairs(tiers) do
    local n = kind == "total" and tier.n or tier
    if count < n then
      local id = kind == "total" and tier.id or kind .. ":" .. key .. ":" .. n
      return count, n, Titles.name(id)
    end
  end
  return count, nil, nil
end

ns.Titles = Titles
