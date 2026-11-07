local env = setmetatable({}, { __index = _G })
env.frames, env.messages, env.sounds = {}, {}, {}
env.SlashCmdList, env.StaticPopupDialogs = {}, {}
env.WOW_PROJECT_ID, env.WOW_PROJECT_MAINLINE = 1, 1
env.Settings = {}
env.UISpecialFrames = {}
env.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }

local clock = 100
local noop = function() end

-- Frame object model --------------------------------------------------------

local methods = {}
local objects = {}

local mt = {
  __index = function(t, k)
    local m = methods[k]
    if m then return m end
    if type(k) == "string" and k:find("^[A-Z]") then return noop end
    return nil
  end,
}

local function newObject(kind, parent)
  local o = {
    _kind = kind, _parent = parent, _children = {},
    _shown = false, _alpha = 1, _scale = 1,
    _level = (parent and parent._level or 0) + 1,
    _w = 0, _h = 0,
    _scripts = {}, _hooks = {}, _events = {}, _points = {},
  }
  setmetatable(o, mt)
  objects[#objects + 1] = o
  if parent then parent._children[#parent._children + 1] = o end
  return o
end

-- UIParent ------------------------------------------------------------------

local UIParent = newObject("Frame", nil)
UIParent._w, UIParent._h = 1920, 1080
UIParent._scale = 1
UIParent._shown = true
UIParent._level = 0
env.UIParent = UIParent

-- Font stubs ----------------------------------------------------------------

local function newFont(name)
  return {
    _name = name,
    _path = "Fonts\\FRIZQT__.TTF", _size = 12, _flags = "",
    SetFont = function(self, path, size, flags)
      self._path, self._size, self._flags = path, size, flags or ""
    end,
    GetFont = function(self)
      return self._path, self._size, self._flags
    end,
  }
end

env.GameFontNormal = newFont("GameFontNormal")
env.CreateFont = function(name)
  local f = newFont(name)
  rawset(env, name, f)
  return f
end

local function runScript(self, name, ...)
  local fn = self._scripts[name]
  if fn then fn(self, ...) end
  local hooks = self._hooks[name]
  if hooks then
    for _, h in ipairs(hooks) do h(self, ...) end
  end
end

methods.SetScript = function(self, name, fn) self._scripts[name] = fn end
methods.GetScript = function(self, name) return self._scripts[name] end
methods.HookScript = function(self, name, fn)
  self._hooks[name] = self._hooks[name] or {}
  table.insert(self._hooks[name], fn)
end
methods.Show = function(self)
  if not self._shown then
    self._shown = true
    runScript(self, "OnShow")
  end
end
methods.Hide = function(self)
  if self._shown then
    self._shown = false
    runScript(self, "OnHide")
  end
end
methods.SetShown = function(self, shown) if shown then self:Show() else self:Hide() end end
methods.IsShown = function(self) return self._shown end
methods.SetAlpha = function(self, a) self._alpha = a end
methods.GetAlpha = function(self) return self._alpha end
methods.SetScale = function(self, s) self._scale = s end
methods.GetScale = function(self) return self._scale end
methods.EnableMouse = function(self, on) self._mouse = on end
methods.SetFrameStrata = function(self, s) self._strata = s end
methods.GetFrameStrata = function(self) return self._strata or "MEDIUM" end
methods.SetFrameLevel = function(self, n) self._level = n end
methods.GetFrameLevel = function(self) return self._level end
methods.SetParent = function(self, parent) self._parent = parent end
methods.GetParent = function(self) return self._parent end

methods.SetPoint = function(self, point, rel, relPoint, x, y)
  if type(rel) == "number" then
    rel, relPoint, x, y = nil, nil, rel, relPoint
  elseif type(relPoint) == "number" then
    relPoint, x, y = nil, relPoint, x
  end
  local entry = { point, rel or self._parent, relPoint or point, x or 0, y or 0 }
  for i, p in ipairs(self._points) do
    if p[1] == point then
      self._points[i] = entry
      return
    end
  end
  self._points[#self._points + 1] = entry
end
methods.ClearAllPoints = function(self) self._points = {} end
methods.SetAllPoints = function(self, rel)
  self._points = {
    { "TOPLEFT", rel or self._parent, "TOPLEFT", 0, 0 },
    { "BOTTOMRIGHT", rel or self._parent, "BOTTOMRIGHT", 0, 0 },
  }
end
methods.GetName = function(self) return self._name end
methods.GetPoint = function(self, i) return unpack(self._points[i or 1]) end
methods.SetScrollChild = function(self, child) self._scrollChild = child end
methods.SetVerticalScroll = function(self, value) self._scroll = value end
methods.GetVerticalScroll = function(self) return self._scroll or 0 end
methods.GetVerticalScrollRange = function(self) return math.max(0, self._scrollChild:GetHeight() - 420) end
methods.Click = function(self) runScript(self, "OnClick") end
methods.GetNumPoints = function(self) return #self._points end
methods.SetSize = function(self, w, h) self._w, self._h = w, h end
methods.SetWidth = function(self, w) self._w = w end
methods.SetHeight = function(self, h) self._h = h end
methods.GetWidth = function(self) return self._w end
methods.GetHeight = function(self) return self._h end
methods.GetSize = function(self) return self._w, self._h end
methods.GetEffectiveScale = function(self)
  if self == UIParent then return UIParent._scale end
  return self._scale * (self._parent and self._parent:GetEffectiveScale() or UIParent._scale)
end

methods.RegisterEvent = function(self, event) self._events[event] = true end
methods.UnregisterEvent = function(self, event) self._events[event] = nil end

methods.CreateTexture = function(self, name)
  local t = newObject("Texture", self)
  t._texture = nil
  t._color = nil
  t._vertex = { 1, 1, 1, 1 }
  t.SetTexture = function(self_, tex) self_._texture = tex end
  t.GetTexture = function(self_) return self_._texture end
  t.SetColorTexture = function(self_, r, g, b, a)
    self_._color = { r, g, b, a == nil and 1 or a }
  end
  t.SetVertexColor = function(self_, r, g, b, a)
    self_._vertex = { r, g, b, a == nil and 1 or a }
  end
  t.GetVertexColor = function(self_)
    return self_._vertex[1], self_._vertex[2], self_._vertex[3], self_._vertex[4]
  end
  t.SetTexCoord = function() end
  return t
end

methods.CreateFontString = function(self, name, layer, template)
  local fs = newObject("FontString", self)
  fs._fontTemplate = template
  fs._text = ""
  fs._textColor = { 1, 1, 1, 1 }
  fs._fontObject = nil
  fs.SetText = function(self_, t) self_._text = t end
  fs.GetText = function(self_) return self_._text end
  fs.SetTextColor = function(self_, r, g, b, a)
    self_._textColor = { r, g, b, a == nil and 1 or a }
  end
  fs.GetTextColor = function(self_)
    return self_._textColor[1], self_._textColor[2], self_._textColor[3], self_._textColor[4]
  end
  fs.SetFontObject = function(self_, obj) self_._fontObject = obj end
  fs.GetFontObject = function(self_) return self_._fontObject end
  fs.SetJustifyH = function(self_, j) self_._justify = j end
  fs.GetStringWidth = function(self_) return #(self_._text or "") * 6 end
  return fs
end

env.CreateFrame = function(kind, name, parent, template)
  local f = newObject(kind or "Frame", parent or UIParent)
  f._template = template
  f._name = name
  -- Preserve the field names used by the older minimal stub.
  f.events = f._events
  f.scripts = f._scripts
  if name then rawset(env, name, f) end
  env.frames[#env.frames + 1] = f
  return f
end

env.fire = function(event, ...)
  local snapshot = {}
  for i, f in ipairs(env.frames) do snapshot[i] = f end
  for _, f in ipairs(snapshot) do
    if f._events[event] and f._scripts.OnEvent then
      f._scripts.OnEvent(f, event, ...)
    end
  end
end

env.advance = function(seconds)
  local snapshot = {}
  for i, f in ipairs(objects) do snapshot[i] = f end
  for _, f in ipairs(snapshot) do
    if f._scripts.OnUpdate and f._shown then
      f._scripts.OnUpdate(f, seconds)
    end
  end
end

-- WoW API stubs --------------------------------------------------------------

env.CombatLogGetCurrentEventInfo = function() return unpack(env.cleu or {}) end
env.GetClientDisplayExpansionLevel = function() return 11 end
env.GetBuildInfo = function() return "12.0", "", "", 120100 end
env.UnitGUID = function(unit) return unit == "player" and "ME" or "E1" end
env.UnitName = function(unit) return unit == "player" and "Hero" or "Fizz" end
env.GetRealmName = function() return "Home" end
env.UnitFactionGroup = function() return "Horde" end
env.GetPlayerInfoByGUID = function()
  return "Mage", "MAGE", "Gnome", "Gnome", 2, "Fizz", "Away"
end
env.UnitLevel = function() return 60 end
env.GetGuildInfo = function() return "Enemy Guild" end
env.UnitIsVisible = function() return true end
env.UnitIsPlayer = function() return true end
env.UnitCanAttack = function() return true end
env.IsInInstance = function() return false, "none" end
env.GetRealZoneText = function() return "Duskwood" end
env.GetSubZoneText = function() return "Darkshire" end
env.time = function() return 1000 end
env.GetTime = function() return clock end
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
