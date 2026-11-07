local _, ns = ...

local Store = {}

Store.DEFAULTS = {
  version = 1,
  settings = {
    alerts = true, sound = true, nemesisThreshold = 3, minimap = true,
    sounds = { unlock = "LEVEL_UP", title = "PVP_THROUGH_QUEUE", nemesis = "RAID_WARNING" },
  },
  players = {}, races = {}, classes = {}, total = { kills = 0, deaths = 0 },
  titles = {}, ledger = {}, factionsSeen = {},
}

local function fillMissing(target, defaults)
  for key, value in pairs(defaults) do
    if target[key] == nil then
      if type(value) == "table" then
        target[key] = {}
        fillMissing(target[key], value)
      else
        target[key] = value
      end
    elseif type(target[key]) == "table" and type(value) == "table" then
      fillMissing(target[key], value)
    end
  end
end

function Store.migrate(db)
  db = db or {}
  fillMissing(db, Store.DEFAULTS)
  db.version = 1
  return db
end

local identityFields = { "name", "realm", "raceFile", "raceID", "classFile", "faction", "level", "guild" }

function Store.player(db, who, ctx)
  local rec = db.players[who.guid]
  if not rec then
    rec = {
      kills = 0, deaths = 0,
      ctx = { world = { k = 0, d = 0 }, battleground = { k = 0, d = 0 }, arena = { k = 0, d = 0 } },
      chars = {}, first = { t = ctx.now, zone = ctx.zone },
    }
    db.players[who.guid] = rec
  end
  for _, key in ipairs(identityFields) do
    if who[key] ~= nil then rec[key] = who[key] end
  end
  rec.last = { t = ctx.now, zone = ctx.zone }
  return rec
end

function Store.charKey(name, realm)
  return name .. "-" .. realm
end

ns.Store = Store
