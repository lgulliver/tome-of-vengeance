local ns, T = ...

local function raceFiles(expansion, retail, factions)
  local files = {}
  for _, race in ipairs(ns.Roster.races(expansion, retail, factions)) do
    files[#files + 1] = race.raceFile
  end
  return files
end

T.test("classic_horde_sees_alliance", function()
  T.eq(raceFiles(0, false, { Horde = true }), { "Human", "Dwarf", "NightElf", "Gnome" })
end)

T.test("classic_alliance_sees_horde", function()
  T.eq(raceFiles(0, false, { Alliance = true }), { "Orc", "Scourge", "Tauren", "Troll" })
end)

T.test("classic_both_factions_sees_all_eight", function()
  T.eq(#ns.Roster.races(0, false, { Horde = true, Alliance = true }), 8)
end)

T.test("no_faction_empty_even_with_neutral_races", function()
  T.eq(ns.Roster.races(0, false, {}), {})
  T.eq(ns.Roster.races(11, false, {}), {})
  T.eq(ns.Roster.races(11, false, { Horde = false, Alliance = false }), {})
end)

T.test("mists_includes_pandaren_for_alliance", function()
  T.eq(raceFiles(4, false, { Alliance = true }), {
    "Orc", "Scourge", "Tauren", "Troll", "BloodElf", "Goblin", "Pandaren",
  })
end)

T.test("retail_lists_every_race_in_data_order", function()
  T.eq(raceFiles(99, true, { Horde = true }), {
    "Human", "Orc", "Dwarf", "NightElf", "Scourge", "Tauren", "Gnome", "Troll",
    "BloodElf", "Draenei", "Goblin", "Worgen", "Pandaren", "Nightborne",
    "HighmountainTauren", "VoidElf", "LightforgedDraenei", "ZandalariTroll", "KulTiran",
    "DarkIronDwarf", "Vulpera", "MagharOrc", "Mechagnome", "Dracthyr", "EarthenDwarf", "Harronir",
  })
  T.eq(#ns.Roster.races(99, true, {}), #ns.Data.Races)
end)

T.test("race_expansion_boundaries", function()
  local counts = { 8, 10, 10, 12, 13, 13, 17, 23, 23, 24, 25, 26 }
  for expansion = 0, 11 do
    T.eq(#ns.Roster.races(expansion, true, {}), counts[expansion + 1], "expansion " .. expansion)
  end
end)

T.test("faction_flexible_races_visible_to_either_faction", function()
  for _, faction in ipairs({ "Horde", "Alliance" }) do
    local seen = {}
    for _, race in ipairs(ns.Roster.races(11, false, { [faction] = true })) do
      seen[race.raceFile] = true
    end
    for _, token in ipairs({ "Pandaren", "Dracthyr", "EarthenDwarf", "Harronir" }) do
      T.ok(seen[token], token)
      T.eq(ns.Roster.race(token).faction, "Neutral")
    end
  end
end)

T.test("classic_classes", function()
  local files = {}
  for _, class in ipairs(ns.Roster.classes(0)) do files[#files + 1] = class.classFile end
  T.eq(files, { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" })
end)

T.test("class_expansion_boundaries", function()
  local counts = { 9, 9, 10, 10, 11, 11, 12, 12, 12, 13, 13, 13 }
  for expansion = 0, 11 do
    T.eq(#ns.Roster.classes(expansion), counts[expansion + 1], "expansion " .. expansion)
  end
end)

T.test("lookups_return_entries_and_unknown_nil", function()
  T.eq(ns.Roster.race("Scourge"), {
    raceFile = "Scourge", raceID = 5, faction = "Horde", since = 0, singular = "Undead", plural = "Undead",
  })
  T.eq(ns.Roster.race("Harronir").raceID, 86)
  T.eq(ns.Roster.class("DEATHKNIGHT"), {
    classFile = "DEATHKNIGHT", classID = 6, since = 2, singular = "Death Knight", plural = "Death Knights",
  })
  T.eq(ns.Roster.race("Undead"), nil)
  T.eq(ns.Roster.race("unknown"), nil)
  T.eq(ns.Roster.class("mage"), nil)
  T.eq(ns.Roster.class("unknown"), nil)
  T.eq(ns.Roster.race(nil), nil)
  T.eq(ns.Roster.class(nil), nil)
end)

T.test("data_tokens_and_ids_unique_with_complete_title_nouns", function()
  for _, kind in ipairs({ { ns.Data.Races, "raceFile", "raceID" }, { ns.Data.Classes, "classFile", "classID" } }) do
    local tokens, ids = {}, {}
    for _, entry in ipairs(kind[1]) do
      local token, id = entry[kind[2]], entry[kind[3]]
      T.eq(type(token), "string")
      T.eq(type(id), "number")
      T.ok(not tokens[token], token)
      T.ok(not ids[id], token)
      tokens[token], ids[id] = true, true
      T.eq(type(entry.since), "number")
      T.ok(entry.since >= 0 and entry.since <= 11 and entry.since % 1 == 0, token)
      T.eq(type(entry.plural), "string")
      T.eq(type(entry.singular), "string")
      T.ok(#entry.plural > 0 and #entry.singular > 0, token)
    end
  end
end)

T.test("filtered_arrays_do_not_change_data_or_factions", function()
  local factions = { Horde = true }
  local races = ns.Roster.races(0, false, factions)
  table.remove(races, 1)
  T.eq(#ns.Roster.races(0, false, factions), 4)
  local classes = ns.Roster.classes(0)
  table.remove(classes, 1)
  T.eq(#ns.Roster.classes(0), 9)
  T.eq(factions, { Horde = true })
end)
