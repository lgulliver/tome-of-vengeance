local env = setmetatable({}, { __index = _G })
env.frames, env.messages, env.sounds = {}, {}, {}
env.SlashCmdList, env.StaticPopupDialogs = {}, {}
env.WOW_PROJECT_ID, env.WOW_PROJECT_MAINLINE = 1, 1
env.Settings = {}
env.CreateFrame = function()
  local frame = { events = {}, scripts = {} }
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:SetScript(event, fn) self.scripts[event] = fn end
  setmetatable(frame, { __index = function(_, key)
    if key:match("^[A-Z]") then return function() end end
  end })
  env.frames[#env.frames + 1] = frame
  return frame
end
env.fire = function(event, ...)
  for _, frame in ipairs(env.frames) do
    if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
  end
end
env.CombatLogGetCurrentEventInfo = function() return unpack(env.cleu or {}) end
env.GetClientDisplayExpansionLevel = function() return 11 end
env.GetBuildInfo = function() return "12.0", "", "", 120100 end
env.UnitGUID = function(unit) return unit == "player" and "ME" or "E1" end
env.UnitName = function(unit) return unit == "player" and "Hero" or "Fizz" end
env.GetRealmName = function() return "Home" end
env.UnitFactionGroup = function() return "Horde" end
env.GetPlayerInfoByGUID = function() return "Mage", "MAGE", "Gnome", "Gnome", 2, "Fizz", "Away" end
env.UnitLevel = function() return 60 end
env.GetGuildInfo = function() return "Enemy Guild" end
env.UnitIsVisible = function() return true end
env.UnitIsPlayer = function() return true end
env.UnitCanAttack = function() return true end
env.IsInInstance = function() return false, "none" end
env.GetRealZoneText = function() return "Duskwood" end
env.GetSubZoneText = function() return "Darkshire" end
env.time = function() return 1000 end
env.GetTime = function() return 100 end
env.issecretvalue = function(value) return env.secret ~= nil and value == env.secret end
env.Ambiguate = function(name) return name:match("^[^-]+") end
env.SOUNDKIT = { RAID_WARNING = 8959 }
env.PlaySound = function(id, channel) env.sounds[#env.sounds + 1] = { id, channel } end
env.StaticPopup_Show = function(id) env.popup = id end
env.StartDuel = function() end
env.hooksecurefunc = function(name, fn)
  local orig = env[name]
  env[name] = function(...) orig(...); fn(...) end
end
env.print = function(message) env.messages[#env.messages + 1] = message end
return env
