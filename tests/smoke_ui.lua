-- Headless glue smoke. Book remains stubbed; Toast is the real module.
local function check(value, message) assert(value, message) end
local function near(a, b) return math.abs(a - b) < 0.01 end

for _, retail in ipairs({ true, false }) do
  local env = dofile("tests/wow_stub.lua")
  if not retail then
    env.WOW_PROJECT_ID = 2
    env.issecretvalue = nil
    env.Settings = nil
  end

  local recorded, sounds = {}, {}
  local shown, section = false, nil
  local ns = { UI = {
    Book = {
      create = function() end,
      toggle = function() shown = not shown end,
      open = function(id) shown, section = true, id end,
      isShown = function() return shown end,
    },
  } }

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

  db.players.E1.deaths = 3
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
  check(shown, "slash toggles")
  env.TomeOfVengeance_OnCompartmentClick()
  check(not shown, "compartment toggles")
  env.SlashCmdList.TOMEOFVENGEANCE("settings")
  check(section == "settings", "settings opens")
  env.SlashCmdList.TOMEOFVENGEANCE("reset")
  check(ns.App.db == db and db.total.kills == kills, "reset requires confirmation")
  env.StaticPopupDialogs.TOMEOFVENGEANCE_RESET.OnAccept()
  check(ns.App.db.total.kills == 0 and ns.App.db == env.TomeOfVengeanceDB, "confirmed reset")
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
