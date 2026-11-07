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

function CombatLog.setDuel(state, opponentName)
  if state.duel then state.attribution:drop(state.duel) end
  state.duel = opponentName
end

ns.CombatLog = CombatLog
