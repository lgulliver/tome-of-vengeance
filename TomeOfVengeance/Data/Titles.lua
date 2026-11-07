local _, ns = ...

ns.Data = ns.Data or {}
ns.Data.Titles = {
  TIERS = { 10, 50, 100, 250, 500, 1000 },
  TEMPLATES = {
    "%s Hunter", "%s Slayer", "Scourge of the %s", "Bane of the %s", "%s Reaper", "Doom of the %s",
  },
  OVERRIDES = {
    Gnome = { [10] = "Gnome Punter", [100] = "Scourge of Gnomeregan", [250] = "Bane of the Tinkerers" },
    Tauren = { [10] = "Beef Collector" },
    Goblin = { [50] = "Profit Warning" },
    ROGUE = { [100] = "End of the Sneak Preview" },
  },
  OVERALL = {
    { n = 1, id = "total:1", name = "Blooded" },
    { n = 10, id = "total:10", name = "Skirmisher" },
    { n = 50, id = "total:50", name = "Raider" },
    { n = 100, id = "total:100", name = "Warmonger" },
    { n = 250, id = "total:250", name = "Butcher" },
    { n = 500, id = "total:500", name = "Warlord" },
    { n = 1000, id = "total:1000", name = "Avatar of Vengeance" },
  },
  SPECIAL = { nemesis = "Nemesis Slayer", revenge = "Vengeance Is Mine" },
}
