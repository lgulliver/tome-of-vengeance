local ns, T = ...
local ENEMY = 0x540
local MYPET = 0x1001

local function mk(sub, srcGUID, srcFlags, dstGUID, dstFlags)
  return {
    subevent = sub, sourceGUID = srcGUID, sourceName = srcGUID == "ME" and "Me" or "Duelist",
    sourceFlags = srcFlags, destGUID = dstGUID, destName = "Enemy", destFlags = dstFlags,
  }
end

local function state(opts)
  return ns.CombatLog.new(opts or { playerGUID = "ME" })
end

T.test("own_killing_blow", function()
  local r = ns.CombatLog.handle(state(), mk("PARTY_KILL", "ME", 0x511, "E1", ENEMY), 1)
  T.eq(r, { kind = "kill", who = { guid = "E1", name = "Enemy" } })
end)

T.test("pet_killing_blow_counts", function()
  local r = ns.CombatLog.handle(state(), mk("PARTY_KILL", "PET1", MYPET, "E1", ENEMY), 1)
  T.eq(r.who.guid, "E1")
end)

T.test("guardian_killing_blow_counts", function()
  local r = ns.CombatLog.handle(state(), mk("PARTY_KILL", "GUARD", 0x2001, "E1", ENEMY), 1)
  T.eq(r.kind, "kill")
end)

T.test("groupmate_killing_blow_ignored", function()
  T.eq(ns.CombatLog.handle(state(), mk("PARTY_KILL", "ALLY", 0x514, "E1", ENEMY), 1), nil)
end)

T.test("other_pet_and_mine_nonpet_ignored", function()
  for _, flags in ipairs({ 0x1002, 0x2002, 0x511 }) do
    T.eq(ns.CombatLog.handle(state(), mk("PARTY_KILL", "OTHER", flags, "E1", ENEMY), 1), nil)
  end
end)

T.test("hostile_pet_not_a_kill", function()
  T.eq(ns.CombatLog.handle(state(), mk("PARTY_KILL", "ME", 0x511, "PET", 0x1140), 1), nil)
end)

T.test("hostile_npc_not_a_kill", function()
  for _, flags in ipairs({ 0x840, 0x940, 0x2140, 0x440, 0x510 }) do
    T.eq(ns.CombatLog.handle(state(), mk("PARTY_KILL", "ME", 0x511, "NPC", flags), 1), nil)
  end
end)

T.test("secret_field_skipped", function()
  local ev = mk("PARTY_KILL", "ME", 0x511, "E1", ENEMY)
  ev.extra = {}
  for field, value in pairs(ev) do
    local s = state({ playerGUID = "ME", isSecret = function(v) return rawequal(v, value) end })
    local ok, result = pcall(ns.CombatLog.handle, s, ev, 1)
    T.ok(ok, field)
    T.eq(result, nil, field)
    T.eq(ns.CombatLog.onPlayerDeath(s, 2), nil)
  end
end)

T.test("missing_or_malformed_field_skipped", function()
  for _, field in ipairs({ "subevent", "sourceGUID", "sourceName", "sourceFlags", "destGUID", "destName", "destFlags" }) do
    for _, invalid in ipairs({ false, {} }) do
      local ev = mk("PARTY_KILL", "ME", 0x511, "E1", ENEMY)
      ev[field] = invalid
      T.eq(ns.CombatLog.handle(state(), ev, 1), nil, field)
    end
    local ev = mk("PARTY_KILL", "ME", 0x511, "E1", ENEMY)
    ev[field] = nil
    T.eq(ns.CombatLog.handle(state(), ev, 1), nil, field)
  end
end)

T.test("death_last_hostile_in_window", function()
  local s = state()
  T.eq(ns.CombatLog.handle(s, mk("SWING_DAMAGE", "E1", ENEMY, "ME", 0x511), 1), nil)
  local ev = mk("SPELL_DAMAGE", "E2", ENEMY, "ME", 0x511)
  ev.sourceName = "Second"
  T.eq(ns.CombatLog.handle(s, ev, 5), nil)
  T.eq(ns.CombatLog.onPlayerDeath(s, 10), { kind = "death", who = { guid = "E2", name = "Second" } })
end)

