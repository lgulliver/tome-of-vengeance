local _, ns = ...

ns.Data = ns.Data or {}

local Sounds = {}

-- Curated shortlists per alert kind. Each key must exist in SOUNDKIT on every
-- supported client; any missing key falls back to 8959 at runtime via
-- ns.Compat.playSound.
Sounds.LIST = {
  unlock = {
    { key = "READY_CHECK", label = "Ready check" },
    { key = "UI_BATTLEGROUND_COUNTDOWN_FINISHED", label = "Battleground countdown" },
  },
  title = {
    { key = "PVP_THROUGH_QUEUE", label = "PvP queue ready" },
    { key = "RAID_WARNING", label = "Raid warning" },
  },
  nemesis = {
    { key = "RAID_WARNING", label = "Raid warning" },
    { key = "ALARM_CLOCK_WARNING_3", label = "Alarm clock" },
    { key = "READY_CHECK", label = "Ready check" },
  },
}

function Sounds.forKind(kind, settings)
  local list = Sounds.LIST[kind] or Sounds.LIST.nemesis
  local chosen = settings.sounds and settings.sounds[kind]
  if chosen then
    for _, entry in ipairs(list) do
      if entry.key == chosen then return chosen end
    end
  end
  return list[1].key
end

ns.Data.Sounds = Sounds
