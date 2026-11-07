local _, ns = ...

ns.Data = ns.Data or {}

-- Faction-flexible races share one token; use one representative raceID per entry.
ns.Data.Races = {
  { raceFile = "Human", raceID = 1, faction = "Alliance", since = 0, singular = "Human", plural = "Humans" },
  { raceFile = "Orc", raceID = 2, faction = "Horde", since = 0, singular = "Orc", plural = "Orcs" },
  { raceFile = "Dwarf", raceID = 3, faction = "Alliance", since = 0, singular = "Dwarf", plural = "Dwarves" },
  { raceFile = "NightElf", raceID = 4, faction = "Alliance", since = 0, singular = "Night Elf", plural = "Night Elves" },
  { raceFile = "Scourge", raceID = 5, faction = "Horde", since = 0, singular = "Undead", plural = "Undead" },
  { raceFile = "Tauren", raceID = 6, faction = "Horde", since = 0, singular = "Tauren", plural = "Tauren" },
  { raceFile = "Gnome", raceID = 7, faction = "Alliance", since = 0, singular = "Gnome", plural = "Gnomes" },
  { raceFile = "Troll", raceID = 8, faction = "Horde", since = 0, singular = "Troll", plural = "Trolls" },
  { raceFile = "BloodElf", raceID = 10, faction = "Horde", since = 1, singular = "Blood Elf", plural = "Blood Elves" },
  { raceFile = "Draenei", raceID = 11, faction = "Alliance", since = 1, singular = "Draenei", plural = "Draenei" },
  { raceFile = "Goblin", raceID = 9, faction = "Horde", since = 3, singular = "Goblin", plural = "Goblins" },
  { raceFile = "Worgen", raceID = 22, faction = "Alliance", since = 3, singular = "Worgen", plural = "Worgen" },
  { raceFile = "Pandaren", raceID = 24, faction = "Neutral", since = 4, singular = "Pandaren", plural = "Pandaren" },
  -- These four allied races became playable during Legion (7.3.5).
  { raceFile = "Nightborne", raceID = 27, faction = "Horde", since = 6, singular = "Nightborne", plural = "Nightborne" },
  { raceFile = "HighmountainTauren", raceID = 28, faction = "Horde", since = 6, singular = "Highmountain Tauren", plural = "Highmountain Tauren" },
  { raceFile = "VoidElf", raceID = 29, faction = "Alliance", since = 6, singular = "Void Elf", plural = "Void Elves" },
  { raceFile = "LightforgedDraenei", raceID = 30, faction = "Alliance", since = 6, singular = "Lightforged Draenei", plural = "Lightforged Draenei" },
  { raceFile = "ZandalariTroll", raceID = 31, faction = "Horde", since = 7, singular = "Zandalari Troll", plural = "Zandalari Trolls" },
  { raceFile = "KulTiran", raceID = 32, faction = "Alliance", since = 7, singular = "Kul Tiran", plural = "Kul Tirans" },
  { raceFile = "DarkIronDwarf", raceID = 34, faction = "Alliance", since = 7, singular = "Dark Iron Dwarf", plural = "Dark Iron Dwarves" },
  { raceFile = "Vulpera", raceID = 35, faction = "Horde", since = 7, singular = "Vulpera", plural = "Vulpera" },
  { raceFile = "MagharOrc", raceID = 36, faction = "Horde", since = 7, singular = "Mag'har Orc", plural = "Mag'har Orcs" },
  { raceFile = "Mechagnome", raceID = 37, faction = "Alliance", since = 7, singular = "Mechagnome", plural = "Mechagnomes" },
  { raceFile = "Dracthyr", raceID = 52, faction = "Neutral", since = 9, singular = "Dracthyr", plural = "Dracthyr" },
  { raceFile = "EarthenDwarf", raceID = 84, faction = "Neutral", since = 10, singular = "Earthen", plural = "Earthen" },
  { raceFile = "Harronir", raceID = 86, faction = "Neutral", since = 11, singular = "Haranir", plural = "Haranir" },
}