T.test("all_damage_subevents_attribute", function()
  for _, sub in ipairs({ "SWING_DAMAGE", "RANGE_DAMAGE", "SPELL_DAMAGE", "SPELL_PERIODIC_DAMAGE", "SPELL_BUILDING_DAMAGE" }) do
    local s = state()
    T.eq(ns.CombatLog.handle(s, mk(sub, "E1", ENEMY, "ME", 0x511), 1), nil)
    T.eq(ns.CombatLog.onPlayerDeath(s, 2).who.guid, "E1", sub)
  end
end)

T.test("nonhostile_nonplayer_other_target_and_nondamage_ignored", function()
  for _, ev in ipairs({
    mk("SPELL_DAMAGE", "E1", 0x510, "ME", 0x511),
    mk("SPELL_DAMAGE", "E1", 0x1140, "ME", 0x511),
    mk("SPELL_DAMAGE", "E1", 0x440, "ME", 0x511),
    mk("SPELL_DAMAGE", "E1", ENEMY, "ALLY", 0x511),
    mk("SPELL_MISSED", "E1", ENEMY, "ME", 0x511),
  }) do
    local s = state()
    T.eq(ns.CombatLog.handle(s, ev, 1), nil)
    T.eq(ns.CombatLog.onPlayerDeath(s, 2), nil)
  end
end)

T.test("death_outside_window_not_recorded", function()
  local s = state()
  ns.CombatLog.handle(s, mk("SWING_DAMAGE", "E1", ENEMY, "ME", 0x511), 1)
  T.eq(ns.CombatLog.onPlayerDeath(s, 14), nil)
end)

T.test("death_at_window_boundary_recorded", function()
  local s = state()
  ns.CombatLog.handle(s, mk("SWING_DAMAGE", "E1", ENEMY, "ME", 0x511), 1)
  T.eq(ns.CombatLog.onPlayerDeath(s, 13).who.guid, "E1")
end)

T.test("custom_window", function()
  local s = state({ playerGUID = "ME", window = 2 })
  ns.CombatLog.handle(s, mk("SWING_DAMAGE", "E1", ENEMY, "ME", 0x511), 1)
  T.eq(ns.CombatLog.onPlayerDeath(s, 4), nil)
end)

T.test("death_no_hits_nil", function()
  T.eq(ns.CombatLog.onPlayerDeath(state(), 1), nil)
end)

T.test("buffer_cleared_after_death", function()
  local s = state()
  ns.CombatLog.handle(s, mk("SWING_DAMAGE", "E1", ENEMY, "ME", 0x511), 1)
  T.eq(ns.CombatLog.onPlayerDeath(s, 2).who.guid, "E1")
  T.eq(ns.CombatLog.onPlayerDeath(s, 3), nil)
end)

T.test("duel_opponent_ignored", function()
  local s = state()
  ns.CombatLog.setDuel(s, "Duelist")
  ns.CombatLog.handle(s, mk("SWING_DAMAGE", "E1", ENEMY, "ME", 0x511), 1)
  ns.CombatLog.setDuel(s, nil)
  T.eq(ns.CombatLog.onPlayerDeath(s, 2), nil)
end)

T.test("duel_kill_not_counted", function()
  local s = state()
  ns.CombatLog.setDuel(s, "Enemy")
  T.eq(ns.CombatLog.handle(s, mk("PARTY_KILL", "ME", 0x511, "E1", ENEMY), 1), nil)
end)

T.test("duel_end_discards_preexisting_hits_preserves_other_attackers", function()
  local s = state()
  local ev = mk("SWING_DAMAGE", "E2", ENEMY, "ME", 0x511)
  ev.sourceName = "Other"
  ns.CombatLog.handle(s, ev, 1)
  ns.CombatLog.handle(s, mk("SWING_DAMAGE", "E1", ENEMY, "ME", 0x511), 2)
  ns.CombatLog.setDuel(s, "Duelist")
  ns.CombatLog.setDuel(s, nil)
  T.eq(ns.CombatLog.onPlayerDeath(s, 3).who.guid, "E2")
end)

T.test("attribution_drop_reset_and_expiry", function()
  local a = ns.Attribution.new(12)
  a:note(1, "E1", "First")
  a:note(2, "E2", "Second")
  a:note(3, "E3", "Second")
  a:drop("Second")
  local guid, name = a:killer(4)
  T.eq(guid, "E1")
  T.eq(name, "First")
  T.eq(a:killer(14), nil)
  a:note(15, "E4", "Fourth")
  a:reset()
  T.eq(a:killer(16), nil)
end)
