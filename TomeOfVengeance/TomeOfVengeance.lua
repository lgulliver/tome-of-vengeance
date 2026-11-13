local addon, ns = ...

local App = {}
ns.App = App
local C = ns.Compat
local frame = CreateFrame("Frame")
local combat, sightings, cleuRegistered = nil, {}, false
local names, purgedAt = {}, 0

function App.announce(anns)
  for _, ann in ipairs(anns or {}) do
    if ns.UI and ns.UI.Toast and ns.UI.Toast.show then pcall(ns.UI.Toast.show, ann) end
  end
end

function App.toggle()
  if ns.UI and ns.UI.Book then pcall(ns.UI.Book.toggle) end
end

local function short(name)
  if not name then return end
  if Ambiguate then return Ambiguate(name, "short") end
  return name:match("^[^-]+")
end

local function clock()
  return GetTime and GetTime() or 0
end

local function sight(guid, now)
  local ann = ns.Nemesis.sighted(App.db, sightings, guid, now or clock())
  if ann then App.announce({ ann }) end
end

local function unitSight(unit)
  if not UnitIsPlayer or not UnitCanAttack or not UnitIsPlayer(unit) or not UnitCanAttack("player", unit) then return end
  local guid = UnitGUID and UnitGUID(unit)
  if not guid or C.isSecret(guid) then return end
  local who = C.who(guid, UnitName and UnitName(unit))
  C.enrich(who, unit)
  ns.Store.player(App.db, who, C.context())
  ns.CombatLog.engage(combat, guid, who.name, clock())
  sight(guid)
end

local function recapEvents()
  if not C_DeathRecap or not C_DeathRecap.GetRecapEvents then return end
  local link = GetDeathRecapLink and GetDeathRecapLink()
  local id = type(link) == "string" and not C.isSecret(link) and tonumber(link:match("death:(%d+)"))
  return C_DeathRecap.GetRecapEvents(id)
end

local function recordDeath(result, ctx)
  local entry = names[result.who.guid]
  App.announce(ns.Record.death(App.db, C.who(result.who.guid, entry and entry.name or result.who.name), ctx))
end

-- The recap can fill in a moment after death.
local function recapDeath(retry)
  local ctx = C.context()
  local result = ns.CombatLog.fromRecap(combat, recapEvents())
  if result then return recordDeath(result, ctx) end
  if retry and C_Timer and C_Timer.After then C_Timer.After(1, function() pcall(recapDeath, false) end) end
end

