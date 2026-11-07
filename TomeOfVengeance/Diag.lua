local _, ns = ...

-- Temporary probe for Midnight-engine clients: records which kill/death sources
-- exist and what they deliver into TomeOfVengeanceDB.diag. Remove before release.
local Diag = {}
ns.Diag = Diag
local MAX_EVENTS = 30

local function safe(value, depth)
  if issecretvalue and issecretvalue(value) then return "<secret>" end
  local kind = type(value)
  if kind == "table" then
    if (depth or 0) >= 3 then return "<table>" end
    local copy = {}
    for k, v in pairs(value) do copy[tostring(k)] = safe(v, (depth or 0) + 1) end
    return copy
  elseif kind == "function" or kind == "userdata" then
    return "<" .. kind .. ">"
  end
  return value
end

local function try(fn, ...)
  if type(fn) ~= "function" then return "<missing>" end
  local result = { pcall(fn, ...) }
  if not result[1] then return "<error: " .. tostring(result[2]) .. ">" end
  table.remove(result, 1)
  return safe(result)
end

local function keys(t)
  local list = {}
  if type(t) == "table" then
    for k in pairs(t) do list[#list + 1] = tostring(k) end
    table.sort(list)
  end
  return list
end

local function eventValid(event)
  if C_EventUtils and C_EventUtils.IsEventValid then return try(C_EventUtils.IsEventValid, event) end
  return "<unknown>"
end

local function log(kind, payload)
  local diag = ns.App and ns.App.db and ns.App.db.diag
  if not diag then return end
  diag.events[#diag.events + 1] = { t = time and time() or 0, kind = kind, payload = payload }
  while #diag.events > MAX_EVENTS do table.remove(diag.events, 1) end
end

function Diag.snapshot()
  local db = ns.App and ns.App.db
  if not db then return end
  local namespaces = {}
  for name, value in pairs(_G) do
    if type(name) == "string" and type(value) == "table" and name:match("^C_")
      and (name:match("Death") or name:match("PvP") or name:match("Combat") or name:match("Damage")
        or name:match("Secret") or name:match("Honor")) then
      namespaces[name] = keys(value)
    end
  end
  local sounds = {}
  for _, list in pairs(ns.Data.Sounds.LIST) do
    for _, entry in ipairs(list) do sounds[entry.key] = SOUNDKIT and SOUNDKIT[entry.key] or "<nil>" end
  end
  local events = {}
  for _, event in ipairs({ "COMBAT_LOG_EVENT_UNFILTERED", "CHAT_MSG_COMBAT_HONOR_GAIN", "PLAYER_PVP_KILLS_CHANGED",
    "PLAYER_DEAD", "PVP_TIMER_UPDATE", "UNIT_DIED", "PARTY_KILL", "CHAT_MSG_COMBAT_HOSTILE_DEATH" }) do
    events[event] = eventValid(event)
  end
  local existing = db.diag and db.diag.events or {}
  db.diag = {
    build = try(GetBuildInfo),
    projectID = WOW_PROJECT_ID,
    secretRestrictions = C_Secrets and try(C_Secrets.HasSecretRestrictions) or "<no C_Secrets>",
    combatLogInfo = CombatLogGetCurrentEventInfo ~= nil,
    deathRecapLink = GetDeathRecapLink ~= nil,
    pvpLifetime = try(GetPVPLifetimeStats),
    pvpSession = try(GetPVPSessionStats),
    warMode = C_PvP and try(C_PvP.IsWarModeActive) or "<no C_PvP>",
    namespaces = namespaces,
    sounds = sounds,
    events = existing,
    validEvents = events,
    playerRace = try(UnitRace, "player"),
  }
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...)
  local args = { ... }
  pcall(function()
    if event == "PLAYER_LOGIN" then
      Diag.snapshot()
    elseif event == "PLAYER_DEAD" then
      local recap = {
        link = try(GetDeathRecapLink),
        recap = C_DeathRecap and try(C_DeathRecap.GetRecapEvents) or "<no C_DeathRecap>",
      }
      log(event, recap)
      -- The recap can fill in a moment after death.
      if C_Timer and C_Timer.After then
        C_Timer.After(2, function()
          pcall(log, "PLAYER_DEAD+2s", {
            link = try(GetDeathRecapLink),
            recap = C_DeathRecap and try(C_DeathRecap.GetRecapEvents) or "<no C_DeathRecap>",
          })
        end)
      end
    else
      log(event, { args = safe(args), lifetime = try(GetPVPLifetimeStats) })
    end
  end)
end)
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_DEAD", "CHAT_MSG_COMBAT_HONOR_GAIN", "PLAYER_PVP_KILLS_CHANGED" }) do
  pcall(frame.RegisterEvent, frame, event)
end
