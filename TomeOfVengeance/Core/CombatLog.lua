local _, ns = ...

local band = (bit or require("bit")).band
local CombatLog = {}
CombatLog.FLAGS = {
  TYPE_PLAYER = 0x400, TYPE_PET = 0x1000, TYPE_GUARDIAN = 0x2000,
  CONTROL_PLAYER = 0x100, REACTION_HOSTILE = 0x40, AFFILIATION_MINE = 0x1,
}
local F = CombatLog.FLAGS
local hostilePlayer = F.TYPE_PLAYER + F.CONTROL_PLAYER + F.REACTION_HOSTILE
local damage = {
  SWING_DAMAGE = true, RANGE_DAMAGE = true, SPELL_DAMAGE = true,
  SPELL_PERIODIC_DAMAGE = true, SPELL_BUILDING_DAMAGE = true,
}
local strings = { "subevent", "sourceGUID", "sourceName", "destGUID", "destName" }

function CombatLog.new(opts)
  return {
    playerGUID = opts.playerGUID, isSecret = opts.isSecret,
    attribution = ns.Attribution.new(opts.window),
    engageWindow = opts.engageWindow or 15, engaged = {},
  }
end

function CombatLog.handle(state, ev, clock)
  if type(ev) ~= "table" then return end
  -- Check every value before comparing, indexing, or doing bit arithmetic.
  if state.isSecret then
    for _, value in pairs(ev) do
      if state.isSecret(value) then return end
    end
  end
  for _, key in ipairs(strings) do
    if type(ev[key]) ~= "string" or ev[key] == "" then return end
  end
  if type(ev.sourceFlags) ~= "number" or type(ev.destFlags) ~= "number" then return end

  if ev.subevent == "PARTY_KILL" then
    if ev.destName == state.duel then return end
    local ownSummon = band(ev.sourceFlags, F.AFFILIATION_MINE) ~= 0
      and band(ev.sourceFlags, F.TYPE_PET + F.TYPE_GUARDIAN) ~= 0
    if (ev.sourceGUID == state.playerGUID or ownSummon)
      and band(ev.destFlags, hostilePlayer) == hostilePlayer then
      return { kind = "kill", who = { guid = ev.destGUID, name = ev.destName } }
    end
  elseif damage[ev.subevent] and ev.destGUID == state.playerGUID
    and ev.sourceName ~= state.duel and band(ev.sourceFlags, hostilePlayer) == hostilePlayer then
    state.attribution:note(clock, ev.sourceGUID, ev.sourceName)
  end
end

function CombatLog.onPlayerDeath(state, clock)
  local guid, name = state.attribution:killer(clock)
  state.attribution:reset()
  if guid then return { kind = "death", who = { guid = guid, name = name } } end
end

local function usable(state, value)
  return type(value) == "string" and value ~= "" and not (state.isSecret and state.isSecret(value))
end

-- Without the combat log nothing names the killing blow, so any engaged
-- hostile player who dies counts as a kill.
function CombatLog.engage(state, guid, name, clock)
  if not usable(state, guid) then return end
  for other, entry in pairs(state.engaged) do
    if clock - entry.clock > state.engageWindow then state.engaged[other] = nil end
  end
  state.engaged[guid] = { name = name, clock = clock }
end

function CombatLog.onUnitDied(state, guid, clock)
  if not usable(state, guid) or guid == state.playerGUID then return end
  local entry = state.engaged[guid]
  state.engaged[guid] = nil
  if not entry or clock - entry.clock > state.engageWindow then return end
  if entry.name and entry.name == state.duel then return end
  return { kind = "kill", who = { guid = guid, name = entry.name } }
end

-- Death recap events carry combat-log fields even where the combat log itself is restricted.
function CombatLog.fromRecap(state, events)
  state.attribution:reset()
  if type(events) ~= "table" or (state.isSecret and state.isSecret(events)) then return end
  local best
  for _, ev in pairs(events) do
    if type(ev) == "table" and usable(state, ev.sourceGUID) and usable(state, ev.sourceName)
      and type(ev.sourceFlags) == "number" and type(ev.timestamp) == "number"
      and not (state.isSecret and (state.isSecret(ev.sourceFlags) or state.isSecret(ev.timestamp)))
      and band(ev.sourceFlags, hostilePlayer) == hostilePlayer and ev.sourceName ~= state.duel
      and (not best or ev.timestamp > best.timestamp) then
      best = ev
    end
  end
  if best then return { kind = "death", who = { guid = best.sourceGUID, name = best.sourceName } } end
end

function CombatLog.setDuel(state, opponentName)
  if state.duel then state.attribution:drop(state.duel) end
  state.duel = opponentName
end

ns.CombatLog = CombatLog