local function handle(event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= addon or App.db then return end
    TomeOfVengeanceDB = ns.Store.migrate(TomeOfVengeanceDB or {})
    App.db = TomeOfVengeanceDB
    combat = ns.CombatLog.new({ playerGUID = C.playerGUID(), isSecret = C.isSecret, window = 12 })
    if ns.UI and ns.UI.Book and ns.UI.Book.create then ns.UI.Book.create() end
    if ns.UI and ns.UI.Minimap then ns.UI.Minimap.create() end
    if ns.UI and ns.UI.Settings then ns.UI.Settings.create() end
    return
  end
  if not App.db then return end
  if event == "PLAYER_LOGIN" then
    combat.playerGUID = C.playerGUID()
    local faction = C.context().faction
    if faction then App.db.factionsSeen[faction] = true end
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    if not CombatLogGetCurrentEventInfo then return end
    local values = { CombatLogGetCurrentEventInfo() }
    for _, value in pairs(values) do if C.isSecret(value) then return end end
    local ev = {
      subevent = values[2], sourceGUID = values[4], sourceName = values[5], sourceFlags = values[6],
      destGUID = values[8], destName = values[9], destFlags = values[10],
    }
    -- Core compares duel names exactly; both client sources need the same form.
    local sourceName, destName = ev.sourceName, ev.destName
    ev.sourceName, ev.destName = short(sourceName), short(destName)
    -- CLEU fires constantly in battlegrounds; build the full context only when recording.
    local now = clock()
    -- Keep full fallback identities while Core uses short names for duel matching.
    if now - purgedAt > 12 then
      for guid, entry in pairs(names) do
        if now - entry.clock > 12 then names[guid] = nil end
      end
      purgedAt = now
    end
    if type(ev.sourceGUID) == "string" and type(sourceName) == "string" then
      local entry = names[ev.sourceGUID]
      if entry then entry.name, entry.clock = sourceName, now
      else names[ev.sourceGUID] = { name = sourceName, clock = now } end
    end
    local result = ns.CombatLog.handle(combat, ev, now)
    if result then App.announce(ns.Record.kill(App.db, C.who(result.who.guid, destName), C.context())) end
    local F = ns.CombatLog.FLAGS
    local hostilePlayer = F.TYPE_PLAYER + F.CONTROL_PLAYER + F.REACTION_HOSTILE
    for _, party in ipairs({ "source", "dest" }) do
      local flags, guid = ev[party .. "Flags"], ev[party .. "GUID"]
      if type(flags) == "number" and bit.band(flags, hostilePlayer) == hostilePlayer and guid then sight(guid, now) end
    end
  elseif event == "PLAYER_DEAD" then
    if cleuRegistered then
      local ctx = C.context()
      local result = ns.CombatLog.onPlayerDeath(combat, ctx.clock)
      if result then recordDeath(result, ctx) end
    else
      recapDeath(true)
    end
    names = {}
  elseif event == "UNIT_DIED" then
    local guid = ...
    if C.isSecret(guid) then return end
    -- A long fight against our target outlasts its first sighting.
    if UnitGUID and guid == UnitGUID("target") then unitSight("target") end
    local result = ns.CombatLog.onUnitDied(combat, guid, clock())
    if result then App.announce(ns.Record.kill(App.db, C.who(guid, result.who.name), C.context())) end
  elseif event == "DUEL_REQUESTED" then
    ns.CombatLog.setDuel(combat, short((...)))
  elseif event == "DUEL_FINISHED" then
    ns.CombatLog.setDuel(combat, nil)
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    unitSight((...))
  elseif event == "PLAYER_TARGET_CHANGED" then
    unitSight("target")
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    unitSight("mouseover")
  end
end

frame:SetScript("OnEvent", function(_, event, ...) pcall(handle, event, ...) end)
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "COMBAT_LOG_EVENT_UNFILTERED", "PLAYER_DEAD",
  "DUEL_REQUESTED", "DUEL_FINISHED", "NAME_PLATE_UNIT_ADDED",
  "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT" }) do
  if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then
    pcall(frame.RegisterEvent, frame, event)
  elseif C.combatLogAllowed() then
    cleuRegistered = pcall(frame.RegisterEvent, frame, event)
  end
end
if not cleuRegistered then pcall(frame.RegisterEvent, frame, "UNIT_DIED") end

-- No event names the opponent when we issue the challenge ourselves.
if hooksecurefunc and StartDuel then
  hooksecurefunc("StartDuel", function(unit)
    if combat and unit then ns.CombatLog.setDuel(combat, short(UnitName and UnitName(unit))) end
  end)
end

if StaticPopupDialogs then
  StaticPopupDialogs.TOMEOFVENGEANCE_RESET = {
    text = "Erase every page of the Tome of Vengeance?", button1 = "Erase", button2 = "Cancel",
    timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function()
      TomeOfVengeanceDB = ns.Store.migrate({})
      App.db, sightings, names = TomeOfVengeanceDB, {}, {}
      local faction = C.context().faction
      if faction then App.db.factionsSeen[faction] = true end
      combat = ns.CombatLog.new({ playerGUID = C.playerGUID(), isSecret = C.isSecret, window = 12 })
      if ns.UI and ns.UI.Minimap then ns.UI.Minimap.refresh() end
      if ns.UI and ns.UI.Book and ns.UI.Book.isShown() then ns.UI.Book.open("settings") end
    end,
  }
end

SLASH_TOMEOFVENGEANCE1 = "/tov"
SlashCmdList.TOMEOFVENGEANCE = function(message)
  pcall(function()
    local command = (message or ""):match("^%s*(.-)%s*$"):lower()
    if command == "settings" then
      if ns.UI and ns.UI.Book then ns.UI.Book.open("settings") end
    elseif command == "reset" then
      if StaticPopup_Show then StaticPopup_Show("TOMEOFVENGEANCE_RESET") end
    elseif command == "debug" then
      local count = 0
      for _ in pairs(App.db and App.db.players or {}) do count = count + 1 end
      print("Tome of Vengeance: " .. (C.isRetail() and "Retail" or "Classic/Forever")
        .. ", expansion: " .. C.expansion() .. ", source: " .. (cleuRegistered and "combat log" or "death recap + UNIT_DIED")
        .. ", records: " .. count .. ", kills: " .. (App.db and App.db.total.kills or 0)
        .. ", deaths: " .. (App.db and App.db.total.deaths or 0))
    elseif command == "" then App.toggle() end
  end)
end
TomeOfVengeance_OnCompartmentClick = App.toggle
