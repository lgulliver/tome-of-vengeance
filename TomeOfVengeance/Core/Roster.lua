local _, ns = ...

local Roster = {}
local racesByFile, classesByFile = {}, {}

for _, race in ipairs(ns.Data.Races) do racesByFile[race.raceFile] = race end
for _, class in ipairs(ns.Data.Classes) do classesByFile[class.classFile] = class end

function Roster.races(expansion, isRetail, factionsSeen)
  local entries = {}
  if not isRetail and not (factionsSeen.Horde or factionsSeen.Alliance) then return entries end
  for _, race in ipairs(ns.Data.Races) do
    local visible = isRetail or race.faction == "Neutral"
      or (race.faction == "Alliance" and factionsSeen.Horde)
      or (race.faction == "Horde" and factionsSeen.Alliance)
    if race.since <= expansion and visible then entries[#entries + 1] = race end
  end
  return entries
end

function Roster.classes(expansion)
  local entries = {}
  for _, class in ipairs(ns.Data.Classes) do
    if class.since <= expansion then entries[#entries + 1] = class end
  end
  return entries
end

function Roster.race(raceFile)
  return racesByFile[raceFile]
end

function Roster.class(classFile)
  return classesByFile[classFile]
end

ns.Roster = Roster
