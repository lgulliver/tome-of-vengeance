local _, ns = ...

local Compat = {}
ns.Compat = Compat

function Compat.isRetail()
  return WOW_PROJECT_ID ~= nil and WOW_PROJECT_MAINLINE ~= nil and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
end

function Compat.expansion()
  if GetClientDisplayExpansionLevel then return GetClientDisplayExpansionLevel() end
  local interface = GetBuildInfo and select(4, GetBuildInfo()) or 10000
  if interface == 16001 then return 0 end
  return math.max(0, math.floor(interface / 10000) - 1)
end

function Compat.playerGUID()
  return UnitGUID and UnitGUID("player")
end

-- Midnight-engine clients (Retail 12.x, Forever) forbid addons from registering
-- the combat log; trying raises the "blocked from an action" popup even under pcall.
function Compat.combatLogAllowed()
  if C_Secrets and C_Secrets.HasSecretRestrictions then
    local ok, restricted = pcall(C_Secrets.HasSecretRestrictions)
    if not ok or restricted then return false end
  end
  return CombatLogGetCurrentEventInfo ~= nil
end

function Compat.isSecret(value)
  return issecretvalue and issecretvalue(value) or false
end

function Compat.who(guid, fallbackName)
  local who = { guid = guid }
  if fallbackName then
    who.name, who.realm = fallbackName:match("^([^-]+)%-(.+)$")
    who.name = who.name or fallbackName
  end
  if GetPlayerInfoByGUID then
    local className, classFile, raceName, raceFile, _, name, realm = GetPlayerInfoByGUID(guid)
    who.className, who.classFile = className, classFile
    who.raceName, who.raceFile = raceName, raceFile
    who.name = name or who.name
    if realm and realm ~= "" then who.realm = realm end
    local race = ns.Roster.race(raceFile)
    if race then who.raceID, who.faction = race.raceID, race.faction end
  end
  return who
end

function Compat.enrich(who, unit)
  if not UnitIsVisible or not UnitIsVisible(unit) then return end
  if UnitLevel then who.level = UnitLevel(unit) end
  if GetGuildInfo then who.guild = GetGuildInfo(unit) end
end

function Compat.context()
  local _, instance = nil, nil
  if IsInInstance then _, instance = IsInInstance() end
  local name, realm
  if UnitName then name, realm = UnitName("player") end
  if not realm or realm == "" then realm = GetRealmName and GetRealmName() end
  return {
    now = time and time() or 0, clock = GetTime and GetTime() or 0,
    kind = instance == "arena" and "arena" or instance == "pvp" and "battleground" or "world",
    zone = GetRealZoneText and GetRealZoneText() or "",
    subzone = GetSubZoneText and GetSubZoneText() or "",
    char = ns.Store.charKey(name or "", realm or ""),
    faction = UnitFactionGroup and UnitFactionGroup("player"),
  }
end

function Compat.playSound(key)
  pcall(function()
    if PlaySound then PlaySound(SOUNDKIT and SOUNDKIT[key] or 8959, "Master") end
  end)
end
